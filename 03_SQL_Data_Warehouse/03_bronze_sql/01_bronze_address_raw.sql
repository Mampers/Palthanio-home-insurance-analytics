/*=========================================================
  BRONZE LOAD: Address
  Source: stg.address
  Target: bronze.address_raw

  Notes:
  - Bronze is "raw + metadata", minimal/no transformation.
  - Table is cloned from stg.address to guarantee perfect alignment.
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
DROP TABLE IF EXISTS bronze.address_raw;
GO

-- Clone structure (0 rows) from staging
SELECT TOP (0)
    *
INTO bronze.address_raw
FROM stg.address;
GO

-----------------------------------------------------------
-- 2) Add Bronze metadata columns
-----------------------------------------------------------
ALTER TABLE bronze.address_raw
ADD
    BronzeLoadDts datetime2(0) NOT NULL
        CONSTRAINT DF_bronze_address_raw_BronzeLoadDts DEFAULT SYSUTCDATETIME(),
    SourceFile varchar(260) NULL;
GO

-----------------------------------------------------------
-- 3) Load data from stg into bronze
--    (Fixed syntax: no empty column list)
-----------------------------------------------------------
INSERT INTO bronze.address_raw
SELECT *
FROM stg.address;
GO

-----------------------------------------------------------
-- 4) Optional: Stamp the source filename for lineage
--    (Change filename if needed)
-----------------------------------------------------------
UPDATE bronze.address_raw
SET SourceFile = 'address_enchanched.csv'
WHERE SourceFile IS NULL;
GO

-----------------------------------------------------------
-- 5) Validation Checks
-----------------------------------------------------------

-- 5A) Row counts (should match)
SELECT 'stg.address' AS TableName, COUNT(*) AS RC
FROM stg.address
UNION ALL
SELECT 'bronze.address_raw', COUNT(*)
FROM bronze.address_raw;
GO

-- 5B) Quick sample
SELECT TOP (20) *
FROM bronze.address_raw
ORDER BY BronzeLoadDts DESC;
GO

-- 5C) Duplicate AddressID check (ideally 0 rows)
--     If your AddressID is meant to be unique, duplicates indicate data issues upstream.
SELECT AddressID, COUNT(*) AS Cnt
FROM bronze.address_raw
GROUP BY AddressID
HAVING COUNT(*) > 1;
GO

-- 5D) Null/blank key checks
SELECT
    SUM(CASE WHEN AddressID  IS NULL OR LTRIM(RTRIM(AddressID))  = '' THEN 1 ELSE 0 END) AS NullOrBlank_AddressID,
    SUM(CASE WHEN CustomerID IS NULL OR LTRIM(RTRIM(CustomerID)) = '' THEN 1 ELSE 0 END) AS NullOrBlank_CustomerID
FROM bronze.address_raw;
GO

-- 5E) Basic weird-character smoke test for Postcode (tabs/newlines)
SELECT TOP (50) Postcode
FROM bronze.address_raw
WHERE Postcode LIKE '%' + CHAR(9)  + '%'
   OR Postcode LIKE '%' + CHAR(10) + '%'
   OR Postcode LIKE '%' + CHAR(13) + '%';
GO
