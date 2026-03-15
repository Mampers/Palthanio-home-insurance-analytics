# KPI Definitions

This document defines the core KPIs used in the **Palthanio Home Insurance Analytics** project.

---

# Core KPIs

## Total Written Premium

**Definition**

Total premium written during a period.

**Formula**

Written Premium = SUM(Premium Amount)

---

## Earned Premium

**Definition**

The portion of written premium recognised over time.

Used as the denominator for profitability metrics.

---

## Claims Paid

**Definition**

Total value of claims paid.

**Formula**

Claims Paid = SUM(Claim Payment Amount)

---

## Outstanding Reserves

**Definition**

Remaining liability expected for claims not yet fully paid.

---

## Incurred Claims

**Formula**

Incurred Claims = Claims Paid + Outstanding Reserves

---

## Loss Ratio

**Formula**

Loss Ratio = Incurred Claims / Earned Premium

**Interpretation**

- < 1.00 = profitable underwriting  
- > 1.00 = claims exceed premium

---

## Expense Ratio

**Formula**

Expense Ratio = Operating Expenses / Earned Premium

---

## Combined Ratio

**Formula**

Combined Ratio = Loss Ratio + Expense Ratio

**Interpretation**

- < 1.00 = underwriting profit  
- > 1.00 = underwriting loss

---

## Underwriting Profit

**Formula**

Underwriting Profit = Earned Premium − Incurred Claims − Expenses

---

## Number of Policies

Total active policies.

---

## Number of Claims

Total claims recorded.

---

## Claims per 1000 Policies

**Formula**

Claims per 1000 = (Claims ÷ Policies) × 1000

---

## Average Premium per Policy

**Formula**

Average Premium = Written Premium ÷ Policies

---

## Broker Contribution %

**Formula**

Broker Premium ÷ Total Premium

---

## High Risk Property Share

Policies classified as High or Very High Risk.

---

## Average Rebuild Cost

Average insured rebuild value of properties.
