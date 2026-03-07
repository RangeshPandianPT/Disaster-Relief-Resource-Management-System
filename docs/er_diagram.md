# DRRMS Entity-Relationship Diagram

## Overview
The Disaster Relief Resource Management System (DRRMS) consists of **10 core entities** managing disaster events, affected areas, resources, volunteers, and donations.

---

## ER Diagram

```mermaid
erDiagram
    DISASTER ||--o{ AFFECTED_AREA : "impacts"
    DISASTER ||--o{ RELIEF_TEAM : "responds_to"
    DISASTER ||--o{ DONATION : "receives"
    
    AFFECTED_AREA ||--o{ RELIEF_TEAM : "assigned_to"
    AFFECTED_AREA ||--o{ REQUEST : "submits"
    
    RESOURCE ||--o{ INVENTORY : "stored_in"
    RESOURCE ||--o{ REQUEST : "requested_as"
    RESOURCE ||--o{ DONATION : "donated_as"
    
    INVENTORY ||--o{ ALLOCATION : "fulfills_from"
    
    RELIEF_TEAM ||--o{ VOLUNTEER : "has_members"
    
    REQUEST ||--o{ ALLOCATION : "fulfilled_by"
    
    DONOR ||--o{ DONATION : "makes"

    DISASTER {
        int disaster_id PK
        varchar disaster_name
        varchar disaster_type
        varchar severity
        date start_date
        date end_date
        varchar status
    }

    AFFECTED_AREA {
        int area_id PK
        int disaster_id FK
        varchar area_name
        varchar district
        varchar state
        int population_affected
        varchar priority
    }

    RESOURCE {
        int resource_id PK
        varchar resource_name
        varchar category
        varchar unit
        int min_stock
    }

    INVENTORY {
        int inventory_id PK
        int resource_id FK
        varchar warehouse_location
        int quantity_available
    }

    RELIEF_TEAM {
        int team_id PK
        int disaster_id FK
        int area_id FK
        varchar team_name
        varchar team_type
        varchar leader_name
        varchar status
    }

    VOLUNTEER {
        int volunteer_id PK
        int team_id FK
        varchar name
        varchar email
        varchar phone
        varchar skills
        varchar availability
    }

    REQUEST {
        int request_id PK
        int area_id FK
        int resource_id FK
        int quantity_requested
        varchar urgency
        varchar status
    }

    ALLOCATION {
        int allocation_id PK
        int request_id FK
        int inventory_id FK
        int quantity_allocated
        varchar delivery_status
    }

    DONOR {
        int donor_id PK
        varchar donor_name
        varchar donor_type
        varchar email
        varchar phone
    }

    DONATION {
        int donation_id PK
        int donor_id FK
        int disaster_id FK
        int resource_id FK
        varchar donation_type
        decimal amount
        int quantity
        varchar status
    }
```

---

## Entity Relationships Summary

| Relationship | Cardinality | Description |
|--------------|-------------|-------------|
| Disaster → Affected_Area | 1:N | A disaster impacts multiple areas |
| Disaster → Relief_Team | 1:N | Teams are formed to respond to disasters |
| Disaster → Donation | 1:N | Donations can be made for specific disasters |
| Affected_Area → Request | 1:N | Areas submit multiple resource requests |
| Affected_Area → Relief_Team | 1:N | Teams are assigned to specific areas |
| Resource → Inventory | 1:N | Resources are stored in multiple warehouses |
| Resource → Request | 1:N | Resources can be requested multiple times |
| Resource → Donation | 1:N | Material donations reference resources |
| Relief_Team → Volunteer | 1:N | Teams consist of multiple volunteers |
| Inventory → Allocation | 1:N | Inventory items fulfill allocations |
| Request → Allocation | 1:N | Requests may have multiple allocations |
| Donor → Donation | 1:N | Donors can make multiple donations |

---

## Key Statistics
- **Total Entities:** 10
- **Total Relationships:** 12
- **Primary Keys:** 10
- **Foreign Keys:** 12
