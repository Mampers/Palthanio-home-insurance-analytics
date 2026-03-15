# SQL Data Warehouse

## Overview

This folder contains the full **SQL Server data warehouse implementation** used in the **Palthanio Home Insurance Analytics project**.

The purpose of this component is to simulate a **real-world insurance data engineering pipeline**, where raw source data is progressively transformed into analytics-ready datasets used by **Power BI** for reporting and decision support.

The warehouse follows a **Medallion Architecture** pattern to ensure data quality, traceability, and maintainability across the pipeline.

---

# Data Warehouse Architecture

The SQL pipeline is structured using four logical layers:

| Layer | Schema | Purpose |
|------|------|------|
| **Staging** | `stg` | Raw ingestion of source CSV files exactly as received |
| **Bronze** | `bronze` | Persistent storage of raw historical data with ingestion metadata |
| **Silver** | `silver` | Cleaned and standardized datasets prepared for modelling |
| **Gold** | `gold` | Dimensional model used for reporting and analytics |

This layered architecture ensures:

- Data lineage
- Data quality control
- Easier debugging
- Reproducible transformations
- Scalable data engineering workflows

---

# Folder Structure

```
03_SQL_Data_Warehouse
│
├── 01_Create_Schemas
│     Creates all schemas required for the warehouse
│
├── 02_Staging
│     Loads raw CSV files into staging tables
│
├── 03_bronze_sql
│     Stores raw ingested data with metadata
│
├── 04_silver_SQL
│     Performs data cleansing and transformation
│
└── 05_gold_sql
      Builds dimensional tables and fact tables for analytics
```

---

# Data Pipeline Flow

```
Source CSV Files
        │
        ▼
Staging Layer (stg)
Raw ingestion of source datasets
        │
        ▼
Bronze Layer (bronze)
Persistent raw storage with ingestion metadata
        │
        ▼
Silver Layer (silver)
Data cleaning and business transformation
        │
        ▼
Gold Layer (gold)
Dimensional modelling for analytics
        │
        ▼
Power BI Semantic Model
```

---

# Key Data Warehouse Components

The warehouse models key entities commonly found in a **home insurance business**, including:

- Policies
- Customers
- Brokers
- Addresses
- Property Risk Attributes
- Coverage Types
- Premium Transactions
- Claims
- Claim Payments
- Claim Reserves
- Operating Expenses

These datasets are transformed into a **star schema model** in the Gold layer.

---

# Dimensional Model (Gold Layer)

The final reporting model contains the following tables.

### Dimension Tables

- `dim_policy`
- `dim_customer`
- `dim_broker`
- `dim_address`
- `dim_property_risk`
- `dim_coverage`
- `dim_date`

### Fact Tables

- `fact_premium_transactions`
- `fact_claim_payments`
- `fact_claim_reserves`
- `fact_operating_expense`

These tables power the **Power BI semantic model** used for portfolio analysis.

---

# Technologies Used

- SQL Server
- T-SQL
- Medallion Architecture
- Dimensional Modelling (Kimball Methodology)
- Power BI

---

# Project Context

The **Palthanio Home Insurance Analytics platform** is a portfolio project designed to simulate how a modern insurance analytics team structures its data warehouse.

The project demonstrates:

- Data engineering workflows
- Data modelling best practices
- Insurance domain analytics
- End-to-end BI development from raw data to dashboard.

---

# Related Components

This SQL data warehouse feeds the Power BI reports contained within this project.

The warehouse enables analytics such as:

- Loss Ratio analysis
- Broker performance analysis
- Claims development tracking
- Premium growth trends
- Underwriting portfolio risk analysis

---

# Author

**Paul Mampilly**  
Senior Power BI Developer | Data Analyst
