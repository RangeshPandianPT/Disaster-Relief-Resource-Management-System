-- ============================================================
-- DISASTER RELIEF RESOURCE MANAGEMENT SYSTEM (DRRMS)
-- Views - Database Views for Reporting and Dashboards
-- ============================================================

USE drrms_db;

-- ============================================================
-- VIEW 1: Active Disaster Summary
-- Purpose: Dashboard view showing all active disasters with stats
-- ============================================================
CREATE OR REPLACE VIEW vw_active_disaster_summary AS
SELECT 
    d.disaster_id,
    d.disaster_name,
    d.disaster_type,
    d.severity,
    d.start_date,
    DATEDIFF(CURDATE(), d.start_date) AS days_since_start,
    COUNT(DISTINCT aa.area_id) AS total_affected_areas,
    COALESCE(SUM(aa.population_affected), 0) AS total_population_affected,
    (SELECT COUNT(*) FROM Relief_Team t WHERE t.disaster_id = d.disaster_id AND t.status = 'Active') AS active_teams,
    (SELECT COUNT(*) FROM Request r 
     INNER JOIN Affected_Area a ON r.area_id = a.area_id 
     WHERE a.disaster_id = d.disaster_id AND r.status = 'Pending') AS pending_requests,
    (SELECT COALESCE(SUM(don.amount), 0) FROM Donation don 
     WHERE don.disaster_id = d.disaster_id AND don.donation_type = 'Money') AS total_funds_received
FROM Disaster d
LEFT JOIN Affected_Area aa ON d.disaster_id = aa.disaster_id
WHERE d.status = 'Active'
GROUP BY d.disaster_id, d.disaster_name, d.disaster_type, d.severity, d.start_date;

-- ============================================================
-- VIEW 2: Pending Requests
-- Purpose: Show all pending resource requests with priorities
-- ============================================================
CREATE OR REPLACE VIEW vw_pending_requests AS
SELECT 
    req.request_id,
    d.disaster_name,
    aa.area_name,
    aa.district,
    aa.state,
    aa.priority AS area_priority,
    r.resource_name,
    r.category AS resource_category,
    req.quantity_requested,
    req.urgency,
    req.request_date,
    DATEDIFF(CURDATE(), req.request_date) AS days_pending,
    CASE 
        WHEN req.urgency = 'Critical' AND DATEDIFF(CURDATE(), req.request_date) > 1 THEN 'URGENT ACTION NEEDED'
        WHEN req.urgency = 'High' AND DATEDIFF(CURDATE(), req.request_date) > 3 THEN 'NEEDS ATTENTION'
        ELSE 'NORMAL'
    END AS alert_status
FROM Request req
INNER JOIN Affected_Area aa ON req.area_id = aa.area_id
INNER JOIN Disaster d ON aa.disaster_id = d.disaster_id
INNER JOIN Resource r ON req.resource_id = r.resource_id
WHERE req.status = 'Pending'
ORDER BY 
    FIELD(req.urgency, 'Critical', 'High', 'Medium', 'Low'),
    req.request_date;

-- ============================================================
-- VIEW 3: Inventory Status
-- Purpose: Complete inventory view with stock status indicators
-- ============================================================
CREATE OR REPLACE VIEW vw_inventory_status AS
SELECT 
    i.inventory_id,
    r.resource_name,
    r.category,
    r.unit,
    i.warehouse_location,
    i.quantity_available,
    r.min_stock,
    CASE 
        WHEN i.quantity_available = 0 THEN 'OUT OF STOCK'
        WHEN i.quantity_available < r.min_stock THEN 'LOW STOCK'
        WHEN i.quantity_available < r.min_stock * 2 THEN 'MODERATE'
        ELSE 'SUFFICIENT'
    END AS stock_status,
    CASE 
        WHEN i.quantity_available < r.min_stock THEN r.min_stock - i.quantity_available
        ELSE 0
    END AS reorder_quantity,
    i.last_updated
FROM Inventory i
INNER JOIN Resource r ON i.resource_id = r.resource_id
ORDER BY 
    FIELD(stock_status, 'OUT OF STOCK', 'LOW STOCK', 'MODERATE', 'SUFFICIENT'),
    r.category;

-- ============================================================
-- VIEW 4: Team Details with Volunteer Count
-- Purpose: Show relief teams with their assigned volunteers
-- ============================================================
CREATE OR REPLACE VIEW vw_team_details AS
SELECT 
    t.team_id,
    t.team_name,
    t.team_type,
    t.leader_name,
    t.contact_phone,
    t.status AS team_status,
    t.formed_date,
    d.disaster_name,
    d.status AS disaster_status,
    aa.area_name AS assigned_area,
    aa.district,
    COUNT(v.volunteer_id) AS volunteer_count,
    GROUP_CONCAT(v.name ORDER BY v.name SEPARATOR ', ') AS volunteer_names
FROM Relief_Team t
INNER JOIN Disaster d ON t.disaster_id = d.disaster_id
LEFT JOIN Affected_Area aa ON t.area_id = aa.area_id
LEFT JOIN Volunteer v ON t.team_id = v.team_id
GROUP BY t.team_id, t.team_name, t.team_type, t.leader_name, t.contact_phone,
         t.status, t.formed_date, d.disaster_name, d.status, aa.area_name, aa.district
ORDER BY t.status, d.disaster_name, t.team_name;

-- ============================================================
-- VIEW 5: Allocation Tracking
-- Purpose: Track resource allocations and delivery status
-- ============================================================
CREATE OR REPLACE VIEW vw_allocation_tracking AS
SELECT 
    al.allocation_id,
    d.disaster_name,
    aa.area_name,
    aa.district,
    r.resource_name,
    r.category,
    req.quantity_requested,
    al.quantity_allocated,
    req.quantity_requested - al.quantity_allocated AS remaining_needed,
    i.warehouse_location AS source_warehouse,
    al.allocation_date,
    al.delivery_status,
    al.delivered_date,
    CASE 
        WHEN al.delivery_status = 'Delivered' THEN 
            TIMESTAMPDIFF(HOUR, al.allocation_date, al.delivered_date)
        ELSE 
            TIMESTAMPDIFF(HOUR, al.allocation_date, NOW())
    END AS hours_since_allocation,
    al.remarks
FROM Allocation al
INNER JOIN Request req ON al.request_id = req.request_id
INNER JOIN Affected_Area aa ON req.area_id = aa.area_id
INNER JOIN Disaster d ON aa.disaster_id = d.disaster_id
INNER JOIN Resource r ON req.resource_id = r.resource_id
INNER JOIN Inventory i ON al.inventory_id = i.inventory_id
ORDER BY 
    FIELD(al.delivery_status, 'Pending', 'Dispatched', 'In_Transit', 'Delivered', 'Failed'),
    al.allocation_date DESC;

-- ============================================================
-- VIEW 6: Donor Contribution Summary
-- Purpose: Summary of donations per donor
-- ============================================================
CREATE OR REPLACE VIEW vw_donor_summary AS
SELECT 
    dn.donor_id,
    dn.donor_name,
    dn.donor_type,
    dn.email,
    dn.phone,
    COUNT(d.donation_id) AS total_donations,
    SUM(CASE WHEN d.donation_type = 'Money' THEN d.amount ELSE 0 END) AS total_monetary,
    COUNT(CASE WHEN d.donation_type = 'Material' THEN 1 END) AS material_donations,
    MIN(d.donation_date) AS first_donation,
    MAX(d.donation_date) AS last_donation
FROM Donor dn
LEFT JOIN Donation d ON dn.donor_id = d.donor_id
GROUP BY dn.donor_id, dn.donor_name, dn.donor_type, dn.email, dn.phone
ORDER BY total_monetary DESC;

-- ============================================================
-- VIEW 7: Resource Demand Analysis
-- Purpose: Analyze which resources are most in demand
-- ============================================================
CREATE OR REPLACE VIEW vw_resource_demand AS
SELECT 
    r.resource_id,
    r.resource_name,
    r.category,
    r.unit,
    COALESCE(SUM(i.quantity_available), 0) AS total_stock,
    COALESCE(SUM(req.quantity_requested), 0) AS total_requested,
    COALESCE(SUM(al.total_allocated), 0) AS total_allocated,
    COALESCE(SUM(req.quantity_requested), 0) - COALESCE(SUM(al.total_allocated), 0) AS unmet_demand,
    COUNT(DISTINCT req.request_id) AS request_count
FROM Resource r
LEFT JOIN Inventory i ON r.resource_id = i.resource_id
LEFT JOIN Request req ON r.resource_id = req.resource_id
LEFT JOIN (
    SELECT request_id, SUM(quantity_allocated) AS total_allocated
    FROM Allocation
    GROUP BY request_id
) al ON req.request_id = al.request_id
GROUP BY r.resource_id, r.resource_name, r.category, r.unit
ORDER BY unmet_demand DESC, request_count DESC;

-- ============================================================
-- VIEW 8: Volunteer Availability
-- Purpose: Show volunteer availability with skills
-- ============================================================
CREATE OR REPLACE VIEW vw_volunteer_availability AS
SELECT 
    v.volunteer_id,
    v.name,
    v.email,
    v.phone,
    v.skills,
    v.availability,
    t.team_name AS current_team,
    t.team_type,
    d.disaster_name AS assigned_disaster,
    CASE 
        WHEN v.team_id IS NULL THEN 'Unassigned'
        ELSE 'Assigned'
    END AS assignment_status
FROM Volunteer v
LEFT JOIN Relief_Team t ON v.team_id = t.team_id
LEFT JOIN Disaster d ON t.disaster_id = d.disaster_id
ORDER BY v.availability, v.name;

-- ============================================================
-- VIEW 9: Area-wise Request Fulfillment
-- Purpose: Track request fulfillment progress per area
-- ============================================================
CREATE OR REPLACE VIEW vw_area_fulfillment AS
SELECT 
    aa.area_id,
    aa.area_name,
    aa.district,
    aa.state,
    aa.population_affected,
    aa.priority,
    d.disaster_name,
    COUNT(req.request_id) AS total_requests,
    SUM(CASE WHEN req.status = 'Fulfilled' THEN 1 ELSE 0 END) AS fulfilled_requests,
    SUM(CASE WHEN req.status = 'Pending' THEN 1 ELSE 0 END) AS pending_requests,
    SUM(CASE WHEN req.status = 'Approved' THEN 1 ELSE 0 END) AS approved_requests,
    ROUND(
        SUM(CASE WHEN req.status = 'Fulfilled' THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(COUNT(req.request_id), 0), 
        2
    ) AS fulfillment_rate
FROM Affected_Area aa
INNER JOIN Disaster d ON aa.disaster_id = d.disaster_id
LEFT JOIN Request req ON aa.area_id = req.area_id
GROUP BY aa.area_id, aa.area_name, aa.district, aa.state, 
         aa.population_affected, aa.priority, d.disaster_name
ORDER BY aa.priority DESC, fulfillment_rate;

-- ============================================================
-- VIEW 10: Daily Operations Dashboard
-- Purpose: Quick overview for daily operations
-- ============================================================
CREATE OR REPLACE VIEW vw_daily_dashboard AS
SELECT 
    (SELECT COUNT(*) FROM Disaster WHERE status = 'Active') AS active_disasters,
    (SELECT COUNT(*) FROM Affected_Area aa 
     INNER JOIN Disaster d ON aa.disaster_id = d.disaster_id 
     WHERE d.status = 'Active') AS affected_areas,
    (SELECT COALESCE(SUM(population_affected), 0) FROM Affected_Area aa 
     INNER JOIN Disaster d ON aa.disaster_id = d.disaster_id 
     WHERE d.status = 'Active') AS total_affected_population,
    (SELECT COUNT(*) FROM Request WHERE status = 'Pending') AS pending_requests,
    (SELECT COUNT(*) FROM Request WHERE status = 'Pending' AND urgency = 'Critical') AS critical_pending,
    (SELECT COUNT(*) FROM Allocation WHERE delivery_status IN ('Pending', 'Dispatched', 'In_Transit')) AS in_progress_deliveries,
    (SELECT COUNT(*) FROM Relief_Team WHERE status = 'Active') AS active_teams,
    (SELECT COUNT(*) FROM Volunteer WHERE availability = 'Available') AS available_volunteers,
    (SELECT COALESCE(SUM(amount), 0) FROM Donation WHERE donation_type = 'Money' 
     AND DATE(donation_date) = CURDATE()) AS today_donations;

-- ============================================================
-- VIEWS CREATED: 10
-- ============================================================
-- 1. vw_active_disaster_summary  - Active disaster dashboard
-- 2. vw_pending_requests         - Pending request queue
-- 3. vw_inventory_status         - Stock levels and alerts
-- 4. vw_team_details             - Team and volunteer info
-- 5. vw_allocation_tracking      - Delivery tracking
-- 6. vw_donor_summary            - Donor contributions
-- 7. vw_resource_demand          - Resource demand analysis
-- 8. vw_volunteer_availability   - Volunteer status
-- 9. vw_area_fulfillment         - Area-wise fulfillment
-- 10. vw_daily_dashboard         - Operations overview
-- ============================================================

-- Sample usage:
-- SELECT * FROM vw_daily_dashboard;
-- SELECT * FROM vw_pending_requests WHERE urgency = 'Critical';
-- SELECT * FROM vw_inventory_status WHERE stock_status = 'LOW STOCK';
