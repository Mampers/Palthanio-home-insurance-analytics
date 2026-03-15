USE PalthanioHomeInsuranceDW;
GO
SET NOCOUNT ON;
GO

/*==============================================================================
  PalthanioHomeInsuranceDW
  GOLD LAYER – DIMENSION TABLE
  Table: gold.dim_policy_risk

  Purpose
  -------
  Creates the Gold Policy Risk dimension from the trusted Silver policy risk
  table.

  The Gold layer is the curated analytics layer of the warehouse. In this case,
  the Policy Risk entity is promoted directly from silver.policy_risk, preserving
  the cleansed and validated structure already established in Silver.

  Design Approach
  ---------------
  - Copies the exact structure and data from silver.policy_risk
  - Avoids assuming or inventing column names
  - Adds a Gold load timestamp for Gold-layer lineage
  - Keeps the script simple, reliable, and aligned to the current warehouse
    design

  Source
  ------
      silver.policy_risk

  Target
  ------
      gold.dim_policy_risk

  Grain
  -----
      One row per policy risk record from silver.policy_risk

  Notes
  -----
  - This uses SELECT INTO because Silver already contains the trusted structure
    required for analytics.
  - If silver.policy_risk already contains an identity or technical key, it
    will be preserved in Gold.
  - GoldLoadDts is added to indicate when the record entered the Gold layer.

==============================================================================*/

-------------------------------------------------------------------------------
-- 1. Ensure the Gold schema exists
-------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
BEGIN
    EXEC ('CREATE SCHEMA gold;');
END
GO

-------------------------------------------------------------------------------
-- 2. Drop the existing Gold table if rebuilding
-------------------------------------------------------------------------------
IF OBJECT_ID('gold.dim_policy_risk','U') IS NOT NULL
BEGIN
    DROP TABLE gold.dim_policy_risk;
END
GO

-------------------------------------------------------------------------------
-- 3. Create and load gold.dim_policy_risk from silver.policy_risk
--
--    SELECT INTO creates the target table and loads the data in one step,
--    preserving the exact Silver-layer structure.
-------------------------------------------------------------------------------
SELECT *
INTO gold.dim_policy_risk
FROM silver.policy_risk;
GO

-------------------------------------------------------------------------------
-- 4. Add Gold load timestamp for lineage into the Gold layer
-------------------------------------------------------------------------------
ALTER TABLE gold.dim_policy_risk
ADD GoldLoadDts DATETIME2(0) NOT NULL
    CONSTRAINT DF_gold_dim_policy_risk_GoldLoadDts DEFAULT SYSUTCDATETIME();
GO

-------------------------------------------------------------------------------
-- 5. Validation checks
-------------------------------------------------------------------------------

-- Compare row counts between Silver and Gold
SELECT COUNT(*) AS SilverPolicyRiskRows
FROM silver.policy_risk;
GO

SELECT COUNT(*) AS GoldPolicyRiskRows
FROM gold.dim_policy_risk;
GO

-- Sample output for review
SELECT TOP (50) *
FROM gold.dim_policy_risk;
GO
