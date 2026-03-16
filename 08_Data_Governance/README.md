# Data Governance

## Overview

The **Data Governance** layer ensures that data used throughout the Palthanio Home Insurance Analytics project is **accurate, consistent, documented, and reliable**.  

In real-world analytics environments, strong governance practices are essential to maintain **data quality, trust, and transparency** across the organisation.

This section documents how the data used in the project is defined, managed, and validated to ensure it can support **reliable analytical insights and business decision-making**.

---

# Purpose of Data Governance

The objective of this section is to demonstrate best practices in managing data across the analytics lifecycle.

Key goals include:

- ensuring consistent data definitions
- documenting all datasets and fields
- maintaining transparency in data transformations
- tracking data lineage from source to dashboard
- implementing basic data quality rules

These practices help ensure that stakeholders can **trust the insights generated from the data warehouse and Power BI dashboards**.

---

# Governance Components

The following governance artefacts are included in this section.

| Document | Purpose |
|--------|--------|
| Data Dictionary | Defines all tables, columns, and business meanings |
| Data Lineage | Shows how data flows from source to dashboard |
| Data Quality Framework | Defines rules used to validate and monitor data quality |

---

# Data Dictionary

The **Data Dictionary** provides definitions for all tables and fields used in the data warehouse and semantic model.

It includes:

- table descriptions
- column definitions
- data types
- business meaning of each field

This documentation ensures that analysts, developers, and business stakeholders share a **common understanding of the data**.

Example:

| Table | Column | Description |
|-----|------|-------------|
| dim_policy | PolicyID | Unique identifier for each insurance policy |
| dim_policy | PropertyType | Type of insured property |
| fact_claims | ClaimAmount | Total amount paid for a claim |

---

# Data Lineage

**Data lineage** describes how data moves through the analytics pipeline.

For this project, data flows through several stages before being visualised in Power BI.

```
CSV Source Data
      ↓
Staging Layer
      ↓
Bronze Layer
Raw data ingestion
      ↓
Silver Layer
Data cleaning and transformations
      ↓
Gold Layer
Dimensional model (Fact & Dimension tables)
      ↓
Power BI Semantic Model
      ↓
Dashboards and Insights
```

Documenting lineage ensures transparency around:

- where data originates
- how it is transformed
- how it is consumed by reports.

---

# Data Quality Framework

Data quality checks are applied throughout the transformation pipeline to ensure the reliability of analytical results.

Key quality rules include:

| Quality Rule | Purpose |
|-------------|---------|
| No duplicate primary keys | Prevent duplicate records |
| Non-null critical fields | Ensure required data is populated |
| Valid date ranges | Prevent incorrect policy dates |
| Numeric validation | Ensure financial values are valid |

These checks help maintain **clean, trustworthy datasets** for reporting and analysis.

---

# Governance Benefits

Implementing data governance provides several important benefits:

| Benefit | Description |
|-------|-------------|
| Data Transparency | Clear documentation of data definitions |
| Trustworthy Reporting | Stakeholders trust analytical outputs |
| Consistent Data Usage | All users reference the same definitions |
| Scalable Analytics | Governance supports future data expansion |

---

# Role of Governance in Analytics

In modern data teams, governance plays a crucial role in ensuring that analytics solutions are sustainable and reliable.

By combining:

- strong documentation
- defined data lineage
- quality validation rules

organisations can build analytics platforms that support **accurate insights and confident decision-making**.

---

# Conclusion

The **Data Governance** framework within this project demonstrates how documentation, lineage tracking, and data quality rules support reliable analytics.

Although this project uses simulated insurance data, the governance principles applied here mirror the practices used in **enterprise data environments** to maintain trust in analytical systems.
