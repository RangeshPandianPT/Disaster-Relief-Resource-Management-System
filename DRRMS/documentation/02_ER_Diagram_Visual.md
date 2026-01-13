# 📊 DRRMS - Visual Entity Relationship Diagram

## Complete ER Diagram (Simplified - 10 Entities)

```mermaid
erDiagram
    DISASTER ||--o{ AFFECTED_AREA : impacts
    DISASTER ||--o{ RELIEF_TEAM : responds
    DISASTER ||--o{ DONATION : receives
    
    AFFECTED_AREA ||--o{ REQUEST : submits
    AFFECTED_AREA ||--o{ RELIEF_TEAM : assigned
    
    REQUEST ||--o{ ALLOCATION : fulfilled_by
    REQUEST }o--|| RESOURCE : requests
    
    RESOURCE ||--o{ INVENTORY : stored_in
    RESOURCE ||--o{ DONATION : donated_as
    
    INVENTORY ||--o{ ALLOCATION : supplies
    
    RELIEF_TEAM ||--o{ VOLUNTEER : includes
    
    DONOR ||--o{ DONATION : provides
    
    DISASTER {
        int disaster_id PK
        varchar name
        varchar type
        varchar severity
        date start_date
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
        timestamp last_updated
    }
    
    REQUEST {
        int request_id PK
        int area_id FK
        int resource_id FK
        int quantity_requested
        varchar urgency
        varchar status
        timestamp request_date
    }
    
    ALLOCATION {
        int allocation_id PK
        int request_id FK
        int inventory_id FK
        int quantity_allocated
        varchar delivery_status
        timestamp allocation_date
    }
    
    VOLUNTEER {
        int volunteer_id PK
        varchar name
        varchar email
        varchar phone
        varchar skills
        varchar availability
        int team_id FK
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
        varchar receipt_no
    }
```

---

## Module-wise Diagrams

### Module A: Disaster & Area Management

```mermaid
erDiagram
    DISASTER ||--o{ AFFECTED_AREA : "impacts"
    
    DISASTER {
        int disaster_id PK
        varchar name
        varchar type
        varchar severity
        date start_date
        varchar status
    }
    
    AFFECTED_AREA {
        int area_id PK
        int disaster_id FK
        varchar area_name
        varchar district
        varchar priority
    }
```

### Module B: Resource & Inventory

```mermaid
erDiagram
    RESOURCE ||--o{ INVENTORY : "stored_in"
    
    RESOURCE {
        int resource_id PK
        varchar name
        varchar category
        varchar unit
    }
    
    INVENTORY {
        int inventory_id PK
        int resource_id FK
        varchar warehouse
        int quantity
    }
```

### Module C: Request & Allocation

```mermaid
erDiagram
    AFFECTED_AREA ||--o{ REQUEST : "submits"
    REQUEST ||--o{ ALLOCATION : "fulfilled_by"
    REQUEST }o--|| RESOURCE : "requests"
    INVENTORY ||--o{ ALLOCATION : "supplies"
    
    REQUEST {
        int request_id PK
        int area_id FK
        int resource_id FK
        int quantity
        varchar status
    }
    
    ALLOCATION {
        int allocation_id PK
        int request_id FK
        int inventory_id FK
        int quantity
        varchar status
    }
```

### Module D: Team & Volunteer

```mermaid
erDiagram
    DISASTER ||--o{ RELIEF_TEAM : "responds"
    RELIEF_TEAM ||--o{ VOLUNTEER : "includes"
    
    RELIEF_TEAM {
        int team_id PK
        int disaster_id FK
        varchar team_name
        varchar team_type
    }
    
    VOLUNTEER {
        int volunteer_id PK
        varchar name
        varchar skills
        int team_id FK
    }
```

### Module E: Donation Tracking

```mermaid
erDiagram
    DONOR ||--o{ DONATION : "provides"
    DISASTER ||--o{ DONATION : "receives"
    
    DONOR {
        int donor_id PK
        varchar name
        varchar type
    }
    
    DONATION {
        int donation_id PK
        int donor_id FK
        int disaster_id FK
        decimal amount
    }
```

---

## Data Flow Diagram

```mermaid
flowchart TD
    subgraph Event["🌀 Disaster Event"]
        D[Disaster Registered]
    end
    
    subgraph Areas["📍 Impact Assessment"]
        D --> AA[Affected Areas Mapped]
    end
    
    subgraph Resources["📦 Resources"]
        RES[(Resource Catalog)]
        INV[(Inventory Stock)]
        RES --> INV
    end
    
    subgraph Requests["📝 Request Flow"]
        AA --> REQ[Requests Submitted]
        REQ --> ALO[Allocations Made]
        INV --> ALO
    end
    
    subgraph Teams["👥 Response"]
        D --> RT[Relief Teams Formed]
        RT --> VOL[Volunteers Assigned]
        VOL --> ALO
    end
    
    subgraph Funding["💰 Donations"]
        DON[Donors]
        DON --> DONA[Donations]
        DONA --> D
        DONA --> INV
    end
    
    ALO --> DEL[Delivery Complete ✅]
```

---

## System Overview

```mermaid
flowchart LR
    subgraph Users["👥 Users"]
        ADMIN[Admin]
        COORD[Coordinator]
        FIELD[Field Officer]
    end
    
    subgraph App["🖥️ Application"]
        WEB[Web Interface]
    end
    
    subgraph DB["🗄️ Database"]
        MYSQL[(MySQL)]
    end
    
    Users --> App --> DB
```

---

*Simplified: 10 Entities | Easy to Implement | Full DBMS Coverage*
