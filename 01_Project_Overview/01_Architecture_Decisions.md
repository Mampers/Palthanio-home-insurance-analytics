# Architecture Decisions

## Purpose
This document explains the architecture and modelling decisions used in the **Palthanio Home Insurance Analytics** project.

The goal of the project is to simulate a realistic insurance analytics environment using modern BI engineering practices.

---

## Solution Architecture

The project follows a **Medallion Architecture** consisting of three layers:

Bronze → Silver → Gold

This approach separates raw ingestion, transformation logic, and analytics-ready data.

---

## Bronze Layer

The Bronze layer stores **raw source data** exactly as ingested from CSV files.

### Objectives
- Preserve original data
- Maintain auditability
- Allow reprocessing if transformation logic changes

### Characteristics
- Minimal transformation
- Raw column naming retained where possible
- Append-first ingestion strategy
- Source traceability

---

## Silver Layer

The Silver layer performs **data cleansing and standardisation**.

### Transformations include

- Data type corrections
- Text standardisation
- Deduplication
- Business rule validation
- Null handling
- Surrogate key preparation

This layer creates **clean and reusable intermediate tables**.

---

## Gold Layer

The Gold layer contains **analytics-ready dimensional models** designed for Power BI.

### Design approach
- Star schema modelling
- Conformed dimensions
- Fact tables representing business processes

### Dimensions

Examples include:

- dim_date  
- dim_policy  
- dim_broker  
- dim_address  
- dim_claim_type  
- dim_expense_category  

### Fact tables

- fact_premium_transactions  
- fact_claim_payments  
- fact_claim_reserves  
- fact_operating_expense  

---

## Star Schema Modelling

A star schema was selected because it:

- improves Power BI performance
- simplifies DAX
- enables reusable dimensions
- aligns with Kimball dimensional modelling

---

## Surrogate Keys

Dimensions use **surrogate keys** instead of business keys.

Benefits include:

- stability if source keys change
- support for unknown members
- improved relational consistency

---

## Date Dimension

A conformed `dim_date` table supports:

- trend analysis
- time intelligence
- period comparisons
- monthly reporting

---

## Fact Table Design

The model separates insurance processes into multiple fact tables:

| Fact Table | Business Process |
|-------------|----------------|
| fact_premium_transactions | Premium movement |
| fact_claim_payments | Claims paid |
| fact_claim_reserves | Outstanding reserves |
| fact_operating_expense | Operating cost snapshots |

---

## Design Principles

The project follows these principles:

- Business-first modelling
- Clear data lineage
- Scalable architecture
- Stakeholder-friendly reporting
- Realistic enterprise practices

---

## Future Enhancements

Possible future improvements include:

- reinsurance modelling
- catastrophe event analysis
- policy renewal analytics
- fraud indicators
- incremental data loads
