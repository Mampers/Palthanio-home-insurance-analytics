/*=========================================================
  BRONZE LOAD: Operating Expenses
  Source: stg.operating_expenses
  Target: bronze.operating_expenses_raw
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
DROP TABLE IF EXISTS bronze.operating_expenses_raw;
GO

SELECT TOP (0) *
INTO bronze.operating_expenses_raw
FROM stg.operating_expenses;
GO

-----------------------------------------------------------
-- 2) Add Bronze metadata columns
-----------------------------------------------------------
ALTER TABLE bronze.operating_expenses_raw
ADD
    BronzeLoadDts datetime2(0) NOT NULL
        CONSTRAINT DF_bronze_operating_expenses_raw_BronzeLoadDts DEFAULT SYSUTCDATETIME(),
    SourceFile varchar(260) NULL;
GO

-----------------------------------------------------------
-- 3) Load data from stg into bronze (auto-build column list)
-----------------------------------------------------------
DECLARE @cols nvarchar(max);

SELECT @cols = STRING_AGG(QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id)
FROM sys.columns c
JOIN sys.tables t  ON c.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'stg'
  AND t.name = 'operating_expenses';

DECLARE @sql nvarchar(max) =
N'INSERT INTO bronze.operating_expenses_raw (' + @cols + N')
  SELECT ' + @cols + N'
  FROM stg.operating_expenses;';

EXEC sp_executesql @sql;
GO

-----------------------------------------------------------
-- 4) Optional: stamp the filename for lineage
-----------------------------------------------------------
UPDATE bronze.operating_expenses_raw
SET SourceFile = 'operating_expenses_enterprise_ready.csv'
WHERE SourceFile IS NULL;
GO

-----------------------------------------------------------
-- 5) Validation checks
-----------------------------------------------------------

-- 5A) Record counts
SELECT COUNT(*) AS RecordCount
FROM stg.operating_expenses;

SELECT COUNT(*) AS RecordCount
FROM bronze.operating_expenses_raw;
GO

-- 5B) Sample
SELECT TOP (20) *
FROM bronze.operating_expenses_raw
ORDER BY BronzeLoadDts DESC;
GO

-- 5C) Duplicate grain check (if your columns exist)
-- Typical grain is ExpenseMonthStart + ExpenseCategory
IF COL_LENGTH('bronze.operating_expenses_raw', 'ExpenseMonthStart') IS NOT NULL
AND COL_LENGTH('bronze.operating_expenses_raw', 'ExpenseCategory') IS NOT NULL
BEGIN
    SELECT ExpenseMonthStart, ExpenseCategory, COUNT(*) AS Cnt
    FROM bronze.operating_expenses_raw
    GROUP BY ExpenseMonthStart, ExpenseCategory
    HAVING COUNT(*) > 1;
END
GO

-- 5D) Null/blank grain checks (optional)
IF COL_LENGTH('bronze.operating_expenses_raw', 'ExpenseMonthStart') IS NOT NULL
AND COL_LENGTH('bronze.operating_expenses_raw', 'ExpenseCategory') IS NOT NULL
BEGIN
    SELECT
        SUM(CASE WHEN ExpenseMonthStart IS NULL OR LTRIM(RTRIM(CAST(ExpenseMonthStart AS varchar(50)))) = '' THEN 1 ELSE 0 END) AS NullOrBlank_ExpenseMonthStart,
        SUM(CASE WHEN ExpenseCategory   IS NULL OR LTRIM(RTRIM(CAST(ExpenseCategory   AS varchar(50)))) = '' THEN 1 ELSE 0 END) AS NullOrBlank_ExpenseCategory
    FROM bronze.operating_expenses_raw;
END
GO
