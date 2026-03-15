/*=========================================================
  BRONZE LOAD: Claims
  Source: stg.claims
  Target: bronze.claims_raw
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
DROP TABLE IF EXISTS bronze.claims_raw;
GO

SELECT TOP (0) *
INTO bronze.claims_raw
FROM stg.claims;
GO

-----------------------------------------------------------
-- 2) Add Bronze metadata columns
-----------------------------------------------------------
ALTER TABLE bronze.claims_raw
ADD
    BronzeLoadDts datetime2(0) NOT NULL
        CONSTRAINT DF_bronze_claims_raw_BronzeLoadDts DEFAULT SYSUTCDATETIME(),
    SourceFile varchar(260) NULL;
GO

-----------------------------------------------------------
-- 3) Load data from stg into bronze (explicit column list)
-----------------------------------------------------------
INSERT INTO bronze.claims_raw
(
    ClaimID,
    PolicyID,
    LossDate,
    ReportedDate,
    ClaimType,
    Severity,
    ClaimStatus,
    ReportingDelayDays,
    ClosedDate,
    ClaimDurationDays,
    ReopenedFlag,
    FraudFlag,
    CatEventFlag,
    ClaimComplexity
)
SELECT
    ClaimID,
    PolicyID,
    LossDate,
    ReportedDate,
    ClaimType,
    Severity,
    ClaimStatus,
    ReportingDelayDays,
    ClosedDate,
    ClaimDurationDays,
    ReopenedFlag,
    FraudFlag,
    CatEventFlag,
    ClaimComplexity
FROM stg.claims;
GO

-----------------------------------------------------------
-- 4) Optional: stamp the filename for lineage
-----------------------------------------------------------
UPDATE bronze.claims_raw
SET SourceFile = 'claims_enterprise_ready.csv'
WHERE SourceFile IS NULL;
GO

-----------------------------------------------------------
-- 5) Validation checks
-----------------------------------------------------------

-- 5A) Record counts (separate queries)
SELECT COUNT(*) AS RecordCount
FROM stg.claims;

SELECT COUNT(*) AS RecordCount
FROM bronze.claims_raw;
GO

-- 5B) Sample
SELECT TOP (20) *
FROM bronze.claims_raw
ORDER BY BronzeLoadDts DESC;
GO

-- 5C) Duplicate ClaimID check (ideally 0 rows)
SELECT ClaimID, COUNT(*) AS Cnt
FROM bronze.claims_raw
GROUP BY ClaimID
HAVING COUNT(*) > 1;
GO

-- 5D) Null/blank key checks
SELECT
    SUM(CASE WHEN ClaimID  IS NULL OR LTRIM(RTRIM(ClaimID))  = '' THEN 1 ELSE 0 END) AS NullOrBlank_ClaimID,
    SUM(CASE WHEN PolicyID IS NULL OR LTRIM(RTRIM(PolicyID)) = '' THEN 1 ELSE 0 END) AS NullOrBlank_PolicyID
FROM bronze.claims_raw;
GO

-- 5E) UK date convertibility checks (ignore blanks)
SELECT TOP (50) LossDate
FROM bronze.claims_raw
WHERE LTRIM(RTRIM(ISNULL(LossDate,''))) <> ''
  AND TRY_CONVERT(date, LossDate, 103) IS NULL;
GO

SELECT TOP (50) ReportedDate
FROM bronze.claims_raw
WHERE LTRIM(RTRIM(ISNULL(ReportedDate,''))) <> ''
  AND TRY_CONVERT(date, ReportedDate, 103) IS NULL;
GO

SELECT TOP (50) ClosedDate
FROM bronze.claims_raw
WHERE LTRIM(RTRIM(ISNULL(ClosedDate,''))) <> ''
  AND TRY_CONVERT(date, ClosedDate, 103) IS NULL;
GO

-- 5F) Numeric smoke tests
SELECT TOP (50)
    ReportingDelayDays,
    ClaimDurationDays
FROM bronze.claims_raw
WHERE (LTRIM(RTRIM(ISNULL(ReportingDelayDays,''))) <> '' AND ReportingDelayDays LIKE '%[^0-9]%' )
   OR (LTRIM(RTRIM(ISNULL(ClaimDurationDays,'')))  <> '' AND ClaimDurationDays  LIKE '%[^0-9]%' );
GO

-- 5G) Flag checks (0/1)
SELECT TOP (50)
    ReopenedFlag,
    FraudFlag,
    CatEventFlag
FROM bronze.claims_raw
WHERE
    (LTRIM(RTRIM(ISNULL(ReopenedFlag,''))) <> '' AND ReopenedFlag NOT IN ('0','1'))
 OR (LTRIM(RTRIM(ISNULL(FraudFlag,'')))    <> '' AND FraudFlag    NOT IN ('0','1'))
 OR (LTRIM(RTRIM(ISNULL(CatEventFlag,''))) <> '' AND CatEventFlag NOT IN ('0','1'));
GO

-- 5H) Interview-grade sanity: ReportedDate should be >= LossDate (when both valid)
SELECT TOP (50)
    ClaimID,
    LossDate,
    ReportedDate
FROM bronze.claims_raw
WHERE TRY_CONVERT(date, LossDate, 103) IS NOT NULL
  AND TRY_CONVERT(date, ReportedDate, 103) IS NOT NULL
  AND TRY_CONVERT(date, ReportedDate, 103) < TRY_CONVERT(date, LossDate, 103);
GO
