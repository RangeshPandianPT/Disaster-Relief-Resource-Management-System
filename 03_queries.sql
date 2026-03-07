-- ============================================================
-- DISASTER RELIEF RESOURCE MANAGEMENT SYSTEM (DRRMS)
-- Sample Queries - Demonstrating SQL Concepts
-- ============================================================

USE drrms_db;

-- ============================================================
-- SECTION 1: BASIC SELECT QUERIES
-- ============================================================

-- Q1: List all active disasters
SELECT disaster_id, disaster_name, disaster_type, severity, start_date, status
FROM Disaster
WHERE status = 'Active'
ORDER BY start_date DESC;

-- Q2: List all resources with low stock (below minimum)
SELECT r.resource_id, r.resource_name, r.category, r.min_stock,
       COALESCE(SUM(i.quantity_available), 0) AS total_stock
FROM Resource r
LEFT JOIN Inventory i ON r.resource_id = i.resource_id
GROUP BY r.resource_id, r.resource_name, r.category, r.min_stock
HAVING total_stock < r.min_stock;

-- Q3: List all available volunteers
SELECT volunteer_id, name, email, phone, skills
FROM Volunteer
WHERE availability = 'Available'
ORDER BY name;

-- ============================================================
-- SECTION 2: JOIN QUERIES (INNER, LEFT, RIGHT)
-- ============================================================

-- Q4: INNER JOIN - Affected areas with their disaster details
SELECT a.area_id, a.area_name, a.district, a.state, a.priority,
       a.population_affected,
       d.disaster_name, d.disaster_type, d.severity
FROM Affected_Area a
INNER JOIN Disaster d ON a.disaster_id = d.disaster_id
WHERE d.status = 'Active'
ORDER BY a.priority DESC, a.population_affected DESC;

-- Q5: LEFT JOIN - All requests with their allocation status
SELECT r.request_id, 
       aa.area_name,
       res.resource_name,
       r.quantity_requested,
       r.urgency,
       r.status AS request_status,
       COALESCE(SUM(al.quantity_allocated), 0) AS total_allocated,
       r.quantity_requested - COALESCE(SUM(al.quantity_allocated), 0) AS pending_quantity
FROM Request r
LEFT JOIN Allocation al ON r.request_id = al.request_id
INNER JOIN Affected_Area aa ON r.area_id = aa.area_id
INNER JOIN Resource res ON r.resource_id = res.resource_id
GROUP BY r.request_id, aa.area_name, res.resource_name, r.quantity_requested, r.urgency, r.status
ORDER BY r.urgency DESC, r.request_date;

-- Q6: Multiple JOIN - Relief teams with volunteer count and area details
SELECT t.team_id, t.team_name, t.team_type, t.leader_name, t.status,
       d.disaster_name,
       aa.area_name, aa.district,
       COUNT(v.volunteer_id) AS volunteer_count
FROM Relief_Team t
INNER JOIN Disaster d ON t.disaster_id = d.disaster_id
LEFT JOIN Affected_Area aa ON t.area_id = aa.area_id
LEFT JOIN Volunteer v ON t.team_id = v.team_id
WHERE t.status = 'Active'
GROUP BY t.team_id, t.team_name, t.team_type, t.leader_name, t.status,
         d.disaster_name, aa.area_name, aa.district
ORDER BY volunteer_count DESC;

-- Q7: JOIN with Inventory - Resource availability by warehouse
SELECT r.resource_name, r.category, r.unit,
       i.warehouse_location,
       i.quantity_available,
       r.min_stock,
       CASE 
           WHEN i.quantity_available < r.min_stock THEN 'LOW STOCK'
           WHEN i.quantity_available < r.min_stock * 2 THEN 'MODERATE'
           ELSE 'SUFFICIENT'
       END AS stock_status
FROM Resource r
INNER JOIN Inventory i ON r.resource_id = i.resource_id
ORDER BY r.category, r.resource_name, i.warehouse_location;

-- ============================================================
-- SECTION 3: AGGREGATE FUNCTIONS
-- ============================================================

-- Q8: Total donations per disaster (monetary)
SELECT d.disaster_name, d.disaster_type,
       COUNT(don.donation_id) AS donation_count,
       SUM(CASE WHEN don.donation_type = 'Money' THEN don.amount ELSE 0 END) AS total_monetary,
       COUNT(CASE WHEN don.donation_type = 'Material' THEN 1 END) AS material_donations
FROM Disaster d
LEFT JOIN Donation don ON d.disaster_id = don.disaster_id
GROUP BY d.disaster_id, d.disaster_name, d.disaster_type
ORDER BY total_monetary DESC;

-- Q9: Volunteer count by availability status
SELECT availability, COUNT(*) AS volunteer_count
FROM Volunteer
GROUP BY availability
ORDER BY volunteer_count DESC;

-- Q10: Request statistics by urgency level
SELECT urgency,
       COUNT(*) AS total_requests,
       SUM(CASE WHEN status = 'Fulfilled' THEN 1 ELSE 0 END) AS fulfilled,
       SUM(CASE WHEN status = 'Pending' THEN 1 ELSE 0 END) AS pending,
       SUM(CASE WHEN status = 'Approved' THEN 1 ELSE 0 END) AS approved
FROM Request
GROUP BY urgency
ORDER BY FIELD(urgency, 'Critical', 'High', 'Medium', 'Low');

-- ============================================================
-- SECTION 4: SUBQUERIES
-- ============================================================

-- Q11: Areas with more requests than average
SELECT aa.area_name, aa.district, aa.state, aa.priority,
       (SELECT COUNT(*) FROM Request r WHERE r.area_id = aa.area_id) AS request_count
FROM Affected_Area aa
WHERE (SELECT COUNT(*) FROM Request r WHERE r.area_id = aa.area_id) >
      (SELECT AVG(req_count) FROM 
           (SELECT COUNT(*) AS req_count FROM Request GROUP BY area_id) AS avg_table);

-- Q12: Donors who have donated more than average amount
SELECT d.donor_name, d.donor_type, 
       SUM(don.amount) AS total_donated
FROM Donor d
INNER JOIN Donation don ON d.donor_id = don.donor_id
WHERE don.donation_type = 'Money'
GROUP BY d.donor_id, d.donor_name, d.donor_type
HAVING SUM(don.amount) > (SELECT AVG(amount) FROM Donation WHERE donation_type = 'Money')
ORDER BY total_donated DESC;

-- Q13: Resources requested but not yet allocated
SELECT r.resource_name, res.area_name, res.quantity_requested, res.urgency
FROM Request res
INNER JOIN Resource r ON res.resource_id = r.resource_id
INNER JOIN Affected_Area aa ON res.area_id = aa.area_id
WHERE res.request_id NOT IN (SELECT DISTINCT request_id FROM Allocation)
  AND res.status = 'Pending';

-- ============================================================
-- SECTION 5: COMPLEX MULTI-TABLE QUERIES
-- ============================================================

-- Q14: Complete allocation report with all details
SELECT 
    d.disaster_name,
    aa.area_name,
    aa.district,
    res.resource_name,
    req.quantity_requested,
    req.urgency,
    al.quantity_allocated,
    i.warehouse_location AS source_warehouse,
    al.delivery_status,
    t.team_name AS delivery_team
FROM Allocation al
INNER JOIN Request req ON al.request_id = req.request_id
INNER JOIN Affected_Area aa ON req.area_id = aa.area_id
INNER JOIN Disaster d ON aa.disaster_id = d.disaster_id
INNER JOIN Resource res ON req.resource_id = res.resource_id
INNER JOIN Inventory i ON al.inventory_id = i.inventory_id
LEFT JOIN Relief_Team t ON t.area_id = aa.area_id AND t.team_type = 'Distribution'
ORDER BY d.disaster_name, aa.area_name, al.allocation_date;

-- Q15: Donor contribution summary with donation details
SELECT 
    don.donor_name,
    don.donor_type,
    d.disaster_name,
    dn.donation_type,
    CASE 
        WHEN dn.donation_type = 'Money' THEN CONCAT('₹', FORMAT(dn.amount, 2))
        ELSE CONCAT(dn.quantity, ' ', r.unit, ' of ', r.resource_name)
    END AS contribution,
    dn.donation_date,
    dn.status
FROM Donation dn
INNER JOIN Donor don ON dn.donor_id = don.donor_id
LEFT JOIN Disaster d ON dn.disaster_id = d.disaster_id
LEFT JOIN Resource r ON dn.resource_id = r.resource_id
ORDER BY dn.donation_date DESC;

-- Q16: Team performance - deliveries per team
SELECT 
    t.team_name,
    t.team_type,
    t.leader_name,
    d.disaster_name,
    COUNT(DISTINCT v.volunteer_id) AS team_size,
    COUNT(DISTINCT al.allocation_id) AS total_allocations,
    SUM(CASE WHEN al.delivery_status = 'Delivered' THEN 1 ELSE 0 END) AS successful_deliveries
FROM Relief_Team t
INNER JOIN Disaster d ON t.disaster_id = d.disaster_id
LEFT JOIN Volunteer v ON t.team_id = v.team_id
LEFT JOIN Affected_Area aa ON t.area_id = aa.area_id
LEFT JOIN Request req ON aa.area_id = req.area_id
LEFT JOIN Allocation al ON req.request_id = al.request_id
WHERE t.status = 'Active'
GROUP BY t.team_id, t.team_name, t.team_type, t.leader_name, d.disaster_name
ORDER BY successful_deliveries DESC;

-- ============================================================
-- SECTION 6: REPORTING QUERIES
-- ============================================================

-- Q17: Dashboard summary - Active disaster overview
SELECT 
    d.disaster_id,
    d.disaster_name,
    d.severity,
    d.start_date,
    DATEDIFF(CURDATE(), d.start_date) AS days_active,
    COUNT(DISTINCT aa.area_id) AS affected_areas,
    SUM(aa.population_affected) AS total_affected,
    COUNT(DISTINCT t.team_id) AS active_teams,
    COUNT(DISTINCT v.volunteer_id) AS deployed_volunteers,
    (SELECT COUNT(*) FROM Request r 
     INNER JOIN Affected_Area a ON r.area_id = a.area_id 
     WHERE a.disaster_id = d.disaster_id AND r.status = 'Pending') AS pending_requests
FROM Disaster d
LEFT JOIN Affected_Area aa ON d.disaster_id = aa.disaster_id
LEFT JOIN Relief_Team t ON d.disaster_id = t.disaster_id AND t.status = 'Active'
LEFT JOIN Volunteer v ON t.team_id = v.team_id AND v.availability = 'Busy'
WHERE d.status = 'Active'
GROUP BY d.disaster_id, d.disaster_name, d.severity, d.start_date
ORDER BY d.severity DESC;

-- Q18: Resource utilization report
SELECT 
    r.resource_name,
    r.category,
    SUM(i.quantity_available) AS total_available,
    COALESCE((SELECT SUM(quantity_requested) FROM Request WHERE resource_id = r.resource_id), 0) AS total_requested,
    COALESCE((SELECT SUM(quantity_allocated) FROM Allocation al 
              INNER JOIN Request req ON al.request_id = req.request_id 
              WHERE req.resource_id = r.resource_id), 0) AS total_allocated,
    ROUND(
        COALESCE((SELECT SUM(quantity_allocated) FROM Allocation al 
                  INNER JOIN Request req ON al.request_id = req.request_id 
                  WHERE req.resource_id = r.resource_id), 0) * 100.0 / 
        NULLIF(COALESCE((SELECT SUM(quantity_requested) FROM Request WHERE resource_id = r.resource_id), 0), 0), 
        2
    ) AS fulfillment_percentage
FROM Resource r
LEFT JOIN Inventory i ON r.resource_id = i.resource_id
GROUP BY r.resource_id, r.resource_name, r.category
ORDER BY r.category, r.resource_name;

-- Q19: Pending critical requests needing immediate attention
SELECT 
    d.disaster_name,
    aa.area_name,
    aa.district,
    r.resource_name,
    req.quantity_requested,
    req.urgency,
    req.request_date,
    DATEDIFF(CURDATE(), req.request_date) AS days_pending
FROM Request req
INNER JOIN Affected_Area aa ON req.area_id = aa.area_id
INNER JOIN Disaster d ON aa.disaster_id = d.disaster_id
INNER JOIN Resource r ON req.resource_id = r.resource_id
WHERE req.status = 'Pending' 
  AND req.urgency IN ('Critical', 'High')
  AND d.status = 'Active'
ORDER BY 
    FIELD(req.urgency, 'Critical', 'High'),
    req.request_date;

-- Q20: Monthly donation trend
SELECT 
    DATE_FORMAT(donation_date, '%Y-%m') AS month,
    COUNT(*) AS donation_count,
    SUM(CASE WHEN donation_type = 'Money' THEN amount ELSE 0 END) AS monetary_total,
    COUNT(CASE WHEN donation_type = 'Material' THEN 1 END) AS material_count
FROM Donation
GROUP BY DATE_FORMAT(donation_date, '%Y-%m')
ORDER BY month DESC;

-- ============================================================
-- QUERIES COMPLETE
-- ============================================================
-- Total Queries: 20
-- Concepts Covered:
-- - Basic SELECT, WHERE, ORDER BY
-- - INNER JOIN, LEFT JOIN
-- - GROUP BY with HAVING
-- - Aggregate Functions (COUNT, SUM, AVG)
-- - Subqueries (Correlated and Non-correlated)
-- - CASE expressions
-- - Multi-table complex joins
-- - Date functions
-- - Reporting queries
-- ============================================================
