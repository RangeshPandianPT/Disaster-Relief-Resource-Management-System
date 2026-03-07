-- ============================================================
-- DISASTER RELIEF RESOURCE MANAGEMENT SYSTEM (DRRMS)
-- Audit Logging - Change Tracking System
-- ============================================================

USE drrms_db;

-- ============================================================
-- AUDIT LOGGING OVERVIEW
-- ============================================================
-- Comprehensive tracking of all changes to critical tables
-- Features:
-- - Captures INSERT, UPDATE, DELETE operations
-- - Stores old and new values as JSON
-- - Records user, timestamp, and session info
-- - Supports compliance and debugging requirements
-- ============================================================

-- ============================================================
-- SECTION 1: AUDIT LOG TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS Audit_Log (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id INT NOT NULL,
    action_type ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    old_values JSON NULL,
    new_values JSON NULL,
    changed_by VARCHAR(100) DEFAULT (CURRENT_USER()),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_id VARCHAR(100) DEFAULT (CONNECTION_ID()),
    client_host VARCHAR(100) DEFAULT NULL,
    
    -- Indexes for efficient querying
    INDEX idx_audit_table (table_name),
    INDEX idx_audit_action (action_type),
    INDEX idx_audit_date (changed_at),
    INDEX idx_audit_record (table_name, record_id)
) ENGINE=InnoDB;

-- ============================================================
-- SECTION 2: AUDIT HELPER FUNCTION
-- ============================================================

DELIMITER //

-- Function to get client info
CREATE FUNCTION fn_get_client_info()
RETURNS VARCHAR(200)
DETERMINISTIC
BEGIN
    RETURN CONCAT('User: ', CURRENT_USER(), ' | Session: ', CONNECTION_ID());
END //

DELIMITER ;

-- ============================================================
-- SECTION 3: AUDIT TRIGGERS FOR ALLOCATION TABLE
-- ============================================================

DELIMITER //

-- Audit INSERT on Allocation
CREATE TRIGGER trg_audit_allocation_insert
AFTER INSERT ON Allocation
FOR EACH ROW
BEGIN
    INSERT INTO Audit_Log (table_name, record_id, action_type, new_values, client_host)
    VALUES (
        'Allocation',
        NEW.allocation_id,
        'INSERT',
        JSON_OBJECT(
            'allocation_id', NEW.allocation_id,
            'request_id', NEW.request_id,
            'inventory_id', NEW.inventory_id,
            'quantity_allocated', NEW.quantity_allocated,
            'delivery_status', NEW.delivery_status,
            'remarks', NEW.remarks
        ),
        (SELECT HOST FROM information_schema.PROCESSLIST WHERE ID = CONNECTION_ID())
    );
END //

-- Audit UPDATE on Allocation
CREATE TRIGGER trg_audit_allocation_update
AFTER UPDATE ON Allocation
FOR EACH ROW
BEGIN
    INSERT INTO Audit_Log (table_name, record_id, action_type, old_values, new_values, client_host)
    VALUES (
        'Allocation',
        NEW.allocation_id,
        'UPDATE',
        JSON_OBJECT(
            'allocation_id', OLD.allocation_id,
            'request_id', OLD.request_id,
            'inventory_id', OLD.inventory_id,
            'quantity_allocated', OLD.quantity_allocated,
            'delivery_status', OLD.delivery_status,
            'delivery_date', OLD.delivery_date,
            'remarks', OLD.remarks
        ),
        JSON_OBJECT(
            'allocation_id', NEW.allocation_id,
            'request_id', NEW.request_id,
            'inventory_id', NEW.inventory_id,
            'quantity_allocated', NEW.quantity_allocated,
            'delivery_status', NEW.delivery_status,
            'delivery_date', NEW.delivery_date,
            'remarks', NEW.remarks
        ),
        (SELECT HOST FROM information_schema.PROCESSLIST WHERE ID = CONNECTION_ID())
    );
END //

-- Audit DELETE on Allocation
CREATE TRIGGER trg_audit_allocation_delete_log
AFTER DELETE ON Allocation
FOR EACH ROW
BEGIN
    INSERT INTO Audit_Log (table_name, record_id, action_type, old_values, client_host)
    VALUES (
        'Allocation',
        OLD.allocation_id,
        'DELETE',
        JSON_OBJECT(
            'allocation_id', OLD.allocation_id,
            'request_id', OLD.request_id,
            'inventory_id', OLD.inventory_id,
            'quantity_allocated', OLD.quantity_allocated,
            'delivery_status', OLD.delivery_status,
            'remarks', OLD.remarks
        ),
        (SELECT HOST FROM information_schema.PROCESSLIST WHERE ID = CONNECTION_ID())
    );
END //

DELIMITER ;

-- ============================================================
-- SECTION 4: AUDIT TRIGGERS FOR REQUEST TABLE
-- ============================================================

DELIMITER //

-- Audit INSERT on Request
CREATE TRIGGER trg_audit_request_insert
AFTER INSERT ON Request
FOR EACH ROW
BEGIN
    INSERT INTO Audit_Log (table_name, record_id, action_type, new_values)
    VALUES (
        'Request',
        NEW.request_id,
        'INSERT',
        JSON_OBJECT(
            'request_id', NEW.request_id,
            'area_id', NEW.area_id,
            'resource_id', NEW.resource_id,
            'quantity_requested', NEW.quantity_requested,
            'urgency', NEW.urgency,
            'status', NEW.status
        )
    );
END //

-- Audit UPDATE on Request (status changes are critical)
CREATE TRIGGER trg_audit_request_update
AFTER UPDATE ON Request
FOR EACH ROW
BEGIN
    -- Only log if there are actual changes
    IF OLD.status != NEW.status OR OLD.urgency != NEW.urgency 
       OR OLD.quantity_requested != NEW.quantity_requested THEN
        INSERT INTO Audit_Log (table_name, record_id, action_type, old_values, new_values)
        VALUES (
            'Request',
            NEW.request_id,
            'UPDATE',
            JSON_OBJECT(
                'status', OLD.status,
                'urgency', OLD.urgency,
                'quantity_requested', OLD.quantity_requested
            ),
            JSON_OBJECT(
                'status', NEW.status,
                'urgency', NEW.urgency,
                'quantity_requested', NEW.quantity_requested
            )
        );
    END IF;
END //

DELIMITER ;

-- ============================================================
-- SECTION 5: AUDIT TRIGGERS FOR DONATION TABLE
-- ============================================================

DELIMITER //

-- Audit INSERT on Donation
CREATE TRIGGER trg_audit_donation_insert
AFTER INSERT ON Donation
FOR EACH ROW
BEGIN
    INSERT INTO Audit_Log (table_name, record_id, action_type, new_values)
    VALUES (
        'Donation',
        NEW.donation_id,
        'INSERT',
        JSON_OBJECT(
            'donation_id', NEW.donation_id,
            'donor_id', NEW.donor_id,
            'disaster_id', NEW.disaster_id,
            'donation_type', NEW.donation_type,
            'amount', NEW.amount,
            'resource_id', NEW.resource_id,
            'quantity', NEW.quantity,
            'receipt_no', NEW.receipt_no,
            'status', NEW.status
        )
    );
END //

-- Audit UPDATE on Donation
CREATE TRIGGER trg_audit_donation_update
AFTER UPDATE ON Donation
FOR EACH ROW
BEGIN
    INSERT INTO Audit_Log (table_name, record_id, action_type, old_values, new_values)
    VALUES (
        'Donation',
        NEW.donation_id,
        'UPDATE',
        JSON_OBJECT(
            'status', OLD.status,
            'amount', OLD.amount,
            'quantity', OLD.quantity
        ),
        JSON_OBJECT(
            'status', NEW.status,
            'amount', NEW.amount,
            'quantity', NEW.quantity
        )
    );
END //

DELIMITER ;

-- ============================================================
-- SECTION 6: AUDIT TRIGGERS FOR VOLUNTEER TABLE
-- ============================================================

DELIMITER //

-- Audit volunteer team assignments
CREATE TRIGGER trg_audit_volunteer_assignment
AFTER UPDATE ON Volunteer
FOR EACH ROW
BEGIN
    -- Log team assignment changes
    IF OLD.team_id IS DISTINCT FROM NEW.team_id THEN
        INSERT INTO Audit_Log (table_name, record_id, action_type, old_values, new_values)
        VALUES (
            'Volunteer',
            NEW.volunteer_id,
            'UPDATE',
            JSON_OBJECT(
                'team_id', OLD.team_id,
                'availability', OLD.availability
            ),
            JSON_OBJECT(
                'team_id', NEW.team_id,
                'availability', NEW.availability
            )
        );
    END IF;
END //

DELIMITER ;

-- ============================================================
-- SECTION 7: AUDIT QUERY PROCEDURES
-- ============================================================

DELIMITER //

-- Get audit trail for a specific record
CREATE PROCEDURE sp_get_audit_trail(
    IN p_table_name VARCHAR(50),
    IN p_record_id INT
)
BEGIN
    SELECT 
        log_id,
        action_type,
        old_values,
        new_values,
        changed_by,
        changed_at,
        session_id
    FROM Audit_Log
    WHERE table_name = p_table_name 
      AND record_id = p_record_id
    ORDER BY changed_at DESC;
END //

-- Get recent audit entries
CREATE PROCEDURE sp_get_recent_audit(
    IN p_hours INT,
    IN p_action_type VARCHAR(20)
)
BEGIN
    SELECT 
        log_id,
        table_name,
        record_id,
        action_type,
        CASE 
            WHEN action_type = 'DELETE' THEN old_values
            ELSE new_values
        END AS values_snapshot,
        changed_by,
        changed_at
    FROM Audit_Log
    WHERE changed_at >= DATE_SUB(NOW(), INTERVAL p_hours HOUR)
      AND (p_action_type IS NULL OR action_type = p_action_type)
    ORDER BY changed_at DESC
    LIMIT 100;
END //

-- Get audit summary by table
CREATE PROCEDURE sp_audit_summary(
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    SELECT 
        table_name,
        action_type,
        COUNT(*) AS operation_count,
        COUNT(DISTINCT changed_by) AS unique_users
    FROM Audit_Log
    WHERE DATE(changed_at) BETWEEN p_start_date AND p_end_date
    GROUP BY table_name, action_type
    ORDER BY table_name, action_type;
END //

-- Find who made a specific change
CREATE PROCEDURE sp_find_change_author(
    IN p_table_name VARCHAR(50),
    IN p_search_value VARCHAR(255)
)
BEGIN
    SELECT 
        log_id,
        record_id,
        action_type,
        old_values,
        new_values,
        changed_by,
        changed_at
    FROM Audit_Log
    WHERE table_name = p_table_name
      AND (JSON_SEARCH(old_values, 'all', p_search_value) IS NOT NULL
           OR JSON_SEARCH(new_values, 'all', p_search_value) IS NOT NULL)
    ORDER BY changed_at DESC;
END //

DELIMITER ;

-- ============================================================
-- SECTION 8: AUDIT VIEWS
-- ============================================================

-- View: Recent critical operations
CREATE OR REPLACE VIEW vw_critical_audit AS
SELECT 
    log_id,
    table_name,
    record_id,
    action_type,
    changed_by,
    changed_at,
    CASE action_type
        WHEN 'DELETE' THEN old_values
        WHEN 'INSERT' THEN new_values
        ELSE JSON_OBJECT('old', old_values, 'new', new_values)
    END AS change_details
FROM Audit_Log
WHERE action_type = 'DELETE'
   OR table_name IN ('Allocation', 'Donation')
ORDER BY changed_at DESC
LIMIT 50;

-- View: Daily audit statistics
CREATE OR REPLACE VIEW vw_daily_audit_stats AS
SELECT 
    DATE(changed_at) AS audit_date,
    table_name,
    SUM(CASE WHEN action_type = 'INSERT' THEN 1 ELSE 0 END) AS inserts,
    SUM(CASE WHEN action_type = 'UPDATE' THEN 1 ELSE 0 END) AS updates,
    SUM(CASE WHEN action_type = 'DELETE' THEN 1 ELSE 0 END) AS deletes,
    COUNT(DISTINCT changed_by) AS active_users
FROM Audit_Log
GROUP BY DATE(changed_at), table_name
ORDER BY audit_date DESC, table_name;

-- ============================================================
-- SECTION 9: COMPLIANCE REPORT
-- ============================================================

DELIMITER //

CREATE PROCEDURE sp_compliance_report(
    IN p_month INT,
    IN p_year INT
)
BEGIN
    DECLARE v_start_date DATE;
    DECLARE v_end_date DATE;
    
    SET v_start_date = MAKEDATE(p_year, 1) + INTERVAL (p_month - 1) MONTH;
    SET v_end_date = LAST_DAY(v_start_date);
    
    -- Summary header
    SELECT 
        p_year AS report_year,
        p_month AS report_month,
        COUNT(*) AS total_operations,
        COUNT(DISTINCT changed_by) AS unique_users,
        COUNT(DISTINCT table_name) AS tables_modified;
    
    -- Operations by table
    SELECT 
        table_name,
        COUNT(*) AS operations,
        SUM(CASE WHEN action_type = 'INSERT' THEN 1 ELSE 0 END) AS inserts,
        SUM(CASE WHEN action_type = 'UPDATE' THEN 1 ELSE 0 END) AS updates,
        SUM(CASE WHEN action_type = 'DELETE' THEN 1 ELSE 0 END) AS deletes
    FROM Audit_Log
    WHERE DATE(changed_at) BETWEEN v_start_date AND v_end_date
    GROUP BY table_name;
    
    -- User activity
    SELECT 
        changed_by AS user,
        COUNT(*) AS total_operations,
        GROUP_CONCAT(DISTINCT table_name) AS tables_modified
    FROM Audit_Log
    WHERE DATE(changed_at) BETWEEN v_start_date AND v_end_date
    GROUP BY changed_by
    ORDER BY total_operations DESC;
    
    -- Deletions (high-risk operations)
    SELECT 
        table_name,
        record_id,
        changed_by,
        changed_at,
        old_values
    FROM Audit_Log
    WHERE action_type = 'DELETE'
      AND DATE(changed_at) BETWEEN v_start_date AND v_end_date
    ORDER BY changed_at;
END //

DELIMITER ;

-- ============================================================
-- SECTION 10: AUDIT LOG MAINTENANCE
-- ============================================================

DELIMITER //

-- Archive old audit logs
CREATE PROCEDURE sp_archive_audit_logs(
    IN p_days_to_keep INT
)
BEGIN
    DECLARE v_cutoff_date TIMESTAMP;
    DECLARE v_archived_count INT;
    
    SET v_cutoff_date = DATE_SUB(NOW(), INTERVAL p_days_to_keep DAY);
    
    -- Create archive table if not exists
    CREATE TABLE IF NOT EXISTS Audit_Log_Archive LIKE Audit_Log;
    
    -- Count records to archive
    SELECT COUNT(*) INTO v_archived_count
    FROM Audit_Log
    WHERE changed_at < v_cutoff_date;
    
    -- Move to archive
    INSERT INTO Audit_Log_Archive
    SELECT * FROM Audit_Log
    WHERE changed_at < v_cutoff_date;
    
    -- Delete from main table
    DELETE FROM Audit_Log
    WHERE changed_at < v_cutoff_date;
    
    SELECT CONCAT('Archived ', v_archived_count, ' audit records older than ', v_cutoff_date) AS result;
END //

DELIMITER ;

-- ============================================================
-- AUDIT SYSTEM SUMMARY
-- ============================================================
-- Tables Created: 1 (Audit_Log)
-- Triggers Created: 8
--   - Allocation: INSERT, UPDATE, DELETE
--   - Request: INSERT, UPDATE
--   - Donation: INSERT, UPDATE
--   - Volunteer: UPDATE (assignments)
--
-- Procedures Created: 6
--   - sp_get_audit_trail
--   - sp_get_recent_audit
--   - sp_audit_summary
--   - sp_find_change_author
--   - sp_compliance_report
--   - sp_archive_audit_logs
--
-- Views Created: 2
--   - vw_critical_audit
--   - vw_daily_audit_stats
-- ============================================================

-- Sample usage:
-- CALL sp_get_audit_trail('Allocation', 1);
-- CALL sp_get_recent_audit(24, NULL);  -- Last 24 hours, all actions
-- CALL sp_audit_summary('2024-01-01', '2024-12-31');
-- CALL sp_compliance_report(11, 2024);  -- November 2024 report
