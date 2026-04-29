-- ============================================================
-- DRRMS REV3
-- Topic 2: Transaction Management (ACID Properties)
-- Database: MySQL 8.0+
-- ============================================================

CREATE DATABASE IF NOT EXISTS drrms_rev3_demo;
USE drrms_rev3_demo;

-- Re-runnable cleanup
DROP PROCEDURE IF EXISTS rev3_sp_allocate_atomic;
DROP TABLE IF EXISTS rev3_acid_audit;
DROP TABLE IF EXISTS rev3_acid_inventory;
DROP TABLE IF EXISTS rev3_isolation_lab;

-- ============================================================
-- TABLE SETUP
-- ============================================================
CREATE TABLE rev3_acid_inventory (
    inventory_id INT PRIMARY KEY AUTO_INCREMENT,
    resource_name VARCHAR(100) NOT NULL UNIQUE,
    qty_available INT NOT NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (qty_available >= 0)
) ENGINE=InnoDB;

CREATE TABLE rev3_acid_audit (
    audit_id INT PRIMARY KEY AUTO_INCREMENT,
    resource_name VARCHAR(100) NOT NULL,
    requested_qty INT NOT NULL,
    actor VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL,
    notes VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT INTO rev3_acid_inventory (resource_name, qty_available) VALUES
('Rice Bags', 200),
('Water Cans', 500),
('Medicine Kits', 120);

-- ============================================================
-- ATOMICITY + CONSISTENCY
-- Procedure does all-or-nothing allocation with rollback on failure.
-- ============================================================
DELIMITER //

CREATE PROCEDURE rev3_sp_allocate_atomic(
    IN p_resource_name VARCHAR(100),
    IN p_qty INT,
    IN p_actor VARCHAR(50),
    OUT p_ok BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_inventory_id INT;
    DECLARE v_current_qty INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        INSERT INTO rev3_acid_audit (resource_name, requested_qty, actor, status, notes)
        VALUES (p_resource_name, p_qty, p_actor, 'ROLLED_BACK', 'Exception raised; transaction rolled back');
        SET p_ok = FALSE;
        SET p_message = 'Rolled back due to SQL exception';
    END;

    SET p_ok = FALSE;
    SET p_message = 'Transaction not started';

    START TRANSACTION;

    SELECT inventory_id, qty_available
    INTO v_inventory_id, v_current_qty
    FROM rev3_acid_inventory
    WHERE resource_name = p_resource_name
    FOR UPDATE;

    IF v_inventory_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Resource not found';
    END IF;

    IF p_qty <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantity must be greater than zero';
    END IF;

    IF v_current_qty < p_qty THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock';
    END IF;

    UPDATE rev3_acid_inventory
    SET qty_available = qty_available - p_qty
    WHERE inventory_id = v_inventory_id;

    INSERT INTO rev3_acid_audit (resource_name, requested_qty, actor, status, notes)
    VALUES (p_resource_name, p_qty, p_actor, 'COMMITTED', 'Allocation committed');

    COMMIT;

    SET p_ok = TRUE;
    SET p_message = CONCAT('Committed. Remaining qty = ', v_current_qty - p_qty);
END //

DELIMITER ;

-- ============================================================
-- ACID DEMO RUNS
-- ============================================================

-- A) Successful transaction
CALL rev3_sp_allocate_atomic('Rice Bags', 25, 'operator_A', @ok1, @msg1);
SELECT @ok1 AS success, @msg1 AS message;

-- B) Failing transaction (insufficient stock): should rollback fully
CALL rev3_sp_allocate_atomic('Rice Bags', 1000, 'operator_B', @ok2, @msg2);
SELECT @ok2 AS success, @msg2 AS message;

SELECT 'INVENTORY_AFTER_ATOMICITY_TEST' AS section;
SELECT * FROM rev3_acid_inventory ORDER BY inventory_id;

SELECT 'AUDIT_AFTER_ATOMICITY_TEST' AS section;
SELECT * FROM rev3_acid_audit ORDER BY audit_id;

-- ============================================================
-- CONSISTENCY CHECK
-- Constraint guarantees no negative stock can persist.
-- ============================================================
SELECT 'CONSISTENCY_CHECK' AS section;
SELECT COUNT(*) AS invalid_negative_qty_rows
FROM rev3_acid_inventory
WHERE qty_available < 0;

-- Optional manual consistency violation test (kept commented):
-- UPDATE rev3_acid_inventory SET qty_available = -5 WHERE inventory_id = 1;

-- ============================================================
-- ISOLATION LAB (Run in two sessions manually)
-- ============================================================
CREATE TABLE rev3_isolation_lab (
    id INT PRIMARY KEY,
    qty INT NOT NULL
) ENGINE=InnoDB;

INSERT INTO rev3_isolation_lab (id, qty)
VALUES (1, 50)
ON DUPLICATE KEY UPDATE qty = VALUES(qty);

-- Session A (Terminal 1)
-- SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- START TRANSACTION;
-- SELECT qty FROM rev3_isolation_lab WHERE id = 1;
-- -- Keep transaction open
--
-- Session B (Terminal 2)
-- START TRANSACTION;
-- UPDATE rev3_isolation_lab SET qty = 80 WHERE id = 1;
-- COMMIT;
--
-- Session A (Terminal 1)
-- SELECT qty FROM rev3_isolation_lab WHERE id = 1;
-- COMMIT;
--
-- Under READ COMMITTED, Session A can see 80 in second read.

-- Repeatable read variant:
-- Session A: SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- Session A keeps transaction open after first read.
-- Session B updates and commits.
-- Session A second read still sees original value within same transaction.

-- ============================================================
-- DURABILITY
-- After COMMIT, data remains even after reconnect/server restart.
-- Verify by reconnecting and running:
-- SELECT resource_name, qty_available FROM rev3_acid_inventory;
-- ============================================================
