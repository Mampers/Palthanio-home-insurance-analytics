# Create Schemas – Data Warehouse Foundation

## Overview

This folder contains the SQL script responsible for creating the schema structure used in the **Palthanio Home Insurance Data Warehouse**.

The schemas form the foundation of the **Medallion Architecture** used throughout the project.

The architecture follows a layered approach to progressively refine data as it moves from raw ingestion to business-ready analytics.

---

## Architecture Layers

The project uses the following schema structure:

| Schema | Purpose |
|------|------|
| **stg** | Raw ingestion layer used for loading CSV data exactly as received |
| **bronze** | Initial storage layer that captures raw historical data with metadata |
| **silver** | Cleaned and standardized data used for transformations and modelling |
| **gold** | Final business-ready dimensional model used for reporting and analytics |

This layered approach improves:

- Data quality
- Data lineage
- Debugging
- Maintainability
- Reproducibility

---

## Script in this Folder

| Script | Description |
|------|------|
| `01_Creating_Schema.sql` | Creates all schemas required for the data warehouse pipeline |

The script ensures schemas exist before data ingestion begins.

---

## Schema Creation Logic

The SQL script uses a defensive pattern to ensure schemas are only created if they do not already exist.

Example pattern used:

```sql
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
BEGIN
    EXEC('CREATE SCHEMA bronze');
END
