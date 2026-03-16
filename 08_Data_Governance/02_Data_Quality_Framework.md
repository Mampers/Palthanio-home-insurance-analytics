# Data Quality Framework

## Overview

Data quality is critical to ensuring that analytical insights are accurate and reliable.  
The Data Quality Framework outlines the validation rules and controls applied throughout the data pipeline.

These rules ensure that the data used in the Palthanio Home Insurance Analytics project maintains **accuracy, completeness, and consistency**.

---

# Data Quality Dimensions

The framework focuses on several key data quality dimensions.

| Dimension | Description |
|------|-------------|
| Accuracy | Data values correctly represent real-world information |
| Completeness | Required fields are populated |
| Consistency | Data remains uniform across tables |
| Validity | Data follows correct formats and value ranges |
| Uniqueness | Duplicate records are prevented |

---

# Data Validation Rules

## Primary Key Validation

All dimension tables must contain **unique primary keys**.

Example:

- PolicyID must be unique in `dim_policy`
- ClaimID must be unique in `fact_claims`

---

## Mandatory Fields

Certain fields must always contain values.

Examples include:

| Field | Reason |
|------|--------|
| PolicyID | Required to link policies and claims |
| ClaimAmount | Required for financial calculations |
| ClaimDate | Required for time-based analysis |

---

## Numeric Validation

Financial values must meet numeric constraints.

Examples:

- claim amounts must be greater than zero
- rebuild costs must be positive values
- premium amounts must be valid currency values

---

## Date Validation

Dates must fall within realistic ranges.

Examples:

- claim dates cannot occur before policy start dates
- policy start dates must occur before policy end dates

---

## Duplicate Record Checks

Duplicate records are removed during the transformation process.

Checks include:

- duplicate claims
- duplicate policies
- duplicate broker records

---

# Data Cleaning Processes

The Silver layer includes transformations designed to improve data quality.

These processes include:

- removing duplicate records
- correcting data types
- replacing missing values where appropriate
- standardising categorical fields

---

# Monitoring Data Quality

Regular monitoring ensures that data quality rules continue to be enforced.

Monitoring includes:

- validating record counts
- checking null values
- confirming relationship integrity between tables

---

# Benefits of Data Quality Controls

Strong data quality practices provide several benefits:

| Benefit | Description |
|------|-------------|
| Reliable analytics | Accurate dashboards and reports |
| Reduced errors | Fewer inconsistencies in datasets |
| Stakeholder trust | Confidence in analytical outputs |
| Scalable data pipelines | Easier expansion of data systems |

---

# Conclusion

The Data Quality Framework ensures that the analytics pipeline produces **clean, reliable, and trustworthy datasets** that support accurate business insights and decision-making.
