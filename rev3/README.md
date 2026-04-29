# DRRMS Rev3 Demo Pack

This folder contains topic-wise, runnable demos for:

1. Normalization (dependencies and anomalies)
2. Transaction Management (ACID properties)
3. Concurrency Control (locking mechanisms)

All files are isolated under a separate demo database: `drrms_rev3_demo`.

## Files

- `01_normalization_dependencies_anomalies.sql`
- `02_transaction_management_acid.sql`
- `03_concurrency_control_locking.sql`

## Prerequisites

- MySQL 8.0+
- Access to run SQL scripts from terminal or MySQL client

## Run Order

Run scripts in this sequence:

```bash
mysql -u root -p < rev3/01_normalization_dependencies_anomalies.sql
mysql -u root -p < rev3/02_transaction_management_acid.sql
mysql -u root -p < rev3/03_concurrency_control_locking.sql
```

If your MySQL user does not have a default database selected, these scripts still work because each script runs:

```sql
CREATE DATABASE IF NOT EXISTS drrms_rev3_demo;
USE drrms_rev3_demo;
```

## What To Show In Demo

## 1) Normalization

Run:

```sql
USE drrms_rev3_demo;
SOURCE rev3/01_normalization_dependencies_anomalies.sql;
```

Show:
- `UNNORMALIZED_BASELINE`
- `UPDATE_ANOMALY_CHECK`
- `DELETE_ANOMALY_CHECK`
- `NORMALIZED_JOIN_VIEW`
- `NORMALIZED_FINAL_STATE`

## 2) ACID Transactions

Run:

```sql
USE drrms_rev3_demo;
SOURCE rev3/02_transaction_management_acid.sql;
```

Show:
- Successful commit (`@ok1 = 1`)
- Failed request rollback (`@ok2 = 0`)
- Inventory remains consistent
- Audit table logs both committed and rolled-back actions

## 3) Concurrency and Locking

Run:

```sql
USE drrms_rev3_demo;
SOURCE rev3/03_concurrency_control_locking.sql;
```

Show:
- `FOR UPDATE` pessimistic locking procedure
- Optimistic locking procedure with `version_no`
- Named lock using `GET_LOCK` / `RELEASE_LOCK`

### Live Blocking Demo (2 sessions)

Open two MySQL sessions and run the blocks from the bottom of `03_concurrency_control_locking.sql`:

- Session A holds row lock with `FOR UPDATE`
- Session B tries update and waits (or times out)
- Commit Session A and observe release

## Reset / Re-run

Scripts are re-runnable. Each script drops and recreates its own demo objects.

If needed, full reset:

```sql
DROP DATABASE IF EXISTS drrms_rev3_demo;
```
