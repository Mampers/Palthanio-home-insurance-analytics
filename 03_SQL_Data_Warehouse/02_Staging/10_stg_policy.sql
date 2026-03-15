-- Create stg.policy

DROP TABLE IF EXISTS stg.policy;
GO

CREATE TABLE stg.policy (
    PolicyID                    varchar(30)  NULL,
    CustomerID                  varchar(30)  NULL,
    AddressID                   varchar(30)  NULL,
    BrokerID                    varchar(30)  NULL,
    ProductType                 varchar(50)  NULL,

    InceptionDate               varchar(20)  NULL,  -- UK format DD/MM/YYYY
    ExpiryDate                  varchar(20)  NULL,  -- UK format DD/MM/YYYY
    PolicyStatus                varchar(30)  NULL,
    PaymentPlan                 varchar(30)  NULL,
    CreatedDate                 varchar(20)  NULL,  -- UK format DD/MM/YYYY

    PolicyTermDays              varchar(20)  NULL,
    PolicyTermMonths            varchar(20)  NULL,

    IsActiveFlag                varchar(10)  NULL,
    IsExpiredFlag               varchar(10)  NULL,

    DaysSinceInception          varchar(20)  NULL,
    EarnedRatio                 varchar(20)  NULL,
    UnearnedRatio               varchar(20)  NULL,

    PreviousPolicyExpiry        varchar(20)  NULL,  -- UK format DD/MM/YYYY or blank
    RenewalFlag                 varchar(10)  NULL,

    DistributionChannel         varchar(30)  NULL,
    PolicyTermBand              varchar(30)  NULL,

    PolicyAgeDays               varchar(20)  NULL,
    MonthsToExpiry              varchar(20)  NULL,
    DueForRenewalFlag           varchar(10)  NULL,

    IsInceptionDateValid        varchar(10)  NULL,
    IsExpiryDateValid           varchar(10)  NULL,
    IsCreatedDateValid          varchar(10)  NULL,

    PolicyDataCompletenessScore varchar(20)  NULL,

    InceptionYearMonth          varchar(20)  NULL,  -- e.g. 2025-08
    ExpiryYearMonth             varchar(20)  NULL
);
GO

-- Bulk insert stg.policy

TRUNCATE TABLE stg.policy;

BULK INSERT stg.policy
FROM 'C:\Users\Paul Mampilly\Documents\ChatGPT Datasets\Home Insurance\CSV Datasets\Calibrated Raw Data\Enchanced\policy_enterprise_ready.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0D0A',
    CODEPAGE        = '65001',
    TABLOCK
);


-- Validation Checks

SELECT COUNT(*) AS RC
FROM stg.policy;

SELECT TOP (20) *
FROM stg.policy;

SELECT PolicyID, COUNT(*) AS Cnt
FROM stg.policy
GROUP BY PolicyID
HAVING COUNT(*) > 1;


SELECT TOP (50)
    IsActiveFlag, IsExpiredFlag, RenewalFlag, DueForRenewalFlag,
    IsInceptionDateValid, IsExpiryDateValid, IsCreatedDateValid
FROM stg.policy
WHERE (IsActiveFlag NOT IN ('0','1') AND LTRIM(RTRIM(ISNULL(IsActiveFlag,''))) <> '')
   OR (IsExpiredFlag NOT IN ('0','1') AND LTRIM(RTRIM(ISNULL(IsExpiredFlag,''))) <> '')
   OR (RenewalFlag NOT IN ('0','1') AND LTRIM(RTRIM(ISNULL(RenewalFlag,''))) <> '')
   OR (DueForRenewalFlag NOT IN ('0','1') AND LTRIM(RTRIM(ISNULL(DueForRenewalFlag,''))) <> '')
   OR (IsInceptionDateValid NOT IN ('0','1') AND LTRIM(RTRIM(ISNULL(IsInceptionDateValid,''))) <> '')
   OR (IsExpiryDateValid NOT IN ('0','1') AND LTRIM(RTRIM(ISNULL(IsExpiryDateValid,''))) <> '')
   OR (IsCreatedDateValid NOT IN ('0','1') AND LTRIM(RTRIM(ISNULL(IsCreatedDateValid,''))) <> '');


   SELECT TOP (50)
    PolicyTermDays, PolicyTermMonths,
    DaysSinceInception, EarnedRatio, UnearnedRatio,
    PolicyAgeDays, MonthsToExpiry,
    PolicyDataCompletenessScore
FROM stg.policy
WHERE PolicyTermDays LIKE '%[^0-9-]%'
   OR PolicyTermMonths LIKE '%[^0-9.-]%'
   OR DaysSinceInception LIKE '%[^0-9-]%'
   OR EarnedRatio LIKE '%[^0-9.-]%'
   OR UnearnedRatio LIKE '%[^0-9.-]%'
   OR PolicyAgeDays LIKE '%[^0-9-]%'
   OR MonthsToExpiry LIKE '%[^0-9.-]%'
   OR PolicyDataCompletenessScore LIKE '%[^0-9]%';



   -- InceptionDate
SELECT TOP (50) InceptionDate
FROM stg.policy
WHERE LTRIM(RTRIM(ISNULL(InceptionDate,''))) <> ''
  AND TRY_CONVERT(date, InceptionDate, 103) IS NULL;

-- ExpiryDate
SELECT TOP (50) ExpiryDate
FROM stg.policy
WHERE LTRIM(RTRIM(ISNULL(ExpiryDate,''))) <> ''
  AND TRY_CONVERT(date, ExpiryDate, 103) IS NULL;

-- CreatedDate
SELECT TOP (50) CreatedDate
FROM stg.policy
WHERE LTRIM(RTRIM(ISNULL(CreatedDate,''))) <> ''
  AND TRY_CONVERT(date, CreatedDate, 103) IS NULL;

-- PreviousPolicyExpiry (if populated)
SELECT TOP (50) PreviousPolicyExpiry
FROM stg.policy
WHERE LTRIM(RTRIM(ISNULL(PreviousPolicyExpiry,''))) <> ''
  AND TRY_CONVERT(date, PreviousPolicyExpiry, 103) IS NULL;


  SELECT TOP (50) PolicyID, InceptionDate, ExpiryDate
FROM stg.policy
WHERE TRY_CONVERT(date, InceptionDate, 103) IS NOT NULL
  AND TRY_CONVERT(date, ExpiryDate, 103) IS NOT NULL
  AND TRY_CONVERT(date, ExpiryDate, 103) <= TRY_CONVERT(date, InceptionDate, 103);
