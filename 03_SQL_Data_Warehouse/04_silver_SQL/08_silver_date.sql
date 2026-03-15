/*==============================================================================
  SILVER STAGE: Date (AUTO-KEY SAFE VERSION)

  Notes:
  - Date dimensions are usually generated in Gold, but this script follows the
    same Bronze -> Silver pattern used elsewhere in the project.
  - Clones structure from bronze.date_raw (exact match)
  - Auto-detects a date key column from common candidates
  - Dedupes by detected key (latest BronzeLoadDts wins)
  - Rejects missing key values
==============================================================================*/

USE PalthanioHomeInsuranceDW;
SET NOCOUNT ON;

BEGIN TRY

    /* 0) Ensure schema */
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
        EXEC('CREATE SCHEMA silver;');

    /* 1) Ensure source exists */
    DECLARE @SrcObjId int = OBJECT_ID(N'bronze.date_raw');
    IF @SrcObjId IS NULL
        THROW 50001, 'Source table bronze.date_raw not found in this database.', 1;

    /* 2) Detect key + required metadata columns */
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
             'datekey',
             'dateid',
             'date',
             'calendardate',
             'fulldate',
             'dt',
             'daydate'
         )
         ORDER BY
             CASE NormName
                 WHEN 'datekey' THEN 1
                 WHEN 'dateid' THEN 2
                 WHEN 'date' THEN 3
                 WHEN 'calendardate' THEN 4
                 WHEN 'fulldate' THEN 5
                 WHEN 'dt' THEN 6
                 WHEN 'daydate' THEN 7
                 ELSE 100
             END);

    DECLARE @LoadCol sysname =
        (SELECT TOP (1) RealName FROM #cols WHERE NormName = 'bronzeloaddts');

    DECLARE @FileCol sysname =
        (SELECT TOP (1) RealName FROM #cols WHERE NormName = 'sourcefile');

    IF @KeyCol IS NULL OR @LoadCol IS NULL
    BEGIN
        PRINT 'DEBUG: bronze.date_raw columns detected:';
        SELECT column_id, RealName, NormName
        FROM #cols
        ORDER BY column_id;

        THROW 50002, 'Could not detect a date key column and/or BronzeLoadDts on bronze.date_raw. See DEBUG output.', 1;
    END

    PRINT 'Using date key column: ' + QUOTENAME(@KeyCol);
    PRINT 'Using load column: ' + QUOTENAME(@LoadCol);

    /* 3) Drop targets */
    IF OBJECT_ID('silver.[date]','U') IS NOT NULL DROP TABLE silver.[date];
    IF OBJECT_ID('silver.date_reject','U') IS NOT NULL DROP TABLE silver.date_reject;

    /* 4) Clone silver.date from bronze */
    SELECT TOP (0) *
    INTO silver.[date]
    FROM bronze.date_raw;

    /* Add SilverLoadDts */
    ALTER TABLE silver.[date]
      ADD SilverLoadDts datetime2(0) NOT NULL
          CONSTRAINT DF_silver_date_SilverLoadDts DEFAULT SYSUTCDATETIME();

    /* 5) Reject table */
    CREATE TABLE silver.date_reject (
        DateKey       varchar(200)  NULL,
        RejectReason  varchar(200)  NOT NULL,
        BronzeLoadDts datetime2(0)  NULL,
        SourceFile    varchar(260)  NULL,
        RejectLoadDts datetime2(0)  NOT NULL DEFAULT SYSUTCDATETIME()
    );

    /* 6) Build insert column list from silver.date excluding SilverLoadDts */
    DECLARE @SilverObjId int = OBJECT_ID(N'silver.[date]');
    DECLARE @InsertCols nvarchar(max);
    DECLARE @SelectCols nvarchar(max);

    SELECT
        @InsertCols = STRING_AGG(QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id),
        @SelectCols = STRING_AGG('l.' + QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.columns c
    WHERE c.object_id = @SilverObjId
      AND c.name <> 'SilverLoadDts';

    /* 7) Dedupe + reject + insert */
    DECLARE @sql nvarchar(max) = N'
IF OBJECT_ID(''tempdb..#Latest'') IS NOT NULL DROP TABLE #Latest;

;WITH Deduped AS (
    SELECT
        b.*,
        ROW_NUMBER() OVER (
            PARTITION BY b.' + QUOTENAME(@KeyCol) + N'
            ORDER BY b.' + QUOTENAME(@LoadCol) + N' DESC
        ) AS rn
    FROM bronze.date_raw b
)
SELECT *
INTO #Latest
FROM Deduped
WHERE rn = 1;

-- Reject missing key
INSERT INTO silver.date_reject (DateKey, RejectReason, BronzeLoadDts, SourceFile)
SELECT
    CAST(l.' + QUOTENAME(@KeyCol) + N' AS varchar(200)) AS DateKey,
    ''Missing Date key'',
    l.' + QUOTENAME(@LoadCol) + N' AS BronzeLoadDts,
    ' + CASE WHEN @FileCol IS NULL THEN N'NULL' ELSE N'l.' + QUOTENAME(@FileCol) END + N' AS SourceFile
FROM #Latest l
WHERE l.' + QUOTENAME(@KeyCol) + N' IS NULL
   OR LTRIM(RTRIM(CAST(l.' + QUOTENAME(@KeyCol) + N' AS varchar(200)))) = '''';

-- Insert good rows
INSERT INTO silver.[date] (' + @InsertCols + N')
SELECT ' + @SelectCols + N'
FROM #Latest l
WHERE l.' + QUOTENAME(@KeyCol) + N' IS NOT NULL
  AND LTRIM(RTRIM(CAST(l.' + QUOTENAME(@KeyCol) + N' AS varchar(200)))) <> '''';
';

    EXEC sp_executesql @sql;

    /* 8) Validations */
    PRINT 'VALIDATION: counts';
    SELECT COUNT(*) AS BronzeCount FROM bronze.date_raw;
    SELECT COUNT(*) AS SilverCount FROM silver.[date];
    SELECT COUNT(*) AS RejectCount FROM silver.date_reject;

    SELECT TOP (50) * FROM silver.[date] ORDER BY SilverLoadDts DESC;
    SELECT TOP (50) * FROM silver.date_reject ORDER BY RejectLoadDts DESC;

    PRINT 'DONE: Silver Date load complete.';

END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
