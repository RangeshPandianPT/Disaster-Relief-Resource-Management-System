-- ============================================================
-- DRRMS REV3
-- Topic 3: Concurrency Control (Locking Mechanisms)
-- Database: MySQL 8.0+
-- ============================================================

CREATE DATABASE IF NOT EXISTS drrms_rev3_demo;
USE drrms_rev3_demo;

-- Re-runnable cleanup
DROP PROCEDURE IF EXISTS rev3_sp_allocate_with_for_update;
DROP PROCEDURE IF EXISTS rev3_sp_allocate_optimistic;
DROP PROCEDURE IF EXISTS rev3_sp_named_lock_demo;
DROP TABLE IF EXISTS rev3_lock_audit;
DROP TABLE IF EXISTS rev3_lock_inventory;

-- ============================================================
-- TABLE SETUP
-- ============================================================
CREATE TABLE rev3_lock_inventory (
    inventory_id INT PRIMARY KEY AUTO_INCREMENT,
    resource_name VARCHAR(100) NOT NULL UNIQUE,
    quantity_available INT NOT NULL,
    version_no INT NOT NULL DEFAULT 1,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (quantity_available >= 0)
) ENGINE=InnoDB;

CREATE TABLE rev3_lock_audit (
    audit_id INT PRIMARY KEY AUTO_INCREMENT,
    inventory_id INT,
    actor VARCHAR(50) NOT NULL,
    requested_qty INT NOT NULL,
    lock_type VARCHAR(30) NOT NULL,
    status VARCHAR(20) NOT NULL,
    notes VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT INTO rev3_lock_inventory (resource_name, quantity_available) VALUES
('Rice Bags', 150),
('Water Cans', 300);

-- ============================================================
-- 1) PESSIMISTIC LOCKING: SELECT ... FOR UPDATE
-- Locks the row until transaction commit/rollback.
-- ============================================================
DELIMITER //

CREATE PROCEDURE rev3_sp_allocate_with_for_update(
    IN p_inventory_id INT,
    IN p_qty INT,
    IN p_actor VARCHAR(50),
    OUT p_ok BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_available INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_ok = FALSE;
        SET p_message = 'Rolled back due to lock wait timeout or SQL error';
    END;

    SET p_ok = FALSE;
    SET p_message = 'Transaction not started';

    IF p_qty <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantity must be greater than zero';
    END IF;

    START TRANSACTION;

    SELECT quantity_available
    INTO v_available
    FROM rev3_lock_inventory
    WHERE inventory_id = p_inventory_id
    FOR UPDATE;

    IF v_available IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inventory row not found';
    END IF;

    IF v_available < p_qty THEN
        ROLLBACK;
        INSERT INTO rev3_lock_audit (inventory_id, actor, requested_qty, lock_type, status, notes)
        VALUES (p_inventory_id, p_actor, p_qty, 'FOR UPDATE', 'FAILED', CONCAT('Available=', v_available));
        SET p_message = CONCAT('Failed: insufficient stock. Available=', v_available);
    ELSE
        UPDATE rev3_lock_inventory
        SET quantity_available = quantity_available - p_qty,
            version_no = version_no + 1
        WHERE inventory_id = p_inventory_id;

        INSERT INTO rev3_lock_audit (inventory_id, actor, requested_qty, lock_type, status, notes)
        VALUES (p_inventory_id, p_actor, p_qty, 'FOR UPDATE', 'COMMITTED', 'Exclusive row lock used');

        COMMIT;
        SET p_ok = TRUE;
        SET p_message = 'Committed using FOR UPDATE lock';
    END IF;
END //

DELIMITER ;

-- ============================================================
-- 2) OPTIMISTIC LOCKING: Version column check
-- No long lock while reading; conflict detected during update.
-- ============================================================
DELIMITER //

CREATE PROCEDURE rev3_sp_allocate_optimistic(
    IN p_inventory_id INT,
    IN p_qty INT,
    IN p_expected_version INT,
    IN p_actor VARCHAR(50),
    OUT p_ok BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_rows INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_ok = FALSE;
        SET p_message = 'Rolled back due to SQL error';
    END;

    SET p_ok = FALSE;
    SET p_message = 'Transaction not started';

    START TRANSACTION;

    UPDATE rev3_lock_inventory
    SET quantity_available = quantity_available - p_qty,
        version_no = version_no + 1
    WHERE inventory_id = p_inventory_id
      AND version_no = p_expected_version
      AND quantity_available >= p_qty;

    SET v_rows = ROW_COUNT();

    IF v_rows = 1 THEN
        INSERT INTO rev3_lock_audit (inventory_id, actor, requested_qty, lock_type, status, notes)
        VALUES (p_inventory_id, p_actor, p_qty, 'OPTIMISTIC', 'COMMITTED', CONCAT('Matched version ', p_expected_version));
        COMMIT;
        SET p_ok = TRUE;
        SET p_message = 'Committed using optimistic version check';
    ELSE
        ROLLBACK;
        INSERT INTO rev3_lock_audit (inventory_id, actor, requested_qty, lock_type, status, notes)
        VALUES (p_inventory_id, p_actor, p_qty, 'OPTIMISTIC', 'FAILED', 'Version mismatch or insufficient stock');
        SET p_message = 'Failed: version mismatch or insufficient stock';
    END IF;
END //

DELIMITER ;

-- ============================================================
-- 3) NAMED LOCKS: GET_LOCK / RELEASE_LOCK
-- Useful for app-level critical sections.
-- ============================================================
DELIMITER //

CREATE PROCEDURE rev3_sp_named_lock_demo(
    IN p_lock_name VARCHAR(64),
    IN p_wait_seconds INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_result INT;

    SELECT GET_LOCK(p_lock_name, p_wait_seconds) INTO v_result;

    IF v_result = 1 THEN
        SET p_message = CONCAT('Acquired lock ', p_lock_name, '. Releasing now.');
        DO RELEASE_LOCK(p_lock_name);
    ELSEIF v_result = 0 THEN
        SET p_message = CONCAT('Timeout while waiting for lock ', p_lock_name);
    ELSE
        SET p_message = CONCAT('Error while acquiring lock ', p_lock_name);
    END IF;
END //

DELIMITER ;

-- ============================================================
-- QUICK DEMO CALLS
-- ============================================================
CALL rev3_sp_allocate_with_for_update(1, 40, 'allocator_A', @ok1, @msg1);
SELECT @ok1 AS success, @msg1 AS message;

-- Expected version is now 2 after previous successful call
CALL rev3_sp_allocate_optimistic(1, 10, 2, 'allocator_B', @ok2, @msg2);
SELECT @ok2 AS success, @msg2 AS message;

CALL rev3_sp_named_lock_demo('rev3_global_allocation_lock', 3, @msg3);
SELECT @msg3 AS named_lock_result;

SELECT * FROM rev3_lock_inventory ORDER BY inventory_id;
SELECT * FROM rev3_lock_audit ORDER BY audit_id;

-- ============================================================
-- TWO-SESSION BLOCKING DEMO (manual)
-- ============================================================
-- Session A (Terminal 1)
-- SET SESSION innodb_lock_wait_timeout = 30;
-- START TRANSACTION;
-- SELECT quantity_available
-- FROM rev3_lock_inventory
-- WHERE inventory_id = 1
-- FOR UPDATE;
-- -- Hold transaction open here
--
-- Session B (Terminal 2)
-- SET SESSION innodb_lock_wait_timeout = 5;
-- START TRANSACTION;
-- UPDATE rev3_lock_inventory
-- SET quantity_available = quantity_available - 5
-- WHERE inventory_id = 1;
-- -- This waits for lock, then times out if Session A does not commit
-- ROLLBACK;
--
-- Session A (Terminal 1)
-- COMMIT;
--
-- Then inspect:
-- SELECT * FROM rev3_lock_inventory WHERE inventory_id = 1;
-- ============================================================
