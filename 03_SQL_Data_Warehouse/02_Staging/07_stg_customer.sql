-- Create stg.customer

DROP TABLE IF EXISTS stg.customer;
GO

CREATE TABLE stg.customer (
    CustomerID               varchar(30)  NULL,
    FirstName                varchar(100) NULL,
    LastName                 varchar(100) NULL,
    DateOfBirth              varchar(20)  NULL,   -- likely DD/MM/YYYY or YYYY-MM-DD depending on file
    Gender                   varchar(20)  NULL,
    Email                    varchar(200) NULL,
    Phone                    varchar(50)  NULL,
    MarketingOptIn           varchar(10)  NULL,   -- Y/N
    CreatedDate              varchar(20)  NULL,
    Age                      varchar(10)  NULL,
    AgeBand                  varchar(50)  NULL,
    CustomerTenureMonths     varchar(10)  NULL,
    CustomerTenureYears      varchar(10)  NULL,
    TenureBand               varchar(50)  NULL,

    HasEmail                 varchar(10)  NULL,   -- 0/1
    IsValidEmail             varchar(10)  NULL,   -- 0/1
    EmailDomain              varchar(100) NULL,
    HasPhone                 varchar(10)  NULL,   -- 0/1
    IsValidPhone             varchar(10)  NULL,   -- 0/1

    MarketingOptInFlag       varchar(10)  NULL,   -- 0/1
    ContactableFlag          varchar(10)  NULL,   -- 0/1
    PreferredContactMethod   varchar(20)  NULL,   -- Email/SMS/None

    VulnerableCustomerFlag   varchar(10)  NULL,   -- 0/1
    RecordCompletenessScore  varchar(10)  NULL,   -- 0–100
    LifeStageSegment         varchar(50)  NULL
);
GO


-- Bulk Insert stg.customer

TRUNCATE TABLE stg.customer;

BULK INSERT stg.customer
FROM 'C:\Users\Paul Mampilly\Documents\ChatGPT Datasets\Home Insurance\CSV Datasets\Calibrated Raw Data\Enchanced\customer_enterprise_ready.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0D0A',   -- Windows CRLF
    CODEPAGE        = '65001',    -- UTF-8
    TABLOCK
);



-- Validation Checks


SELECT COUNT(*) AS RC
FROM stg.customer;

SELECT TOP (20) *
FROM stg.customer;

SELECT CustomerID, COUNT(*) AS Cnt
FROM stg.customer
GROUP BY CustomerID
HAVING COUNT(*) > 1;


SELECT TOP (50)
    HasEmail, IsValidEmail, HasPhone, IsValidPhone,
    MarketingOptInFlag, ContactableFlag,
    VulnerableCustomerFlag
FROM stg.customer
WHERE HasEmail NOT IN ('0','1')
   OR IsValidEmail NOT IN ('0','1')
   OR HasPhone NOT IN ('0','1')
   OR IsValidPhone NOT IN ('0','1')
   OR MarketingOptInFlag NOT IN ('0','1')
   OR ContactableFlag NOT IN ('0','1')
   OR VulnerableCustomerFlag NOT IN ('0','1');


   SELECT TOP (50) MarketingOptIn
FROM stg.customer
WHERE MarketingOptIn IS NOT NULL
  AND LTRIM(RTRIM(MarketingOptIn)) <> ''
  AND UPPER(LTRIM(RTRIM(MarketingOptIn))) NOT IN ('Y','N');


  SELECT TOP (50)
    Age, CustomerTenureMonths, CustomerTenureYears, RecordCompletenessScore
FROM stg.customer
WHERE Age LIKE '%[^0-9]%'
   OR CustomerTenureMonths LIKE '%[^0-9]%'
   OR CustomerTenureYears LIKE '%[^0-9.]%'
   OR RecordCompletenessScore LIKE '%[^0-9]%';



   SELECT TOP (50) DateOfBirth
FROM stg.customer
WHERE DateOfBirth IS NOT NULL
  AND LTRIM(RTRIM(DateOfBirth)) <> ''
  AND TRY_CONVERT(date, DateOfBirth, 103) IS NULL
  AND TRY_CONVERT(date, DateOfBirth, 23) IS NULL;  -- ISO yyyy-mm-dd


  SELECT TOP (50) CreatedDate
FROM stg.customer
WHERE CreatedDate IS NOT NULL
  AND LTRIM(RTRIM(CreatedDate)) <> ''
  AND TRY_CONVERT(date, CreatedDate, 103) IS NULL
  AND TRY_CONVERT(date, CreatedDate, 23) IS NULL;


  SELECT TOP (50) CustomerID, HasEmail, Email
FROM stg.customer
WHERE HasEmail = '0'
  AND Email IS NOT NULL
  AND LTRIM(RTRIM(Email)) <> '';


  SELECT TOP (50)
    CustomerID, ContactableFlag, IsValidEmail, IsValidPhone, MarketingOptInFlag
FROM stg.customer
WHERE ContactableFlag = '1'
  AND MarketingOptInFlag <> '1'
  AND (IsValidEmail <> '1' AND IsValidPhone <> '1');
