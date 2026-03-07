-- ============================================================
-- DISASTER RELIEF RESOURCE MANAGEMENT SYSTEM (DRRMS)
-- Transaction Management - ACID Properties Demonstration
-- ============================================================

USE drrms_db;

-- ============================================================
-- TRANSACTION CONCEPT OVERVIEW
-- ============================================================
-- ACID Properties:
-- A - Atomicity: All operations succeed or all fail
-- C - Consistency: Database moves from one valid state to another
-- I - Isolation: Concurrent transactions don't interfere
-- D - Durability: Committed changes persist
-- ============================================================

-- ============================================================
-- TRANSACTION 1: Atomic Resource Allocation
-- Allocates resources from multiple warehouses to a request
-- Either all allocations succeed or none do
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_atomic_multi_warehouse_allocation(
    IN p_request_id INT,
    IN p_warehouse1_inv_id INT,
    IN p_qty1 INT,
    IN p_warehouse2_inv_id INT,
    IN p_qty2 INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(200)
)
BEGIN
    DECLARE v_available1 INT;
    DECLARE v_available2 INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Rollback on any error
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = 'Transaction failed - all changes rolled back';
    END;
    
    -- Start transaction
    START TRANSACTION;
    
    -- Lock rows for update to prevent race conditions
    SELECT quantity_available INTO v_available1
    FROM Inventory WHERE inventory_id = p_warehouse1_inv_id FOR UPDATE;
    
    SELECT quantity_available INTO v_available2
    FROM Inventory WHERE inventory_id = p_warehouse2_inv_id FOR UPDATE;
    
    -- Validate both warehouses have sufficient stock
    IF v_available1 < p_qty1 THEN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = CONCAT('Warehouse 1 insufficient: has ', v_available1, ', need ', p_qty1);
    ELSEIF v_available2 < p_qty2 THEN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = CONCAT('Warehouse 2 insufficient: has ', v_available2, ', need ', p_qty2);
    ELSE
        -- Both warehouses have stock - proceed with allocation
        
        -- Create allocations
        INSERT INTO Allocation (request_id, inventory_id, quantity_allocated, delivery_status)
        VALUES (p_request_id, p_warehouse1_inv_id, p_qty1, 'Pending');
        
        INSERT INTO Allocation (request_id, inventory_id, quantity_allocated, delivery_status)
        VALUES (p_request_id, p_warehouse2_inv_id, p_qty2, 'Pending');
        
        -- Update inventory (triggers will handle this, but showing explicit for learning)
        -- Note: In production, triggers already handle this
        
        -- Commit the transaction
        COMMIT;
        
        SET p_success = TRUE;
        SET p_message = CONCAT('Successfully allocated ', p_qty1 + p_qty2, ' units from 2 warehouses');
    END IF;
END //

DELIMITER ;

-- ============================================================
-- TRANSACTION 2: Disaster Closure with Team Disbandment
-- Closes a disaster and releases all volunteers atomically
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_transaction_close_disaster(
    IN p_disaster_id INT,
    IN p_end_date DATE,
    OUT p_teams_disbanded INT,
    OUT p_volunteers_released INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_teams_disbanded = -1;
        SET p_volunteers_released = -1;
    END;
    
    START TRANSACTION;
    
    -- Count teams and volunteers before changes
    SELECT COUNT(*) INTO p_teams_disbanded
    FROM Relief_Team
    WHERE disaster_id = p_disaster_id AND status = 'Active';
    
    SELECT COUNT(*) INTO p_volunteers_released
    FROM Volunteer v
    INNER JOIN Relief_Team t ON v.team_id = t.team_id
    WHERE t.disaster_id = p_disaster_id;
    
    -- Update disaster status
    UPDATE Disaster
    SET status = 'Resolved', end_date = p_end_date
    WHERE disaster_id = p_disaster_id;
    
    -- Release volunteers first (due to foreign key)
    UPDATE Volunteer v
    INNER JOIN Relief_Team t ON v.team_id = t.team_id
    SET v.team_id = NULL, v.availability = 'Available'
    WHERE t.disaster_id = p_disaster_id;
    
    -- Disband all teams
    UPDATE Relief_Team
    SET status = 'Disbanded'
    WHERE disaster_id = p_disaster_id;
    
    COMMIT;
END //

DELIMITER ;

-- ============================================================
-- TRANSACTION 3: Batch Donation Processing with Savepoints
-- Demonstrates partial rollback using savepoints
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_batch_donations_with_savepoints(
    IN p_donor_id INT,
    IN p_disaster_id INT,
    OUT p_successful_count INT,
    OUT p_failed_count INT
)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_resource_id INT;
    DECLARE v_quantity INT;
    DECLARE v_current_donation INT DEFAULT 0;
    
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Rollback to last savepoint on error
        ROLLBACK TO SAVEPOINT donation_savepoint;
        SET p_failed_count = p_failed_count + 1;
    END;
    
    SET p_successful_count = 0;
    SET p_failed_count = 0;
    
    START TRANSACTION;
    
    -- Simulate batch of donations (normally from a temp table or cursor)
    -- Donation 1: Rice - 100 kg
    SAVEPOINT donation_savepoint;
    INSERT INTO Donation (donor_id, disaster_id, donation_type, resource_id, quantity, status)
    VALUES (p_donor_id, p_disaster_id, 'Material', 1, 100, 'Received');
    SET p_successful_count = p_successful_count + 1;
    
    -- Donation 2: Water bottles
    SAVEPOINT donation_savepoint;
    INSERT INTO Donation (donor_id, disaster_id, donation_type, resource_id, quantity, status)
    VALUES (p_donor_id, p_disaster_id, 'Material', 4, 500, 'Received');
    SET p_successful_count = p_successful_count + 1;
    
    -- Donation 3: Blankets
    SAVEPOINT donation_savepoint;
    INSERT INTO Donation (donor_id, disaster_id, donation_type, resource_id, quantity, status)
    VALUES (p_donor_id, p_disaster_id, 'Material', 11, 50, 'Received');
    SET p_successful_count = p_successful_count + 1;
    
    COMMIT;
END //

DELIMITER ;

-- ============================================================
-- TRANSACTION 4: Transfer Resources Between Warehouses
-- Atomic transfer ensuring no resource is lost
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_transfer_between_warehouses(
    IN p_resource_id INT,
    IN p_from_warehouse VARCHAR(100),
    IN p_to_warehouse VARCHAR(100),
    IN p_quantity INT,
    OUT p_status VARCHAR(100)
)
BEGIN
    DECLARE v_from_inv_id INT;
    DECLARE v_to_inv_id INT;
    DECLARE v_from_qty INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status = 'FAILED: Transaction rolled back';
    END;
    
    START TRANSACTION;
    
    -- Get source inventory with lock
    SELECT inventory_id, quantity_available 
    INTO v_from_inv_id, v_from_qty
    FROM Inventory 
    WHERE resource_id = p_resource_id AND warehouse_location = p_from_warehouse
    FOR UPDATE;
    
    IF v_from_inv_id IS NULL THEN
        ROLLBACK;
        SET p_status = 'FAILED: Source warehouse not found';
    ELSEIF v_from_qty < p_quantity THEN
        ROLLBACK;
        SET p_status = CONCAT('FAILED: Insufficient stock. Available: ', v_from_qty);
    ELSE
        -- Get or create destination inventory
        SELECT inventory_id INTO v_to_inv_id
        FROM Inventory
        WHERE resource_id = p_resource_id AND warehouse_location = p_to_warehouse
        FOR UPDATE;
        
        -- Deduct from source
        UPDATE Inventory
        SET quantity_available = quantity_available - p_quantity,
            last_updated = CURRENT_TIMESTAMP
        WHERE inventory_id = v_from_inv_id;
        
        -- Add to destination
        IF v_to_inv_id IS NOT NULL THEN
            UPDATE Inventory
            SET quantity_available = quantity_available + p_quantity,
                last_updated = CURRENT_TIMESTAMP
            WHERE inventory_id = v_to_inv_id;
        ELSE
            INSERT INTO Inventory (resource_id, warehouse_location, quantity_available)
            VALUES (p_resource_id, p_to_warehouse, p_quantity);
        END IF;
        
        COMMIT;
        SET p_status = CONCAT('SUCCESS: Transferred ', p_quantity, ' units');
    END IF;
END //

DELIMITER ;

-- ============================================================
-- TRANSACTION 5: Isolation Level Demonstration
-- Shows different isolation levels and their effects
-- ============================================================

-- Example: Setting isolation levels for different operations

-- READ UNCOMMITTED - Fastest but allows dirty reads
-- Use for: Quick reports where accuracy isn't critical
/*
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
START TRANSACTION;
SELECT COUNT(*) FROM Request WHERE status = 'Pending';
COMMIT;
*/

-- READ COMMITTED (Default) - No dirty reads
-- Use for: Most normal operations
/*
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
SELECT * FROM Inventory WHERE resource_id = 1;
-- Other transactions can modify data, but you won't see uncommitted changes
COMMIT;
*/

-- REPEATABLE READ - Consistent reads within transaction
-- Use for: Reports that need consistent data
/*
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION;
SELECT quantity_available FROM Inventory WHERE inventory_id = 1; -- Returns 100
-- Even if another transaction updates to 80 and commits
SELECT quantity_available FROM Inventory WHERE inventory_id = 1; -- Still returns 100
COMMIT;
*/

-- SERIALIZABLE - Highest isolation, like running one at a time
-- Use for: Critical financial/allocation operations
/*
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION;
SELECT SUM(quantity_available) FROM Inventory WHERE resource_id = 1;
-- Locks prevent other transactions from modifying these rows
UPDATE Inventory SET quantity_available = quantity_available - 10 WHERE inventory_id = 1;
COMMIT;
*/

-- ============================================================
-- TRANSACTION 6: Pessimistic Locking Example
-- Prevents concurrent modifications during critical operations
-- ============================================================
DELIMITER //

CREATE PROCEDURE sp_safe_allocation_with_lock(
    IN p_request_id INT,
    IN p_inventory_id INT,
    IN p_quantity INT,
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE v_available INT;
    DECLARE v_resource_name VARCHAR(100);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = 'FAILED: Lock timeout or error';
    END;
    
    -- Set lock wait timeout (5 seconds)
    SET innodb_lock_wait_timeout = 5;
    
    START TRANSACTION;
    
    -- Acquire exclusive lock on the inventory row
    SELECT i.quantity_available, r.resource_name 
    INTO v_available, v_resource_name
    FROM Inventory i
    INNER JOIN Resource r ON i.resource_id = r.resource_id
    WHERE i.inventory_id = p_inventory_id
    FOR UPDATE;  -- This locks the row
    
    IF v_available < p_quantity THEN
        ROLLBACK;
        SET p_result = CONCAT('FAILED: Only ', v_available, ' ', v_resource_name, ' available');
    ELSE
        -- Safe to proceed - row is locked
        INSERT INTO Allocation (request_id, inventory_id, quantity_allocated, delivery_status)
        VALUES (p_request_id, p_inventory_id, p_quantity, 'Pending');
        
        -- Inventory update is handled by trigger
        
        COMMIT;
        SET p_result = CONCAT('SUCCESS: Allocated ', p_quantity, ' ', v_resource_name);
    END IF;
END //

DELIMITER ;

-- ============================================================
-- TRANSACTIONS PROCEDURES CREATED: 6
-- ============================================================
-- 1. sp_atomic_multi_warehouse_allocation - Multi-source allocation
-- 2. sp_transaction_close_disaster        - Disaster closure
-- 3. sp_batch_donations_with_savepoints   - Savepoint demo
-- 4. sp_transfer_between_warehouses       - Warehouse transfer
-- 5. (Isolation Level Examples)           - Different isolation levels
-- 6. sp_safe_allocation_with_lock         - Pessimistic locking
-- ============================================================

-- Sample usage:
-- CALL sp_transfer_between_warehouses(1, 'Central Warehouse, Kolkata', 'Regional Warehouse, Chennai', 100, @status);
-- SELECT @status;

-- CALL sp_safe_allocation_with_lock(1, 1, 50, @result);
-- SELECT @result;
