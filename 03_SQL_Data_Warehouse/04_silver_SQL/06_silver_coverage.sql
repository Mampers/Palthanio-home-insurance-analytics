/*==============================================================================
  SILVER STAGE: Coverage (AUTO-KEY SAFE VERSION)

  Fixes:
  - Avoids hardcoding CoverageID (prevents Msg 207)
  - Detects the key column from bronze.coverage_raw using common candidates
  - Clones silver.coverage from bronze.coverage_raw (exact structure match)
  - Dedupes by detected key (latest BronzeLoadDts wins)
  - Rejects missing key

  Source:
    bronze.coverage_raw

  Targets:
    silver.coverage
    silver.coverage_reject
==============================================================================*/

USE PalthanioHomeInsuranceDW;
SET NOCOUNT ON;

BEGIN TRY

    /* 0) Ensure schema */
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
        EXEC('CREATE SCHEMA silver;');

    /* 1) Ensure source exists */
    DECLARE @SrcObjId int = OBJECT_ID(N'bronze.coverage_raw');
    IF @SrcObjId IS NULL
        THROW 50001, 'Source table bronze.coverage_raw not found in this database.', 1;

    /* 2) Detect key column name (no guessing, based on candidates) */
    IF OBJECT_ID('tempdb..#cols') IS NOT NULL DROP TABLE #cols;

    SELECT
        c.column_id,
        c.name AS RealName,
        LOWER(REPLACE(REPLACE(c.name,' ',''),'_','')) AS NormName
    INTO #cols
    FROM sys.columns c
    WHERE c.object_id = @SrcObjId;

    DECLARE @KeyCol sysname =
        (SELECT TOP (1) RealName
         FROM #cols
         WHERE NormName IN (
             'coverageid',
             'policycoverageid',
             'coveragerecordid',
             'coveragekey',
             'coveragetransactionid',
             'policyid',      -- fallback if coverage is policy-grain
             'id'             -- last resort
         )
         ORDER BY
             CASE NormName
                 WHEN 'coverageid' THEN 1
                 WHEN 'policycoverageid' THEN 2
                 WHEN 'coveragerecordid' THEN 3
                 WHEN 'coveragekey' THEN 4
                 WHEN 'coveragetransactionid' THEN 5
                 WHEN 'policyid' THEN 90
                 WHEN 'id' THEN 99
                 ELSE 100
             END);

    DECLARE @LoadCol sysname =
        (SELECT TOP (1) RealName FROM #cols WHERE NormName = 'bronzeloaddts');

    DECLARE @FileCol sysname =
        (SELECT TOP (1) RealName FROM #cols WHERE NormName = 'sourcefile');

    IF @KeyCol IS NULL OR @LoadCol IS NULL
    BEGIN
        PRINT 'DEBUG: bronze.coverage_raw columns detected:';
        SELECT column_id, RealName, NormName
        FROM #cols
        ORDER BY column_id;

        THROW 50002, 'Could not detect a key column and/or BronzeLoadDts on bronze.coverage_raw. See DEBUG output.', 1;
    END

    PRINT 'Using key column: ' + QUOTENAME(@KeyCol);
    PRINT 'Using load column: ' + QUOTENAME(@LoadCol);

    /* 3) Drop targets */
    IF OBJECT_ID('silver.coverage','U') IS NOT NULL DROP TABLE silver.coverage;
    IF OBJECT_ID('silver.coverage_reject','U') IS NOT NULL DROP TABLE silver.coverage_reject;

    /* 4) Clone silver.coverage from bronze */
    SELECT TOP (0) *
    INTO silver.coverage
    FROM bronze.coverage_raw;

    /* Add SilverLoadDts */
    ALTER TABLE silver.coverage
      ADD SilverLoadDts datetime2(0) NOT NULL
          CONSTRAINT DF_silver_coverage_SilverLoadDts DEFAULT SYSUTCDATETIME();

    /* 5) Reject table */
    CREATE TABLE silver.coverage_reject (
        CoverageKey    varchar(200)  NULL,
        RejectReason   varchar(200)  NOT NULL,
        BronzeLoadDts  datetime2(0)  NULL,
        SourceFile     varchar(260)  NULL,
        RejectLoadDts  datetime2(0)  NOT NULL DEFAULT SYSUTCDATETIME()
    );

    /* 6) Build insert column list from silver.coverage excluding SilverLoadDts */
    DECLARE @SilverObjId int = OBJECT_ID(N'silver.coverage');
    DECLARE @InsertCols nvarchar(max);
    DECLARE @SelectCols nvarchar(max);

    SELECT
        @InsertCols = STRING_AGG(QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id),
        @SelectCols = STRING_AGG('l.' + QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.columns c
    WHERE c.object_id = @SilverObjId
      AND c.name <> 'SilverLoadDts';

    /* 7) Dedupe + reject + insert (dynamic to use detected key column) */
    DECLARE @sql nvarchar(max) = N'
IF OBJECT_ID(''tempdb..#Latest'') IS NOT NULL DROP TABLE #Latest;

;WITH Deduped AS (
    SELECT
        b.*,
        ROW_NUMBER() OVER (
            PARTITION BY b.' + QUOTENAME(@KeyCol) + N'
            ORDER BY b.' + QUOTENAME(@LoadCol) + N' DESC
        ) AS rn
    FROM bronze.coverage_raw b
)
SELECT *
INTO #Latest
FROM Deduped
WHERE rn = 1;

-- Reject missing key
INSERT INTO silver.coverage_reject (CoverageKey, RejectReason, BronzeLoadDts, SourceFile)
SELECT
    CAST(l.' + QUOTENAME(@KeyCol) + N' AS varchar(200)) AS CoverageKey,
    ''Missing Coverage key'',
    l.' + QUOTENAME(@LoadCol) + N' AS BronzeLoadDts,
    ' + CASE WHEN @FileCol IS NULL THEN N'NULL' ELSE N'l.' + QUOTENAME(@FileCol) END + N' AS SourceFile
FROM #Latest l
WHERE l.' + QUOTENAME(@KeyCol) + N' IS NULL
   OR LTRIM(RTRIM(CAST(l.' + QUOTENAME(@KeyCol) + N' AS varchar(200)))) = '''';

-- Insert good rows
INSERT INTO silver.coverage (' + @InsertCols + N')
SELECT ' + @SelectCols + N'
FROM #Latest l
WHERE l.' + QUOTENAME(@KeyCol) + N' IS NOT NULL
  AND LTRIM(RTRIM(CAST(l.' + QUOTENAME(@KeyCol) + N' AS varchar(200)))) <> '''';
';

    EXEC sp_executesql @sql;

    /* 8) Validations */
    PRINT 'VALIDATION: counts';
    SELECT COUNT(*) AS BronzeCount FROM bronze.coverage_raw;
    SELECT COUNT(*) AS SilverCount FROM silver.coverage;
    SELECT COUNT(*) AS RejectCount FROM silver.coverage_reject;

    SELECT TOP (50) * FROM silver.coverage ORDER BY SilverLoadDts DESC;
    SELECT TOP (50) * FROM silver.coverage_reject ORDER BY RejectLoadDts DESC;

    PRINT 'DONE: Silver Coverage load complete.';

END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
