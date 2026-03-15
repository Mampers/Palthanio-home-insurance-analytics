# Data Architecture

## Overview

This folder documents the **data architecture and modelling design** for the Palthanio Home Insurance Analytics project.

It explains how the source datasets are structured, how the dimensional model is designed, and how fact and dimension tables support analytical reporting in Power BI.

The documentation in this section bridges the gap between the **raw data sources** and the **SQL data warehouse implementation** described in the next section of the project.

---

## Purpose

The objective of the data architecture documentation is to:

- describe the source datasets used in the project
- explain the dimensional modelling approach
- define the structure of fact and dimension tables
- document key fields and metrics used across the analytics model
- provide clear reference material for developers and analysts

This ensures the data model is transparent, maintainable, and aligned with analytical requirements.

---

## Data Architecture Approach

The project follows a **dimensional modelling approach** commonly used in enterprise data warehouses.

The design separates:

- **dimension tables** that describe business entities
- **fact tables** that store measurable events and transactions

This approach improves analytical performance and simplifies Power BI reporting.

The architecture supports the following analytical capabilities:

- premium revenue analysis
- claims cost analysis
- broker performance tracking
- risk segmentation
- underwriting profitability measurement

---

## Files in this Folder

### 01_Source_Data_Description.md

Describes the original source datasets used in the project including:

- policy data
- broker information
- property address details
- premium transactions
- claims records
- claim payments
- claim reserves
- operating expenses

This file provides context on the raw data inputs used to build the analytical model.

---

### 02_Data_Model.md

Defines the overall dimensional model used in the project.

This includes:

- dimension tables
- fact tables
- star schema design
- relationships between entities

The model is designed to support efficient analytical queries in Power BI.

---

### 03_Dimension_Design.md

Explains the design of the dimension tables used in the model.

Dimension tables provide descriptive attributes that allow metrics to be analysed by:

- time
- geography
- broker
- property characteristics
- claim categories

---

### 04_Fact_Table_Design.md

Documents the design of the fact tables that store measurable business events.

Fact tables capture financial and operational metrics such as:

- written premium
- claim payments
- claim reserves
- operating expenses

These tables form the foundation of the project's KPIs.

---

### 05_Data_Dictionary.md

Provides a reference for key fields used across the model.

The data dictionary defines:

- field names
- field descriptions
- business meaning of important attributes

This helps analysts and developers understand the structure and purpose of the data.

---

## Relationship to Other Project Sections

This folder focuses on the **logical design of the data model**.

The following sections of the repository extend this design:

| Folder | Purpose |
|------|------|
| `01_Project_Overview` | Business requirements, KPIs, and architecture decisions |
| `03_SQL_Data_Warehouse` | SQL scripts used to implement the warehouse |
| `04_Power_BI_Modelling` | Power BI semantic model, DAX measures, and dashboard design |

Together these components form a complete end-to-end analytics solution.

---

## Summary

The data architecture documentation ensures that the analytical model is:

- clearly structured
- aligned with business questions
- easy to understand and maintain
- suitable for scalable BI reporting

This section provides the conceptual foundation for the SQL data warehouse and Power BI dashboards used in the Palthanio Home Insurance Analytics project.
