-- ============================================================
-- DISASTER RELIEF RESOURCE MANAGEMENT SYSTEM (DRRMS)
-- Sample Data Insertion Script
-- ============================================================

USE drrms_db;

-- ============================================================
-- SAMPLE DATA: DISASTER
-- ============================================================
INSERT INTO Disaster (disaster_name, disaster_type, severity, start_date, end_date, description, status) VALUES
('Cyclone Amphan', 'Cyclone', 'Critical', '2024-05-15', '2024-05-25', 'Super cyclone affecting coastal regions of West Bengal and Odisha', 'Resolved'),
('Kerala Floods 2024', 'Flood', 'High', '2024-08-10', '2024-08-28', 'Heavy monsoon flooding in Kerala affecting multiple districts', 'Resolved'),
('Gujarat Earthquake', 'Earthquake', 'Critical', '2024-11-20', NULL, 'Magnitude 6.2 earthquake in Kutch region', 'Active'),
('Uttarakhand Forest Fire', 'Fire', 'Medium', '2024-04-05', '2024-04-12', 'Forest fire in Chamoli district affecting surrounding villages', 'Resolved'),
('Chennai Floods', 'Flood', 'High', '2025-01-05', NULL, 'Urban flooding due to heavy rainfall in Chennai metropolitan area', 'Active');

-- ============================================================
-- SAMPLE DATA: AFFECTED_AREA
-- ============================================================
INSERT INTO Affected_Area (disaster_id, area_name, district, state, population_affected, priority) VALUES
-- Cyclone Amphan areas
(1, 'Sundarbans South', 'South 24 Parganas', 'West Bengal', 150000, 'Critical'),
(1, 'Kakdwip Block', 'South 24 Parganas', 'West Bengal', 85000, 'High'),
(1, 'Basanti Block', 'South 24 Parganas', 'West Bengal', 65000, 'High'),

-- Kerala Floods areas
(2, 'Wayanad Town', 'Wayanad', 'Kerala', 45000, 'Critical'),
(2, 'Kalpetta', 'Wayanad', 'Kerala', 32000, 'High'),
(2, 'Idukki Central', 'Idukki', 'Kerala', 28000, 'Medium'),

-- Gujarat Earthquake areas
(3, 'Bhuj City', 'Kutch', 'Gujarat', 120000, 'Critical'),
(3, 'Anjar', 'Kutch', 'Gujarat', 55000, 'High'),
(3, 'Gandhidham', 'Kutch', 'Gujarat', 90000, 'High'),

-- Uttarakhand Fire areas
(4, 'Chamoli Village Cluster', 'Chamoli', 'Uttarakhand', 5000, 'Medium'),

-- Chennai Floods areas
(5, 'Velachery', 'Chennai', 'Tamil Nadu', 75000, 'High'),
(5, 'Tambaram', 'Chennai', 'Tamil Nadu', 60000, 'High'),
(5, 'Adyar', 'Chennai', 'Tamil Nadu', 45000, 'Medium');

-- ============================================================
-- SAMPLE DATA: RESOURCE
-- ============================================================
INSERT INTO Resource (resource_name, category, unit, min_stock) VALUES
-- Food Items
('Rice (25kg bags)', 'Food', 'Bags', 500),
('Ready-to-eat Meals', 'Food', 'Packets', 1000),
('Biscuits Pack', 'Food', 'Cartons', 200),

-- Water
('Drinking Water (1L bottles)', 'Water', 'Bottles', 5000),
('Water Purification Tablets', 'Water', 'Strips', 500),
('Water Tanker (5000L)', 'Water', 'Trips', 10),

-- Medicine
('First Aid Kit', 'Medicine', 'Kits', 100),
('ORS Packets', 'Medicine', 'Packets', 2000),
('Paracetamol Tablets', 'Medicine', 'Strips', 500),
('Antiseptic Solution', 'Medicine', 'Bottles', 200),

-- Shelter
('Tarpaulin Sheets', 'Shelter', 'Pieces', 300),
('Emergency Tents (4-person)', 'Shelter', 'Units', 50),
('Plastic Sheets', 'Shelter', 'Rolls', 100),

-- Clothing
('Blankets', 'Clothing', 'Pieces', 500),
('Clothing Kit (Adult)', 'Clothing', 'Kits', 200),
('Clothing Kit (Child)', 'Clothing', 'Kits', 200),

-- Equipment
('Torch with Batteries', 'Equipment', 'Units', 100),
('Rope (50m)', 'Equipment', 'Coils', 50),
('Generator (5kW)', 'Equipment', 'Units', 10),

-- Hygiene
('Sanitary Napkins', 'Hygiene', 'Packets', 500),
('Soap Bars', 'Hygiene', 'Pieces', 1000),
('Hand Sanitizer', 'Hygiene', 'Bottles', 300);

-- ============================================================
-- SAMPLE DATA: INVENTORY
-- ============================================================
INSERT INTO Inventory (resource_id, warehouse_location, quantity_available) VALUES
-- Main Warehouse - Kolkata
(1, 'Central Warehouse, Kolkata', 2500),
(2, 'Central Warehouse, Kolkata', 8000),
(4, 'Central Warehouse, Kolkata', 25000),
(7, 'Central Warehouse, Kolkata', 500),
(11, 'Central Warehouse, Kolkata', 1200),
(14, 'Central Warehouse, Kolkata', 2000),

-- Regional Warehouse - Chennai
(1, 'Regional Warehouse, Chennai', 1800),
(2, 'Regional Warehouse, Chennai', 5000),
(4, 'Regional Warehouse, Chennai', 18000),
(7, 'Regional Warehouse, Chennai', 350),
(8, 'Regional Warehouse, Chennai', 8000),
(12, 'Regional Warehouse, Chennai', 200),

-- Regional Warehouse - Ahmedabad
(1, 'Regional Warehouse, Ahmedabad', 2000),
(4, 'Regional Warehouse, Ahmedabad', 20000),
(7, 'Regional Warehouse, Ahmedabad', 400),
(11, 'Regional Warehouse, Ahmedabad', 800),
(12, 'Regional Warehouse, Ahmedabad', 150),
(19, 'Regional Warehouse, Ahmedabad', 25),

-- District Warehouse - Wayanad
(1, 'District Warehouse, Wayanad', 500),
(4, 'District Warehouse, Wayanad', 8000),
(7, 'District Warehouse, Wayanad', 150);

-- ============================================================
-- SAMPLE DATA: RELIEF_TEAM
-- ============================================================
INSERT INTO Relief_Team (disaster_id, area_id, team_name, team_type, leader_name, contact_phone, status, formed_date) VALUES
-- Cyclone Amphan Teams
(1, 1, 'Sundarbans Rescue Alpha', 'Rescue', 'Rajesh Kumar', '9876543210', 'Disbanded', '2024-05-15'),
(1, 2, 'Kakdwip Medical Response', 'Medical', 'Dr. Priya Sharma', '9876543211', 'Disbanded', '2024-05-16'),

-- Kerala Floods Teams
(2, 4, 'Wayanad Swift Rescue', 'Rescue', 'Mohammed Ali', '9876543212', 'Disbanded', '2024-08-10'),
(2, 5, 'Kalpetta Relief Distribution', 'Distribution', 'Lakshmi Nair', '9876543213', 'Disbanded', '2024-08-11'),

-- Gujarat Earthquake Teams
(3, 7, 'Bhuj Emergency Response', 'Rescue', 'Amit Patel', '9876543214', 'Active', '2024-11-20'),
(3, 7, 'Bhuj Medical Camp', 'Medical', 'Dr. Kavita Shah', '9876543215', 'Active', '2024-11-20'),
(3, 8, 'Anjar Distribution Team', 'Distribution', 'Ramesh Joshi', '9876543216', 'Active', '2024-11-21'),
(3, 9, 'Gandhidham Assessment', 'Assessment', 'Neha Mehta', '9876543217', 'Active', '2024-11-21'),

-- Chennai Floods Teams
(5, 11, 'Velachery Rescue Unit', 'Rescue', 'Karthik Rajan', '9876543218', 'Active', '2025-01-05'),
(5, 12, 'Tambaram Relief Team', 'Distribution', 'Sudha Krishnan', '9876543219', 'Active', '2025-01-06'),
(5, 11, 'Chennai Medical Response', 'Medical', 'Dr. Arjun Nair', '9876543220', 'Active', '2025-01-05');

-- ============================================================
-- SAMPLE DATA: VOLUNTEER
-- ============================================================
INSERT INTO Volunteer (name, email, phone, skills, availability, team_id) VALUES
-- Gujarat Earthquake Volunteers (Active)
('Suresh Desai', 'suresh.desai@email.com', '9988776601', 'First Aid, Swimming', 'Busy', 5),
('Priya Malhotra', 'priya.m@email.com', '9988776602', 'Medical, Counseling', 'Busy', 6),
('Vikram Singh', 'vikram.s@email.com', '9988776603', 'Driving, Logistics', 'Busy', 7),
('Anjali Gupta', 'anjali.g@email.com', '9988776604', 'Documentation, Assessment', 'Busy', 8),
('Rahul Sharma', 'rahul.sharma@email.com', '9988776605', 'Rescue, First Aid', 'Busy', 5),
('Meera Patel', 'meera.p@email.com', '9988776606', 'Nursing, First Aid', 'Busy', 6),

-- Chennai Floods Volunteers (Active)
('Arun Kumar', 'arun.k@email.com', '9988776607', 'Swimming, Rescue', 'Busy', 9),
('Deepa Venkat', 'deepa.v@email.com', '9988776608', 'First Aid, Cooking', 'Busy', 10),
('Ravi Chandran', 'ravi.c@email.com', '9988776609', 'Driving, Logistics', 'Busy', 10),
('Lakshmi Iyer', 'lakshmi.i@email.com', '9988776610', 'Medical, Counseling', 'Busy', 11),

-- Available Volunteers (Not assigned)
('Kiran Reddy', 'kiran.r@email.com', '9988776611', 'IT, Communication', 'Available', NULL),
('Sneha Das', 'sneha.d@email.com', '9988776612', 'Translation, Documentation', 'Available', NULL),
('Arjun Nayak', 'arjun.n@email.com', '9988776613', 'Rescue, Swimming', 'Available', NULL),
('Pooja Singh', 'pooja.s@email.com', '9988776614', 'Cooking, Distribution', 'Available', NULL),
('Manish Kumar', 'manish.k@email.com', '9988776615', 'Construction, Repair', 'Unavailable', NULL);

-- ============================================================
-- SAMPLE DATA: REQUEST
-- ============================================================
INSERT INTO Request (area_id, resource_id, quantity_requested, urgency, status, remarks) VALUES
-- Gujarat Earthquake Requests (Active disaster)
(7, 1, 500, 'Critical', 'Approved', 'Immediate food supply needed for shelter camps'),
(7, 4, 10000, 'Critical', 'Fulfilled', 'Drinking water for affected families'),
(7, 7, 100, 'High', 'Partially_Fulfilled', 'First aid kits for medical camps'),
(7, 12, 50, 'Critical', 'Approved', 'Emergency tents for displaced families'),
(8, 1, 300, 'High', 'Pending', 'Food supplies for Anjar relief camp'),
(8, 14, 500, 'High', 'Approved', 'Blankets for cold weather'),
(9, 4, 8000, 'High', 'Pending', 'Water supply for Gandhidham'),
(9, 7, 80, 'Medium', 'Pending', 'First aid kits for community centers'),

-- Chennai Floods Requests (Active disaster)
(11, 4, 15000, 'Critical', 'Approved', 'Drinking water for flooded areas'),
(11, 2, 3000, 'High', 'Approved', 'Ready meals for stranded residents'),
(11, 11, 200, 'High', 'Pending', 'Tarpaulin for temporary shelters'),
(12, 1, 400, 'High', 'Approved', 'Rice bags for relief distribution'),
(12, 4, 10000, 'High', 'Pending', 'Water bottles for Tambaram camps'),
(13, 14, 300, 'Medium', 'Pending', 'Blankets for night shelters');

-- ============================================================
-- SAMPLE DATA: ALLOCATION
-- ============================================================
INSERT INTO Allocation (request_id, inventory_id, quantity_allocated, delivery_status, delivered_date, remarks) VALUES
-- Gujarat Earthquake Allocations
(1, 13, 400, 'Delivered', '2024-11-22 14:30:00', 'Delivered to Bhuj main camp'),
(2, 14, 10000, 'Delivered', '2024-11-21 10:00:00', 'Water supply delivered'),
(3, 15, 60, 'Delivered', '2024-11-22 09:00:00', 'First batch delivered'),
(3, 4, 30, 'In_Transit', NULL, 'Second batch from Kolkata'),
(4, 17, 30, 'Dispatched', NULL, 'Tents dispatched from Ahmedabad'),
(6, 6, 400, 'Pending', NULL, 'Blankets being prepared'),

-- Chennai Floods Allocations
(9, 9, 12000, 'In_Transit', NULL, 'Water supply from Chennai warehouse'),
(10, 8, 2500, 'Dispatched', NULL, 'Ready meals dispatched'),
(12, 7, 350, 'Delivered', '2025-01-07 16:00:00', 'Rice delivered to Tambaram');

-- ============================================================
-- SAMPLE DATA: DONOR
-- ============================================================
INSERT INTO Donor (donor_name, donor_type, email, phone, address) VALUES
('Tata Trusts', 'Corporate', 'relief@tatatrusts.org', '022-66658282', 'Bombay House, Mumbai'),
('Infosys Foundation', 'Corporate', 'foundation@infosys.com', '080-28520261', 'Electronics City, Bangalore'),
('Red Cross India', 'NGO', 'contact@redcross.org.in', '011-23716441', 'Red Cross Bhawan, New Delhi'),
('UNICEF India', 'International', 'newdelhi@unicef.org', '011-24690401', 'UNICEF House, New Delhi'),
('State Government Relief Fund', 'Government', 'relief@gov.in', '011-23012345', 'Ministry of Home Affairs, Delhi'),
('Rajesh Agarwal', 'Individual', 'rajesh.a@email.com', '9876512345', 'Sector 15, Gurgaon'),
('Sunita Mehta', 'Individual', 'sunita.m@email.com', '9876512346', 'Juhu, Mumbai'),
('Reliance Foundation', 'Corporate', 'help@reliancefoundation.org', '022-35553000', 'Maker Chambers, Mumbai'),
('Azim Premji Foundation', 'Corporate', 'contact@azimpremjifoundation.org', '080-66144900', 'Hosur Road, Bangalore'),
('Goonj NGO', 'NGO', 'mail@goonj.org', '011-26972351', 'Sarita Vihar, New Delhi');

-- ============================================================
-- SAMPLE DATA: DONATION
-- ============================================================
INSERT INTO Donation (donor_id, disaster_id, donation_type, amount, resource_id, quantity, receipt_no, status) VALUES
-- Monetary Donations
(1, 3, 'Money', 5000000.00, NULL, NULL, 'DON-2024-001', 'Acknowledged'),
(2, 3, 'Money', 3000000.00, NULL, NULL, 'DON-2024-002', 'Acknowledged'),
(4, 3, 'Money', 10000000.00, NULL, NULL, 'DON-2024-003', 'Acknowledged'),
(5, 3, 'Money', 25000000.00, NULL, NULL, 'DON-2024-004', 'Received'),
(6, 3, 'Money', 50000.00, NULL, NULL, 'DON-2024-005', 'Acknowledged'),
(7, 5, 'Money', 100000.00, NULL, NULL, 'DON-2025-001', 'Received'),
(8, 5, 'Money', 8000000.00, NULL, NULL, 'DON-2025-002', 'Received'),
(9, 5, 'Money', 2500000.00, NULL, NULL, 'DON-2025-003', 'Received'),

-- Material Donations
(3, 3, 'Material', NULL, 7, 200, 'DON-2024-006', 'Acknowledged'),
(3, 3, 'Material', NULL, 14, 500, 'DON-2024-007', 'Acknowledged'),
(10, 5, 'Material', NULL, 1, 300, 'DON-2025-004', 'Received'),
(10, 5, 'Material', NULL, 15, 150, 'DON-2025-005', 'Received'),
(8, 5, 'Material', NULL, 4, 5000, 'DON-2025-006', 'Received'),

-- General Fund (No specific disaster)
(1, NULL, 'Money', 10000000.00, NULL, NULL, 'DON-2024-GEN-001', 'Acknowledged'),
(2, NULL, 'Money', 5000000.00, NULL, NULL, 'DON-2024-GEN-002', 'Acknowledged');

-- ============================================================
-- DATA INSERTION COMPLETE
-- ============================================================
-- Records Inserted:
-- Disaster: 5
-- Affected_Area: 13
-- Resource: 22
-- Inventory: 21
-- Relief_Team: 11
-- Volunteer: 15
-- Request: 14
-- Allocation: 9
-- Donor: 10
-- Donation: 15
-- ============================================================

-- Verification Query
SELECT 'Disaster' as TableName, COUNT(*) as RecordCount FROM Disaster
UNION ALL SELECT 'Affected_Area', COUNT(*) FROM Affected_Area
UNION ALL SELECT 'Resource', COUNT(*) FROM Resource
UNION ALL SELECT 'Inventory', COUNT(*) FROM Inventory
UNION ALL SELECT 'Relief_Team', COUNT(*) FROM Relief_Team
UNION ALL SELECT 'Volunteer', COUNT(*) FROM Volunteer
UNION ALL SELECT 'Request', COUNT(*) FROM Request
UNION ALL SELECT 'Allocation', COUNT(*) FROM Allocation
UNION ALL SELECT 'Donor', COUNT(*) FROM Donor
UNION ALL SELECT 'Donation', COUNT(*) FROM Donation;
