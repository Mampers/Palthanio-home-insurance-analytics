/*=========================================================
  BRONZE LOAD: Claim Payments
  Source: stg.claim_payments
  Target: bronze.claim_payments_raw
=========================================================*/

-----------------------------------------------------------
-- 0) Ensure bronze schema exists
-----------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
BEGIN
    EXEC('CREATE SCHEMA bronze');
END
GO

-----------------------------------------------------------
-- 1) Drop & recreate bronze table (clone stg schema)
-----------------------------------------------------------
DROP TABLE IF EXISTS bronze.claim_payments_raw;
GO

SELECT TOP (0) *
INTO bronze.claim_payments_raw
FROM stg.claim_payments;
GO

-----------------------------------------------------------
-- 2) Add Bronze metadata columns
-----------------------------------------------------------
ALTER TABLE bronze.claim_payments_raw
ADD
    BronzeLoadDts datetime2(0) NOT NULL
        CONSTRAINT DF_bronze_claim_payments_raw_BronzeLoadDts DEFAULT SYSUTCDATETIME(),
    SourceFile varchar(260) NULL;
GO

-----------------------------------------------------------
-- 3) Load data from stg into bronze (explicit column list)
-----------------------------------------------------------
INSERT INTO bronze.claim_payments_raw
(
    PaymentID,
    ClaimID,
    PaymentDate,
    PaymentAmount,
    PaymentMethod,
    PaymentStatus,
    ClaimType,
    ClaimSeverityBand,
    OutstandingReserve,
    IncurredAmount,
    LargeLossFlag
)
SELECT
    PaymentID,
    ClaimID,
    PaymentDate,
    PaymentAmount,
    PaymentMethod,
    PaymentStatus,
    ClaimType,
    ClaimSeverityBand,
    OutstandingReserve,
    IncurredAmount,
    LargeLossFlag
FROM stg.claim_payments;
GO

-----------------------------------------------------------
-- 4) Optional: stamp the filename for lineage
-----------------------------------------------------------
UPDATE bronze.claim_payments_raw
SET SourceFile = 'claim_payments_realistic_interview_ready.csv'
WHERE SourceFile IS NULL;
GO

-----------------------------------------------------------
-- 5) Validation checks
-----------------------------------------------------------

-- 5A) Record counts (separate queries; alias not RowCount)

SELECT COUNT(*) AS RecordCount
FROM stg.claim_payments;

SELECT COUNT(*) AS RecordCount
FROM bronze.claim_payments_raw;
GO

-- 5B) Sample
SELECT TOP (20) *
FROM bronze.claim_payments_raw
ORDER BY BronzeLoadDts DESC;
GO

-- 5C) Duplicate key check (PaymentID should be unique)
SELECT PaymentID, COUNT(*) AS Cnt
FROM bronze.claim_payments_raw
GROUP BY PaymentID
HAVING COUNT(*) > 1;
GO

-- 5D) Null/blank key checks
SELECT
    SUM(CASE WHEN PaymentID IS NULL OR LTRIM(RTRIM(PaymentID)) = '' THEN 1 ELSE 0 END) AS NullOrBlank_PaymentID,
    SUM(CASE WHEN ClaimID   IS NULL OR LTRIM(RTRIM(ClaimID))   = '' THEN 1 ELSE 0 END) AS NullOrBlank_ClaimID
FROM bronze.claim_payments_raw;
GO

-- 5E) UK date convertibility check (ignores blanks)
SELECT TOP (50) PaymentDate
FROM bronze.claim_payments_raw
WHERE LTRIM(RTRIM(ISNULL(PaymentDate,''))) <> ''
  AND TRY_CONVERT(date, PaymentDate, 103) IS NULL;
GO

-- 5F) Numeric smoke tests (allow decimals; allow negatives for reserve/incurred if you ever use them)
SELECT TOP (50)
    PaymentAmount,
    OutstandingReserve,
    IncurredAmount
FROM bronze.claim_payments_raw
WHERE PaymentAmount      LIKE '%[^0-9.-]%'
   OR OutstandingReserve LIKE '%[^0-9.-]%'
   OR IncurredAmount     LIKE '%[^0-9.-]%';
GO

-- 5G) Flag checks (LargeLossFlag should be 0/1)
SELECT TOP (50) LargeLossFlag
FROM bronze.claim_payments_raw
WHERE LTRIM(RTRIM(ISNULL(LargeLossFlag,''))) <> ''
  AND LargeLossFlag NOT IN ('0','1');
GO
