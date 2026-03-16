# Data Lineage

## Overview

Data lineage documents the **flow of data from its original source through each transformation stage until it reaches the final analytical dashboards**.

Understanding lineage helps stakeholders trace how data is created, transformed, and consumed throughout the analytics pipeline.

This project follows a **modern data warehouse architecture**, incorporating multiple transformation layers before delivering insights through Power BI.

---

# Data Flow Architecture

The data pipeline follows the structure below:

```
Source CSV Data
      ↓
Staging Layer
      ↓
Bronze Layer (Raw Data)
      ↓
Silver Layer (Data Cleaning & Transformation)
      ↓
Gold Layer (Dimensional Model)
      ↓
Power BI Semantic Model
      ↓
Power BI Dashboards
```

---

# Stage Descriptions

## Source Data

The project uses **simulated home insurance datasets stored as CSV files**, representing typical operational datasets used by an insurance company.

Examples include:

- policy data
- claims data
- broker data
- property information

---

## Staging Layer

The staging layer temporarily loads raw data from source files into SQL Server.

Purpose:

- initial ingestion
- minimal transformation
- preparation for warehouse processing

---

## Bronze Layer

The Bronze layer stores **raw ingested data in its original format**.

Characteristics:

- minimal transformation
- raw data preservation
- historical data capture

---

## Silver Layer

The Silver layer performs **data cleaning and standardisation**.

Transformations include:

- data type correction
- removal of duplicates
- null handling
- field standardisation

This layer prepares the data for dimensional modelling.

---

## Gold Layer

The Gold layer contains the **final analytical model** structured as a dimensional schema.

Components:

- fact tables
- dimension tables
- business-ready datasets

This layer is optimised for analytical queries.

---

## Power BI Semantic Model

The Gold layer is connected to Power BI, where a semantic model is created to support analytical calculations.

This includes:

- relationships between tables
- DAX measures
- business KPIs

---

## Power BI Dashboards

The final stage presents insights through interactive dashboards that analyse:

- underwriting performance
- claims analysis
- portfolio risk
- profitability trends

---

# Benefits of Data Lineage

Documenting lineage provides several advantages:

| Benefit | Description |
|------|-------------|
| Transparency | Clear understanding of data origin |
| Debugging | Easier identification of data issues |
| Governance | Improved documentation of transformations |
| Trust | Stakeholders trust analytical results |

---

# Conclusion

The documented data lineage ensures full transparency across the analytics pipeline and demonstrates how raw operational data is transformed into business insights.
