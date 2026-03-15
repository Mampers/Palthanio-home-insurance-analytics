USE PalthanioHomeInsuranceDW;
GO
SET NOCOUNT ON;
GO

/*==============================================================================
  PalthanioHomeInsuranceDW
  GOLD LAYER – FACT TABLE
  Table: gold.fact_premium_transactions

  Purpose
  -------
  Creates the Gold Premium Transactions fact table from the trusted
  Silver premium transactions table.

  The Gold layer is the curated analytics layer of the warehouse.
  Premium transactions are modelled as a fact table because they represent
  measurable business events at transaction grain.

  Design Approach
  ---------------
  - Copies the exact structure and data from silver.premium_transactions
  - Avoids assuming or inventing column names
  - Adds a Gold load timestamp for Gold-layer lineage
  - Keeps the implementation simple and reliable

  Source
  ------
      silver.premium_transactions

  Target
  ------
      gold.fact_premium_transactions

  Grain
  -----
      One row per premium transaction record from silver.premium_transactions

  Notes
  -----
  - This script uses SELECT INTO because Silver already contains the trusted
    structure required for analytics.
  - If silver.premium_transactions already contains business keys, transaction
    identifiers, or technical lineage columns, they will be preserved in Gold.
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
-- 2. Drop the existing Gold fact table if rebuilding
-------------------------------------------------------------------------------
IF OBJECT_ID('gold.fact_premium_transactions','U') IS NOT NULL
BEGIN
    DROP TABLE gold.fact_premium_transactions;
END
GO

-------------------------------------------------------------------------------
-- 3. Create and load gold.fact_premium_transactions from Silver
--
--    SELECT INTO creates the target table and loads the data in one step,
--    preserving the exact Silver-layer structure.
-------------------------------------------------------------------------------
SELECT *
INTO gold.fact_premium_transactions
FROM silver.premium_transactions;
GO

-------------------------------------------------------------------------------
-- 4. Add Gold load timestamp for lineage into the Gold layer
-------------------------------------------------------------------------------
ALTER TABLE gold.fact_premium_transactions
ADD GoldLoadDts DATETIME2(0) NOT NULL
    CONSTRAINT DF_gold_fact_premium_transactions_GoldLoadDts
    DEFAULT SYSUTCDATETIME();
GO

-------------------------------------------------------------------------------
-- 5. Validation checks
-------------------------------------------------------------------------------

-- Compare row counts between Silver and Gold
SELECT COUNT(*) AS SilverPremiumTransactionRows
FROM silver.premium_transactions;
GO

SELECT COUNT(*) AS GoldPremiumTransactionRows
FROM gold.fact_premium_transactions;
GO

-- Sample output for review
SELECT TOP (50) *
FROM gold.fact_premium_transactions;
GO
