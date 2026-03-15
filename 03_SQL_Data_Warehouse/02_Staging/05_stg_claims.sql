-- Create stg.claims


DROP TABLE IF EXISTS stg.claims;
GO

CREATE TABLE stg.claims (
    ClaimID             varchar(30)  NULL,
    PolicyID            varchar(30)  NULL,
    LossDate            varchar(20)  NULL,  -- likely UK format DD/MM/YYYY
    ReportedDate        varchar(20)  NULL,  -- likely UK format DD/MM/YYYY
    ClaimType           varchar(50)  NULL,
    Severity            varchar(20)  NULL,
    ClaimStatus         varchar(20)  NULL,
    ReportingDelayDays  varchar(20)  NULL,
    ClosedDate          varchar(20)  NULL,  -- may be blank for Open claims
    ClaimDurationDays   varchar(20)  NULL,
    ReopenedFlag        varchar(10)  NULL,  -- 0/1
    FraudFlag           varchar(10)  NULL,  -- 0/1
    CatEventFlag        varchar(10)  NULL,  -- 0/1
    ClaimComplexity     varchar(30)  NULL
);
GO

-- Bulk Insert stg.claims

TRUNCATE TABLE stg.claims;

BULK INSERT stg.claims
FROM 'C:\Users\Paul Mampilly\Documents\ChatGPT Datasets\Home Insurance\CSV Datasets\Calibrated Raw Data\Enchanced\claims_enterprise_ready.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0D0A',   -- Windows CRLF
    CODEPAGE        = '65001',    -- UTF-8
    TABLOCK
);


-- Validation Checks


SELECT COUNT(*) AS NoOfRows
FROM stg.claims;

SELECT TOP (20) *
FROM stg.claims;


SELECT TOP (50)
    ReportingDelayDays,
    ClaimDurationDays
FROM stg.claims
WHERE ReportingDelayDays LIKE '%[^0-9]%'
   OR ClaimDurationDays  LIKE '%[^0-9]%';


   SELECT TOP (50)
    ReopenedFlag,
    FraudFlag,
    CatEventFlag
FROM stg.claims
WHERE ReopenedFlag NOT IN ('0','1')
   OR FraudFlag    NOT IN ('0','1')
   OR CatEventFlag NOT IN ('0','1');



   -- LossDate
SELECT TOP (50) LossDate
FROM stg.claims
WHERE LossDate IS NOT NULL
  AND LTRIM(RTRIM(LossDate)) <> ''
  AND TRY_CONVERT(date, LossDate, 103) IS NULL;

-- ReportedDate
SELECT TOP (50) ReportedDate
FROM stg.claims
WHERE ReportedDate IS NOT NULL
  AND LTRIM(RTRIM(ReportedDate)) <> ''
  AND TRY_CONVERT(date, ReportedDate, 103) IS NULL;

-- ClosedDate (often blank for open claims)
SELECT TOP (50) ClosedDate
FROM stg.claims
WHERE ClosedDate IS NOT NULL
  AND LTRIM(RTRIM(ClosedDate)) <> ''



  SELECT TOP (50)
    ClaimID, LossDate, ReportedDate
FROM stg.claims
WHERE TRY_CONVERT(date, LossDate, 103) IS NOT NULL
  AND TRY_CONVERT(date, ReportedDate, 103) IS NOT NULL
  AND TRY_CONVERT(date, ReportedDate, 103) < TRY_CONVERT(date, LossDate, 103)
  AND TRY_CONVERT(date, ClosedDate, 103) IS NULL;


  SELECT TOP (50) ClaimID, ClaimStatus, ClosedDate
FROM stg.claims
WHERE ClaimStatus = 'Closed'
  AND (ClosedDate IS NULL OR LTRIM(RTRIM(ClosedDate)) = '');
