-- ============================================================
-- DRRMS Database Migration System
-- Migration Log Table - Tracks Applied Migrations
-- ============================================================

USE drrms_db;

-- Create migration tracking table
CREATE TABLE IF NOT EXISTS _migrations (
    migration_id INT AUTO_INCREMENT PRIMARY KEY,
    version VARCHAR(10) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    applied_by VARCHAR(100) DEFAULT (CURRENT_USER()),
    checksum VARCHAR(64),
    execution_time_ms INT,
    status ENUM('pending', 'applied', 'failed', 'rolled_back') DEFAULT 'pending'
);

-- Insert initial state if starting fresh
INSERT IGNORE INTO _migrations (version, name, status) 
VALUES ('000', 'initial_state', 'applied');

-- View pending migrations
CREATE OR REPLACE VIEW vw_pending_migrations AS
SELECT version, name, status
FROM _migrations
WHERE status = 'pending'
ORDER BY version;

-- View migration history
CREATE OR REPLACE VIEW vw_migration_history AS
SELECT version, name, applied_at, applied_by, execution_time_ms, status
FROM _migrations
ORDER BY version DESC;
