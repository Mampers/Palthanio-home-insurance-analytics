# Power BI Dashboard

## Overview

The **Power BI Dashboard** layer represents the final analytical presentation of the Palthanio Home Insurance Analytics project.  
It delivers business insights through interactive dashboards built on top of the **Gold Layer semantic model**.

These dashboards are designed to simulate how an insurance company would monitor:

- underwriting profitability
- claims behaviour
- portfolio risk exposure
- broker performance
- regional risk distribution

The dashboards transform the curated data warehouse model into **actionable insights for business stakeholders such as underwriting managers, finance teams, and risk analysts**.

---

# Dashboard Architecture

The dashboards are built using a **star-schema semantic model** created in the SQL data warehouse.

```
SQL Server Data Warehouse (Gold Layer)
        ↓
Power BI Semantic Model
        ↓
Power BI Dashboards
        ↓
Business Insights
```

The Power BI dashboards connect directly to the **Gold tables**, ensuring:

- clean dimensional modelling
- consistent KPI calculations
- scalable reporting performance

---

# Dashboard Pages

The Power BI report contains several analytical pages that focus on different aspects of insurance portfolio performance.

---

# 1. Executive Summary

Provides a **high-level overview of portfolio performance**.

### Key Metrics

- Total Net Premium
- Total Claims Paid
- Loss Ratio
- Combined Ratio
- Number of Policies
- Claims Frequency

### Purpose

This page is designed for **executive stakeholders** to quickly assess whether the portfolio is profitable and identify potential risk areas.

---

# 2. Claims Analysis

Focuses on analysing **claims patterns and financial impact**.

### Key Insights

- Claims frequency by claim type
- Average claim cost by claim type
- Total claims paid by distribution channel
- Claims distribution across property types

### Purpose

Helps claims teams understand:

- what types of claims occur most frequently
- which claim categories drive the largest costs

---

# 3. Policy Portfolio Analysis

Provides insights into the **composition of the insurance portfolio**.

### Key Insights

- Active policies by property type
- Average rebuild cost by property type
- Premium distribution across channels
- Portfolio exposure by property value

### Purpose

Allows underwriters to understand the **risk profile of the policy portfolio**.

---

# 4. Underwriting Performance

Evaluates **underwriting profitability across different dimensions**.

### Key Insights

- Loss ratio by property type
- Claims frequency by distribution channel
- Underwriting performance by channel
- Average claim cost by property category

### Purpose

Helps insurers identify:

- which segments of the portfolio generate underwriting losses
- where pricing or underwriting policies may need adjustment

---

# 5. Profitability & Risk Segmentation

Analyses **portfolio profitability and risk concentration**.

### Key Insights

- Combined ratio
- High-risk property share
- Claims per 1000 policies
- Broker loss ratio
- Average claim cost by property type

### Purpose

Supports **strategic underwriting decisions and risk management**.

---

# 6. Regional Underwriting Performance

Examines **geographic risk exposure**.

### Key Insights

- Loss ratio by region
- Claims frequency by region
- Average claim cost by region
- Premium vs loss ratio by region

### Purpose

Helps insurers determine whether certain regions require:

- pricing adjustments
- underwriting restrictions
- catastrophe risk modelling

---

# 7. Claims Severity & Risk Drivers

Explores **drivers behind high-value insurance claims**.

### Key Insights

- claims distribution by claim cost band
- total claims paid by claim type
- average claims cost by severity
- claims frequency by property age

### Purpose

Identifies:

- catastrophic claims exposure
- structural drivers of high claim costs
- property characteristics that increase risk

---

# Dashboard Screenshots

The following screenshots illustrate each analytical page included in the Power BI report.

```
Dashboard_Screenshots/
│
├── Executive_Summary.png
├── Claims_Analysis.png
├── Policy_Portfolio_Analysis.png
├── Underwriting_Performance.png
├── Profitability_Risk_Segmentation.png
├── Regional_Underwriting_Performance.png
└── Claims_Severity_Risk_Drivers.png
```

These visuals provide a quick preview of the analytical capabilities of the dashboard.

---

# Power BI File

The full Power BI report file can be found in the following directory:

```
PowerBI_File/
└── Palthanio_Home_Insurance.pbix
```

This file contains:

- the semantic model
- all DAX measures
- dashboard pages
- interactive visuals

---

# Key Business Questions Answered

The dashboard helps answer several critical insurance business questions:

- Is the portfolio profitable?
- Which property types generate the highest claims costs?
- Which brokers produce profitable policies?
- Which regions have the highest underwriting losses?
- What factors drive high-value insurance claims?

---

# Technologies Used

- **SQL Server** – Data warehouse
- **Dimensional modelling (Kimball Method)**
- **Power BI Desktop**
- **DAX (Data Analysis Expressions)**
- **Star schema data modelling**

---

# Conclusion

The Power BI dashboards provide a **comprehensive analytical view of insurance portfolio performance**.

By combining financial metrics, claims behaviour, and risk segmentation, the dashboards enable insurers to:

- identify unprofitable segments
- understand claims drivers
- monitor underwriting performance
- optimise pricing strategies

These insights help insurance companies make **data-driven underwriting and risk management decisions**.
