/*==============================================================================
  DATABASE:      PalthanioHomeInsuranceDW
  LAYER:         GOLD
  OBJECT:        gold.fact_claim_payments
  SOURCE:        silver.claim_payments

  AUTHOR:        Paul Mampilly (Portfolio Project)
  CREATED:       2026-03-04

  PURPOSE
  -------
  Create Gold fact table for claim payments (transactional fact).
  Bullet-proof approach:
    - Do NOT guess columns
    - Clone schema from Silver
    - Add Gold metadata + indexes
    - Add PK only if an obvious Payment ID column exists

  GRAIN
  -----
  One row per payment transaction (as provided by Silver).

==============================================================================*/

USE PalthanioHomeInsuranceDW;
GO
SET NOCOUNT ON;
GO

/*==============================================================================
  0) PRE-FLIGHT CHECKS
==============================================================================*/
IF OBJECT_ID('silver.claim_payments','U') IS NULL
BEGIN
    THROW 66001, 'Source table silver.claim_payments does not exist. Run Silver first.', 1;
END;

DECLARE @SilverRowCount int;
SELECT @SilverRowCount = COUNT(*) FROM silver.claim_payments;

IF @SilverRowCount = 0
BEGIN
    THROW 66002, 'Source table silver.claim_payments exists but contains 0 rows.', 1;
END;

PRINT CONCAT('Pre-flight OK. silver.claim_payments rows = ', @SilverRowCount);
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
IF OBJECT_ID('gold.fact_claim_payments','U') IS NOT NULL
    DROP TABLE gold.fact_claim_payments;
GO

/*==============================================================================
  3) CREATE GOLD TABLE BY CLONING SILVER (NO COLUMN GUESSING)
==============================================================================*/
SELECT *
INTO gold.fact_claim_payments
FROM silver.claim_payments;
GO

/*==============================================================================
  4) ADD GOLD METADATA
==============================================================================*/
ALTER TABLE gold.fact_claim_payments
ADD GoldLoadDts datetime2(0) NOT NULL
    CONSTRAINT DF_gold_fact_claim_payments_GoldLoadDts DEFAULT SYSUTCDATETIME();
GO

/*==============================================================================
  5) OPTIONAL: ADD PRIMARY KEY IF A CLEAR PAYMENT KEY EXISTS
     (Only apply if the column exists in your Silver schema)
==============================================================================*/

-- Try common payment key column names (add/adjust if your Silver uses a different one)
IF COL_LENGTH('gold.fact_claim_payments','PaymentID') IS NOT NULL
BEGIN
    EXEC('ALTER TABLE gold.fact_claim_payments ALTER COLUMN PaymentID varchar(50) NOT NULL;');
    EXEC('ALTER TABLE gold.fact_claim_payments ADD CONSTRAINT PK_gold_fact_claim_payments PRIMARY KEY (PaymentID);');
    PRINT 'PK created on PaymentID.';
END
ELSE IF COL_LENGTH('gold.fact_claim_payments','ClaimPaymentID') IS NOT NULL
BEGIN
    EXEC('ALTER TABLE gold.fact_claim_payments ALTER COLUMN ClaimPaymentID varchar(50) NOT NULL;');
    EXEC('ALTER TABLE gold.fact_claim_payments ADD CONSTRAINT PK_gold_fact_claim_payments PRIMARY KEY (ClaimPaymentID);');
    PRINT 'PK created on ClaimPaymentID.';
END
ELSE IF COL_LENGTH('gold.fact_claim_payments','PaymentTransactionID') IS NOT NULL
BEGIN
    EXEC('ALTER TABLE gold.fact_claim_payments ALTER COLUMN PaymentTransactionID varchar(50) NOT NULL;');
    EXEC('ALTER TABLE gold.fact_claim_payments ADD CONSTRAINT PK_gold_fact_claim_payments PRIMARY KEY (PaymentTransactionID);');
    PRINT 'PK created on PaymentTransactionID.';
END
ELSE
BEGIN
    PRINT 'No obvious Payment ID column found. PK not created (by design).';
    PRINT 'If you want a surrogate PaymentKey, tell me the natural key column name and I will add it cleanly.';
END
GO

/*==============================================================================
  6) INDEXES FOR STAR-SCHEMA JOINS (ONLY IF COLUMNS EXIST)
==============================================================================*/

-- Claim join index
IF COL_LENGTH('gold.fact_claim_payments','ClaimID') IS NOT NULL
BEGIN
    CREATE INDEX IX_gold_fact_claim_payments_ClaimID
    ON gold.fact_claim_payments(ClaimID);
    PRINT 'Index created on ClaimID.';
END

-- Payment date index (common names)
IF COL_LENGTH('gold.fact_claim_payments','PaymentDate') IS NOT NULL
BEGIN
    CREATE INDEX IX_gold_fact_claim_payments_PaymentDate
    ON gold.fact_claim_payments(PaymentDate);
    PRINT 'Index created on PaymentDate.';
END
ELSE IF COL_LENGTH('gold.fact_claim_payments','TransactionDate') IS NOT NULL
BEGIN
    CREATE INDEX IX_gold_fact_claim_payments_TransactionDate
    ON gold.fact_claim_payments(TransactionDate);
    PRINT 'Index created on TransactionDate.';
END
GO

/*==============================================================================
  7) VALIDATION
==============================================================================*/
SELECT COUNT(*) AS SilverRows FROM silver.claim_payments;
SELECT COUNT(*) AS GoldRows   FROM gold.fact_claim_payments;

SELECT TOP (50) *
FROM gold.fact_claim_payments
ORDER BY GoldLoadDts DESC;
GO
