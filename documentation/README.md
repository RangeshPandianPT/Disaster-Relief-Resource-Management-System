# 🚨 Disaster Relief Resource Management System (DRRMS)
## Complete Database Project

---

## 📋 Project Information

| Item | Details |
|------|---------|
| **Project Title** | Design and Implementation of a Disaster Relief Resource Management System Using RDBMS |
| **Domain** | Disaster Management / Social Welfare |
| **Database** | MySQL 8.0+ / MariaDB 10.5+ |
| **Entities** | 10 Tables |
| **Level** | Moderate (Ideal for DBMS Lab/Mini Project) |

---

## 🗂️ Project Structure

```
DRRMS/
├── documentation/
│   ├── 01_ER_Diagram_Design.md    ✅ Entity specifications
│   ├── 02_ER_Diagram_Visual.md    ✅ Mermaid ER diagrams
│   └── README.md                   ✅ This file
│
└── database/
    ├── 01_schema.sql              ✅ Table creation (DDL)
    ├── 02_sample_data.sql         ✅ Test data (115+ records)
    ├── 03_queries.sql             ✅ 20 sample queries
    ├── 04_views.sql               ✅ 10 database views
    ├── 05_triggers.sql            ✅ 8 triggers
    └── 06_procedures.sql          ✅ 10 stored procedures
```

---

## 🚀 Quick Start

### Step 1: Create Database & Tables
```sql
SOURCE d:/DBMS/DRRMS/database/01_schema.sql;
```

### Step 2: Insert Sample Data
```sql
SOURCE d:/DBMS/DRRMS/database/02_sample_data.sql;
```

### Step 3: Create Views
```sql
SOURCE d:/DBMS/DRRMS/database/04_views.sql;
```

### Step 4: Create Triggers
```sql
SOURCE d:/DBMS/DRRMS/database/05_triggers.sql;
```

### Step 5: Create Stored Procedures
```sql
SOURCE d:/DBMS/DRRMS/database/06_procedures.sql;
```

### Step 6: Run Sample Queries
```sql
SOURCE d:/DBMS/DRRMS/database/03_queries.sql;
```

---

## 📊 Database Summary

### Tables (10)

| # | Table | Purpose | Records |
|---|-------|---------|---------|
| 1 | Disaster | Disaster events | 5 |
| 2 | Affected_Area | Impact zones | 13 |
| 3 | Resource | Relief items | 22 |
| 4 | Inventory | Stock levels | 21 |
| 5 | Relief_Team | Response teams | 11 |
| 6 | Volunteer | Volunteers | 15 |
| 7 | Request | Resource requests | 14 |
| 8 | Allocation | Assignments | 9 |
| 9 | Donor | Donation sources | 10 |
| 10 | Donation | Donations | 15 |

### Views (10)

| View | Purpose |
|------|---------|
| vw_active_disaster_summary | Active disaster dashboard |
| vw_pending_requests | Pending request queue |
| vw_inventory_status | Stock levels & alerts |
| vw_team_details | Team & volunteer info |
| vw_allocation_tracking | Delivery tracking |
| vw_donor_summary | Donor contributions |
| vw_resource_demand | Demand analysis |
| vw_volunteer_availability | Volunteer status |
| vw_area_fulfillment | Area fulfillment rates |
| vw_daily_dashboard | Operations overview |

### Triggers (8)

| Trigger | Purpose |
|---------|---------|
| trg_after_allocation_insert | Reduce inventory on allocation |
| trg_after_allocation_delete | Restore inventory on cancel |
| trg_after_allocation_update | Update request on delivery |
| trg_before_donation_insert | Auto-generate receipt |
| trg_before_allocation_insert | Validate allocation qty |
| trg_after_donation_insert | Add materials to inventory |

### Stored Procedures (10)

| Procedure | Purpose |
|-----------|---------|
| sp_register_disaster | Register new disaster |
| sp_add_affected_area | Add affected area |
| sp_submit_request | Submit resource request |
| sp_allocate_resources | Allocate resources |
| sp_update_delivery_status | Update delivery |
| sp_register_volunteer | Register volunteer |
| sp_assign_volunteer_to_team | Assign to team |
| sp_record_donation | Record donation |
| sp_get_disaster_report | Generate report |
| sp_close_disaster | Close disaster |

---

## 📈 DBMS Concepts Covered

| Concept | Implementation |
|---------|----------------|
| ✅ DDL | CREATE TABLE, ALTER, DROP |
| ✅ DML | INSERT, UPDATE, DELETE |
| ✅ Primary Keys | All tables have AUTO_INCREMENT PKs |
| ✅ Foreign Keys | 12 FK relationships |
| ✅ Constraints | CHECK, UNIQUE, NOT NULL, DEFAULT |
| ✅ Joins | INNER, LEFT, RIGHT joins |
| ✅ Subqueries | Correlated & non-correlated |
| ✅ Aggregate Functions | COUNT, SUM, AVG, GROUP BY |
| ✅ Views | 10 views for reporting |
| ✅ Triggers | 8 triggers for automation |
| ✅ Stored Procedures | 10 procedures for business logic |
| ✅ Transactions | Atomic operations in procedures |
| ✅ Indexes | 14 indexes for optimization |
| ✅ Normalization | 3NF design |

---

## 🔍 Sample Queries

```sql
-- Active disaster overview
SELECT * FROM vw_active_disaster_summary;

-- Critical pending requests
SELECT * FROM vw_pending_requests WHERE urgency = 'Critical';

-- Low stock items
SELECT * FROM vw_inventory_status WHERE stock_status = 'LOW STOCK';

-- Team with volunteers
SELECT * FROM vw_team_details WHERE team_status = 'Active';

-- Daily dashboard
SELECT * FROM vw_daily_dashboard;
```

---

## 📝 Sample Procedure Calls

```sql
-- Register a new disaster
CALL sp_register_disaster('Cyclone Test', 'Cyclone', 'High', '2025-01-15', 'Test disaster', @id);
SELECT @id;

-- Get disaster report
CALL sp_get_disaster_report(3);

-- Register volunteer
CALL sp_register_volunteer('John Doe', 'john@email.com', '9876543210', 'First Aid, Driving', @vid);
```

---

## 🎯 Project Highlights

1. **Real-world Problem** - Disaster management is highly relevant
2. **Complete Workflow** - Request → Allocation → Delivery cycle
3. **Multiple Stakeholders** - Authorities, volunteers, donors
4. **Audit Trail** - Transparent donation tracking
5. **Automation** - Triggers for inventory management
6. **Reporting** - Views for dashboards and analytics

---

## 📚 References

- MySQL 8.0 Reference Manual
- Database Normalization Principles
- Disaster Management Best Practices

---

*Created: January 2025*
*Status: ✅ Complete*
