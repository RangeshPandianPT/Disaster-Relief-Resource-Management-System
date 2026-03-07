-- ============================================================
-- DISASTER RELIEF RESOURCE MANAGEMENT SYSTEM (DRRMS)
-- SQL Schema - Table Creation Script
-- Database: MySQL 8.0+ / MariaDB 10.5+
-- ============================================================

-- Create Database
CREATE DATABASE IF NOT EXISTS drrms_db;
USE drrms_db;

-- ============================================================
-- TABLE 1: DISASTER
-- Stores information about disaster events
-- ============================================================
CREATE TABLE Disaster (
    disaster_id INT PRIMARY KEY AUTO_INCREMENT,
    disaster_name VARCHAR(100) NOT NULL,
    disaster_type VARCHAR(50) NOT NULL 
        CHECK (disaster_type IN ('Cyclone', 'Earthquake', 'Flood', 'Fire', 'Tsunami', 'Landslide', 'Drought', 'Other')),
    severity VARCHAR(20) NOT NULL 
        CHECK (severity IN ('Low', 'Medium', 'High', 'Critical')),
    start_date DATE NOT NULL,
    end_date DATE NULL,
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'Active' 
        CHECK (status IN ('Active', 'Contained', 'Resolved')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ============================================================
-- TABLE 2: AFFECTED_AREA
-- Geographic regions impacted by disasters
-- ============================================================
CREATE TABLE Affected_Area (
    area_id INT PRIMARY KEY AUTO_INCREMENT,
    disaster_id INT NOT NULL,
    area_name VARCHAR(100) NOT NULL,
    district VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    population_affected INT DEFAULT 0,
    priority VARCHAR(20) NOT NULL DEFAULT 'Medium' 
        CHECK (priority IN ('Low', 'Medium', 'High', 'Critical')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (disaster_id) REFERENCES Disaster(disaster_id) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================================================
-- TABLE 3: RESOURCE
-- Relief resource items catalog
-- ============================================================
CREATE TABLE Resource (
    resource_id INT PRIMARY KEY AUTO_INCREMENT,
    resource_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL 
        CHECK (category IN ('Food', 'Water', 'Medicine', 'Shelter', 'Clothing', 'Equipment', 'Hygiene', 'Other')),
    unit VARCHAR(20) NOT NULL,
    min_stock INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- TABLE 4: INVENTORY
-- Stock levels of resources at warehouses
-- ============================================================
CREATE TABLE Inventory (
    inventory_id INT PRIMARY KEY AUTO_INCREMENT,
    resource_id INT NOT NULL,
    warehouse_location VARCHAR(100) NOT NULL,
    quantity_available INT NOT NULL DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (resource_id) REFERENCES Resource(resource_id) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================================================
-- TABLE 5: RELIEF_TEAM
-- Response teams assigned to disasters
-- ============================================================
CREATE TABLE Relief_Team (
    team_id INT PRIMARY KEY AUTO_INCREMENT,
    disaster_id INT NOT NULL,
    area_id INT NULL,
    team_name VARCHAR(100) NOT NULL,
    team_type VARCHAR(50) NOT NULL 
        CHECK (team_type IN ('Rescue', 'Medical', 'Logistics', 'Distribution', 'Assessment')),
    leader_name VARCHAR(100),
    contact_phone VARCHAR(15),
    status VARCHAR(20) NOT NULL DEFAULT 'Active' 
        CHECK (status IN ('Active', 'Standby', 'Disbanded')),
    formed_date DATE NOT NULL,
    
    FOREIGN KEY (disaster_id) REFERENCES Disaster(disaster_id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (area_id) REFERENCES Affected_Area(area_id) 
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- ============================================================
-- TABLE 6: VOLUNTEER
-- Individual volunteer information
-- ============================================================
CREATE TABLE Volunteer (
    volunteer_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(15) NOT NULL,
    skills VARCHAR(200),
    availability VARCHAR(20) DEFAULT 'Available' 
        CHECK (availability IN ('Available', 'Busy', 'Unavailable')),
    team_id INT NULL,
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (team_id) REFERENCES Relief_Team(team_id) 
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- ============================================================
-- TABLE 7: REQUEST
-- Resource requests from affected areas
-- ============================================================
CREATE TABLE Request (
    request_id INT PRIMARY KEY AUTO_INCREMENT,
    area_id INT NOT NULL,
    resource_id INT NOT NULL,
    quantity_requested INT NOT NULL,
    urgency VARCHAR(20) NOT NULL DEFAULT 'Medium' 
        CHECK (urgency IN ('Low', 'Medium', 'High', 'Critical')),
    request_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'Pending' 
        CHECK (status IN ('Pending', 'Approved', 'Fulfilled', 'Partially_Fulfilled', 'Rejected')),
    remarks TEXT,
    
    FOREIGN KEY (area_id) REFERENCES Affected_Area(area_id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (resource_id) REFERENCES Resource(resource_id) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================================================
-- TABLE 8: ALLOCATION
-- Resource allocation to fulfill requests
-- ============================================================
CREATE TABLE Allocation (
    allocation_id INT PRIMARY KEY AUTO_INCREMENT,
    request_id INT NOT NULL,
    inventory_id INT NOT NULL,
    quantity_allocated INT NOT NULL,
    allocation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    delivery_status VARCHAR(20) NOT NULL DEFAULT 'Pending' 
        CHECK (delivery_status IN ('Pending', 'Dispatched', 'In_Transit', 'Delivered', 'Failed')),
    delivered_date TIMESTAMP NULL,
    remarks TEXT,
    
    FOREIGN KEY (request_id) REFERENCES Request(request_id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (inventory_id) REFERENCES Inventory(inventory_id) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================================================
-- TABLE 9: DONOR
-- Individuals or organizations providing donations
-- ============================================================
CREATE TABLE Donor (
    donor_id INT PRIMARY KEY AUTO_INCREMENT,
    donor_name VARCHAR(150) NOT NULL,
    donor_type VARCHAR(50) NOT NULL 
        CHECK (donor_type IN ('Individual', 'Corporate', 'NGO', 'Government', 'International')),
    email VARCHAR(100),
    phone VARCHAR(15),
    address TEXT,
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- TABLE 10: DONATION
-- Monetary or material donations received
-- ============================================================
CREATE TABLE Donation (
    donation_id INT PRIMARY KEY AUTO_INCREMENT,
    donor_id INT NOT NULL,
    disaster_id INT NULL,
    donation_type VARCHAR(20) NOT NULL 
        CHECK (donation_type IN ('Money', 'Material')),
    amount DECIMAL(12,2) NULL,
    resource_id INT NULL,
    quantity INT NULL,
    donation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    receipt_no VARCHAR(50) UNIQUE,
    status VARCHAR(20) DEFAULT 'Received' 
        CHECK (status IN ('Pledged', 'Received', 'Acknowledged')),
    
    FOREIGN KEY (donor_id) REFERENCES Donor(donor_id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (disaster_id) REFERENCES Disaster(disaster_id) 
        ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (resource_id) REFERENCES Resource(resource_id) 
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- ============================================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- ============================================================

-- Disaster indexes
CREATE INDEX idx_disaster_status ON Disaster(status);
CREATE INDEX idx_disaster_type ON Disaster(disaster_type);

-- Affected Area indexes
CREATE INDEX idx_area_disaster ON Affected_Area(disaster_id);
CREATE INDEX idx_area_priority ON Affected_Area(priority);

-- Inventory indexes
CREATE INDEX idx_inventory_resource ON Inventory(resource_id);
CREATE INDEX idx_inventory_warehouse ON Inventory(warehouse_location);

-- Request indexes
CREATE INDEX idx_request_area ON Request(area_id);
CREATE INDEX idx_request_status ON Request(status);
CREATE INDEX idx_request_urgency ON Request(urgency);

-- Allocation indexes
CREATE INDEX idx_allocation_request ON Allocation(request_id);
CREATE INDEX idx_allocation_status ON Allocation(delivery_status);

-- Volunteer indexes
CREATE INDEX idx_volunteer_team ON Volunteer(team_id);
CREATE INDEX idx_volunteer_availability ON Volunteer(availability);

-- Donation indexes
CREATE INDEX idx_donation_donor ON Donation(donor_id);
CREATE INDEX idx_donation_disaster ON Donation(disaster_id);

-- ============================================================
-- SCHEMA CREATION COMPLETE
-- ============================================================
-- Tables Created: 10
-- Foreign Keys: 12
-- Indexes: 14
-- ============================================================
