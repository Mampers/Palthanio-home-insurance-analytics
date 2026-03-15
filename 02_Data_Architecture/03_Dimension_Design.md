# Dimension Design

## Overview

Dimension tables store descriptive attributes that provide context for fact table metrics.

They enable slicing and filtering of business metrics across different analytical perspectives.

---

## Design Principles

The dimension tables follow several design principles:

- surrogate keys are used where appropriate
- attributes are descriptive and user-friendly
- dimensions support multiple fact tables
- dimension tables avoid transactional duplication

---

## Core Dimensions

### Date Dimension

Supports time-based reporting.

Common attributes include:

- Date
- Month
- Quarter
- Year
- Fiscal Period

---

### Policy Dimension

Represents the insured property and associated policy characteristics.

Attributes include:

- PolicyID
- Property Type
- Risk Band
- Rebuild Cost
- Policy Start Date
- Policy End Date

---

### Broker Dimension

Represents insurance distribution partners.

Attributes include:

- BrokerID
- Broker Name
- Channel
- Broker Region

---

### Address Dimension

Represents geographic attributes of the insured property.

Attributes include:

- Postcode
- City
- Region
- Country

---

### Claim Type Dimension

Classifies insurance claims.

Examples include:

- Theft
- Fire
- Flood
- Accidental Damage

---

### Expense Category Dimension

Groups operating expenses into business categories.

Examples include:

- Administration
- Claims Handling
- Marketing
- Technology

---

## Benefits

These dimensions enable users to analyse metrics by:

- time
- geography
- broker
- property characteristics
- risk categories
