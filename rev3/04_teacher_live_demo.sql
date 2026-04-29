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
