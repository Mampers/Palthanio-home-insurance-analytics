/*=========================================================
  BRONZE LOAD: Claim Reserves
  Source: stg.claim_reserves
  Target: bronze.claim_reserves_raw
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
DROP TABLE IF EXISTS bronze.claim_reserves_raw;
GO

SELECT TOP (0) *
INTO bronze.claim_reserves_raw
FROM stg.claim_reserves;
GO

-----------------------------------------------------------
-- 2) Add Bronze metadata columns
-----------------------------------------------------------
ALTER TABLE bronze.claim_reserves_raw
ADD
    BronzeLoadDts datetime2(0) NOT NULL
        CONSTRAINT DF_bronze_claim_reserves_raw_BronzeLoadDts DEFAULT SYSUTCDATETIME(),
    SourceFile varchar(260) NULL;
GO

-----------------------------------------------------------
-- 3) Load data from stg into bronze (explicit column list)
-----------------------------------------------------------
INSERT INTO bronze.claim_reserves_raw
(
    ReserveID,
    ClaimID,
    SnapshotDate,
    ReserveAmount,
    ReserveStatus,
    ReserveType,
    PreviousReserve,
    ReserveChange,
    ReserveMovementType,
    LargeReserveFlag,
    LatestSnapshotFlag,
    ReserveAgeMonths
)
SELECT
    ReserveID,
    ClaimID,
    SnapshotDate,
    ReserveAmount,
    ReserveStatus,
    ReserveType,
    PreviousReserve,
    ReserveChange,
    ReserveMovementType,
    LargeReserveFlag,
    LatestSnapshotFlag,
    ReserveAgeMonths
FROM stg.claim_reserves;
GO

-----------------------------------------------------------
-- 4) Optional: stamp the filename for lineage
-----------------------------------------------------------
UPDATE bronze.claim_reserves_raw
SET SourceFile = 'claim_reserves_enterprise_ready.csv'
WHERE SourceFile IS NULL;
GO

-----------------------------------------------------------
-- 5) Validation checks
-----------------------------------------------------------

-- 5A) Record counts (separate queries)
SELECT COUNT(*) AS RecordCount
FROM stg.claim_reserves;

SELECT COUNT(*) AS RecordCount
FROM bronze.claim_reserves_raw;
GO

-- 5B) Sample
SELECT TOP (20) *
FROM bronze.claim_reserves_raw
ORDER BY BronzeLoadDts DESC;
GO

-- 5C) Duplicate key check (ReserveID should be unique)
SELECT ReserveID, COUNT(*) AS Cnt
FROM bronze.claim_reserves_raw
GROUP BY ReserveID
HAVING COUNT(*) > 1;
GO

-- 5D) Null/blank key checks
SELECT
    SUM(CASE WHEN ReserveID IS NULL OR LTRIM(RTRIM(ReserveID)) = '' THEN 1 ELSE 0 END) AS NullOrBlank_ReserveID,
    SUM(CASE WHEN ClaimID   IS NULL OR LTRIM(RTRIM(ClaimID))   = '' THEN 1 ELSE 0 END) AS NullOrBlank_ClaimID
FROM bronze.claim_reserves_raw;
GO

-- 5E) UK date convertibility check (ignores blanks)
SELECT TOP (50) SnapshotDate
FROM bronze.claim_reserves_raw
WHERE LTRIM(RTRIM(ISNULL(SnapshotDate,''))) <> ''
  AND TRY_CONVERT(date, SnapshotDate, 103) IS NULL;
GO

-- 5F) Numeric smoke tests (allow decimals and negatives)
SELECT TOP (50)
    ReserveAmount,
    PreviousReserve,
    ReserveChange,
    ReserveAgeMonths
FROM bronze.claim_reserves_raw
WHERE ReserveAmount   LIKE '%[^0-9.-]%'
   OR PreviousReserve LIKE '%[^0-9.-]%'
   OR ReserveChange   LIKE '%[^0-9.-]%'
   OR ReserveAgeMonths LIKE '%[^0-9]%';
GO

-- 5G) Flag checks (0/1 only)
SELECT TOP (50)
    LargeReserveFlag,
    LatestSnapshotFlag
FROM bronze.claim_reserves_raw
WHERE LTRIM(RTRIM(ISNULL(LargeReserveFlag,''))) <> ''
  AND LargeReserveFlag NOT IN ('0','1')
   OR LTRIM(RTRIM(ISNULL(LatestSnapshotFlag,''))) <> ''
  AND LatestSnapshotFlag NOT IN ('0','1');
GO
