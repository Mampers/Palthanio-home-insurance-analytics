# Data Dictionary

## Overview

The data dictionary defines key fields used within the Palthanio Home Insurance Analytics data model.

It provides clear descriptions for analysts and stakeholders.

---

## Policy Fields

| Field | Description |
|------|-------------|
| PolicyID | Unique identifier for each insurance policy |
| PropertyType | Category of insured property |
| RiskBand | Risk classification of the property |
| RebuildCost | Estimated rebuild value of the property |

---

## Broker Fields

| Field | Description |
|------|-------------|
| BrokerID | Unique identifier for broker |
| BrokerName | Broker company name |
| Channel | Distribution channel |

---

## Claim Fields

| Field | Description |
|------|-------------|
| ClaimID | Unique identifier for insurance claim |
| ClaimType | Type of claim event |
| ClaimDate | Date the claim occurred |

---

## Financial Fields

| Field | Description |
|------|-------------|
| PremiumAmount | Premium paid for the policy |
| PaymentAmount | Amount paid to settle claim |
| ReserveAmount | Outstanding claim liability |
| ExpenseAmount | Operating business cost |
