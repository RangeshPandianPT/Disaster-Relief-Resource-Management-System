-- ============================================================
-- DISASTER RELIEF RESOURCE MANAGEMENT SYSTEM (DRRMS)
-- Security & Roles - Role-Based Access Control
-- ============================================================

USE drrms_db;

-- ============================================================
-- SECURITY OVERVIEW
-- ============================================================
-- This script demonstrates:
-- 1. User creation
-- 2. Role-based access control (RBAC)
-- 3. View-based security
-- 4. Stored procedure security
-- 5. Row-level security concepts
-- ============================================================

-- ============================================================
-- SECTION 1: CREATE ROLES
-- ============================================================
-- Note: Roles require MySQL 8.0+
-- Run these commands as a user with administrative privileges

-- Create roles for different user types
CREATE ROLE IF NOT EXISTS 'drrms_admin';
CREATE ROLE IF NOT EXISTS 'drrms_coordinator';
CREATE ROLE IF NOT EXISTS 'drrms_volunteer_mgr';
CREATE ROLE IF NOT EXISTS 'drrms_donor_mgr';
CREATE ROLE IF NOT EXISTS 'drrms_readonly';

-- ============================================================
-- SECTION 2: GRANT PRIVILEGES TO ROLES
-- ============================================================

-- ADMIN ROLE: Full access to everything
GRANT ALL PRIVILEGES ON drrms_db.* TO 'drrms_admin';

-- COORDINATOR ROLE: Manage disasters, areas, teams, requests, allocations
GRANT SELECT, INSERT, UPDATE ON drrms_db.Disaster TO 'drrms_coordinator';
GRANT SELECT, INSERT, UPDATE ON drrms_db.Affected_Area TO 'drrms_coordinator';
GRANT SELECT, INSERT, UPDATE ON drrms_db.Relief_Team TO 'drrms_coordinator';
GRANT SELECT, INSERT, UPDATE ON drrms_db.Request TO 'drrms_coordinator';
GRANT SELECT, INSERT, UPDATE ON drrms_db.Allocation TO 'drrms_coordinator';
GRANT SELECT ON drrms_db.Resource TO 'drrms_coordinator';
GRANT SELECT ON drrms_db.Inventory TO 'drrms_coordinator';
GRANT SELECT ON drrms_db.Volunteer TO 'drrms_coordinator';

-- VOLUNTEER MANAGER ROLE: Manage volunteers and teams
GRANT SELECT, INSERT, UPDATE ON drrms_db.Volunteer TO 'drrms_volunteer_mgr';
GRANT SELECT, INSERT, UPDATE ON drrms_db.Relief_Team TO 'drrms_volunteer_mgr';
GRANT SELECT ON drrms_db.Disaster TO 'drrms_volunteer_mgr';
GRANT SELECT ON drrms_db.Affected_Area TO 'drrms_volunteer_mgr';

-- DONOR MANAGER ROLE: Manage donors and donations
GRANT SELECT, INSERT, UPDATE ON drrms_db.Donor TO 'drrms_donor_mgr';
GRANT SELECT, INSERT, UPDATE ON drrms_db.Donation TO 'drrms_donor_mgr';
GRANT SELECT ON drrms_db.Resource TO 'drrms_donor_mgr';
GRANT SELECT ON drrms_db.Disaster TO 'drrms_donor_mgr';

-- READONLY ROLE: View-only access for reporting
GRANT SELECT ON drrms_db.* TO 'drrms_readonly';

-- ============================================================
-- SECTION 3: CREATE SAMPLE USERS
-- ============================================================

-- Create users with passwords
-- Note: In production, use strong passwords!
CREATE USER IF NOT EXISTS 'admin_user'@'localhost' IDENTIFIED BY 'AdminPass123!';
CREATE USER IF NOT EXISTS 'coordinator1'@'localhost' IDENTIFIED BY 'CoordPass123!';
CREATE USER IF NOT EXISTS 'volunteer_mgr'@'localhost' IDENTIFIED BY 'VolMgrPass123!';
CREATE USER IF NOT EXISTS 'donor_mgr'@'localhost' IDENTIFIED BY 'DonorMgrPass123!';
CREATE USER IF NOT EXISTS 'report_viewer'@'localhost' IDENTIFIED BY 'ReportPass123!';

-- Assign roles to users
GRANT 'drrms_admin' TO 'admin_user'@'localhost';
GRANT 'drrms_coordinator' TO 'coordinator1'@'localhost';
GRANT 'drrms_volunteer_mgr' TO 'volunteer_mgr'@'localhost';
GRANT 'drrms_donor_mgr' TO 'donor_mgr'@'localhost';
GRANT 'drrms_readonly' TO 'report_viewer'@'localhost';

-- Set default roles
SET DEFAULT ROLE 'drrms_admin' TO 'admin_user'@'localhost';
SET DEFAULT ROLE 'drrms_coordinator' TO 'coordinator1'@'localhost';
SET DEFAULT ROLE 'drrms_volunteer_mgr' TO 'volunteer_mgr'@'localhost';
SET DEFAULT ROLE 'drrms_donor_mgr' TO 'donor_mgr'@'localhost';
SET DEFAULT ROLE 'drrms_readonly' TO 'report_viewer'@'localhost';

-- ============================================================
-- SECTION 4: SECURE VIEWS (View-Based Security)
-- ============================================================
-- Views can limit what data users see

-- Secure view: Hide sensitive donor contact information
CREATE OR REPLACE VIEW vw_public_donor_list AS
SELECT 
    donor_id,
    donor_name,
    donor_type,
    -- Mask email address
    CONCAT(LEFT(email, 3), '***@***') AS masked_email,
    -- Show city from address only
    SUBSTRING_INDEX(address, ',', -1) AS city,
    registered_at
FROM Donor;

-- Grant access to this view instead of the base table
GRANT SELECT ON drrms_db.vw_public_donor_list TO 'drrms_readonly';

-- Secure view: Volunteer directory without personal contact details
CREATE OR REPLACE VIEW vw_volunteer_directory AS
SELECT 
    volunteer_id,
    name,
    skills,
    availability,
    experience_years,
    t.team_name,
    t.team_type
FROM Volunteer v
LEFT JOIN Relief_Team t ON v.team_id = t.team_id;
-- Email and phone are not exposed

GRANT SELECT ON drrms_db.vw_volunteer_directory TO 'drrms_readonly';

-- ============================================================
-- SECTION 5: STORED PROCEDURE SECURITY
-- ============================================================
-- Execute procedures with DEFINER privileges for controlled access

DELIMITER //

-- Procedure that runs with elevated privileges
CREATE PROCEDURE sp_secure_add_donation(
    IN p_donor_id INT,
    IN p_disaster_id INT,
    IN p_amount DECIMAL(12,2),
    OUT p_donation_id INT,
    OUT p_receipt VARCHAR(50)
)
SQL SECURITY DEFINER  -- Runs with creator's privileges
COMMENT 'Securely add a donation with auto-generated receipt'
BEGIN
    -- Validate donor exists
    IF NOT EXISTS (SELECT 1 FROM Donor WHERE donor_id = p_donor_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid donor ID';
    END IF;
    
    -- Insert donation
    INSERT INTO Donation (donor_id, disaster_id, donation_type, amount, status)
    VALUES (p_donor_id, p_disaster_id, 'Money', p_amount, 'Received');
    
    SET p_donation_id = LAST_INSERT_ID();
    
    -- Get receipt number (generated by trigger)
    SELECT receipt_no INTO p_receipt
    FROM Donation WHERE donation_id = p_donation_id;
END //

DELIMITER ;

-- Grant execute permission without direct table access
GRANT EXECUTE ON PROCEDURE drrms_db.sp_secure_add_donation TO 'drrms_donor_mgr';

-- ============================================================
-- SECTION 6: APPLICATION USER (Connection Pooling)
-- ============================================================
-- User for application connections with limited scope

CREATE USER IF NOT EXISTS 'drrms_app'@'%' 
IDENTIFIED BY 'AppSecurePass456!'
WITH MAX_CONNECTIONS_PER_HOUR 1000
     MAX_QUERIES_PER_HOUR 10000
     MAX_UPDATES_PER_HOUR 5000;

-- Grant specific permissions for application
GRANT SELECT, INSERT, UPDATE ON drrms_db.Request TO 'drrms_app'@'%';
GRANT SELECT, INSERT, UPDATE ON drrms_db.Allocation TO 'drrms_app'@'%';
GRANT SELECT ON drrms_db.Resource TO 'drrms_app'@'%';
GRANT SELECT ON drrms_db.Inventory TO 'drrms_app'@'%';
GRANT SELECT ON drrms_db.Disaster TO 'drrms_app'@'%';
GRANT SELECT ON drrms_db.Affected_Area TO 'drrms_app'@'%';
GRANT EXECUTE ON drrms_db.* TO 'drrms_app'@'%';

-- ============================================================
-- SECTION 7: AUDIT USER (For Audit Logging)
-- ============================================================

CREATE USER IF NOT EXISTS 'drrms_audit'@'localhost' IDENTIFIED BY 'AuditPass789!';
GRANT SELECT, INSERT ON drrms_db.Audit_Log TO 'drrms_audit'@'localhost';
GRANT SELECT, INSERT ON drrms_db.Audit_Log_Archive TO 'drrms_audit'@'localhost';

-- ============================================================
-- SECTION 8: SECURITY HELPER PROCEDURES
-- ============================================================

DELIMITER //

-- Check user permissions
CREATE PROCEDURE sp_check_user_permissions(IN p_username VARCHAR(100))
SQL SECURITY DEFINER
BEGIN
    SELECT 
        grantee,
        table_schema,
        table_name,
        privilege_type
    FROM information_schema.table_privileges
    WHERE grantee LIKE CONCAT('%', p_username, '%')
    ORDER BY table_name, privilege_type;
END //

-- View active roles for current session
CREATE PROCEDURE sp_show_current_roles()
SQL SECURITY DEFINER
BEGIN
    SELECT CURRENT_USER() AS current_user,
           CURRENT_ROLE() AS active_roles;
END //

DELIMITER ;

-- ============================================================
-- SECTION 9: PASSWORD POLICY (MySQL 8.0+)
-- ============================================================
-- These are global settings, run as admin

-- Set password expiration (90 days)
-- ALTER USER 'coordinator1'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY;

-- Require password history (cannot reuse last 5)
-- ALTER USER 'coordinator1'@'localhost' PASSWORD HISTORY 5;

-- ============================================================
-- SECTION 10: UTILITY COMMANDS
-- ============================================================

-- View all roles
-- SELECT * FROM mysql.user WHERE account_locked = 'N';

-- View role grants
-- SHOW GRANTS FOR 'drrms_coordinator';

-- View users and their roles
-- SELECT user, host FROM mysql.user WHERE user LIKE 'drrms%' OR user LIKE '%_user' OR user LIKE '%_mgr';

-- Revoke a role
-- REVOKE 'drrms_coordinator' FROM 'coordinator1'@'localhost';

-- Drop a user
-- DROP USER 'coordinator1'@'localhost';

-- ============================================================
-- SECURITY SUMMARY
-- ============================================================
-- Roles Created: 5
--   1. drrms_admin         - Full access
--   2. drrms_coordinator   - Disaster/Request management
--   3. drrms_volunteer_mgr - Volunteer management
--   4. drrms_donor_mgr     - Donation management
--   5. drrms_readonly      - View-only access
--
-- Users Created: 6
--   1. admin_user      -> drrms_admin
--   2. coordinator1    -> drrms_coordinator
--   3. volunteer_mgr   -> drrms_volunteer_mgr
--   4. donor_mgr       -> drrms_donor_mgr
--   5. report_viewer   -> drrms_readonly
--   6. drrms_app       -> Application user
--
-- Secure Views: 2
-- Secure Procedures: 3
-- ============================================================

-- Flush privileges to apply changes
FLUSH PRIVILEGES;
