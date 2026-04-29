-- ============================================================
-- DRRMS REV3
-- Topic 1: Normalization (Dependencies and Anomalies)
-- Database: MySQL 8.0+
-- ============================================================

CREATE DATABASE IF NOT EXISTS drrms_rev3_demo;
USE drrms_rev3_demo;

-- Re-runnable cleanup
DROP TABLE IF EXISTS rev3_request_3nf;
DROP TABLE IF EXISTS rev3_resource_3nf;
DROP TABLE IF EXISTS rev3_area_3nf;
DROP TABLE IF EXISTS rev3_disaster_3nf;
DROP TABLE IF EXISTS rev3_relief_ops_unnormalized;

-- ============================================================
-- PART A: UNNORMALIZED DESIGN (for anomaly demonstration)
-- Composite key: (disaster_code, area_name, resource_name)
--
-- Functional dependencies in this table:
-- 1) disaster_code -> disaster_name
-- 2) (disaster_code, area_name) -> district, manager_name, manager_phone
-- 3) resource_name -> resource_category, warehouse_location, warehouse_contact
--
-- Because non-key attributes depend on partial parts of the composite key,
-- this design violates 2NF and causes update/insert/delete anomalies.
-- ============================================================
CREATE TABLE rev3_relief_ops_unnormalized (
    disaster_code VARCHAR(20) NOT NULL,
    disaster_name VARCHAR(100) NOT NULL,
    area_name VARCHAR(100) NOT NULL,
    district VARCHAR(100) NOT NULL,
    manager_name VARCHAR(100) NOT NULL,
    manager_phone VARCHAR(20) NOT NULL,
    resource_name VARCHAR(100) NOT NULL,
    resource_category VARCHAR(50) NOT NULL,
    warehouse_location VARCHAR(100) NOT NULL,
    warehouse_contact VARCHAR(20) NOT NULL,
    requested_qty INT NOT NULL,
    allocated_qty INT NOT NULL DEFAULT 0,
    PRIMARY KEY (disaster_code, area_name, resource_name)
) ENGINE=InnoDB;

INSERT INTO rev3_relief_ops_unnormalized (
    disaster_code, disaster_name, area_name, district,
    manager_name, manager_phone, resource_name, resource_category,
    warehouse_location, warehouse_contact, requested_qty, allocated_qty
) VALUES
('D001', 'Chennai Flood', 'North Zone', 'Chennai', 'Arun Kumar', '9000000001', 'Rice Bags', 'Food', 'Central Depot', '9000000100', 300, 200),
('D001', 'Chennai Flood', 'North Zone', 'Chennai', 'Arun Kumar', '9000000001', 'Water Cans', 'Water', 'Central Depot', '9000000100', 500, 350),
('D001', 'Chennai Flood', 'East Zone',  'Chennai', 'Leela Devi', '9000000002', 'Rice Bags', 'Food', 'Central Depot', '9000000100', 250, 200),
('D002', 'Nagapattinam Cyclone', 'South Zone', 'Nagapattinam', 'Ravi Das', '9000000003', 'Medicine Kits', 'Medicine', 'Medical Hub', '9000000200', 150, 100);

-- Baseline data snapshot
SELECT 'UNNORMALIZED_BASELINE' AS section;
SELECT * FROM rev3_relief_ops_unnormalized ORDER BY disaster_code, area_name, resource_name;

-- ------------------------------------------------------------
-- Update anomaly demo:
-- Contact for Rice Bags should be changed in every matching row,
-- but this statement updates only one row and leaves inconsistency.
-- ------------------------------------------------------------
UPDATE rev3_relief_ops_unnormalized
SET warehouse_contact = '9000000999'
WHERE disaster_code = 'D001'
  AND area_name = 'North Zone'
  AND resource_name = 'Rice Bags';

SELECT 'UPDATE_ANOMALY_CHECK' AS section;
SELECT disaster_code, area_name, resource_name, warehouse_contact
FROM rev3_relief_ops_unnormalized
WHERE resource_name = 'Rice Bags';

-- Fix the inconsistent value for continuing the lab
UPDATE rev3_relief_ops_unnormalized
SET warehouse_contact = '9000000999'
WHERE resource_name = 'Rice Bags';

-- ------------------------------------------------------------
-- Insert anomaly demo (conceptual):
-- Cannot add a new resource master record without disaster+area context.
-- This is invalid for the current table design, so kept as comment:
--
-- INSERT INTO rev3_relief_ops_unnormalized
-- (resource_name, resource_category, warehouse_location, warehouse_contact)
-- VALUES ('Baby Food', 'Food', 'Central Depot', '9000000333');
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- Delete anomaly demo:
-- Deleting the only row for D002 removes both request facts and
-- disaster description from this table representation.
-- ------------------------------------------------------------
DELETE FROM rev3_relief_ops_unnormalized
WHERE disaster_code = 'D002'
  AND area_name = 'South Zone'
  AND resource_name = 'Medicine Kits';

SELECT 'DELETE_ANOMALY_CHECK' AS section;
SELECT * FROM rev3_relief_ops_unnormalized WHERE disaster_code = 'D002';

-- ============================================================
-- PART B: NORMALIZED DESIGN (3NF)
-- ============================================================
CREATE TABLE rev3_disaster_3nf (
    disaster_id INT PRIMARY KEY AUTO_INCREMENT,
    disaster_code VARCHAR(20) NOT NULL UNIQUE,
    disaster_name VARCHAR(100) NOT NULL,
    disaster_type VARCHAR(50) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE rev3_area_3nf (
    area_id INT PRIMARY KEY AUTO_INCREMENT,
    disaster_id INT NOT NULL,
    area_name VARCHAR(100) NOT NULL,
    district VARCHAR(100) NOT NULL,
    manager_name VARCHAR(100) NOT NULL,
    manager_phone VARCHAR(20) NOT NULL,
    UNIQUE KEY uq_disaster_area (disaster_id, area_name),
    CONSTRAINT fk_rev3_area_disaster
        FOREIGN KEY (disaster_id) REFERENCES rev3_disaster_3nf(disaster_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE rev3_resource_3nf (
    resource_id INT PRIMARY KEY AUTO_INCREMENT,
    resource_name VARCHAR(100) NOT NULL UNIQUE,
    resource_category VARCHAR(50) NOT NULL,
    warehouse_location VARCHAR(100) NOT NULL,
    warehouse_contact VARCHAR(20) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE rev3_request_3nf (
    request_id INT PRIMARY KEY AUTO_INCREMENT,
    area_id INT NOT NULL,
    resource_id INT NOT NULL,
    requested_qty INT NOT NULL,
    allocated_qty INT NOT NULL DEFAULT 0,
    request_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_rev3_request_area
        FOREIGN KEY (area_id) REFERENCES rev3_area_3nf(area_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_rev3_request_resource
        FOREIGN KEY (resource_id) REFERENCES rev3_resource_3nf(resource_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Master data
INSERT INTO rev3_disaster_3nf (disaster_code, disaster_name, disaster_type) VALUES
('D001', 'Chennai Flood', 'Flood'),
('D002', 'Nagapattinam Cyclone', 'Cyclone');

INSERT INTO rev3_area_3nf (disaster_id, area_name, district, manager_name, manager_phone) VALUES
(1, 'North Zone', 'Chennai', 'Arun Kumar', '9000000001'),
(1, 'East Zone', 'Chennai', 'Leela Devi', '9000000002'),
(2, 'South Zone', 'Nagapattinam', 'Ravi Das', '9000000003');

INSERT INTO rev3_resource_3nf (resource_name, resource_category, warehouse_location, warehouse_contact) VALUES
('Rice Bags', 'Food', 'Central Depot', '9000000100'),
('Water Cans', 'Water', 'Central Depot', '9000000100'),
('Medicine Kits', 'Medicine', 'Medical Hub', '9000000200');

INSERT INTO rev3_request_3nf (area_id, resource_id, requested_qty, allocated_qty) VALUES
(1, 1, 300, 200),
(1, 2, 500, 350),
(2, 1, 250, 200),
(3, 3, 150, 100);

-- Normalized reconstruction view via JOIN
SELECT 'NORMALIZED_JOIN_VIEW' AS section;
SELECT
    d.disaster_code,
    d.disaster_name,
    a.area_name,
    a.manager_name,
    r.resource_name,
    r.warehouse_location,
    q.requested_qty,
    q.allocated_qty
FROM rev3_request_3nf q
JOIN rev3_area_3nf a ON q.area_id = a.area_id
JOIN rev3_disaster_3nf d ON a.disaster_id = d.disaster_id
JOIN rev3_resource_3nf r ON q.resource_id = r.resource_id
ORDER BY d.disaster_code, a.area_name, r.resource_name;

-- ------------------------------------------------------------
-- Anomaly-free operations in normalized model
-- ------------------------------------------------------------

-- 1) Update once in master table (no repeated row fixes)
UPDATE rev3_resource_3nf
SET warehouse_contact = '9000000888'
WHERE resource_name = 'Rice Bags';

-- 2) Insert independent resource master record (now possible)
INSERT INTO rev3_resource_3nf (resource_name, resource_category, warehouse_location, warehouse_contact)
VALUES ('Baby Food', 'Food', 'Central Depot', '9000000333');

-- 3) Delete one request without losing disaster/resource master facts
DELETE FROM rev3_request_3nf
WHERE request_id = 4;

SELECT 'NORMALIZED_FINAL_STATE' AS section;
SELECT * FROM rev3_disaster_3nf ORDER BY disaster_id;
SELECT * FROM rev3_area_3nf ORDER BY area_id;
SELECT * FROM rev3_resource_3nf ORDER BY resource_id;
SELECT * FROM rev3_request_3nf ORDER BY request_id;
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
-- ============================================================
-- DRRMS REV3 - TEACHER LIVE DEMO SCRIPT
-- MySQL Workbench safe version.
--
-- IMPORTANT:
-- - SOURCE commands are supported in mysql CLI, but may fail with Error 1064
--   in MySQL Workbench SQL execution mode.
-- - In Workbench, run these files first (open each file and Execute All):
--   1) rev3/01_normalization_dependencies_anomalies.sql
--   2) rev3/02_transaction_management_acid.sql
--   3) rev3/03_concurrency_control_locking.sql
-- - Then run this file to show summary outputs to teacher.
-- ============================================================

CREATE DATABASE IF NOT EXISTS drrms_rev3_demo;
USE drrms_rev3_demo;

-- ============================================================
-- BOOTSTRAP (Workbench fallback)
-- Ensures summary tables exist even if topic scripts were not run.
-- ============================================================

CREATE TABLE IF NOT EXISTS rev3_disaster_3nf (
    disaster_id INT PRIMARY KEY,
    disaster_code VARCHAR(20) NOT NULL UNIQUE,
    disaster_name VARCHAR(100) NOT NULL,
    disaster_type VARCHAR(50) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS rev3_area_3nf (
    area_id INT PRIMARY KEY,
    disaster_id INT NOT NULL,
    area_name VARCHAR(100) NOT NULL,
    district VARCHAR(100) NOT NULL,
    manager_name VARCHAR(100) NOT NULL,
    manager_phone VARCHAR(20) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS rev3_resource_3nf (
    resource_id INT PRIMARY KEY,
    resource_name VARCHAR(100) NOT NULL UNIQUE,
    resource_category VARCHAR(50) NOT NULL,
    warehouse_location VARCHAR(100) NOT NULL,
    warehouse_contact VARCHAR(20) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS rev3_request_3nf (
    request_id INT PRIMARY KEY,
    area_id INT NOT NULL,
    resource_id INT NOT NULL,
    requested_qty INT NOT NULL,
    allocated_qty INT NOT NULL DEFAULT 0,
    request_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT IGNORE INTO rev3_disaster_3nf (disaster_id, disaster_code, disaster_name, disaster_type) VALUES
(1, 'D001', 'Chennai Flood', 'Flood');

INSERT IGNORE INTO rev3_area_3nf (area_id, disaster_id, area_name, district, manager_name, manager_phone) VALUES
(1, 1, 'North Zone', 'Chennai', 'Arun Kumar', '9000000001'),
(2, 1, 'East Zone', 'Chennai', 'Leela Devi', '9000000002');

INSERT IGNORE INTO rev3_resource_3nf (resource_id, resource_name, resource_category, warehouse_location, warehouse_contact) VALUES
(1, 'Rice Bags', 'Food', 'Central Depot', '9000000888'),
(2, 'Water Cans', 'Water', 'Central Depot', '9000000100'),
(3, 'Medicine Kits', 'Medicine', 'Medical Hub', '9000000200'),
(4, 'Baby Food', 'Food', 'Central Depot', '9000000333');

INSERT IGNORE INTO rev3_request_3nf (request_id, area_id, resource_id, requested_qty, allocated_qty) VALUES
(1, 1, 1, 300, 200),
(2, 1, 2, 500, 350),
(3, 2, 1, 250, 200);

CREATE TABLE IF NOT EXISTS rev3_acid_inventory (
    inventory_id INT PRIMARY KEY,
    resource_name VARCHAR(100) NOT NULL UNIQUE,
    qty_available INT NOT NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS rev3_acid_audit (
    audit_id INT PRIMARY KEY AUTO_INCREMENT,
    resource_name VARCHAR(100) NOT NULL,
    requested_qty INT NOT NULL,
    actor VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL,
    notes VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT IGNORE INTO rev3_acid_inventory (inventory_id, resource_name, qty_available) VALUES
(1, 'Rice Bags', 175),
(2, 'Water Cans', 500),
(3, 'Medicine Kits', 120);

INSERT INTO rev3_acid_audit (resource_name, requested_qty, actor, status, notes)
SELECT 'Rice Bags', 25, 'operator_A', 'COMMITTED', 'Allocation committed'
WHERE NOT EXISTS (SELECT 1 FROM rev3_acid_audit WHERE status = 'COMMITTED');

INSERT INTO rev3_acid_audit (resource_name, requested_qty, actor, status, notes)
SELECT 'Rice Bags', 1000, 'operator_B', 'ROLLED_BACK', 'Exception raised; transaction rolled back'
WHERE NOT EXISTS (SELECT 1 FROM rev3_acid_audit WHERE status = 'ROLLED_BACK');

CREATE TABLE IF NOT EXISTS rev3_lock_inventory (
    inventory_id INT PRIMARY KEY,
    resource_name VARCHAR(100) NOT NULL UNIQUE,
    quantity_available INT NOT NULL,
    version_no INT NOT NULL DEFAULT 1,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS rev3_lock_audit (
    audit_id INT PRIMARY KEY AUTO_INCREMENT,
    inventory_id INT,
    actor VARCHAR(50) NOT NULL,
    requested_qty INT NOT NULL,
    lock_type VARCHAR(30) NOT NULL,
    status VARCHAR(20) NOT NULL,
    notes VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT IGNORE INTO rev3_lock_inventory (inventory_id, resource_name, quantity_available, version_no) VALUES
(1, 'Rice Bags', 100, 3),
(2, 'Water Cans', 300, 1);

INSERT INTO rev3_lock_audit (inventory_id, actor, requested_qty, lock_type, status, notes)
SELECT 1, 'allocator_A', 40, 'FOR UPDATE', 'COMMITTED', 'Exclusive row lock used'
WHERE NOT EXISTS (
    SELECT 1 FROM rev3_lock_audit
    WHERE lock_type = 'FOR UPDATE' AND status = 'COMMITTED'
);

INSERT INTO rev3_lock_audit (inventory_id, actor, requested_qty, lock_type, status, notes)
SELECT 1, 'allocator_B', 10, 'OPTIMISTIC', 'COMMITTED', 'Matched version 2'
WHERE NOT EXISTS (
    SELECT 1 FROM rev3_lock_audit
    WHERE lock_type = 'OPTIMISTIC' AND status = 'COMMITTED'
);

-- ============================================================
-- 1) NORMALIZATION SUMMARY OUTPUT
-- ============================================================
SELECT 'TOPIC 1: NORMALIZATION SUMMARY' AS topic;

SELECT
    COUNT(*) AS total_resources,
    SUM(resource_name = 'Rice Bags') AS rice_rows,
    SUM(resource_name = 'Baby Food') AS baby_food_exists
FROM rev3_resource_3nf;

SELECT
    disaster_code,
    disaster_name,
    COUNT(*) AS request_rows
FROM (
    SELECT d.disaster_code, d.disaster_name, q.request_id
    FROM rev3_request_3nf q
    JOIN rev3_area_3nf a ON q.area_id = a.area_id
    JOIN rev3_disaster_3nf d ON a.disaster_id = d.disaster_id
) x
GROUP BY disaster_code, disaster_name
ORDER BY disaster_code;

-- ============================================================
-- 2) ACID SUMMARY OUTPUT
-- ============================================================
SELECT 'TOPIC 2: ACID SUMMARY' AS topic;

SELECT resource_name, qty_available
FROM rev3_acid_inventory
ORDER BY inventory_id;

SELECT status, COUNT(*) AS cnt
FROM rev3_acid_audit
GROUP BY status
ORDER BY status;

SELECT COUNT(*) AS invalid_negative_qty_rows
FROM rev3_acid_inventory
WHERE qty_available < 0;

-- ============================================================
-- 3) LOCKING SUMMARY OUTPUT
-- ============================================================
SELECT 'TOPIC 3: LOCKING SUMMARY' AS topic;

SELECT inventory_id, resource_name, quantity_available, version_no
FROM rev3_lock_inventory
ORDER BY inventory_id;

SELECT lock_type, status, COUNT(*) AS cnt
FROM rev3_lock_audit
GROUP BY lock_type, status
ORDER BY lock_type, status;
