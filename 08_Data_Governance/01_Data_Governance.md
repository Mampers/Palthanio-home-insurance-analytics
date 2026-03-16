# Data Dictionary

## Overview

The Data Dictionary documents the structure and meaning of the datasets used within the **Palthanio Home Insurance Analytics** project.

This documentation ensures that analysts, developers, and business stakeholders have a **clear understanding of each dataset and field used in the analytics pipeline**.

The project follows a **dimensional modelling approach (Kimball methodology)**, using fact and dimension tables to support analytical queries and reporting.

---

# Dimension Tables

## dim_policy

| Column | Description |
|------|-------------|
| PolicyID | Unique identifier for each insurance policy |
| PropertyType | Type of insured property (House, Flat, Bungalow, etc.) |
| PropertyAgeBand | Age category of the property |
| RebuildCost | Estimated cost to rebuild the property |
| DistributionChannel | Channel through which the policy was sold |
| BrokerID | Identifier for the broker selling the policy |

---

## dim_broker

| Column | Description |
|------|-------------|
| BrokerID | Unique identifier for the broker |
| BrokerName | Name of the broker |
| BrokerRegion | Geographic region where the broker operates |

---

## dim_address

| Column | Description |
|------|-------------|
| AddressID | Unique identifier for property address |
| City | City of the insured property |
| Region | Geographic region |
| PostcodeArea | Postal code area for location grouping |

---

## dim_claim_type

| Column | Description |
|------|-------------|
| ClaimTypeID | Unique identifier for claim category |
| ClaimType | Type of claim (Storm, Theft, Flood, etc.) |

---

## dim_claim_status

| Column | Description |
|------|-------------|
| ClaimStatusID | Identifier for claim status |
| ClaimStatus | Current claim status (Open, Closed, Pending) |

---

# Fact Tables

## fact_premium_transactions

| Column | Description |
|------|-------------|
| PolicyID | Linked insurance policy |
| PremiumAmount | Total premium paid |
| TransactionDate | Date of premium transaction |

---

## fact_claims

| Column | Description |
|------|-------------|
| ClaimID | Unique claim identifier |
| PolicyID | Policy associated with the claim |
| ClaimTypeID | Category of claim |
| ClaimAmount | Amount paid for the claim |
| ClaimDate | Date the claim occurred |

---

# Analytical Metrics

The dataset supports key insurance metrics such as:

| Metric | Definition |
|------|-------------|
| Loss Ratio | Total Claims Paid / Total Premium |
| Claims Frequency | Number of Claims / Number of Policies |
| Average Claim Cost | Total Claims Paid / Number of Claims |
| Combined Ratio | Loss Ratio + Expense Ratio |

---

# Conclusion

The Data Dictionary provides a structured reference for understanding the datasets used in the analytics solution.  
Clear documentation ensures consistency across reporting and supports reliable analytical insights.
