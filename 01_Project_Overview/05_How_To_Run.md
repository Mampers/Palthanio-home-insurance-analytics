# How To Run

This document explains how to run the **Palthanio Home Insurance Analytics** project.

---

# Prerequisites

Required tools:

- SQL Server
- SQL Server Management Studio
- Power BI Desktop
- Git

---

# Step 1 — Clone Repository

Clone the project from GitHub.

---

# Step 2 — Load Bronze Layer

Run Bronze scripts to load CSV data.

Purpose:

- raw data ingestion
- source preservation

---

# Step 3 — Run Silver Transformations

Execute Silver scripts to:

- clean data
- standardise fields
- deduplicate records
- apply business rules

---

# Step 4 — Build Gold Layer

Run Gold scripts to create:

- dimension tables
- fact tables
- surrogate keys

---

# Step 5 — Validate Data

Check:

- row counts
- premium totals
- claim totals
- expense totals
- dimension relationships

---

# Step 6 — Open Power BI

Open the Power BI report and refresh the model.

Confirm:

- relationships are valid
- measures calculate correctly
- visuals render properly

---

# Suggested Report Pages

- Executive Summary
- Portfolio Trends
- Broker Performance
- Claims Analysis
- Policy Segmentation
- Financial Ratios
