-- ============================================================
-- Migration 003: Add Audit System
-- Description: Adds audit logging tables and triggers
-- ============================================================

-- UP Migration
-- Create Audit_Log table if not exists
CREATE TABLE IF NOT EXISTS Audit_Log (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id INT NOT NULL,
    action_type ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    old_values JSON NULL,
    new_values JSON NULL,
    changed_by VARCHAR(100) DEFAULT (CURRENT_USER()),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_id VARCHAR(100),
    INDEX idx_audit_table (table_name),
    INDEX idx_audit_date (changed_at)
);

-- Record this migration
INSERT INTO _migrations (version, name, status) 
VALUES ('003', 'add_audit_system', 'applied')
ON DUPLICATE KEY UPDATE status = 'applied';

-- DOWN Migration (Rollback)
/*
DROP TABLE IF EXISTS Audit_Log;
DELETE FROM _migrations WHERE version = '003';
*/
