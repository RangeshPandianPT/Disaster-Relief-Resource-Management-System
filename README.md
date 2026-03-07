# DRRMS - Disaster Relief Resource Management System

A comprehensive database management system for coordinating disaster relief operations.

## 📁 Project Structure

```
DRRMS/
├── database/           # SQL Scripts (13 files)
│   ├── 01_schema.sql           # Table definitions
│   ├── 02_sample_data.sql      # Sample data
│   ├── 03_queries.sql          # Complex queries
│   ├── 04_views.sql            # Database views
│   ├── 05_triggers.sql         # Automation triggers
│   ├── 06_procedures.sql       # Stored procedures
│   ├── 07_functions.sql        # User-defined functions
│   ├── 08_transactions.sql     # Transaction examples
│   ├── 09_cursors.sql          # Cursor operations
│   ├── 10_events.sql           # Scheduled events
│   ├── 11_security.sql         # Roles & permissions
│   ├── 12_audit.sql            # Audit logging
│   └── 13_performance.sql      # Query optimization
│
├── migrations/         # Database Version Control
│   ├── 001_initial_schema.sql
│   ├── 002_add_indexes.sql
│   ├── 003_add_audit.sql
│   ├── migration_log.sql
│   └── migrate.py              # Python migration runner
│
├── cli/                # Command Line Interface
│   ├── drrms_cli.py            # Main CLI application
│   ├── db_connection.py        # Database utilities
│   ├── commands/               # CLI command modules
│   └── requirements.txt
│
├── webapp/             # Flask Web Application
│   ├── app.py                  # Main Flask app
│   ├── config.py               # Configuration
│   ├── models/                 # Database models
│   ├── routes/                 # API routes
│   ├── templates/              # HTML templates
│   ├── static/                 # CSS, JS, images
│   └── requirements.txt
│
└── documentation/      # Project Documentation
    ├── 01_ER_Diagram_Design.md
    └── 02_ER_Diagram_Visual.md
```

## 🚀 Quick Start

### 1. Setup Database

```bash
# Create database in MySQL
mysql -u root -p -e "CREATE DATABASE drrms_db;"

# Run schema and sample data
mysql -u root -p drrms_db < database/01_schema.sql
mysql -u root -p drrms_db < database/02_sample_data.sql
```

### 2. Run CLI Tool

```bash
cd cli
pip install -r requirements.txt

# Update database password in db_connection.py

python drrms_cli.py status
python drrms_cli.py report dashboard
python drrms_cli.py disaster list
python drrms_cli.py inventory alerts
```

### 3. Run Web Application

```bash
cd webapp
pip install -r requirements.txt

# Update database password in config.py

python app.py
# Open http://localhost:5000
```

## 📊 Features

### Database Layer
- 10 core entities with relationships
- 20+ complex queries with joins/subqueries
- 10 database views for reporting
- 16 triggers for automation
- 20+ stored procedures
- 10 user-defined functions
- Transaction management examples
- Event scheduling
- Role-based security
- Audit logging

### CLI Tool
- Disaster management (list, add, view, update)
- Inventory tracking with visual indicators
- Request management
- Report generation with ASCII charts

### Web Application
- Interactive dashboard with Chart.js
- Disaster management with modal views
- Inventory tracking with alerts
- Request filtering and management
- Volunteer directory
- Donation tracking
- Modern dark theme UI
- Responsive design

## 🔧 Technologies

- **Database**: MySQL 8.0+
- **Backend**: Python 3.8+, Flask
- **Frontend**: HTML5, CSS3, JavaScript
- **Charts**: Chart.js
- **CLI**: Click, Tabulate

## 📝 DBMS Concepts Covered

| Concept | Implementation |
|---------|----------------|
| DDL | Schema creation, ALTER |
| DML | INSERT, UPDATE, DELETE |
| JOINs | INNER, LEFT, RIGHT, CROSS |
| Subqueries | Correlated, nested |
| Views | Materialized, updateable |
| Triggers | BEFORE/AFTER, row-level |
| Procedures | Parameters, error handling |
| Functions | Scalar, deterministic |
| Transactions | ACID, savepoints, isolation |
| Cursors | Row-by-row processing |
| Events | Scheduled tasks |
| Security | RBAC, grants |
| Audit | Change tracking |
| Performance | Indexing, query tuning |

## 👨‍💻 Author

DRRMS Database Project for DBMS Learning

## 📄 License

This project is for educational purposes.
