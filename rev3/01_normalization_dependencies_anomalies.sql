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
