-- ============================================================
-- Migration 002: Add Performance Indexes
-- Description: Adds optimized indexes for common queries
-- ============================================================

-- UP Migration
CREATE INDEX IF NOT EXISTS idx_request_status_urgency ON Request(status, urgency);
CREATE INDEX IF NOT EXISTS idx_request_area_status ON Request(area_id, status);
CREATE INDEX IF NOT EXISTS idx_donation_date ON Donation(donation_date);
CREATE INDEX IF NOT EXISTS idx_allocation_date ON Allocation(allocation_date);

-- Record this migration
INSERT INTO _migrations (version, name, status) 
VALUES ('002', 'add_performance_indexes', 'applied')
ON DUPLICATE KEY UPDATE status = 'applied';

-- DOWN Migration (Rollback)
/*
DROP INDEX idx_request_status_urgency ON Request;
DROP INDEX idx_request_area_status ON Request;
DROP INDEX idx_donation_date ON Donation;
DROP INDEX idx_allocation_date ON Allocation;

DELETE FROM _migrations WHERE version = '002';
*/
