# Data Model

## Overview

The Palthanio Home Insurance Analytics project uses a dimensional star schema designed to support efficient analytical reporting in Power BI.

The model separates descriptive attributes into dimension tables and transactional business events into fact tables.

---

## Star Schema Design

The model follows dimensional modelling best practices where:

- Dimension tables describe business entities
- Fact tables capture measurable events
- Relationships enable flexible analytical queries

This structure improves query performance and simplifies Power BI report design.

---

## Dimension Tables

### dim_date

Provides a calendar structure used for time-based analysis.

Typical attributes:

- Date
- Month
- Quarter
- Year
- Day of Week

---

### dim_policy

Represents insurance policies and property attributes.

Attributes include:

- PolicyID
- Property Type
- Risk Band
- Rebuild Cost
- BrokerID

---

### dim_broker

Contains distribution partner information.

Attributes include:

- BrokerID
- Broker Name
- Channel
- Region

---

### dim_address

Stores geographic information for insured properties.

Attributes include:

- City
- Region
- Postcode
- Country

---

### dim_claim_type

Describes the category of insurance claim.

Examples include:

- Fire
- Flood
- Theft
- Accidental Damage

---

### dim_expense_category

Categorises operational costs.

Examples include:

- Administration
- Claims Handling
- Sales & Marketing
- IT & Infrastructure

---

## Fact Tables

### fact_premium_transactions

Captures written premium activity.

Key fields:

- PolicyID
- DateKey
- Premium Amount

---

### fact_claim_payments

Captures payments made against claims.

Key fields:

- ClaimID
- Payment Date
- Payment Amount

---

### fact_claim_reserves

Stores outstanding liabilities for claims.

Key fields:

- ClaimID
- Reserve Amount
- Reserve Date

---

### fact_operating_expense

Captures monthly operating expenses.

Key fields:

- Expense Category
- DateKey
- Expense Amount

---

## Analytical Benefits

This dimensional model enables efficient analysis such as:

- premium trends
- claims cost analysis
- broker performance
- underwriting profitability
- portfolio risk segmentation
