-- ============================================================
-- DISASTER RELIEF RESOURCE MANAGEMENT SYSTEM (DRRMS)
-- SQL Script - Predictive Analytics & Forecasting
-- ============================================================
USE drrms_db;

DELIMITER //

-- 1. Predict Inventory Depletion
-- Estimates how many days until a resource runs out based on average daily requests
CREATE PROCEDURE sp_PredictResourceDepletion(IN p_resource_id INT)
BEGIN
    DECLARE v_current_stock INT;
    DECLARE v_avg_daily_request DECIMAL(10,2);
    DECLARE v_days_remaining INT;

    -- Get total current stock for the resource
    SELECT COALESCE(SUM(quantity_available), 0) INTO v_current_stock
    FROM Inventory
    WHERE resource_id = p_resource_id;

    -- Calculate average daily requested amount over the last 30 days
    SELECT COALESCE(SUM(quantity_requested) / 30, 0) INTO v_avg_daily_request
    FROM Request
    WHERE resource_id = p_resource_id 
      AND request_date >= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 30 DAY);

    -- Calculate days remaining
    IF v_avg_daily_request > 0 THEN
        SET v_days_remaining = FLOOR(v_current_stock / v_avg_daily_request);
        
        SELECT 
            r.resource_name AS Resource_Name,
            v_current_stock AS Current_Stock,
            v_avg_daily_request AS Avg_Daily_Request,
            v_days_remaining AS Estimated_Days_Remaining,
            CASE 
                WHEN v_days_remaining <= 3 THEN 'CRITICAL ALERT: Imminent Shortage'
                WHEN v_days_remaining <= 7 THEN 'WARNING: Restock Soon'
                ELSE 'OK: Sufficient Stock'
            END AS Stock_Status
        FROM Resource r
        WHERE r.resource_id = p_resource_id;
    ELSE
        SELECT 
            r.resource_name AS Resource_Name,
            v_current_stock AS Current_Stock,
            0 AS Avg_Daily_Request,
            999 AS Estimated_Days_Remaining,
            'OK: No recent requests' AS Stock_Status
        FROM Resource r
        WHERE r.resource_id = p_resource_id;
    END IF;
END //

-- 2. View for Active Disaster Resource Intensity
-- Shows which disasters are consuming the most resources and their request fulfillment rate
CREATE OR REPLACE VIEW vw_DisasterResourceIntensity AS
SELECT 
    d.disaster_name,
    d.disaster_type,
    d.severity,
    COUNT(DISTINCT r.request_id) AS total_requests,
    SUM(r.quantity_requested) AS total_quantity_requested,
    SUM(CASE WHEN r.status = 'Fulfilled' THEN 1 ELSE 0 END) AS fulfilled_requests,
    (SUM(CASE WHEN r.status = 'Fulfilled' THEN 1 ELSE 0 END) / COUNT(r.request_id)) * 100 AS fulfillment_rate_percent,
    COUNT(DISTINCT aa.area_id) AS affected_areas_count
FROM Disaster d
JOIN Affected_Area aa ON d.disaster_id = aa.disaster_id
LEFT JOIN Request r ON aa.area_id = r.area_id
WHERE d.status = 'Active'
GROUP BY d.disaster_id;

DELIMITER ;
