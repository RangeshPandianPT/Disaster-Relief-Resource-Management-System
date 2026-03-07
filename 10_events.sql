-- ============================================================
-- DISASTER RELIEF RESOURCE MANAGEMENT SYSTEM (DRRMS)
-- Event Scheduler - Automated Database Tasks
-- ============================================================

USE drrms_db;

-- ============================================================
-- EVENT SCHEDULER OVERVIEW
-- ============================================================
-- Events are scheduled tasks that run automatically
-- Similar to cron jobs in Linux or Task Scheduler in Windows
-- Requires: SET GLOBAL event_scheduler = ON;
-- ============================================================

-- Enable the event scheduler (run as admin)
-- SET GLOBAL event_scheduler = ON;

-- Check if event scheduler is running
-- SHOW VARIABLES LIKE 'event_scheduler';

-- ============================================================
-- EVENT 1: Daily Inventory Health Check
-- Runs every day at 6:00 AM to flag low stock items
-- ============================================================
DELIMITER //

CREATE EVENT IF NOT EXISTS evt_daily_inventory_check
ON SCHEDULE EVERY 1 DAY
STARTS (TIMESTAMP(CURRENT_DATE) + INTERVAL 1 DAY + INTERVAL 6 HOUR)
ON COMPLETION PRESERVE
COMMENT 'Daily check for low inventory levels'
DO
BEGIN
    -- Create/update a monitoring table
    CREATE TABLE IF NOT EXISTS Inventory_Alerts (
        alert_id INT AUTO_INCREMENT PRIMARY KEY,
        resource_id INT,
        resource_name VARCHAR(100),
        warehouse_location VARCHAR(100),
        quantity_available INT,
        min_stock INT,
        alert_level VARCHAR(20),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        acknowledged BOOLEAN DEFAULT FALSE
    );
    
    -- Clear old unacknowledged alerts for items that are now stocked
    DELETE FROM Inventory_Alerts 
    WHERE acknowledged = FALSE 
    AND resource_id IN (
        SELECT i.resource_id 
        FROM Inventory i
        INNER JOIN Resource r ON i.resource_id = r.resource_id
        WHERE i.quantity_available >= r.min_stock
    );
    
    -- Insert new alerts for low stock items
    INSERT INTO Inventory_Alerts (resource_id, resource_name, warehouse_location, 
                                  quantity_available, min_stock, alert_level)
    SELECT 
        i.resource_id,
        r.resource_name,
        i.warehouse_location,
        i.quantity_available,
        r.min_stock,
        CASE 
            WHEN i.quantity_available = 0 THEN 'CRITICAL'
            WHEN i.quantity_available < r.min_stock * 0.25 THEN 'HIGH'
            WHEN i.quantity_available < r.min_stock * 0.5 THEN 'MEDIUM'
            ELSE 'LOW'
        END
    FROM Inventory i
    INNER JOIN Resource r ON i.resource_id = r.resource_id
    WHERE i.quantity_available < r.min_stock
    AND NOT EXISTS (
        SELECT 1 FROM Inventory_Alerts ia 
        WHERE ia.resource_id = i.resource_id 
        AND ia.warehouse_location = i.warehouse_location
        AND ia.acknowledged = FALSE
    );
END //

DELIMITER ;

-- ============================================================
-- EVENT 2: Weekly Statistics Summary
-- Runs every Sunday at midnight to generate weekly stats
-- ============================================================
DELIMITER //

CREATE EVENT IF NOT EXISTS evt_weekly_statistics
ON SCHEDULE EVERY 1 WEEK
STARTS (TIMESTAMP(CURRENT_DATE + INTERVAL (6 - WEEKDAY(CURRENT_DATE)) DAY))
ON COMPLETION PRESERVE
COMMENT 'Weekly statistics compilation'
DO
BEGIN
    -- Create statistics archive table
    CREATE TABLE IF NOT EXISTS Weekly_Statistics (
        stat_id INT AUTO_INCREMENT PRIMARY KEY,
        week_start DATE,
        week_end DATE,
        active_disasters INT,
        new_requests INT,
        fulfilled_requests INT,
        total_allocations INT,
        new_donations INT,
        monetary_donations DECIMAL(15,2),
        new_volunteers INT,
        generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Insert weekly statistics
    INSERT INTO Weekly_Statistics (
        week_start, week_end, active_disasters, new_requests,
        fulfilled_requests, total_allocations, new_donations,
        monetary_donations, new_volunteers
    )
    SELECT 
        DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY) AS week_start,
        DATE_SUB(CURRENT_DATE, INTERVAL 1 DAY) AS week_end,
        (SELECT COUNT(*) FROM Disaster WHERE status = 'Active'),
        (SELECT COUNT(*) FROM Request 
         WHERE request_date >= DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)),
        (SELECT COUNT(*) FROM Request 
         WHERE status = 'Fulfilled' 
         AND request_date >= DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)),
        (SELECT COUNT(*) FROM Allocation 
         WHERE allocation_date >= DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)),
        (SELECT COUNT(*) FROM Donation 
         WHERE donation_date >= DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)),
        (SELECT COALESCE(SUM(amount), 0) FROM Donation 
         WHERE donation_type = 'Money' 
         AND donation_date >= DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)),
        (SELECT COUNT(*) FROM Volunteer 
         WHERE registered_at >= DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY));
END //

DELIMITER ;

-- ============================================================
-- EVENT 3: Hourly Delivery Status Check
-- Updates stuck deliveries and sends alerts
-- ============================================================
DELIMITER //

CREATE EVENT IF NOT EXISTS evt_hourly_delivery_check
ON SCHEDULE EVERY 1 HOUR
STARTS (TIMESTAMP(CURRENT_DATE) + INTERVAL 1 HOUR)
ON COMPLETION PRESERVE
COMMENT 'Check for stuck deliveries'
DO
BEGIN
    -- Create delivery alerts table
    CREATE TABLE IF NOT EXISTS Delivery_Alerts (
        alert_id INT AUTO_INCREMENT PRIMARY KEY,
        allocation_id INT,
        request_id INT,
        current_status VARCHAR(20),
        hours_in_status INT,
        alert_type VARCHAR(50),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        resolved BOOLEAN DEFAULT FALSE
    );
    
    -- Flag allocations stuck in 'Dispatched' for more than 24 hours
    INSERT INTO Delivery_Alerts (allocation_id, request_id, current_status, 
                                 hours_in_status, alert_type)
    SELECT 
        a.allocation_id,
        a.request_id,
        a.delivery_status,
        TIMESTAMPDIFF(HOUR, a.allocation_date, NOW()),
        'STUCK_IN_TRANSIT'
    FROM Allocation a
    WHERE a.delivery_status = 'Dispatched'
    AND TIMESTAMPDIFF(HOUR, a.allocation_date, NOW()) > 24
    AND NOT EXISTS (
        SELECT 1 FROM Delivery_Alerts da 
        WHERE da.allocation_id = a.allocation_id AND da.resolved = FALSE
    );
    
    -- Flag allocations in 'In_Transit' for more than 48 hours
    INSERT INTO Delivery_Alerts (allocation_id, request_id, current_status, 
                                 hours_in_status, alert_type)
    SELECT 
        a.allocation_id,
        a.request_id,
        a.delivery_status,
        TIMESTAMPDIFF(HOUR, a.allocation_date, NOW()),
        'DELAYED_DELIVERY'
    FROM Allocation a
    WHERE a.delivery_status = 'In_Transit'
    AND TIMESTAMPDIFF(HOUR, a.allocation_date, NOW()) > 48
    AND NOT EXISTS (
        SELECT 1 FROM Delivery_Alerts da 
        WHERE da.allocation_id = a.allocation_id AND da.resolved = FALSE
    );
END //

DELIMITER ;

-- ============================================================
-- EVENT 4: Monthly Audit Log Cleanup
-- Archives old audit logs to prevent table bloat
-- ============================================================
DELIMITER //

CREATE EVENT IF NOT EXISTS evt_monthly_audit_cleanup
ON SCHEDULE EVERY 1 MONTH
STARTS (TIMESTAMP(LAST_DAY(CURRENT_DATE) + INTERVAL 1 DAY))
ON COMPLETION PRESERVE
COMMENT 'Archive and cleanup old audit logs'
DO
BEGIN
    -- Create archive table if not exists
    CREATE TABLE IF NOT EXISTS Audit_Log_Archive (
        archive_id INT AUTO_INCREMENT PRIMARY KEY,
        original_log_id INT,
        table_name VARCHAR(50),
        record_id INT,
        action_type VARCHAR(20),
        old_values JSON,
        new_values JSON,
        changed_by VARCHAR(100),
        changed_at TIMESTAMP,
        archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Archive logs older than 3 months (if Audit_Log table exists)
    -- Note: Audit_Log is created in 12_audit.sql
    IF EXISTS (SELECT 1 FROM information_schema.tables 
               WHERE table_schema = 'drrms_db' AND table_name = 'Audit_Log') THEN
        
        INSERT INTO Audit_Log_Archive (original_log_id, table_name, record_id,
                                       action_type, old_values, new_values,
                                       changed_by, changed_at)
        SELECT log_id, table_name, record_id, action_type, old_values, 
               new_values, changed_by, changed_at
        FROM Audit_Log
        WHERE changed_at < DATE_SUB(CURRENT_DATE, INTERVAL 3 MONTH);
        
        -- Delete archived records
        DELETE FROM Audit_Log
        WHERE changed_at < DATE_SUB(CURRENT_DATE, INTERVAL 3 MONTH);
    END IF;
END //

DELIMITER ;

-- ============================================================
-- EVENT 5: Daily Volunteer Availability Reset
-- Resets volunteer status for disbanded team members
-- ============================================================
DELIMITER //

CREATE EVENT IF NOT EXISTS evt_daily_volunteer_reset
ON SCHEDULE EVERY 1 DAY
STARTS (TIMESTAMP(CURRENT_DATE) + INTERVAL 1 DAY + INTERVAL 1 HOUR)
ON COMPLETION PRESERVE
COMMENT 'Release volunteers from disbanded teams'
DO
BEGIN
    -- Release volunteers still marked as Busy but in disbanded teams
    UPDATE Volunteer v
    INNER JOIN Relief_Team t ON v.team_id = t.team_id
    SET v.team_id = NULL, 
        v.availability = 'Available'
    WHERE t.status = 'Disbanded'
    AND v.availability = 'Busy';
    
    -- Also release volunteers in resolved disasters
    UPDATE Volunteer v
    INNER JOIN Relief_Team t ON v.team_id = t.team_id
    INNER JOIN Disaster d ON t.disaster_id = d.disaster_id
    SET v.team_id = NULL,
        v.availability = 'Available'
    WHERE d.status = 'Resolved'
    AND v.availability = 'Busy';
END //

DELIMITER ;

-- ============================================================
-- EVENT 6: Request Priority Escalation (Every 6 Hours)
-- Auto-escalates pending requests based on age
-- ============================================================
DELIMITER //

CREATE EVENT IF NOT EXISTS evt_priority_escalation
ON SCHEDULE EVERY 6 HOUR
STARTS (TIMESTAMP(CURRENT_DATE) + INTERVAL 6 HOUR)
ON COMPLETION PRESERVE
COMMENT 'Escalate old pending requests'
DO
BEGIN
    -- Escalate Low -> Medium after 3 days
    UPDATE Request
    SET urgency = 'Medium',
        remarks = CONCAT(COALESCE(remarks, ''), ' [Auto-escalated: ', NOW(), ']')
    WHERE status = 'Pending'
    AND urgency = 'Low'
    AND DATEDIFF(CURDATE(), request_date) > 3;
    
    -- Escalate Medium -> High after 5 days
    UPDATE Request
    SET urgency = 'High',
        remarks = CONCAT(COALESCE(remarks, ''), ' [Auto-escalated: ', NOW(), ']')
    WHERE status = 'Pending'
    AND urgency = 'Medium'
    AND DATEDIFF(CURDATE(), request_date) > 5;
    
    -- Escalate High -> Critical after 7 days
    UPDATE Request
    SET urgency = 'Critical',
        remarks = CONCAT(COALESCE(remarks, ''), ' [Auto-escalated: ', NOW(), ']')
    WHERE status = 'Pending'
    AND urgency = 'High'
    AND DATEDIFF(CURDATE(), request_date) > 7;
END //

DELIMITER ;

-- ============================================================
-- UTILITY: View All Events
-- ============================================================
-- SHOW EVENTS FROM drrms_db;

-- ============================================================
-- UTILITY: Manually Run an Event (for testing)
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_run_event_manually(IN p_event_name VARCHAR(64))
BEGIN
    CASE p_event_name
        WHEN 'inventory_check' THEN
            -- Simulate evt_daily_inventory_check
            SELECT 'Running inventory check...' AS status;
            -- Add the event code here for manual testing
            
        WHEN 'statistics' THEN
            SELECT 'Running statistics generation...' AS status;
            
        WHEN 'delivery_check' THEN
            SELECT 'Running delivery check...' AS status;
            
        ELSE
            SELECT CONCAT('Unknown event: ', p_event_name) AS error;
    END CASE;
END //

DELIMITER ;

-- ============================================================
-- EVENTS CREATED: 6
-- ============================================================
-- 1. evt_daily_inventory_check   - Daily at 6 AM - Low stock alerts
-- 2. evt_weekly_statistics       - Every Sunday - Weekly stats
-- 3. evt_hourly_delivery_check   - Every hour - Stuck deliveries
-- 4. evt_monthly_audit_cleanup   - Monthly - Archive old logs
-- 5. evt_daily_volunteer_reset   - Daily at 1 AM - Release volunteers
-- 6. evt_priority_escalation     - Every 6 hours - Escalate requests
-- ============================================================

-- To enable events:
-- SET GLOBAL event_scheduler = ON;

-- To view events:
-- SHOW EVENTS FROM drrms_db;

-- To disable a specific event:
-- ALTER EVENT evt_daily_inventory_check DISABLE;

-- To drop an event:
-- DROP EVENT IF EXISTS evt_daily_inventory_check;
