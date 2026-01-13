# 🚨 Disaster Relief Resource Management System (DRRMS)
## Project Overview

---

## 📋 Project Information

| Item | Details |
|------|---------|
| **Project Title** | Design and Implementation of a Disaster Relief Resource Management System Using RDBMS |
| **Domain** | Disaster Management / Social Welfare |
| **Database** | MySQL / PostgreSQL |
| **Entities** | 10 Tables (Simplified) |

---

## 🎯 Objectives

1. Centralized management of disaster relief operations
2. Real-time tracking of resources and allocations
3. Coordination between response teams and volunteers
4. Transparency in donation management
5. Optimal resource allocation based on urgency

---

## 🗂️ Project Structure

```
DRRMS/
├── documentation/
│   ├── 01_ER_Diagram_Design.md      ✅ Entity specifications (10 tables)
│   ├── 02_ER_Diagram_Visual.md      ✅ Mermaid ER diagrams
│   └── README.md                     ✅ This file
│
├── database/
│   ├── 01_schema.sql                 📝 Table creation scripts
│   ├── 02_sample_data.sql            📝 Test data
│   ├── 03_queries.sql                📝 Sample queries & joins
│   ├── 04_views.sql                  📝 View definitions
│   ├── 05_triggers.sql               📝 Triggers
│   └── 06_procedures.sql             📝 Stored procedures
│
└── frontend/                         📝 Web interface (optional)
```

**Legend:** ✅ Completed | 📝 To be created

---

## 📊 Database Entities (10 Tables)

| # | Entity | Purpose | Key Relationships |
|---|--------|---------|-------------------|
| 1 | **Disaster** | Disaster events | → Affected_Area, Relief_Team, Donation |
| 2 | **Affected_Area** | Impact zones | → Request, ← Disaster |
| 3 | **Resource** | Relief items | → Inventory, Request, Donation |
| 4 | **Inventory** | Stock levels | → Allocation, ← Resource |
| 5 | **Request** | Resource requests | → Allocation, ← Affected_Area |
| 6 | **Allocation** | Resource assignments | ← Request, Inventory |
| 7 | **Volunteer** | Volunteers | ← Relief_Team |
| 8 | **Relief_Team** | Response teams | → Volunteer, ← Disaster |
| 9 | **Donor** | Donation sources | → Donation |
| 10 | **Donation** | Recorded donations | ← Donor, Disaster |

---

## 🔗 Relationship Diagram

```
       DISASTER
          │
    ┌─────┼─────┐
    ▼     ▼     ▼
  AREA  TEAM  DONATION
    │     │      │
    ▼     ▼      │
REQUEST VOLUNTEER│
    │            │
    ▼            │
ALLOCATION ◄─────┘
    │
    │
INVENTORY ◄── RESOURCE
```

---

## 📈 DBMS Concepts Demonstrated

| Concept | Example in DRRMS |
|---------|------------------|
| **Primary Keys** | disaster_id, request_id, etc. |
| **Foreign Keys** | request.area_id → affected_area.area_id |
| **Joins** | Request + Resource + Allocation |
| **Views** | Pending requests, team status |
| **Triggers** | Update inventory on allocation |
| **Stored Procedures** | Auto-allocate resources |
| **Transactions** | Allocation + inventory update |

---

## 🚀 Progress

- [x] ER Diagram Design (10 entities)
- [x] Visual diagrams
- [ ] SQL Schema
- [ ] Sample Data
- [ ] Queries & Joins
- [ ] Views, Triggers, Procedures
- [ ] Web Interface (optional)

---

*Simplified Design | 10 Entities | Student-Friendly*
