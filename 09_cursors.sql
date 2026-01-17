-- ============================================================
-- DISASTER RELIEF RESOURCE MANAGEMENT SYSTEM (DRRMS)
-- Cursors - Row-by-Row Processing Examples
-- ============================================================

USE drrms_db;

-- ============================================================
-- CURSOR CONCEPT OVERVIEW
-- ============================================================
-- Cursors allow row-by-row processing of result sets
-- Useful when:
-- - Complex logic needed per row
-- - Row-by-row updates based on calculations
-- - Generating reports with running totals
-- - Data migration/transformation
-- ============================================================

-- ============================================================
-- CURSOR 1: Generate Low Stock Alerts
-- Loops through inventory and creates alert messages
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_cursor_generate_stock_alerts()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_resource_name VARCHAR(100);
    DECLARE v_warehouse VARCHAR(100);
    DECLARE v_available INT;
    DECLARE v_min_stock INT;
    DECLARE v_stock_percent DECIMAL(5,2);
    DECLARE alert_count INT DEFAULT 0;
    
    -- Cursor declaration
    DECLARE stock_cursor CURSOR FOR
        SELECT r.resource_name, i.warehouse_location, 
               i.quantity_available, r.min_stock
        FROM Inventory i
        INNER JOIN Resource r ON i.resource_id = r.resource_id
        WHERE i.quantity_available < r.min_stock
        ORDER BY (i.quantity_available / r.min_stock);
    
    -- Handler for end of cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Create temporary table for alerts
    DROP TEMPORARY TABLE IF EXISTS temp_stock_alerts;
    CREATE TEMPORARY TABLE temp_stock_alerts (
        alert_id INT AUTO_INCREMENT PRIMARY KEY,
        resource_name VARCHAR(100),
        warehouse VARCHAR(100),
        current_stock INT,
        minimum_required INT,
        stock_percentage DECIMAL(5,2),
        severity VARCHAR(20),
        alert_message VARCHAR(255),
        generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Open cursor
    OPEN stock_cursor;
    
    -- Loop through rows
    read_loop: LOOP
        FETCH stock_cursor INTO v_resource_name, v_warehouse, v_available, v_min_stock;
        
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Calculate stock percentage
        SET v_stock_percent = (v_available / v_min_stock) * 100;
        
        -- Insert alert based on severity
        INSERT INTO temp_stock_alerts 
            (resource_name, warehouse, current_stock, minimum_required, 
             stock_percentage, severity, alert_message)
        VALUES (
            v_resource_name,
            v_warehouse,
            v_available,
            v_min_stock,
            v_stock_percent,
            CASE 
                WHEN v_available = 0 THEN 'CRITICAL'
                WHEN v_stock_percent < 25 THEN 'HIGH'
                WHEN v_stock_percent < 50 THEN 'MEDIUM'
                ELSE 'LOW'
            END,
            CONCAT(
                CASE 
                    WHEN v_available = 0 THEN '🔴 OUT OF STOCK: '
                    WHEN v_stock_percent < 25 THEN '🟠 CRITICAL LOW: '
                    WHEN v_stock_percent < 50 THEN '🟡 LOW STOCK: '
                    ELSE '🟢 REORDER SOON: '
                END,
                v_resource_name, ' at ', v_warehouse,
                ' (', v_available, '/', v_min_stock, ' = ', ROUND(v_stock_percent, 1), '%)'
            )
        );
        
        SET alert_count = alert_count + 1;
    END LOOP;
    
    -- Close cursor
    CLOSE stock_cursor;
    
    -- Return results
    SELECT CONCAT('Generated ', alert_count, ' stock alerts') AS summary;
    SELECT * FROM temp_stock_alerts ORDER BY 
        FIELD(severity, 'CRITICAL', 'HIGH', 'MEDIUM', 'LOW'),
        stock_percentage;
END //

DELIMITER ;

-- ============================================================
-- CURSOR 2: Batch Update Request Priorities
-- Updates request urgency based on age and fulfillment
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_cursor_update_request_priorities()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_request_id INT;
    DECLARE v_current_urgency VARCHAR(20);
    DECLARE v_days_pending INT;
    DECLARE v_new_urgency VARCHAR(20);
    DECLARE updated_count INT DEFAULT 0;
    
    DECLARE request_cursor CURSOR FOR
        SELECT r.request_id, r.urgency, 
               DATEDIFF(CURDATE(), r.request_date) AS days_pending
        FROM Request r
        WHERE r.status = 'Pending'
        ORDER BY r.request_date;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    OPEN request_cursor;
    
    update_loop: LOOP
        FETCH request_cursor INTO v_request_id, v_current_urgency, v_days_pending;
        
        IF done THEN
            LEAVE update_loop;
        END IF;
        
        -- Determine if urgency should be escalated
        SET v_new_urgency = v_current_urgency;
        
        IF v_current_urgency = 'Low' AND v_days_pending > 3 THEN
            SET v_new_urgency = 'Medium';
        ELSEIF v_current_urgency = 'Medium' AND v_days_pending > 5 THEN
            SET v_new_urgency = 'High';
        ELSEIF v_current_urgency = 'High' AND v_days_pending > 7 THEN
            SET v_new_urgency = 'Critical';
        END IF;
        
        -- Update if changed
        IF v_new_urgency != v_current_urgency THEN
            UPDATE Request 
            SET urgency = v_new_urgency,
                remarks = CONCAT(COALESCE(remarks, ''), 
                    ' [Auto-escalated from ', v_current_urgency, 
                    ' to ', v_new_urgency, ' after ', v_days_pending, ' days]')
            WHERE request_id = v_request_id;
            
            SET updated_count = updated_count + 1;
        END IF;
    END LOOP;
    
    CLOSE request_cursor;
    
    SELECT CONCAT('Escalated ', updated_count, ' requests') AS result;
END //

DELIMITER ;

-- ============================================================
-- CURSOR 3: Generate Disaster Summary Report
-- Builds a comprehensive report using running totals
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_cursor_disaster_summary_report()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_disaster_id INT;
    DECLARE v_disaster_name VARCHAR(100);
    DECLARE v_severity VARCHAR(20);
    DECLARE v_affected_areas INT;
    DECLARE v_total_pop INT;
    DECLARE v_teams INT;
    DECLARE v_volunteers INT;
    DECLARE v_donations DECIMAL(15,2);
    
    DECLARE grand_total_affected INT DEFAULT 0;
    DECLARE grand_total_teams INT DEFAULT 0;
    DECLARE grand_total_donations DECIMAL(15,2) DEFAULT 0;
    
    DECLARE disaster_cursor CURSOR FOR
        SELECT disaster_id, disaster_name, severity
        FROM Disaster
        WHERE status = 'Active'
        ORDER BY FIELD(severity, 'Extreme', 'Severe', 'Moderate', 'Minor');
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Create report table
    DROP TEMPORARY TABLE IF EXISTS temp_disaster_report;
    CREATE TEMPORARY TABLE temp_disaster_report (
        row_num INT AUTO_INCREMENT PRIMARY KEY,
        disaster_name VARCHAR(100),
        severity VARCHAR(20),
        affected_areas INT,
        population_affected INT,
        running_total_affected INT,
        active_teams INT,
        volunteers_deployed INT,
        monetary_donations DECIMAL(15,2),
        running_total_donations DECIMAL(15,2)
    );
    
    OPEN disaster_cursor;
    
    report_loop: LOOP
        FETCH disaster_cursor INTO v_disaster_id, v_disaster_name, v_severity;
        
        IF done THEN
            LEAVE report_loop;
        END IF;
        
        -- Get affected areas and population
        SELECT COUNT(*), COALESCE(SUM(population_affected), 0)
        INTO v_affected_areas, v_total_pop
        FROM Affected_Area WHERE disaster_id = v_disaster_id;
        
        -- Get teams and volunteers
        SELECT COUNT(DISTINCT t.team_id), COUNT(DISTINCT v.volunteer_id)
        INTO v_teams, v_volunteers
        FROM Relief_Team t
        LEFT JOIN Volunteer v ON t.team_id = v.team_id
        WHERE t.disaster_id = v_disaster_id AND t.status = 'Active';
        
        -- Get donations
        SELECT COALESCE(SUM(CASE WHEN donation_type = 'Money' THEN amount ELSE 0 END), 0)
        INTO v_donations
        FROM Donation WHERE disaster_id = v_disaster_id;
        
        -- Update running totals
        SET grand_total_affected = grand_total_affected + v_total_pop;
        SET grand_total_teams = grand_total_teams + v_teams;
        SET grand_total_donations = grand_total_donations + v_donations;
        
        -- Insert row with running totals
        INSERT INTO temp_disaster_report (
            disaster_name, severity, affected_areas, population_affected,
            running_total_affected, active_teams, volunteers_deployed,
            monetary_donations, running_total_donations
        ) VALUES (
            v_disaster_name, v_severity, v_affected_areas, v_total_pop,
            grand_total_affected, v_teams, v_volunteers,
            v_donations, grand_total_donations
        );
    END LOOP;
    
    CLOSE disaster_cursor;
    
    -- Return report with grand totals
    SELECT '=== ACTIVE DISASTER SUMMARY REPORT ===' AS header;
    SELECT * FROM temp_disaster_report;
    SELECT 
        'GRAND TOTALS' AS summary_type,
        grand_total_affected AS total_population_affected,
        grand_total_teams AS total_active_teams,
        grand_total_donations AS total_monetary_donations;
END //

DELIMITER ;

-- ============================================================
-- CURSOR 4: Auto-Release Idle Volunteers
-- Finds and releases volunteers who haven't been active
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_cursor_release_idle_volunteers(
    IN p_days_threshold INT
)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_volunteer_id INT;
    DECLARE v_volunteer_name VARCHAR(100);
    DECLARE v_team_name VARCHAR(100);
    DECLARE v_days_assigned INT;
    DECLARE released_count INT DEFAULT 0;
    
    DECLARE volunteer_cursor CURSOR FOR
        SELECT v.volunteer_id, v.name, t.team_name,
               DATEDIFF(CURDATE(), t.formed_date) AS days_assigned
        FROM Volunteer v
        INNER JOIN Relief_Team t ON v.team_id = t.team_id
        WHERE v.availability = 'Busy'
          AND t.status = 'Disbanded'
        ORDER BY days_assigned DESC;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Create log table
    DROP TEMPORARY TABLE IF EXISTS temp_release_log;
    CREATE TEMPORARY TABLE temp_release_log (
        volunteer_id INT,
        volunteer_name VARCHAR(100),
        previous_team VARCHAR(100),
        days_assigned INT,
        released_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    OPEN volunteer_cursor;
    
    release_loop: LOOP
        FETCH volunteer_cursor INTO v_volunteer_id, v_volunteer_name, v_team_name, v_days_assigned;
        
        IF done THEN
            LEAVE release_loop;
        END IF;
        
        -- Log the release
        INSERT INTO temp_release_log (volunteer_id, volunteer_name, previous_team, days_assigned)
        VALUES (v_volunteer_id, v_volunteer_name, v_team_name, v_days_assigned);
        
        -- Release the volunteer
        UPDATE Volunteer
        SET team_id = NULL, availability = 'Available'
        WHERE volunteer_id = v_volunteer_id;
        
        SET released_count = released_count + 1;
    END LOOP;
    
    CLOSE volunteer_cursor;
    
    -- Return results
    SELECT CONCAT('Released ', released_count, ' idle volunteers') AS summary;
    SELECT * FROM temp_release_log;
END //

DELIMITER ;

-- ============================================================
-- CURSOR 5: Calculate Area Risk Scores
-- Complex calculation requiring row-by-row processing
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_cursor_calculate_risk_scores()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_area_id INT;
    DECLARE v_area_name VARCHAR(100);
    DECLARE v_population INT;
    DECLARE v_priority VARCHAR(20);
    DECLARE v_pending_requests INT;
    DECLARE v_fulfilled_pct DECIMAL(5,2);
    DECLARE v_risk_score DECIMAL(5,2);
    
    DECLARE area_cursor CURSOR FOR
        SELECT aa.area_id, aa.area_name, aa.population_affected, aa.priority
        FROM Affected_Area aa
        INNER JOIN Disaster d ON aa.disaster_id = d.disaster_id
        WHERE d.status = 'Active';
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    DROP TEMPORARY TABLE IF EXISTS temp_risk_scores;
    CREATE TEMPORARY TABLE temp_risk_scores (
        area_id INT,
        area_name VARCHAR(100),
        population INT,
        priority VARCHAR(20),
        pending_requests INT,
        fulfillment_rate DECIMAL(5,2),
        risk_score DECIMAL(5,2),
        risk_level VARCHAR(20)
    );
    
    OPEN area_cursor;
    
    calc_loop: LOOP
        FETCH area_cursor INTO v_area_id, v_area_name, v_population, v_priority;
        
        IF done THEN
            LEAVE calc_loop;
        END IF;
        
        -- Get pending requests count
        SELECT COUNT(*) INTO v_pending_requests
        FROM Request WHERE area_id = v_area_id AND status = 'Pending';
        
        -- Calculate fulfillment rate
        SELECT 
            CASE 
                WHEN COUNT(*) = 0 THEN 100.00
                ELSE (SUM(CASE WHEN status = 'Fulfilled' THEN 1 ELSE 0 END) / COUNT(*)) * 100
            END
        INTO v_fulfilled_pct
        FROM Request WHERE area_id = v_area_id;
        
        -- Calculate risk score (0-100)
        -- Higher population = higher risk
        -- Higher pending requests = higher risk
        -- Lower fulfillment = higher risk
        -- Critical priority = higher multiplier
        SET v_risk_score = 
            (v_population / 10000) * 10 +  -- Population factor (0-~50)
            (v_pending_requests * 5) +      -- Pending requests factor (0-~25)
            ((100 - v_fulfilled_pct) * 0.25); -- Fulfillment factor (0-25)
        
        -- Apply priority multiplier
        SET v_risk_score = v_risk_score * CASE v_priority
            WHEN 'Critical' THEN 1.5
            WHEN 'High' THEN 1.25
            WHEN 'Medium' THEN 1.0
            ELSE 0.75
        END;
        
        -- Cap at 100
        IF v_risk_score > 100 THEN SET v_risk_score = 100; END IF;
        
        INSERT INTO temp_risk_scores VALUES (
            v_area_id, v_area_name, v_population, v_priority,
            v_pending_requests, v_fulfilled_pct, v_risk_score,
            CASE 
                WHEN v_risk_score >= 80 THEN 'EXTREME'
                WHEN v_risk_score >= 60 THEN 'HIGH'
                WHEN v_risk_score >= 40 THEN 'MODERATE'
                WHEN v_risk_score >= 20 THEN 'LOW'
                ELSE 'MINIMAL'
            END
        );
    END LOOP;
    
    CLOSE area_cursor;
    
    SELECT * FROM temp_risk_scores ORDER BY risk_score DESC;
END //

DELIMITER ;

-- ============================================================
-- CURSORS/PROCEDURES CREATED: 5
-- ============================================================
-- 1. sp_cursor_generate_stock_alerts       - Low stock alerts
-- 2. sp_cursor_update_request_priorities   - Priority escalation
-- 3. sp_cursor_disaster_summary_report     - Summary with running totals
-- 4. sp_cursor_release_idle_volunteers     - Release disbanded team volunteers
-- 5. sp_cursor_calculate_risk_scores       - Area risk assessment
-- ============================================================

-- Sample usage:
-- CALL sp_cursor_generate_stock_alerts();
-- CALL sp_cursor_disaster_summary_report();
-- CALL sp_cursor_calculate_risk_scores();
