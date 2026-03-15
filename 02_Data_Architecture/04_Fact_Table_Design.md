# Fact Table Design

## Overview

Fact tables capture measurable business events and financial transactions.

They form the foundation for KPI calculations and business reporting.

---

## Design Principles

Fact tables follow several modelling principles:

- each fact table represents a specific business process
- foreign keys link facts to dimension tables
- measures represent numeric metrics
- fact tables remain narrow and efficient

---

## Premium Transactions Fact

### fact_premium_transactions

Represents written premium activity.

Measures include:

- Premium Amount
- Policy Premium

Used for:

- revenue analysis
- premium growth tracking
- broker contribution analysis

---

## Claims Payments Fact

### fact_claim_payments

Captures claim settlement payments.

Measures include:

- Payment Amount

Used for:

- claims cost analysis
- claims trend analysis

---

## Claim Reserves Fact

### fact_claim_reserves

Stores outstanding expected claim liabilities.

Measures include:

- Reserve Amount

Used for:

- incurred claims calculations
- financial exposure analysis

---

## Operating Expense Fact

### fact_operating_expense

Captures business operating costs.

Measures include:

- Expense Amount

Used for:

- expense ratio calculation
- combined ratio analysis

---

## Analytical Value

Together these fact tables enable calculation of key insurance KPIs such as:

- Loss Ratio
- Expense Ratio
- Combined Ratio
- Underwriting Profit
