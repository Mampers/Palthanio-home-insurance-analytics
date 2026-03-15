# Palthanio Home Insurance Analytics

A modern insurance analytics project designed to simulate how a home insurance company can analyse portfolio performance, claims behaviour, and underwriting profitability using SQL Server and Power BI.

This project demonstrates end-to-end data analytics engineering, including data warehousing, dimensional modelling, and business intelligence reporting.

---

# Business Scenario

Home insurance companies must continuously monitor the profitability and risk profile of their policy portfolio.

Key business questions include:

- Is the insurance portfolio profitable?
- Which brokers deliver profitable business?
- Which property types generate the highest claims?
- Are claims increasing faster than premium growth?
- How do operating expenses affect underwriting performance?

This project builds a data model and dashboard solution to answer these questions.

---

# Project Architecture

The solution follows a **Medallion Architecture**.

Bronze → Silver → Gold


### Bronze Layer
Raw data ingestion from source CSV files.

Purpose:
- preserve original source data
- enable traceability
- support reprocessing

### Silver Layer
Data transformation and cleansing.

Includes:
- standardised data types
- deduplication
- null handling
- business rule validation

### Gold Layer
Analytics-ready star schema designed for Power BI.

Includes:
- dimension tables
- fact tables
- surrogate keys
- business KPIs

---

# Data Model

The project uses a **star schema dimensional model**.

### Dimension Tables

| Dimension | Description |
|----------|-------------|
| dim_date | Calendar dimension for time analysis |
| dim_policy | Insurance policy attributes |
| dim_address | Property location information |
| dim_broker | Broker / distribution partner |
| dim_claim_type | Type of insurance claim |
| dim_expense_category | Operating expense classifications |

### Fact Tables

| Fact Table | Description |
|-----------|-------------|
| fact_premium_transactions | Written premium activity |
| fact_claim_payments | Claims paid |
| fact_claim_reserves | Outstanding claims reserves |
| fact_operating_expense | Monthly operating expenses |

---

# Core Insurance KPIs

The dashboard focuses on common insurance performance metrics.

### Financial KPIs

- Total Written Premium
- Earned Premium
- Claims Paid
- Outstanding Reserves
- Incurred Claims
- Loss Ratio
- Expense Ratio
- Combined Ratio
- Underwriting Profit

### Portfolio KPIs

- Number of Policies
- Number of Claims
- Claims per 1,000 Policies
- Average Premium per Policy
- Broker Contribution %

---

# Power BI Dashboard

The Power BI report provides several analytical views.

### Executive Summary
High level overview of portfolio performance.

### Portfolio Performance Trends
Premium, claims, and loss ratio trends over time.

### Broker Performance
Analysis of broker contribution and profitability.

### Claims Analysis
Claims cost by claim type, region, and policy characteristics.

### Policy Portfolio Analysis
Risk segmentation and property characteristics.

### Financial Ratio Analysis
Loss ratio, expense ratio, and combined ratio monitoring.

---

# Repository Structure


Palthanio-home-insurance-analytics
│
├── 01_Project_Overview
│ ├── 01_Architecture_Decisions.md
│ ├── 02_Business_Requirements.md
│ ├── 03_KPI_Definitions.md
│ ├── 04_Stakeholders_Persona.md
│ └── 05_How_To_Run.md
│
├── 02_Data
│ └── Raw datasets
│
├── 03_SQL_Data_Warehouse
│ ├── Bronze_Load
│ ├── Silver_Transform
│ └── Gold_Load
│
├── 04_PowerBI
│ └── Power BI Report (.pbix)
│
└── README.md


---

# Tools Used

- SQL Server
- SQL Server Management Studio
- Power BI Desktop
- DAX
- Git / GitHub

---

# Key Skills Demonstrated

This project demonstrates:

- dimensional modelling
- insurance analytics
- SQL data engineering
- medallion architecture
- KPI development
- Power BI dashboard design
- stakeholder-focused reporting

---

# Future Enhancements

Potential future extensions include:

- policy renewal analysis
- customer segmentation
- catastrophe risk modelling
- fraud indicators
- reinsurance analysis

---

# Author

**Paul Mampilly**

Senior Power BI Developer  
PL-300 Certified Data Analyst  

This project forms part of a professional analytics portfolio demonstrating real-world B


