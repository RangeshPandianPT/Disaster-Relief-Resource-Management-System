-- ============================================================
-- DISASTER RELIEF RESOURCE MANAGEMENT SYSTEM (DRRMS)
-- Stored Procedures - Business Logic Encapsulation
-- ============================================================

USE drrms_db;

-- ============================================================
-- PROCEDURE 1: Register New Disaster
-- Creates a disaster and optionally adds affected areas
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_register_disaster(
    IN p_disaster_name VARCHAR(100),
    IN p_disaster_type VARCHAR(50),
    IN p_severity VARCHAR(20),
    IN p_start_date DATE,
    IN p_description TEXT,
    OUT p_disaster_id INT
)
BEGIN
    INSERT INTO Disaster (disaster_name, disaster_type, severity, start_date, description, status)
    VALUES (p_disaster_name, p_disaster_type, p_severity, p_start_date, p_description, 'Active');
    
    SET p_disaster_id = LAST_INSERT_ID();
    
    SELECT p_disaster_id AS new_disaster_id, 
           'Disaster registered successfully' AS message;
END //

DELIMITER ;

-- ============================================================
-- PROCEDURE 2: Add Affected Area
-- Adds a new affected area to an existing disaster
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_add_affected_area(
    IN p_disaster_id INT,
    IN p_area_name VARCHAR(100),
    IN p_district VARCHAR(100),
    IN p_state VARCHAR(100),
    IN p_population_affected INT,
    IN p_priority VARCHAR(20),
    OUT p_area_id INT
)
BEGIN
    -- Validate disaster exists and is active
    IF NOT EXISTS (SELECT 1 FROM Disaster WHERE disaster_id = p_disaster_id AND status = 'Active') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Disaster not found or not active';
    END IF;
    
    INSERT INTO Affected_Area (disaster_id, area_name, district, state, population_affected, priority)
    VALUES (p_disaster_id, p_area_name, p_district, p_state, p_population_affected, p_priority);
    
    SET p_area_id = LAST_INSERT_ID();
    
    SELECT p_area_id AS new_area_id,
           'Affected area added successfully' AS message;
END //

DELIMITER ;

-- ============================================================
-- PROCEDURE 3: Submit Resource Request
-- Creates a new resource request for an affected area
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_submit_request(
    IN p_area_id INT,
    IN p_resource_id INT,
    IN p_quantity INT,
    IN p_urgency VARCHAR(20),
    IN p_remarks TEXT,
    OUT p_request_id INT
)
BEGIN
    -- Validate affected area exists
    IF NOT EXISTS (SELECT 1 FROM Affected_Area WHERE area_id = p_area_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Affected area not found';
    END IF;
    
    -- Validate resource exists
    IF NOT EXISTS (SELECT 1 FROM Resource WHERE resource_id = p_resource_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Resource not found';
    END IF;
    
    INSERT INTO Request (area_id, resource_id, quantity_requested, urgency, status, remarks)
    VALUES (p_area_id, p_resource_id, p_quantity, p_urgency, 'Pending', p_remarks);
    
    SET p_request_id = LAST_INSERT_ID();
    
    SELECT p_request_id AS new_request_id,
           'Request submitted successfully' AS message;
END //

DELIMITER ;

-- ============================================================
-- PROCEDURE 4: Allocate Resources
-- Allocates resources from inventory to fulfill a request
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_allocate_resources(
    IN p_request_id INT,
    IN p_inventory_id INT,
    IN p_quantity INT,
    IN p_remarks TEXT,
    OUT p_allocation_id INT
)
BEGIN
    DECLARE v_available INT;
    DECLARE v_requested INT;
    DECLARE v_already_allocated INT;
    
    -- Get available quantity
    SELECT quantity_available INTO v_available
    FROM Inventory WHERE inventory_id = p_inventory_id;
    
    IF v_available IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Inventory not found';
    END IF;
    
    -- Check if enough quantity available
    IF p_quantity > v_available THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Insufficient inventory quantity';
    END IF;
    
    -- Get requested and already allocated quantities
    SELECT quantity_requested INTO v_requested
    FROM Request WHERE request_id = p_request_id;
    
    SELECT COALESCE(SUM(quantity_allocated), 0) INTO v_already_allocated
    FROM Allocation WHERE request_id = p_request_id;
    
    -- Check if allocation exceeds request
    IF (v_already_allocated + p_quantity) > v_requested THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Total allocation would exceed requested quantity';
    END IF;
    
    -- Create allocation (trigger will update inventory)
    INSERT INTO Allocation (request_id, inventory_id, quantity_allocated, delivery_status, remarks)
    VALUES (p_request_id, p_inventory_id, p_quantity, 'Pending', p_remarks);
    
    SET p_allocation_id = LAST_INSERT_ID();
    
    SELECT p_allocation_id AS new_allocation_id,
           'Resources allocated successfully' AS message,
           v_available - p_quantity AS remaining_inventory;
END //

DELIMITER ;

-- ============================================================
-- PROCEDURE 5: Update Delivery Status
-- Updates the delivery status of an allocation
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_update_delivery_status(
    IN p_allocation_id INT,
    IN p_status VARCHAR(20),
    IN p_remarks TEXT
)
BEGIN
    DECLARE v_current_status VARCHAR(20);
    
    -- Get current status
    SELECT delivery_status INTO v_current_status
    FROM Allocation WHERE allocation_id = p_allocation_id;
    
    IF v_current_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Allocation not found';
    END IF;
    
    -- Validate status transition
    IF v_current_status = 'Delivered' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot update status of delivered allocation';
    END IF;
    
    -- Update allocation
    UPDATE Allocation 
    SET delivery_status = p_status,
        delivered_date = CASE WHEN p_status = 'Delivered' THEN CURRENT_TIMESTAMP ELSE delivered_date END,
        remarks = COALESCE(p_remarks, remarks)
    WHERE allocation_id = p_allocation_id;
    
    SELECT 'Delivery status updated successfully' AS message,
           p_status AS new_status;
END //

DELIMITER ;

-- ============================================================
-- PROCEDURE 6: Register Volunteer
-- Registers a new volunteer in the system
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_register_volunteer(
    IN p_name VARCHAR(100),
    IN p_email VARCHAR(100),
    IN p_phone VARCHAR(15),
    IN p_skills VARCHAR(200),
    OUT p_volunteer_id INT
)
BEGIN
    -- Check if email already exists
    IF EXISTS (SELECT 1 FROM Volunteer WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Email already registered';
    END IF;
    
    INSERT INTO Volunteer (name, email, phone, skills, availability)
    VALUES (p_name, p_email, p_phone, p_skills, 'Available');
    
    SET p_volunteer_id = LAST_INSERT_ID();
    
    SELECT p_volunteer_id AS new_volunteer_id,
           'Volunteer registered successfully' AS message;
END //

DELIMITER ;

-- ============================================================
-- PROCEDURE 7: Assign Volunteer to Team
-- Assigns a volunteer to a relief team
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_assign_volunteer_to_team(
    IN p_volunteer_id INT,
    IN p_team_id INT
)
BEGIN
    -- Validate volunteer exists and is available
    IF NOT EXISTS (SELECT 1 FROM Volunteer WHERE volunteer_id = p_volunteer_id AND availability = 'Available') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Volunteer not found or not available';
    END IF;
    
    -- Validate team exists and is active
    IF NOT EXISTS (SELECT 1 FROM Relief_Team WHERE team_id = p_team_id AND status = 'Active') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Team not found or not active';
    END IF;
    
    -- Assign volunteer
    UPDATE Volunteer 
    SET team_id = p_team_id,
        availability = 'Busy'
    WHERE volunteer_id = p_volunteer_id;
    
    SELECT 'Volunteer assigned to team successfully' AS message;
END //

DELIMITER ;

-- ============================================================
-- PROCEDURE 8: Record Donation
-- Records a new donation (monetary or material)
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_record_donation(
    IN p_donor_id INT,
    IN p_disaster_id INT,
    IN p_donation_type VARCHAR(20),
    IN p_amount DECIMAL(12,2),
    IN p_resource_id INT,
    IN p_quantity INT,
    OUT p_donation_id INT,
    OUT p_receipt_no VARCHAR(50)
)
BEGIN
    -- Validate donor
    IF NOT EXISTS (SELECT 1 FROM Donor WHERE donor_id = p_donor_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Donor not found';
    END IF;
    
    -- Validate donation type and data
    IF p_donation_type = 'Money' AND (p_amount IS NULL OR p_amount <= 0) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Monetary donation requires valid amount';
    END IF;
    
    IF p_donation_type = 'Material' AND (p_resource_id IS NULL OR p_quantity IS NULL OR p_quantity <= 0) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Material donation requires resource and quantity';
    END IF;
    
    -- Insert donation (receipt_no generated by trigger)
    INSERT INTO Donation (donor_id, disaster_id, donation_type, amount, resource_id, quantity, status)
    VALUES (p_donor_id, p_disaster_id, p_donation_type, p_amount, p_resource_id, p_quantity, 'Received');
    
    SET p_donation_id = LAST_INSERT_ID();
    
    -- Get the generated receipt number
    SELECT receipt_no INTO p_receipt_no
    FROM Donation WHERE donation_id = p_donation_id;
    
    SELECT p_donation_id AS new_donation_id,
           p_receipt_no AS receipt_number,
           'Donation recorded successfully' AS message;
END //

DELIMITER ;

-- ============================================================
-- PROCEDURE 9: Get Disaster Report
-- Generates a comprehensive report for a disaster
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_get_disaster_report(
    IN p_disaster_id INT
)
BEGIN
    -- Disaster summary
    SELECT 
        d.disaster_name,
        d.disaster_type,
        d.severity,
        d.start_date,
        d.status,
        DATEDIFF(COALESCE(d.end_date, CURDATE()), d.start_date) AS duration_days
    FROM Disaster d
    WHERE d.disaster_id = p_disaster_id;
    
    -- Affected areas summary
    SELECT 
        COUNT(*) AS total_areas,
        SUM(population_affected) AS total_affected,
        SUM(CASE WHEN priority = 'Critical' THEN 1 ELSE 0 END) AS critical_areas
    FROM Affected_Area
    WHERE disaster_id = p_disaster_id;
    
    -- Request statistics
    SELECT 
        COUNT(*) AS total_requests,
        SUM(CASE WHEN status = 'Pending' THEN 1 ELSE 0 END) AS pending,
        SUM(CASE WHEN status = 'Approved' THEN 1 ELSE 0 END) AS approved,
        SUM(CASE WHEN status = 'Fulfilled' THEN 1 ELSE 0 END) AS fulfilled
    FROM Request r
    INNER JOIN Affected_Area aa ON r.area_id = aa.area_id
    WHERE aa.disaster_id = p_disaster_id;
    
    -- Team and volunteer summary
    SELECT 
        COUNT(DISTINCT t.team_id) AS total_teams,
        COUNT(DISTINCT v.volunteer_id) AS total_volunteers
    FROM Relief_Team t
    LEFT JOIN Volunteer v ON t.team_id = v.team_id
    WHERE t.disaster_id = p_disaster_id AND t.status = 'Active';
    
    -- Donation summary
    SELECT 
        COUNT(*) AS total_donations,
        SUM(CASE WHEN donation_type = 'Money' THEN amount ELSE 0 END) AS total_monetary,
        COUNT(CASE WHEN donation_type = 'Material' THEN 1 END) AS material_donations
    FROM Donation
    WHERE disaster_id = p_disaster_id;
END //

DELIMITER ;

-- ============================================================
-- PROCEDURE 10: Close Disaster
-- Marks a disaster as resolved and disbands teams
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_close_disaster(
    IN p_disaster_id INT,
    IN p_end_date DATE
)
BEGIN
    -- Validate disaster exists and is active
    IF NOT EXISTS (SELECT 1 FROM Disaster WHERE disaster_id = p_disaster_id AND status = 'Active') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Disaster not found or already closed';
    END IF;
    
    -- Check for pending requests
    IF EXISTS (
        SELECT 1 FROM Request r
        INNER JOIN Affected_Area aa ON r.area_id = aa.area_id
        WHERE aa.disaster_id = p_disaster_id AND r.status = 'Pending'
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot close disaster with pending requests';
    END IF;
    
    -- Update disaster status
    UPDATE Disaster 
    SET status = 'Resolved',
        end_date = COALESCE(p_end_date, CURDATE())
    WHERE disaster_id = p_disaster_id;
    
    -- Disband all teams
    UPDATE Relief_Team 
    SET status = 'Disbanded'
    WHERE disaster_id = p_disaster_id;
    
    -- Release volunteers
    UPDATE Volunteer v
    INNER JOIN Relief_Team t ON v.team_id = t.team_id
    SET v.team_id = NULL,
        v.availability = 'Available'
    WHERE t.disaster_id = p_disaster_id;
    
    SELECT 'Disaster closed successfully' AS message,
           (SELECT COUNT(*) FROM Relief_Team WHERE disaster_id = p_disaster_id) AS teams_disbanded;
END //

DELIMITER ;

-- ============================================================
-- STORED PROCEDURES CREATED: 10
-- ============================================================
-- 1. sp_register_disaster        - Register new disaster
-- 2. sp_add_affected_area        - Add affected area
-- 3. sp_submit_request           - Submit resource request
-- 4. sp_allocate_resources       - Allocate resources
-- 5. sp_update_delivery_status   - Update delivery status
-- 6. sp_register_volunteer       - Register volunteer
-- 7. sp_assign_volunteer_to_team - Assign volunteer to team
-- 8. sp_record_donation          - Record donation
-- 9. sp_get_disaster_report      - Generate disaster report
-- 10. sp_close_disaster          - Close/resolve disaster
-- ============================================================

-- Sample usage:
-- CALL sp_register_disaster('Test Flood', 'Flood', 'High', '2025-01-15', 'Test disaster', @id);
-- SELECT @id;

-- CALL sp_get_disaster_report(3);
