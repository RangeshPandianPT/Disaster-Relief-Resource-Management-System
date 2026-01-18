-- ============================================================
-- DISASTER RELIEF RESOURCE MANAGEMENT SYSTEM (DRRMS)
-- Performance Optimization - Query Tuning & Best Practices
-- ============================================================

USE drrms_db;

-- ============================================================
-- SECTION 1: QUERY ANALYSIS WITH EXPLAIN
-- ============================================================
-- Use EXPLAIN to understand query execution plans

-- Example 1: Analyze a JOIN query
EXPLAIN ANALYZE
SELECT r.request_id, aa.area_name, res.resource_name, r.quantity_requested
FROM Request r
INNER JOIN Affected_Area aa ON r.area_id = aa.area_id
INNER JOIN Resource res ON r.resource_id = res.resource_id
WHERE r.status = 'Pending';

-- Example 2: Analyze subquery vs JOIN
-- Subquery version (often slower)
EXPLAIN ANALYZE
SELECT * FROM Request 
WHERE area_id IN (SELECT area_id FROM Affected_Area WHERE priority = 'Critical');

-- JOIN version (usually faster)
EXPLAIN ANALYZE
SELECT r.* FROM Request r
INNER JOIN Affected_Area aa ON r.area_id = aa.area_id
WHERE aa.priority = 'Critical';

-- ============================================================
-- SECTION 2: OPTIMIZED INDEXES
-- ============================================================

-- Composite index for common query patterns
CREATE INDEX idx_request_status_urgency ON Request(status, urgency);
CREATE INDEX idx_request_area_status ON Request(area_id, status);

-- Covering index - includes all columns needed by query
CREATE INDEX idx_allocation_covering ON Allocation(request_id, delivery_status, quantity_allocated);

-- Index for date range queries
CREATE INDEX idx_donation_date ON Donation(donation_date);
CREATE INDEX idx_allocation_date ON Allocation(allocation_date);

-- Partial index simulation using generated column
-- For filtering active disasters frequently
ALTER TABLE Disaster ADD COLUMN is_active BOOLEAN 
    GENERATED ALWAYS AS (status = 'Active') STORED;
CREATE INDEX idx_disaster_active ON Disaster(is_active);

-- ============================================================
-- SECTION 3: QUERY REWRITING FOR PERFORMANCE
-- ============================================================

-- SLOW: Using OR in WHERE clause
-- SELECT * FROM Request WHERE urgency = 'Critical' OR urgency = 'High';

-- FASTER: Using IN clause
SELECT * FROM Request WHERE urgency IN ('Critical', 'High');

-- SLOW: Using functions on indexed columns
-- SELECT * FROM Donation WHERE YEAR(donation_date) = 2024;

-- FASTER: Using range comparison
SELECT * FROM Donation 
WHERE donation_date >= '2024-01-01' AND donation_date < '2025-01-01';

-- SLOW: SELECT * with LIMIT without ORDER BY
-- SELECT * FROM Volunteer LIMIT 10;

-- FASTER: Deterministic ordering
SELECT * FROM Volunteer ORDER BY volunteer_id LIMIT 10;

-- ============================================================
-- SECTION 4: OPTIMIZED STORED PROCEDURES
-- ============================================================

DELIMITER //

-- Optimized procedure using EXISTS instead of COUNT
CREATE PROCEDURE sp_optimized_check_stock(
    IN p_resource_id INT,
    OUT p_has_stock BOOLEAN
)
BEGIN
    -- Instead of: SELECT COUNT(*) > 0 ...
    SELECT EXISTS(
        SELECT 1 FROM Inventory 
        WHERE resource_id = p_resource_id 
        AND quantity_available > 0
        LIMIT 1
    ) INTO p_has_stock;
END //

-- Batch insert procedure for better performance
CREATE PROCEDURE sp_batch_insert_donations(
    IN p_json_data JSON
)
BEGIN
    -- Use JSON_TABLE for bulk inserts (MySQL 8.0+)
    INSERT INTO Donation (donor_id, disaster_id, donation_type, amount, status)
    SELECT 
        donor_id, disaster_id, donation_type, amount, 'Received'
    FROM JSON_TABLE(p_json_data, '$[*]' COLUMNS(
        donor_id INT PATH '$.donor_id',
        disaster_id INT PATH '$.disaster_id',
        donation_type VARCHAR(20) PATH '$.type',
        amount DECIMAL(12,2) PATH '$.amount'
    )) AS jt;
END //

-- Pagination with keyset (faster than OFFSET for large tables)
CREATE PROCEDURE sp_get_requests_paginated(
    IN p_last_id INT,
    IN p_page_size INT
)
BEGIN
    -- Instead of: LIMIT 10 OFFSET 10000 (slow)
    -- Use keyset pagination (fast):
    SELECT request_id, area_id, resource_id, quantity_requested, status
    FROM Request
    WHERE request_id > p_last_id
    ORDER BY request_id
    LIMIT p_page_size;
END //

DELIMITER ;

-- ============================================================
-- SECTION 5: QUERY CACHE AND HINTS
-- ============================================================

-- Force index usage (when optimizer makes wrong choice)
SELECT * FROM Request FORCE INDEX (idx_request_status_urgency)
WHERE status = 'Pending' AND urgency = 'Critical';

-- Ignore index (for testing without index)
SELECT * FROM Request IGNORE INDEX (idx_request_status_urgency)
WHERE status = 'Pending';

-- Straight join (force join order)
SELECT STRAIGHT_JOIN r.*, aa.area_name
FROM Request r
INNER JOIN Affected_Area aa ON r.area_id = aa.area_id
WHERE r.status = 'Pending';

-- ============================================================
-- SECTION 6: TABLE PARTITIONING (for large tables)
-- ============================================================

-- Example: Partition Donations by year
-- Note: This requires recreating the table

/*
CREATE TABLE Donation_Partitioned (
    donation_id INT AUTO_INCREMENT,
    donor_id INT NOT NULL,
    disaster_id INT,
    donation_type VARCHAR(20) NOT NULL,
    amount DECIMAL(12,2),
    resource_id INT,
    quantity INT,
    donation_date DATE NOT NULL,
    receipt_no VARCHAR(50),
    status VARCHAR(20),
    PRIMARY KEY (donation_id, donation_date)
)
PARTITION BY RANGE (YEAR(donation_date)) (
    PARTITION p2022 VALUES LESS THAN (2023),
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION pmax VALUES LESS THAN MAXVALUE
);
*/

-- ============================================================
-- SECTION 7: PERFORMANCE BENCHMARKING PROCEDURE
-- ============================================================

DELIMITER //

CREATE PROCEDURE sp_benchmark_query(
    IN p_query_name VARCHAR(100),
    IN p_iterations INT
)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE start_time DATETIME(6);
    DECLARE end_time DATETIME(6);
    DECLARE total_ms DECIMAL(10,3);
    
    CREATE TEMPORARY TABLE IF NOT EXISTS benchmark_results (
        query_name VARCHAR(100),
        iterations INT,
        total_time_ms DECIMAL(10,3),
        avg_time_ms DECIMAL(10,3),
        run_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    SET start_time = NOW(6);
    
    WHILE i < p_iterations DO
        -- Run the query to benchmark
        CASE p_query_name
            WHEN 'pending_requests' THEN
                SELECT COUNT(*) INTO @dummy FROM Request WHERE status = 'Pending';
            WHEN 'active_disasters' THEN
                SELECT COUNT(*) INTO @dummy FROM Disaster WHERE status = 'Active';
            WHEN 'low_stock' THEN
                SELECT COUNT(*) INTO @dummy FROM Inventory i
                INNER JOIN Resource r ON i.resource_id = r.resource_id
                WHERE i.quantity_available < r.min_stock;
            WHEN 'donation_total' THEN
                SELECT SUM(amount) INTO @dummy FROM Donation WHERE donation_type = 'Money';
            ELSE
                SELECT 1 INTO @dummy;
        END CASE;
        
        SET i = i + 1;
    END WHILE;
    
    SET end_time = NOW(6);
    SET total_ms = TIMESTAMPDIFF(MICROSECOND, start_time, end_time) / 1000;
    
    INSERT INTO benchmark_results (query_name, iterations, total_time_ms, avg_time_ms)
    VALUES (p_query_name, p_iterations, total_ms, total_ms / p_iterations);
    
    SELECT * FROM benchmark_results ORDER BY run_at DESC LIMIT 5;
END //

DELIMITER ;

-- ============================================================
-- SECTION 8: SLOW QUERY IDENTIFICATION
-- ============================================================

-- View to identify potentially slow queries from process list
CREATE OR REPLACE VIEW vw_slow_processes AS
SELECT 
    id AS process_id,
    user,
    host,
    db,
    command,
    time AS seconds_running,
    state,
    LEFT(info, 100) AS query_preview
FROM information_schema.processlist
WHERE command != 'Sleep'
AND time > 5  -- Running for more than 5 seconds
ORDER BY time DESC;

-- ============================================================
-- SECTION 9: INDEX USAGE ANALYSIS
-- ============================================================

-- Check which indexes are being used
CREATE OR REPLACE VIEW vw_index_usage AS
SELECT 
    t.TABLE_NAME,
    s.INDEX_NAME,
    s.SEQ_IN_INDEX,
    s.COLUMN_NAME,
    s.CARDINALITY,
    t.TABLE_ROWS,
    ROUND(s.CARDINALITY / NULLIF(t.TABLE_ROWS, 0) * 100, 2) AS selectivity_pct
FROM information_schema.STATISTICS s
JOIN information_schema.TABLES t 
    ON s.TABLE_SCHEMA = t.TABLE_SCHEMA AND s.TABLE_NAME = t.TABLE_NAME
WHERE s.TABLE_SCHEMA = 'drrms_db'
ORDER BY t.TABLE_NAME, s.INDEX_NAME, s.SEQ_IN_INDEX;

-- ============================================================
-- SECTION 10: OPTIMIZATION RECOMMENDATIONS
-- ============================================================

DELIMITER //

CREATE PROCEDURE sp_optimization_recommendations()
BEGIN
    -- Check tables without primary key
    SELECT 'Tables without PRIMARY KEY:' AS recommendation;
    SELECT TABLE_NAME 
    FROM information_schema.TABLES t
    WHERE TABLE_SCHEMA = 'drrms_db'
    AND TABLE_TYPE = 'BASE TABLE'
    AND NOT EXISTS (
        SELECT 1 FROM information_schema.TABLE_CONSTRAINTS tc
        WHERE tc.TABLE_SCHEMA = t.TABLE_SCHEMA
        AND tc.TABLE_NAME = t.TABLE_NAME
        AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
    );
    
    -- Check for missing indexes on foreign keys
    SELECT 'Foreign keys without indexes:' AS recommendation;
    SELECT 
        kcu.TABLE_NAME,
        kcu.COLUMN_NAME,
        kcu.CONSTRAINT_NAME
    FROM information_schema.KEY_COLUMN_USAGE kcu
    WHERE kcu.TABLE_SCHEMA = 'drrms_db'
    AND kcu.REFERENCED_TABLE_NAME IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM information_schema.STATISTICS s
        WHERE s.TABLE_SCHEMA = kcu.TABLE_SCHEMA
        AND s.TABLE_NAME = kcu.TABLE_NAME
        AND s.COLUMN_NAME = kcu.COLUMN_NAME
    );
    
    -- Large tables that might benefit from partitioning
    SELECT 'Large tables (>10000 rows) - consider partitioning:' AS recommendation;
    SELECT TABLE_NAME, TABLE_ROWS, 
           ROUND(DATA_LENGTH / 1024 / 1024, 2) AS data_size_mb
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'drrms_db'
    AND TABLE_ROWS > 10000
    ORDER BY TABLE_ROWS DESC;
END //

DELIMITER ;

-- ============================================================
-- PERFORMANCE OPTIMIZATION SUMMARY
-- ============================================================
-- New Indexes: 6
-- Optimized Procedures: 4
-- Analysis Views: 2
-- Benchmarking Tools: 1
-- Recommendation System: 1
-- ============================================================

-- Sample usage:
-- CALL sp_benchmark_query('pending_requests', 100);
-- CALL sp_optimization_recommendations();
-- SELECT * FROM vw_index_usage;
