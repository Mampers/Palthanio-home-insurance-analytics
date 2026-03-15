/*=========================================================
  BRONZE LOAD: Date
  Source: stg.[date]
  Target: bronze.date_raw
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
DROP TABLE IF EXISTS bronze.date_raw;
GO

SELECT TOP (0) *
INTO bronze.date_raw
FROM stg.[date];
GO

-----------------------------------------------------------
-- 2) Add Bronze metadata columns
-----------------------------------------------------------
ALTER TABLE bronze.date_raw
ADD
    BronzeLoadDts datetime2(0) NOT NULL
        CONSTRAINT DF_bronze_date_raw_BronzeLoadDts DEFAULT SYSUTCDATETIME(),
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
  AND t.name = 'date';

DECLARE @sql nvarchar(max) =
N'INSERT INTO bronze.date_raw (' + @cols + N')
  SELECT ' + @cols + N'
  FROM stg.[date];';

EXEC sp_executesql @sql;
GO

-----------------------------------------------------------
-- 4) Optional: stamp the filename for lineage
-----------------------------------------------------------
UPDATE bronze.date_raw
SET SourceFile = 'date_enterprise_ready.csv'
WHERE SourceFile IS NULL;
GO

-----------------------------------------------------------
-- 5) Validation checks
-----------------------------------------------------------

-- 5A) Record counts
SELECT COUNT(*) AS RecordCount
FROM stg.[date];

SELECT COUNT(*) AS RecordCount
FROM bronze.date_raw;
GO

-- 5B) Sample
SELECT TOP (20) *
FROM bronze.date_raw
ORDER BY BronzeLoadDts DESC;
GO

-- 5C) Duplicate DateKey check (if DateKey exists)
-- If your column is called DateKey, this will work; if not, skip it.
IF COL_LENGTH('bronze.date_raw', 'DateKey') IS NOT NULL
BEGIN
    SELECT DateKey, COUNT(*) AS Cnt
    FROM bronze.date_raw
    GROUP BY DateKey
    HAVING COUNT(*) > 1;
END
GO
