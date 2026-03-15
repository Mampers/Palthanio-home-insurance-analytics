-- stg.coverage

DROP TABLE IF EXISTS stg.coverage;
GO

CREATE TABLE stg.coverage (
    PolicyID          varchar(30)  NULL,
    CoverageType      varchar(50)  NULL,
    CoverageLimit     varchar(30)  NULL,
    Excess            varchar(30)  NULL,
    IsIncluded        varchar(10)  NULL,  -- Y/N
    ExcessBand        varchar(30)  NULL,
    IsIncludedFlag    varchar(10)  NULL,  -- 0/1
    CoverageTier      varchar(30)  NULL,
    HighExposureFlag  varchar(10)  NULL   -- 0/1
);
GO

-- Bulk Insert stg.coverage


TRUNCATE TABLE stg.coverage;

BULK INSERT stg.coverage
FROM 'C:\Users\Paul Mampilly\Documents\ChatGPT Datasets\Home Insurance\CSV Datasets\Calibrated Raw Data\Enchanced\coverage_enterprise_ready.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0D0A',   -- Windows CRLF
    CODEPAGE        = '65001',    -- UTF-8
    TABLOCK
);


-- Validation Checks

SELECT COUNT(*) AS NoofRows
FROM stg.coverage;

SELECT TOP (20) *
FROM stg.coverage;


SELECT TOP (50)
    CoverageLimit,
    Excess
FROM stg.coverage
WHERE CoverageLimit LIKE '%[^0-9.]%'
   OR Excess        LIKE '%[^0-9.]%';



   SELECT TOP (50)
    IsIncludedFlag,
    HighExposureFlag
FROM stg.coverage
WHERE IsIncludedFlag   NOT IN ('0','1')
   OR HighExposureFlag NOT IN ('0','1');


   SELECT TOP (50) IsIncluded
FROM stg.coverage
WHERE IsIncluded IS NOT NULL
  AND LTRIM(RTRIM(IsIncluded)) <> ''
  AND UPPER(LTRIM(RTRIM(IsIncluded))) NOT IN ('Y','N');



  SELECT TOP (50)
    PolicyID, CoverageType, IsIncluded, IsIncludedFlag
FROM stg.coverage
WHERE (UPPER(LTRIM(RTRIM(IsIncluded))) = 'Y' AND IsIncludedFlag <> '1')
   OR (UPPER(LTRIM(RTRIM(IsIncluded))) = 'N' AND IsIncludedFlag <> '0');



   SELECT TOP (50)
    PolicyID, CoverageType, CoverageLimit, HighExposureFlag
FROM stg.coverage
WHERE TRY_CONVERT(decimal(18,2), CoverageLimit) IS NOT NULL
  AND (
        (TRY_CONVERT(decimal(18,2), CoverageLimit) >= 300000 AND HighExposureFlag <> '1')
     OR (TRY_CONVERT(decimal(18,2), CoverageLimit) <  300000 AND HighExposureFlag <> '0')
      );
