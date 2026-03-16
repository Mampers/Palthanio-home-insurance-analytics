# Model Optimisation

## Overview

This section documents the optimisation decisions made within the **Power BI semantic model** for the **Palthanio Home Insurance Analytics** project.

The goal of model optimisation was to improve:

- report performance
- model usability
- relationship clarity
- DAX simplicity
- overall maintainability

The optimisation process focused on creating a reporting-friendly model from the Gold-layer SQL data warehouse while preserving analytical flexibility.

---

## Optimisation Objectives

The semantic model was refined to achieve the following:

- reduce unnecessary model complexity
- simplify relationships between fact and dimension tables
- minimise ambiguity in filter propagation
- improve report responsiveness
- support cleaner DAX calculations
- make the model easier to navigate for end users and developers

---

## Key Optimisation Techniques Applied

### 1. Star Schema Design

The model was structured around a **star schema** where possible, with:

- dimension tables providing descriptive attributes
- fact tables storing transactional and quantitative measures

This approach improves:

- query performance
- filter behaviour
- model readability
- DAX measure consistency

---

### 2. Use of Gold Layer Tables

The Power BI model was built primarily from the **Gold layer** of the SQL warehouse.

This ensured that:

- data had already been cleaned and standardised upstream
- business logic was centralised in SQL where appropriate
- the semantic model remained leaner and easier to maintain

This reduced the need for excessive transformation work inside Power BI.

---

### 3. Reporting Merge Tables

To support reporting efficiency and simplify the data model, selected **merged reporting tables** were created.

Examples include reporting tables that combined related entities such as:

- broker and policy information
- claims and claims payment information
- other reporting-friendly combinations used to reduce relationship complexity

These merged tables were introduced to:

- reduce the number of relationships required in the semantic model
- avoid overly complex joins during report building
- simplify report authoring
- improve usability for stakeholder-facing dashboards
- support cleaner visuals and easier KPI development

This was especially useful where the raw model structure introduced unnecessary complexity for reporting scenarios.

> In this project, merged tables were used as a **reporting optimisation technique**, not as a replacement for the dimensional model.

---

### 4. Relationship Simplification

The model was reviewed to reduce overly complex relationship paths and limit ambiguity.

Optimisation steps included:

- preferring clear one-to-many relationships
- reducing unnecessary many-to-many behaviour
- simplifying paths between dimensions and facts
- ensuring filters flowed in a predictable direction

Where the original structure created reporting friction, merged reporting tables were introduced to create a more practical reporting layer.

---

### 5. Measure Simplification

Optimisation also included designing measures in a way that reduced complexity where possible.

This involved:

- using clean fact sources for KPI calculations
- avoiding unnecessary repetition across measures
- centralising calculation logic into reusable DAX measures
- aligning measures to business definitions such as Loss Ratio, Claim Frequency, and Premium totals

A simpler model structure made DAX measures easier to write, test, and maintain.

---

### 6. Reduced Visual-Level Complexity

Model optimisation helped reduce the need for:

- excessive calculated columns in Power BI
- repeated manual joins in visuals
- unnecessarily complex report-page logic

This contributed to a cleaner report-building experience and improved dashboard maintainability.

---

## Why the Merged Tables Were Useful

In this project, merged tables were used selectively to improve the reporting experience.

They were beneficial because they:

- reduced the number of tables required for certain report pages
- made common reporting scenarios easier to build
- reduced issues caused by indirect relationship chains
- improved clarity when building stakeholder-facing dashboards
- supported faster visual development

This approach is especially useful in portfolio projects where the aim is to demonstrate both:

- strong dimensional modelling principles
- practical semantic-model optimisation for reporting

---

## Trade-Off Considerations

Although merged tables can improve report usability, they should be applied carefully.

Potential trade-offs include:

- duplication of certain attributes
- less flexibility than a pure dimensional design
- risk of bloating the model if overused

For this reason, merged tables in this project were used selectively and only where they improved reporting performance or simplified report development.

---

## Performance Benefits

The optimisation approach contributed to:

- a more intuitive semantic model
- easier report development
- reduced relationship complexity
- improved filtering behaviour
- more maintainable DAX logic

These decisions helped create a model that was both technically structured and practical for business reporting.

---

## Model Design Philosophy

The semantic model was designed with a balance between:

- **data modelling best practice**
- **real-world reporting usability**

While the Gold-layer warehouse provides the formal dimensional foundation, the semantic model also incorporates reporting-focused optimisations where needed to make Power BI development more efficient.

This reflects a practical BI design approach often used in real business environments.

---

## Related Assets

This optimisation layer supports:

- dashboard development
- KPI calculation
- stakeholder-friendly report design
- simplified report interactions

Related project sections include:

- `03_SQL_Data_Warehouse`
- `04_Semantic_Model/01_Data_Model`
- `04_Semantic_Model/02_DAX_Measures`
- `05_Dashboards`

---

## Summary

The Power BI semantic model was optimised to balance:

- performance
- simplicity
- maintainability
- business usability

This included the selective use of merged reporting tables to reduce complexity and improve report development, while still preserving the core dimensional modelling principles established in the SQL data warehouse.
