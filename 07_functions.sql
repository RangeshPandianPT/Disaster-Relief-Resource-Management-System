-- ============================================================
-- DISASTER RELIEF RESOURCE MANAGEMENT SYSTEM (DRRMS)
-- User-Defined Functions - Reusable SQL Functions
-- ============================================================

USE drrms_db;

-- ============================================================
-- FUNCTION 1: Calculate Fulfillment Rate
-- Returns the percentage of requests fulfilled for a disaster
-- ============================================================
DELIMITER //

CREATE FUNCTION fn_calculate_fulfillment_rate(p_disaster_id INT)
RETURNS DECIMAL(5,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total_requests INT DEFAULT 0;
    DECLARE fulfilled_requests INT DEFAULT 0;
    DECLARE rate DECIMAL(5,2);
    
    SELECT COUNT(*) INTO total_requests
    FROM Request r
    INNER JOIN Affected_Area aa ON r.area_id = aa.area_id
    WHERE aa.disaster_id = p_disaster_id;
    
    SELECT COUNT(*) INTO fulfilled_requests
    FROM Request r
    INNER JOIN Affected_Area aa ON r.area_id = aa.area_id
    WHERE aa.disaster_id = p_disaster_id AND r.status = 'Fulfilled';
    
    IF total_requests = 0 THEN
        SET rate = 0.00;
    ELSE
        SET rate = (fulfilled_requests / total_requests) * 100;
    END IF;
    
    RETURN rate;
END //

DELIMITER ;

-- ============================================================
-- FUNCTION 2: Days Since Disaster Started
-- Returns the number of days since a disaster began
-- ============================================================
DELIMITER //

CREATE FUNCTION fn_get_days_since_disaster(p_disaster_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE start_dt DATE;
    DECLARE end_dt DATE;
    DECLARE days_count INT;
    
    SELECT start_date, end_date INTO start_dt, end_dt
    FROM Disaster 
    WHERE disaster_id = p_disaster_id;
    
    IF start_dt IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- If disaster is resolved, calculate until end_date
    -- Otherwise, calculate until today
    IF end_dt IS NOT NULL THEN
        SET days_count = DATEDIFF(end_dt, start_dt);
    ELSE
        SET days_count = DATEDIFF(CURDATE(), start_dt);
    END IF;
    
    RETURN days_count;
END //

DELIMITER ;

-- ============================================================
-- FUNCTION 3: Format Currency
-- Returns a formatted currency string with Indian Rupee symbol
-- ============================================================
DELIMITER //

CREATE FUNCTION fn_format_currency(p_amount DECIMAL(15,2))
RETURNS VARCHAR(30)
DETERMINISTIC
BEGIN
    IF p_amount IS NULL THEN
        RETURN '₹0.00';
    END IF;
    
    RETURN CONCAT('₹', FORMAT(p_amount, 2));
END //

DELIMITER ;

-- ============================================================
-- FUNCTION 4: Resource Shortage Level
-- Returns severity level based on stock vs minimum threshold
-- ============================================================
DELIMITER //

CREATE FUNCTION fn_resource_shortage_level(p_resource_id INT)
RETURNS VARCHAR(20)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total_stock INT DEFAULT 0;
    DECLARE min_stock INT DEFAULT 0;
    DECLARE stock_ratio DECIMAL(5,2);
    
    SELECT COALESCE(SUM(i.quantity_available), 0), COALESCE(r.min_stock, 0)
    INTO total_stock, min_stock
    FROM Resource r
    LEFT JOIN Inventory i ON r.resource_id = i.resource_id
    WHERE r.resource_id = p_resource_id
    GROUP BY r.resource_id, r.min_stock;
    
    IF min_stock = 0 THEN
        RETURN 'NO_THRESHOLD';
    END IF;
    
    SET stock_ratio = total_stock / min_stock;
    
    IF total_stock = 0 THEN
        RETURN 'OUT_OF_STOCK';
    ELSEIF stock_ratio < 0.25 THEN
        RETURN 'CRITICAL';
    ELSEIF stock_ratio < 0.5 THEN
        RETURN 'LOW';
    ELSEIF stock_ratio < 1.0 THEN
        RETURN 'MODERATE';
    ELSE
        RETURN 'ADEQUATE';
    END IF;
END //

DELIMITER ;

-- ============================================================
-- FUNCTION 5: Volunteer Workload Score
-- Calculates workload based on experience and assignments
-- ============================================================
DELIMITER //

CREATE FUNCTION fn_volunteer_workload(p_volunteer_id INT)
RETURNS VARCHAR(20)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE exp_yrs INT DEFAULT 0;
    DECLARE is_assigned BOOLEAN DEFAULT FALSE;
    DECLARE team_type_val VARCHAR(50);
    
    SELECT 
        v.experience_years,
        CASE WHEN v.team_id IS NOT NULL THEN TRUE ELSE FALSE END,
        t.team_type
    INTO exp_yrs, is_assigned, team_type_val
    FROM Volunteer v
    LEFT JOIN Relief_Team t ON v.team_id = t.team_id
    WHERE v.volunteer_id = p_volunteer_id;
    
    IF NOT is_assigned THEN
        RETURN 'AVAILABLE';
    END IF;
    
    -- Rescue and Medical teams have higher workload
    IF team_type_val IN ('Rescue', 'Medical') THEN
        IF exp_yrs < 2 THEN
            RETURN 'HIGH';
        ELSE
            RETURN 'MODERATE';
        END IF;
    ELSE
        IF exp_yrs < 1 THEN
            RETURN 'MODERATE';
        ELSE
            RETURN 'LIGHT';
        END IF;
    END IF;
END //

DELIMITER ;

-- ============================================================
-- FUNCTION 6: Donor Contribution Rank
-- Returns donor tier based on total contributions
-- ============================================================
DELIMITER //

CREATE FUNCTION fn_donor_rank(p_donor_id INT)
RETURNS VARCHAR(20)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total_monetary DECIMAL(15,2) DEFAULT 0;
    DECLARE material_count INT DEFAULT 0;
    
    SELECT 
        COALESCE(SUM(CASE WHEN donation_type = 'Money' THEN amount ELSE 0 END), 0),
        COUNT(CASE WHEN donation_type = 'Material' THEN 1 END)
    INTO total_monetary, material_count
    FROM Donation
    WHERE donor_id = p_donor_id;
    
    -- Ranking criteria:
    -- PLATINUM: > 10 lakh or > 10 material donations
    -- GOLD: > 5 lakh or > 5 material donations
    -- SILVER: > 1 lakh or > 2 material donations  
    -- BRONZE: Any contribution
    -- NEW: No contributions yet
    
    IF total_monetary >= 1000000 OR material_count >= 10 THEN
        RETURN 'PLATINUM';
    ELSEIF total_monetary >= 500000 OR material_count >= 5 THEN
        RETURN 'GOLD';
    ELSEIF total_monetary >= 100000 OR material_count >= 2 THEN
        RETURN 'SILVER';
    ELSEIF total_monetary > 0 OR material_count > 0 THEN
        RETURN 'BRONZE';
    ELSE
        RETURN 'NEW';
    END IF;
END //

DELIMITER ;

-- ============================================================
-- FUNCTION 7: Get Priority Numeric Value
-- Converts priority string to numeric for sorting
-- ============================================================
DELIMITER //

CREATE FUNCTION fn_priority_value(p_priority VARCHAR(20))
RETURNS INT
DETERMINISTIC
BEGIN
    RETURN CASE p_priority
        WHEN 'Critical' THEN 4
        WHEN 'High' THEN 3
        WHEN 'Medium' THEN 2
        WHEN 'Low' THEN 1
        ELSE 0
    END;
END //

DELIMITER ;

-- ============================================================
-- FUNCTION 8: Calculate Resource Gap
-- Returns the shortage quantity for a resource
-- ============================================================
DELIMITER //

CREATE FUNCTION fn_resource_gap(p_resource_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total_available INT DEFAULT 0;
    DECLARE total_requested INT DEFAULT 0;
    DECLARE pending_requested INT DEFAULT 0;
    
    -- Get total available in inventory
    SELECT COALESCE(SUM(quantity_available), 0) INTO total_available
    FROM Inventory
    WHERE resource_id = p_resource_id;
    
    -- Get total pending requests
    SELECT COALESCE(SUM(quantity_requested), 0) INTO pending_requested
    FROM Request
    WHERE resource_id = p_resource_id 
    AND status IN ('Pending', 'Approved', 'Partially_Fulfilled');
    
    -- Return gap (negative means shortage)
    RETURN total_available - pending_requested;
END //

DELIMITER ;

-- ============================================================
-- FUNCTION 9: Format Phone Number
-- Returns formatted phone number for display
-- ============================================================
DELIMITER //

CREATE FUNCTION fn_format_phone(p_phone VARCHAR(15))
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE cleaned VARCHAR(15);
    
    IF p_phone IS NULL OR LENGTH(p_phone) < 10 THEN
        RETURN p_phone;
    END IF;
    
    -- Remove any non-numeric characters
    SET cleaned = REGEXP_REPLACE(p_phone, '[^0-9]', '');
    
    -- Format as XXX-XXX-XXXX for 10 digits
    IF LENGTH(cleaned) = 10 THEN
        RETURN CONCAT(
            SUBSTRING(cleaned, 1, 3), '-',
            SUBSTRING(cleaned, 4, 3), '-',
            SUBSTRING(cleaned, 7, 4)
        );
    END IF;
    
    RETURN p_phone;
END //

DELIMITER ;

-- ============================================================
-- FUNCTION 10: Get Disaster Status Emoji
-- Returns emoji indicator for disaster severity
-- ============================================================
DELIMITER //

CREATE FUNCTION fn_severity_indicator(p_severity VARCHAR(20))
RETURNS VARCHAR(10)
DETERMINISTIC
BEGIN
    RETURN CASE p_severity
        WHEN 'Extreme' THEN '🔴'
        WHEN 'Severe' THEN '🟠'
        WHEN 'Moderate' THEN '🟡'
        WHEN 'Minor' THEN '🟢'
        ELSE '⚪'
    END;
END //

DELIMITER ;

-- ============================================================
-- FUNCTIONS CREATED: 10
-- ============================================================
-- 1. fn_calculate_fulfillment_rate  - Request fulfillment %
-- 2. fn_get_days_since_disaster     - Days since start
-- 3. fn_format_currency             - Currency formatting
-- 4. fn_resource_shortage_level     - Stock level indicator
-- 5. fn_volunteer_workload          - Volunteer assignment load
-- 6. fn_donor_rank                  - Donor tier classification
-- 7. fn_priority_value              - Priority to numeric
-- 8. fn_resource_gap                - Stock vs demand gap
-- 9. fn_format_phone                - Phone formatting
-- 10. fn_severity_indicator         - Severity emoji
-- ============================================================

-- Sample usage:
-- SELECT fn_calculate_fulfillment_rate(1);
-- SELECT fn_format_currency(250000.50);
-- SELECT fn_donor_rank(1);
-- SELECT disaster_name, fn_severity_indicator(severity) AS indicator FROM Disaster;

-- View all functions:
-- SHOW FUNCTION STATUS WHERE Db = 'drrms_db';
