/*=========================================================
  BRONZE LOAD: Coverage
  Source: stg.coverage
  Target: bronze.coverage_raw
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
DROP TABLE IF EXISTS bronze.coverage_raw;
GO

SELECT TOP (0) *
INTO bronze.coverage_raw
FROM stg.coverage;
GO

-----------------------------------------------------------
-- 2) Add Bronze metadata columns
-----------------------------------------------------------
ALTER TABLE bronze.coverage_raw
ADD
    BronzeLoadDts datetime2(0) NOT NULL
        CONSTRAINT DF_bronze_coverage_raw_BronzeLoadDts DEFAULT SYSUTCDATETIME(),
    SourceFile varchar(260) NULL;
GO

-----------------------------------------------------------
-- 3) Load data from stg into bronze (explicit column list)
-----------------------------------------------------------
INSERT INTO bronze.coverage_raw
(
    PolicyID,
    CoverageType,
    CoverageLimit,
    Excess,
    IsIncluded,
    ExcessBand,
    IsIncludedFlag,
    CoverageTier,
    HighExposureFlag
)
SELECT
    PolicyID,
    CoverageType,
    CoverageLimit,
    Excess,
    IsIncluded,
    ExcessBand,
    IsIncludedFlag,
    CoverageTier,
    HighExposureFlag
FROM stg.coverage;
GO

-----------------------------------------------------------
-- 4) Optional: stamp the filename for lineage
-----------------------------------------------------------
UPDATE bronze.coverage_raw
SET SourceFile = 'coverage_enterprise_ready.csv'
WHERE SourceFile IS NULL;
GO

-----------------------------------------------------------
-- 5) Validation checks
-----------------------------------------------------------

-- 5A) Record counts
SELECT COUNT(*) AS RecordCount
FROM stg.coverage;

SELECT COUNT(*) AS RecordCount
FROM bronze.coverage_raw;
GO

-- 5B) Sample
SELECT TOP (20) *
FROM bronze.coverage_raw
ORDER BY BronzeLoadDts DESC;
GO

-- 5C) Grain check: one row per PolicyID + CoverageType
SELECT PolicyID, CoverageType, COUNT(*) AS Cnt
FROM bronze.coverage_raw
GROUP BY PolicyID, CoverageType
HAVING COUNT(*) > 1;
GO

-- 5D) Null/blank key checks
SELECT
    SUM(CASE WHEN PolicyID IS NULL OR LTRIM(RTRIM(PolicyID)) = '' THEN 1 ELSE 0 END) AS NullOrBlank_PolicyID,
    SUM(CASE WHEN CoverageType IS NULL OR LTRIM(RTRIM(CoverageType)) = '' THEN 1 ELSE 0 END) AS NullOrBlank_CoverageType
FROM bronze.coverage_raw;
GO

-- 5E) Numeric smoke test (limits/excess)
SELECT TOP (50)
    CoverageLimit,
    Excess
FROM bronze.coverage_raw
WHERE (LTRIM(RTRIM(ISNULL(CoverageLimit,''))) <> '' AND CoverageLimit LIKE '%[^0-9.]%')
   OR (LTRIM(RTRIM(ISNULL(Excess,''))) <> '' AND Excess LIKE '%[^0-9.]%');
GO

-- 5F) IsIncluded values should be Y/N (ignore blanks)
SELECT TOP (50) IsIncluded
FROM bronze.coverage_raw
WHERE LTRIM(RTRIM(ISNULL(IsIncluded,''))) <> ''
  AND UPPER(LTRIM(RTRIM(IsIncluded))) NOT IN ('Y','N');
GO

-- 5G) Flag checks (0/1)
SELECT TOP (50)
    IsIncludedFlag,
    HighExposureFlag
FROM bronze.coverage_raw
WHERE
    (LTRIM(RTRIM(ISNULL(IsIncludedFlag,''))) <> '' AND IsIncludedFlag NOT IN ('0','1'))
 OR (LTRIM(RTRIM(ISNULL(HighExposureFlag,''))) <> '' AND HighExposureFlag NOT IN ('0','1'));
GO

-- 5H) Consistency check: IsIncluded aligns with IsIncludedFlag
SELECT TOP (50)
    PolicyID,
    CoverageType,
    IsIncluded,
    IsIncludedFlag
FROM bronze.coverage_raw
WHERE
    (UPPER(LTRIM(RTRIM(ISNULL(IsIncluded,'')))) = 'Y' AND IsIncludedFlag <> '1')
 OR (UPPER(LTRIM(RTRIM(ISNULL(IsIncluded,'')))) = 'N' AND IsIncludedFlag <> '0');
GO
