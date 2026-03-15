/*==============================================================================
  SILVER STAGE: Operating Expenses (AUTO-KEY SAFE VERSION)

  Why this design?
  ----------------
  Operating Expenses are often snapshot-grain (month + category),
  not a transactional "ExpenseID". This script:
   - clones Silver table structure from Bronze (exact match, avoids Msg 207)
   - auto-detects whether a single ID exists; otherwise uses composite key:
       ExpenseMonthStart + ExpenseCategory (common pattern)
   - dedupes by detected key (latest BronzeLoadDts wins)
   - rejects rows with missing key(s)

  Source:
    bronze.operating_expenses_raw

  Targets:
    silver.operating_expenses
    silver.operating_expenses_reject
==============================================================================*/

USE PalthanioHomeInsuranceDW;
SET NOCOUNT ON;

BEGIN TRY

    /* 0) Ensure schema */
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
        EXEC('CREATE SCHEMA silver;');

    /* 1) Ensure source exists */
    DECLARE @SrcObjId int = OBJECT_ID(N'bronze.operating_expenses_raw');
    IF @SrcObjId IS NULL
        THROW 50001, 'Source table bronze.operating_expenses_raw not found in this database.', 1;

    /* 2) Read source columns */
    IF OBJECT_ID('tempdb..#cols') IS NOT NULL DROP TABLE #cols;

    SELECT
        c.column_id,
        c.name AS RealName,
        LOWER(REPLACE(REPLACE(c.name,' ',''),'_','')) AS NormName
    INTO #cols
    FROM sys.columns c
    WHERE c.object_id = @SrcObjId;

    DECLARE @LoadCol sysname = (SELECT TOP (1) RealName FROM #cols WHERE NormName = 'bronzeloaddts');
    DECLARE @FileCol sysname = (SELECT TOP (1) RealName FROM #cols WHERE NormName = 'sourcefile');

    IF @LoadCol IS NULL
    BEGIN
        PRINT 'DEBUG: bronze.operating_expenses_raw columns detected:';
        SELECT column_id, RealName, NormName FROM #cols ORDER BY column_id;
        THROW 50002, 'Could not detect BronzeLoadDts on bronze.operating_expenses_raw. See DEBUG output.', 1;
    END

    /* 3) Detect key strategy: single ID or composite (month + category) */
    DECLARE @IdCol sysname =
        (SELECT TOP (1) RealName
         FROM #cols
         WHERE NormName IN ('expenseid','operatingexpenseid','opexid','id')
         ORDER BY
           CASE NormName
             WHEN 'expenseid' THEN 1
             WHEN 'operatingexpenseid' THEN 2
             WHEN 'opexid' THEN 3
             WHEN 'id' THEN 99
             ELSE 100
           END);

    DECLARE @MonthCol sysname =
        (SELECT TOP (1) RealName
         FROM #cols
         WHERE NormName IN ('expensemonthstart','monthstart','month','expensedate','periodstart','snapshotmonth','snapshotdate')
         ORDER BY
           CASE NormName
             WHEN 'expensemonthstart' THEN 1
             WHEN 'periodstart' THEN 2
             WHEN 'monthstart' THEN 3
             WHEN 'snapshotmonth' THEN 4
             WHEN 'snapshotdate' THEN 5
             WHEN 'expensedate' THEN 6
             WHEN 'month' THEN 7
             ELSE 100
           END);

    DECLARE @CatCol sysname =
        (SELECT TOP (1) RealName
         FROM #cols
         WHERE NormName IN ('expensecategory','category','expensecategoryname','costcategory','opexcategory')
         ORDER BY
           CASE NormName
             WHEN 'expensecategory' THEN 1
             WHEN 'expensecategoryname' THEN 2
             WHEN 'costcategory' THEN 3
             WHEN 'opexcategory' THEN 4
             WHEN 'category' THEN 5
             ELSE 100
           END);

    DECLARE @KeyMode varchar(20) =
        CASE
            WHEN @IdCol IS NOT NULL THEN 'SINGLE'
            WHEN @MonthCol IS NOT NULL AND @CatCol IS NOT NULL THEN 'COMPOSITE'
            ELSE 'NONE'
        END;

    IF @KeyMode = 'NONE'
    BEGIN
        PRINT 'DEBUG: bronze.operating_expenses_raw columns detected:';
        SELECT column_id, RealName, NormName FROM #cols ORDER BY column_id;
        THROW 50003, 'Could not detect a usable key (ExpenseID or Month+Category) for operating expenses. See DEBUG output.', 1;
    END

    PRINT 'Key mode: ' + @KeyMode;
    IF @KeyMode = 'SINGLE'
        PRINT 'Using ID column: ' + QUOTENAME(@IdCol);
    ELSE
        PRINT 'Using composite key columns: ' + QUOTENAME(@MonthCol) + ' + ' + QUOTENAME(@CatCol);

    /* 4) Drop targets */
    IF OBJECT_ID('silver.operating_expenses','U') IS NOT NULL DROP TABLE silver.operating_expenses;
    IF OBJECT_ID('silver.operating_expenses_reject','U') IS NOT NULL DROP TABLE silver.operating_expenses_reject;

    /* 5) Clone silver table from bronze */
    SELECT TOP (0) *
    INTO silver.operating_expenses
    FROM bronze.operating_expenses_raw;

    /* Add SilverLoadDts */
    ALTER TABLE silver.operating_expenses
      ADD SilverLoadDts datetime2(0) NOT NULL
          CONSTRAINT DF_silver_operating_expenses_SilverLoadDts DEFAULT SYSUTCDATETIME();

    /* 6) Reject table */
    CREATE TABLE silver.operating_expenses_reject (
        ExpenseKey    varchar(400)  NULL,
        RejectReason  varchar(200)  NOT NULL,
        BronzeLoadDts datetime2(0)  NULL,
        SourceFile    varchar(260)  NULL,
        RejectLoadDts datetime2(0)  NOT NULL DEFAULT SYSUTCDATETIME()
    );

    /* 7) Build insert column list from silver.operating_expenses excluding SilverLoadDts */
    DECLARE @SilverObjId int = OBJECT_ID(N'silver.operating_expenses');
    DECLARE @InsertCols nvarchar(max);
    DECLARE @SelectCols nvarchar(max);

    SELECT
        @InsertCols = STRING_AGG(QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id),
        @SelectCols = STRING_AGG('l.' + QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.columns c
    WHERE c.object_id = @SilverObjId
      AND c.name <> 'SilverLoadDts';

    /* 8) Dedupe + reject + insert (dynamic to handle key mode) */
    DECLARE @PartitionBy nvarchar(max);
    DECLARE @KeyExpr nvarchar(max);
    DECLARE @MissingKeyWhere nvarchar(max);

    IF @KeyMode = 'SINGLE'
    BEGIN
        SET @PartitionBy = N'b.' + QUOTENAME(@IdCol);
        SET @KeyExpr = N'CAST(l.' + QUOTENAME(@IdCol) + N' AS varchar(400))';
        SET @MissingKeyWhere = N'(l.' + QUOTENAME(@IdCol) + N' IS NULL OR LTRIM(RTRIM(CAST(l.' + QUOTENAME(@IdCol) + N' AS varchar(400)))) = '''')';
    END
    ELSE
    BEGIN
        SET @PartitionBy = N'b.' + QUOTENAME(@MonthCol) + N', b.' + QUOTENAME(@CatCol);
        SET @KeyExpr =
            N'CONCAT('
            + N'CAST(l.' + QUOTENAME(@MonthCol) + N' AS varchar(200)), ''|'', '
            + N'CAST(l.' + QUOTENAME(@CatCol) + N' AS varchar(200))'
            + N')';
        SET @MissingKeyWhere =
            N'(l.' + QUOTENAME(@MonthCol) + N' IS NULL OR LTRIM(RTRIM(CAST(l.' + QUOTENAME(@MonthCol) + N' AS varchar(200)))) = '''')'
            + N' OR '
            + N'(l.' + QUOTENAME(@CatCol) + N' IS NULL OR LTRIM(RTRIM(CAST(l.' + QUOTENAME(@CatCol) + N' AS varchar(200)))) = '''')';
    END

    DECLARE @sql nvarchar(max) = N'
IF OBJECT_ID(''tempdb..#Latest'') IS NOT NULL DROP TABLE #Latest;

;WITH Deduped AS (
    SELECT
        b.*,
        ROW_NUMBER() OVER (
            PARTITION BY ' + @PartitionBy + N'
            ORDER BY b.' + QUOTENAME(@LoadCol) + N' DESC
        ) AS rn
    FROM bronze.operating_expenses_raw b
)
SELECT *
INTO #Latest
FROM Deduped
WHERE rn = 1;

-- Reject missing key
INSERT INTO silver.operating_expenses_reject (ExpenseKey, RejectReason, BronzeLoadDts, SourceFile)
SELECT
    ' + @KeyExpr + N' AS ExpenseKey,
    ''Missing Expense key'',
    l.' + QUOTENAME(@LoadCol) + N' AS BronzeLoadDts,
    ' + CASE WHEN @FileCol IS NULL THEN N'NULL' ELSE N'l.' + QUOTENAME(@FileCol) END + N' AS SourceFile
FROM #Latest l
WHERE ' + @MissingKeyWhere + N';

-- Insert good rows
INSERT INTO silver.operating_expenses (' + @InsertCols + N')
SELECT ' + @SelectCols + N'
FROM #Latest l
WHERE NOT (' + @MissingKeyWhere + N');
';

    EXEC sp_executesql @sql;

    /* 9) Validations */
    PRINT 'VALIDATION: counts';
    SELECT COUNT(*) AS BronzeCount FROM bronze.operating_expenses_raw;
    SELECT COUNT(*) AS SilverCount FROM silver.operating_expenses;
    SELECT COUNT(*) AS RejectCount FROM silver.operating_expenses_reject;

    SELECT TOP (50) * FROM silver.operating_expenses ORDER BY SilverLoadDts DESC;
    SELECT TOP (50) * FROM silver.operating_expenses_reject ORDER BY RejectLoadDts DESC;

    PRINT 'DONE: Silver Operating Expenses load complete.';

END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
