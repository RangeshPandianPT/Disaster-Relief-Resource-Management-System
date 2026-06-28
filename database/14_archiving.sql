-- ============================================================
-- DISASTER RELIEF RESOURCE MANAGEMENT SYSTEM (DRRMS)
-- SQL Script - Data Archiving Strategy
-- ============================================================
USE drrms_db;

-- 1. Create Archive Tables
CREATE TABLE IF NOT EXISTS Disaster_Archive (
    disaster_id INT PRIMARY KEY,
    disaster_name VARCHAR(100) NOT NULL,
    disaster_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NULL,
    description TEXT,
    status VARCHAR(20) NOT NULL,
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS Request_Archive (
    request_id INT PRIMARY KEY,
    area_id INT NOT NULL,
    resource_id INT NOT NULL,
    quantity_requested INT NOT NULL,
    urgency VARCHAR(20) NOT NULL,
    request_date TIMESTAMP NOT NULL,
    status VARCHAR(20) NOT NULL,
    remarks TEXT,
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DELIMITER //

-- 2. Stored Procedure for Archiving Resolved Disasters and their Requests
CREATE PROCEDURE sp_ArchiveResolvedData()
BEGIN
    DECLARE v_archived_count INT DEFAULT 0;
    
    -- Start Transaction
    START TRANSACTION;
    
    BEGIN
        -- Error handler
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            SELECT 'Error occurred during archiving. Transaction rolled back.' AS result;
        END;

        -- Archive Resolved Disasters
        INSERT INTO Disaster_Archive (disaster_id, disaster_name, disaster_type, severity, start_date, end_date, description, status)
        SELECT disaster_id, disaster_name, disaster_type, severity, start_date, end_date, description, status
        FROM Disaster
        WHERE status = 'Resolved' AND end_date IS NOT NULL AND end_date < DATE_SUB(CURDATE(), INTERVAL 30 DAY);
        
        -- Get count for reporting
        SET v_archived_count = ROW_COUNT();

        -- Archive related Requests (Fulfilled or Rejected) for the archived Disasters
        INSERT INTO Request_Archive (request_id, area_id, resource_id, quantity_requested, urgency, request_date, status, remarks)
        SELECT r.request_id, r.area_id, r.resource_id, r.quantity_requested, r.urgency, r.request_date, r.status, r.remarks
        FROM Request r
        INNER JOIN Affected_Area aa ON r.area_id = aa.area_id
        INNER JOIN Disaster d ON aa.disaster_id = d.disaster_id
        WHERE d.status = 'Resolved' AND d.end_date IS NOT NULL AND d.end_date < DATE_SUB(CURDATE(), INTERVAL 30 DAY)
          AND (r.status = 'Fulfilled' OR r.status = 'Rejected');

        -- Delete archived records from original tables
        DELETE r
        FROM Request r
        INNER JOIN Affected_Area aa ON r.area_id = aa.area_id
        INNER JOIN Disaster d ON aa.disaster_id = d.disaster_id
        WHERE d.status = 'Resolved' AND d.end_date IS NOT NULL AND d.end_date < DATE_SUB(CURDATE(), INTERVAL 30 DAY)
          AND (r.status = 'Fulfilled' OR r.status = 'Rejected');

        DELETE FROM Disaster
        WHERE status = 'Resolved' AND end_date IS NOT NULL AND end_date < DATE_SUB(CURDATE(), INTERVAL 30 DAY);

        -- Commit Transaction
        COMMIT;
        
        SELECT CONCAT('Successfully archived ', v_archived_count, ' disaster(s) and their associated requests.') AS result;
    END;
END //

DELIMITER ;

-- 3. Event Schedule to automatically run archiving (e.g., monthly)
-- Ensure event scheduler is ON: SET GLOBAL event_scheduler = ON;
DELIMITER //
CREATE EVENT IF NOT EXISTS evt_MonthlyDataArchiving
ON SCHEDULE EVERY 1 MONTH
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    CALL sp_ArchiveResolvedData();
END //
DELIMITER ;
