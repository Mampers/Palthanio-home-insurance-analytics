USE PalthanioHomeInsuranceDW;
GO
SET NOCOUNT ON;
GO

/*==============================================================================
  PalthanioHomeInsuranceDW
  GOLD LAYER – DIMENSION TABLE
  Table: gold.dim_policy

  Purpose
  -------
  Creates the Gold Policy dimension from the trusted Silver policy table.

  The Gold layer is the business-facing analytics layer of the warehouse.
  In this case, the Policy dimension is promoted directly from silver.policy,
  preserving the cleansed structure already established in Silver.

  Design Approach
  ---------------
  - Source table structure is copied directly from silver.policy
  - All trusted Silver policy records are loaded into Gold
  - A Gold load timestamp is added for lineage into the Gold layer
  - This approach is intentionally simple and reliable, avoiding assumptions
    about column names that may differ from environment to environment

  Source
  ------
      silver.policy

  Target
  ------
      gold.dim_policy

  Grain
  -----
      One row per policy record from silver.policy

  Notes
  -----
  - This script uses SELECT INTO because silver.policy already reflects the
    cleansed and validated structure required for analytics.
  - If silver.policy already contains a surrogate or identity column, it will
    be preserved in Gold.
  - GoldLoadDts is added to show when the record entered the Gold layer.

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
-- 2. Drop the existing Gold dimension if rebuilding
-------------------------------------------------------------------------------
IF OBJECT_ID('gold.dim_policy','U') IS NOT NULL
BEGIN
    DROP TABLE gold.dim_policy;
END
GO

-------------------------------------------------------------------------------
-- 3. Create and load gold.dim_policy from silver.policy
--
--    SELECT INTO creates the table and loads the data in one step using the
--    exact structure already present in the Silver layer.
-------------------------------------------------------------------------------
SELECT *
INTO gold.dim_policy
FROM silver.policy;
GO

-------------------------------------------------------------------------------
-- 4. Add Gold load timestamp for Gold-layer lineage
-------------------------------------------------------------------------------
ALTER TABLE gold.dim_policy
ADD GoldLoadDts DATETIME2(0) NOT NULL
    CONSTRAINT DF_gold_dim_policy_GoldLoadDts DEFAULT SYSUTCDATETIME();
GO

-------------------------------------------------------------------------------
-- 5. Validation checks
-------------------------------------------------------------------------------

-- Row count comparison between Silver and Gold
SELECT COUNT(*) AS SilverPolicyRows
FROM silver.policy;
GO

SELECT COUNT(*) AS GoldPolicyRows
FROM gold.dim_policy;
GO

-- Sample output to inspect the loaded Gold dimension
SELECT TOP (50) *
FROM gold.dim_policy;
GO
