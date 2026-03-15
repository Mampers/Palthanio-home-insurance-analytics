# Source Data Description

## Overview

The Palthanio Home Insurance Analytics project uses a synthetic dataset designed to simulate how a home insurance company manages policies, premiums, claims, and operational expenses.

The dataset represents core insurance business processes and allows for realistic financial and risk analysis using a dimensional data model.

---

## Data Sources

The project uses structured CSV datasets which represent operational data typically extracted from insurance policy administration systems.

The key source entities include:

| Dataset | Description |
|------|------|
| Policies | Core policy information including property attributes and risk segmentation |
| Brokers | Distribution channel and broker partner details |
| Addresses | Property location information |
| Premium Transactions | Written premium activity |
| Claims | Insurance claims recorded against policies |
| Claim Payments | Payments made against claims |
| Claim Reserves | Outstanding expected claim liabilities |
| Operating Expenses | Business operating costs by category |

---

## Policy Data

The policy dataset contains core policy attributes including:

- PolicyID
- BrokerID
- Property Type
- Risk Band
- Rebuild Cost
- Policy Start Date
- Policy End Date

This dataset forms the foundation of the portfolio analysis.

---

## Broker Data

The broker dataset describes the distribution partners responsible for selling insurance policies.

Attributes include:

- BrokerID
- Broker Name
- Distribution Channel
- Broker Region

This enables broker performance analysis and contribution measurement.

---

## Address Data

The address dataset captures property location attributes such as:

- Region
- Postcode
- City
- Geographic grouping

This allows claims and premium analysis by geography.

---

## Premium Transactions

Premium transactions capture written premium activity including:

- PolicyID
- Transaction Date
- Premium Amount
- Transaction Type

These records support premium trend analysis and policy revenue metrics.

---

## Claims Data

Claims represent insurance loss events recorded against policies.

Typical attributes include:

- ClaimID
- PolicyID
- Claim Type
- Claim Date
- Claim Status

This dataset supports claims frequency and severity analysis.

---

## Claim Payments

Claim payments represent financial settlement amounts paid for claims.

Attributes include:

- ClaimID
- Payment Date
- Payment Amount

This dataset supports claims cost analysis.

---

## Claim Reserves

Claim reserves represent the estimated future liability for claims not yet fully settled.

Attributes include:

- ClaimID
- Reserve Amount
- Reserve Date

This supports incurred claims calculations.

---

## Operating Expenses

Operating expenses capture the business costs associated with running the insurance operation.

Examples include:

- Administration Costs
- Claims Handling Costs
- Sales and Distribution Costs
- Technology Costs

These expenses are used to calculate the **Expense Ratio** and **Combined Ratio**.

---

## Data Purpose

The combined datasets allow the project to simulate a realistic insurance portfolio and support key analytics such as:

- premium growth
- claims trends
- broker performance
- underwriting profitability
- loss ratio analysis
