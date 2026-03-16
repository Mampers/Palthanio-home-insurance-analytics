# Project Roadmap

## Overview

This roadmap outlines potential future enhancements for the **Palthanio Home Insurance Analytics** project.  
While the current solution demonstrates a complete end-to-end analytics pipeline — from raw data ingestion to business insights — there are several opportunities to extend the platform and increase its analytical value.

These enhancements focus on expanding the project in three key areas:

- **Advanced analytics**
- **Data engineering improvements**
- **Business intelligence capabilities**

The roadmap demonstrates how the project could evolve into a **production-ready insurance analytics platform**.

---

# Current Project Scope

The current version of the project includes:

- SQL Server data warehouse with **Bronze → Silver → Gold layers**
- Dimensional modelling using **Kimball methodology**
- Power BI semantic model
- Multiple analytical dashboards
- Business recommendations derived from insights
- Data governance documentation

These components simulate how an insurance organisation can analyse:

- underwriting performance
- claims behaviour
- portfolio profitability
- risk segmentation

---

# Phase 1 — Data Engineering Enhancements

## Incremental Data Loading

Currently the project loads full datasets during processing.

Future improvements could include **incremental data loading** to support:

- improved performance
- reduced processing time
- scalable data pipelines

Example improvements:

- timestamp-based incremental loads
- change data capture (CDC)
- partitioned fact tables

---

## Automated Data Pipelines

Data pipelines could be automated using orchestration tools such as:

- Azure Data Factory
- Microsoft Fabric Data Pipelines
- Apache Airflow

Automation would enable:

- scheduled refresh processes
- error monitoring
- pipeline retry mechanisms

---

# Phase 2 — Advanced Analytics

## Predictive Claims Modelling

Machine learning models could be introduced to predict:

- probability of claims
- expected claim severity
- policy risk scores

Potential models include:

- logistic regression
- gradient boosting models
- random forest models

Predictive analytics could assist underwriters in **identifying high-risk policies before they are issued**.

---

## Broker Risk Scoring

Broker performance analytics could be enhanced by introducing a **broker risk scoring model**.

Possible scoring factors:

- broker loss ratio
- claims frequency
- policy volume
- high-risk policy concentration

This would allow insurers to:

- identify profitable broker partnerships
- manage broker risk exposure

---

# Phase 3 — External Data Integration

## Weather and Environmental Data

Weather and environmental risk data could significantly enhance risk modelling.

Potential data sources:

- weather APIs
- flood risk databases
- environmental hazard datasets

This would enable improved modelling of claims related to:

- storms
- floods
- environmental damage

---

## Geographic Risk Modelling

Geospatial analytics could be introduced to evaluate regional risk exposure.

Potential enhancements include:

- postcode risk scoring
- property location clustering
- regional catastrophe risk modelling

These insights would support **regional underwriting strategy**.

---

# Phase 4 — Real-Time Analytics

## Real-Time Claims Monitoring

A real-time analytics layer could be implemented to monitor claims as they occur.

Possible technologies:

- streaming data ingestion
- event-based analytics
- real-time Power BI dashboards

Real-time monitoring would help insurers identify **emerging risk trends quickly**.

---

# Phase 5 — Enhanced Business Intelligence

## Self-Service Analytics

Future improvements could allow business users to explore the data independently using:

- Power BI semantic models
- governed datasets
- reusable KPI measures

This would empower underwriting and claims teams to perform their own analysis.

---

## Advanced Financial Modelling

Additional financial metrics could be incorporated, such as:

- actuarial reserve modelling
- catastrophe loss projections
- long-term profitability forecasts

These models would help insurers better evaluate financial exposure.

---

# Long-Term Vision

The long-term goal for the Palthanio Home Insurance Analytics platform is to evolve into a **fully integrated insurance analytics environment** capable of supporting:

- operational analytics
- predictive risk modelling
- real-time monitoring
- strategic decision-making

By progressively implementing the roadmap enhancements, the platform could simulate a **modern enterprise insurance data ecosystem**.

---

# Conclusion

This roadmap demonstrates how the project can evolve beyond a portfolio project into a more advanced analytics platform.

By integrating automation, predictive analytics, external datasets, and real-time monitoring, the Palthanio Home Insurance Analytics solution could support increasingly sophisticated data-driven decision-making for insurance organisations.
