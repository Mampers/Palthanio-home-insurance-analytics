/*==============================================================================
  DATABASE:      PalthanioHomeInsuranceDW
  LAYER:         GOLD
  OBJECT:        gold.fact_claim_reserves
  SOURCE:        silver.claim_reserves

  AUTHOR:        Paul Mampilly (Portfolio Project)
  CREATED:       2026-03-04

  PURPOSE
  -------
  Create Gold fact table for claim reserves.
  Bullet-proof approach:
    - Do NOT guess columns
    - Clone schema from Silver
    - Add Gold metadata + indexes
    - Add PK only if an obvious Reserve ID column exists

  GRAIN (Typical / Recommended)
  -----------------------------
  Snapshot Fact: 1 row per ClaimID + SnapshotDate (or per ReserveID snapshot)
  because reserves are re-estimated over time.

==============================================================================*/

USE PalthanioHomeInsuranceDW;
GO
SET NOCOUNT ON;
GO

/*==============================================================================
  0) PRE-FLIGHT CHECKS
==============================================================================*/
IF OBJECT_ID('silver.claim_reserves','U') IS NULL
BEGIN
    THROW 67001, 'Source table silver.claim_reserves does not exist. Run Silver first.', 1;
END;

DECLARE @SilverRowCount int;
SELECT @SilverRowCount = COUNT(*) FROM silver.claim_reserves;

IF @SilverRowCount = 0
BEGIN
    THROW 67002, 'Source table silver.claim_reserves exists but contains 0 rows.', 1;
END;

PRINT CONCAT('Pre-flight OK. silver.claim_reserves rows = ', @SilverRowCount);
GO

/*==============================================================================
  1) ENSURE GOLD SCHEMA EXISTS
==============================================================================*/
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('CREATE SCHEMA gold;');
GO

/*==============================================================================
  2) DROP + RECREATE (REPEATABLE DEV MODE)
==============================================================================*/
IF OBJECT_ID('gold.fact_claim_reserves','U') IS NOT NULL
    DROP TABLE gold.fact_claim_reserves;
GO

/*==============================================================================
  3) CREATE GOLD TABLE BY CLONING SILVER (NO COLUMN GUESSING)
==============================================================================*/
SELECT *
INTO gold.fact_claim_reserves
FROM silver.claim_reserves;
GO

/*==============================================================================
  4) ADD GOLD METADATA
==============================================================================*/
ALTER TABLE gold.fact_claim_reserves
ADD GoldLoadDts datetime2(0) NOT NULL
    CONSTRAINT DF_gold_fact_claim_reserves_GoldLoadDts DEFAULT SYSUTCDATETIME();
GO

/*==============================================================================
  5) OPTIONAL: ADD PRIMARY KEY IF A CLEAR RESERVE KEY EXISTS
==============================================================================*/
IF COL_LENGTH('gold.fact_claim_reserves','ReserveID') IS NOT NULL
BEGIN
    EXEC('ALTER TABLE gold.fact_claim_reserves ALTER COLUMN ReserveID varchar(50) NOT NULL;');
    EXEC('ALTER TABLE gold.fact_claim_reserves ADD CONSTRAINT PK_gold_fact_claim_reserves PRIMARY KEY (ReserveID);');
    PRINT 'PK created on ReserveID.';
END
ELSE IF COL_LENGTH('gold.fact_claim_reserves','ClaimReserveID') IS NOT NULL
BEGIN
    EXEC('ALTER TABLE gold.fact_claim_reserves ALTER COLUMN ClaimReserveID varchar(50) NOT NULL;');
    EXEC('ALTER TABLE gold.fact_claim_reserves ADD CONSTRAINT PK_gold_fact_claim_reserves PRIMARY KEY (ClaimReserveID);');
    PRINT 'PK created on ClaimReserveID.';
END
ELSE
BEGIN
    PRINT 'No obvious Reserve ID column found. PK not created (by design).';
    PRINT 'If you want a surrogate ReserveKey, tell me the natural key column name and I will add it cleanly.';
END
GO

/*==============================================================================
  6) INDEXES FOR STAR-SCHEMA JOINS (ONLY IF COLUMNS EXIST)
==============================================================================*/
IF COL_LENGTH('gold.fact_claim_reserves','ClaimID') IS NOT NULL
BEGIN
    CREATE INDEX IX_gold_fact_claim_reserves_ClaimID
    ON gold.fact_claim_reserves(ClaimID);
    PRINT 'Index created on ClaimID.';
END

IF COL_LENGTH('gold.fact_claim_reserves','SnapshotDate') IS NOT NULL
BEGIN
    CREATE INDEX IX_gold_fact_claim_reserves_SnapshotDate
    ON gold.fact_claim_reserves(SnapshotDate);
    PRINT 'Index created on SnapshotDate.';
END
ELSE IF COL_LENGTH('gold.fact_claim_reserves','ReserveDate') IS NOT NULL
BEGIN
    CREATE INDEX IX_gold_fact_claim_reserves_ReserveDate
    ON gold.fact_claim_reserves(ReserveDate);
    PRINT 'Index created on ReserveDate.';
END
GO

/*==============================================================================
  7) VALIDATION
==============================================================================*/
SELECT COUNT(*) AS SilverRows FROM silver.claim_reserves;
SELECT COUNT(*) AS GoldRows   FROM gold.fact_claim_reserves;

SELECT TOP (50) *
FROM gold.fact_claim_reserves
ORDER BY GoldLoadDts DESC;
GO


SELECT TOP 50 *
FROM silver.claim_reserves

SELECT TOP 50 *
FROM gold.fact_claim_reserves
