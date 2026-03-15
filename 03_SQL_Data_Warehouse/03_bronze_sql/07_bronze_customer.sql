/*=========================================================
  BRONZE LOAD: Customer
  Source: stg.customer
  Target: bronze.customer_raw
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
DROP TABLE IF EXISTS bronze.customer_raw;
GO

SELECT TOP (0) *
INTO bronze.customer_raw
FROM stg.customer;
GO

-----------------------------------------------------------
-- 2) Add Bronze metadata columns
-----------------------------------------------------------
ALTER TABLE bronze.customer_raw
ADD
    BronzeLoadDts datetime2(0) NOT NULL
        CONSTRAINT DF_bronze_customer_raw_BronzeLoadDts DEFAULT SYSUTCDATETIME(),
    SourceFile varchar(260) NULL;
GO

-----------------------------------------------------------
-- 3) Load data from stg into bronze (explicit column list)
-----------------------------------------------------------
INSERT INTO bronze.customer_raw
(
    CustomerID,
    FirstName,
    LastName,
    DateOfBirth,
    Gender,
    Email,
    Phone,
    MarketingOptIn,
    CreatedDate,
    Age,
    AgeBand,
    CustomerTenureMonths,
    CustomerTenureYears,
    TenureBand,
    HasEmail,
    IsValidEmail,
    EmailDomain,
    HasPhone,
    IsValidPhone,
    MarketingOptInFlag,
    ContactableFlag,
    PreferredContactMethod,
    VulnerableCustomerFlag,
    RecordCompletenessScore,
    LifeStageSegment
)
SELECT
    CustomerID,
    FirstName,
    LastName,
    DateOfBirth,
    Gender,
    Email,
    Phone,
    MarketingOptIn,
    CreatedDate,
    Age,
    AgeBand,
    CustomerTenureMonths,
    CustomerTenureYears,
    TenureBand,
    HasEmail,
    IsValidEmail,
    EmailDomain,
    HasPhone,
    IsValidPhone,
    MarketingOptInFlag,
    ContactableFlag,
    PreferredContactMethod,
    VulnerableCustomerFlag,
    RecordCompletenessScore,
    LifeStageSegment
FROM stg.customer;
GO

-----------------------------------------------------------
-- 4) Optional: stamp the filename for lineage
-----------------------------------------------------------
UPDATE bronze.customer_raw
SET SourceFile = 'customer_enterprise_ready.csv'
WHERE SourceFile IS NULL;
GO

-----------------------------------------------------------
-- 5) Validation checks
-----------------------------------------------------------

-- 5A) Record counts
SELECT COUNT(*) AS RecordCount
FROM stg.customer;

SELECT COUNT(*) AS RecordCount
FROM bronze.customer_raw;
GO

-- 5B) Sample
SELECT TOP (20) *
FROM bronze.customer_raw
ORDER BY BronzeLoadDts DESC;
GO

-- 5C) Duplicate CustomerID check (ideally 0 rows)
SELECT CustomerID, COUNT(*) AS Cnt
FROM bronze.customer_raw
GROUP BY CustomerID
HAVING COUNT(*) > 1;
GO

-- 5D) Null/blank key checks
SELECT
    SUM(CASE WHEN CustomerID IS NULL OR LTRIM(RTRIM(CustomerID)) = '' THEN 1 ELSE 0 END) AS NullOrBlank_CustomerID
FROM bronze.customer_raw;
GO

-- 5E) Date convertibility checks (supports UK + ISO)
SELECT TOP (50) DateOfBirth
FROM bronze.customer_raw
WHERE LTRIM(RTRIM(ISNULL(DateOfBirth,''))) <> ''
  AND TRY_CONVERT(date, DateOfBirth, 103) IS NULL
  AND TRY_CONVERT(date, DateOfBirth, 23)  IS NULL;
GO

SELECT TOP (50) CreatedDate
FROM bronze.customer_raw
WHERE LTRIM(RTRIM(ISNULL(CreatedDate,''))) <> ''
  AND TRY_CONVERT(date, CreatedDate, 103) IS NULL
  AND TRY_CONVERT(date, CreatedDate, 23)  IS NULL;
GO

-- 5F) Numeric smoke tests
SELECT TOP (50)
    Age,
    CustomerTenureMonths,
    CustomerTenureYears,
    RecordCompletenessScore
FROM bronze.customer_raw
WHERE (LTRIM(RTRIM(ISNULL(Age,''))) <> '' AND Age LIKE '%[^0-9]%')
   OR (LTRIM(RTRIM(ISNULL(CustomerTenureMonths,''))) <> '' AND CustomerTenureMonths LIKE '%[^0-9]%')
   OR (LTRIM(RTRIM(ISNULL(CustomerTenureYears,''))) <> '' AND CustomerTenureYears LIKE '%[^0-9.]%')
   OR (LTRIM(RTRIM(ISNULL(RecordCompletenessScore,''))) <> '' AND RecordCompletenessScore LIKE '%[^0-9]%');
GO

-- 5G) Flag checks (0/1)
SELECT TOP (50)
    HasEmail,
    IsValidEmail,
    HasPhone,
    IsValidPhone,
    MarketingOptInFlag,
    ContactableFlag,
    VulnerableCustomerFlag
FROM bronze.customer_raw
WHERE
    (LTRIM(RTRIM(ISNULL(HasEmail,''))) <> '' AND HasEmail NOT IN ('0','1'))
 OR (LTRIM(RTRIM(ISNULL(IsValidEmail,''))) <> '' AND IsValidEmail NOT IN ('0','1'))
 OR (LTRIM(RTRIM(ISNULL(HasPhone,''))) <> '' AND HasPhone NOT IN ('0','1'))
 OR (LTRIM(RTRIM(ISNULL(IsValidPhone,''))) <> '' AND IsValidPhone NOT IN ('0','1'))
 OR (LTRIM(RTRIM(ISNULL(MarketingOptInFlag,''))) <> '' AND MarketingOptInFlag NOT IN ('0','1'))
 OR (LTRIM(RTRIM(ISNULL(ContactableFlag,''))) <> '' AND ContactableFlag NOT IN ('0','1'))
 OR (LTRIM(RTRIM(ISNULL(VulnerableCustomerFlag,''))) <> '' AND VulnerableCustomerFlag NOT IN ('0','1'));
GO

-- 5H) MarketingOptIn check (Y/N)
SELECT TOP (50) MarketingOptIn
FROM bronze.customer_raw
WHERE LTRIM(RTRIM(ISNULL(MarketingOptIn,''))) <> ''
  AND UPPER(LTRIM(RTRIM(MarketingOptIn))) NOT IN ('Y','N');
GO
