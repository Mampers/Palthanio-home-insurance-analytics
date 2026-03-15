/*==============================================================================
  Palthanio Home Insurance Analytics
  Layer: Silver
  Object: silver.premium_transactions
  Source: bronze.premium_transactions_raw

  ------------------------------------------------------------------------------
  PURPOSE
  ------------------------------------------------------------------------------
  Standardise and deduplicate Premium Transaction records loaded into Bronze.

  Business Grain (expected):
      1 row per premium transaction (latest BronzeLoadDts wins)

  Key Rules Applied:
      - Deduplicate by detected transaction key (or fallback composite key)
      - Reject rows where the key is NULL/blank
      - Preserve the bronze structure exactly (clone table)
      - Add SilverLoadDts for auditability and lineage

  Outputs:
      - silver.premium_transactions
      - silver.premium_transactions_reject
==============================================================================*/

USE PalthanioHomeInsuranceDW;
SET NOCOUNT ON;

BEGIN TRY

    /*===========================================================
      0) Ensure silver schema exists
    ===========================================================*/
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
        EXEC('CREATE SCHEMA silver;');

    /*===========================================================
      1) Ensure source exists
         NOTE: If your bronze table name differs, change it here.
    ===========================================================*/
    DECLARE @SrcTable sysname = N'bronze.premium_transactions_raw';
    DECLARE @SrcObjId int = OBJECT_ID(@SrcTable, 'U');

    IF @SrcObjId IS NULL
        THROW 50001, 'Source table bronze.premium_transactions_raw not found in this database.', 1;

    /*===========================================================
      2) Read bronze columns (for key detection)
    ===========================================================*/
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
        PRINT 'DEBUG: bronze premium_transactions columns detected:';
        SELECT column_id, RealName, NormName FROM #cols ORDER BY column_id;
        THROW 50002, 'Could not detect BronzeLoadDts on bronze.premium_transactions_raw. See DEBUG output.', 1;
    END

    /*===========================================================
      3) Detect a usable key column
         Prefer TransactionID-like columns.
         Fallback to composite if needed.
    ===========================================================*/
    DECLARE @KeyCol sysname =
        (SELECT TOP (1) RealName
         FROM #cols
         WHERE NormName IN (
            'transactionid',
            'premiumtransactionid',
            'premiumtransid',
            'premiumtransactionkey',
            'premiumid',
            'id'
         )
         ORDER BY
            CASE NormName
                WHEN 'transactionid' THEN 1
                WHEN 'premiumtransactionid' THEN 2
                WHEN 'premiumtransid' THEN 3
                WHEN 'premiumtransactionkey' THEN 4
                WHEN 'premiumid' THEN 5
                WHEN 'id' THEN 99
                ELSE 100
            END);

    /* Composite key candidates */
    DECLARE @PolicyCol sysname = (SELECT TOP (1) RealName FROM #cols WHERE NormName IN ('policyid','policykey','policynumber'));
    DECLARE @DateCol   sysname = (SELECT TOP (1) RealName FROM #cols WHERE NormName IN ('transactiondate','transdate','effectivedate','posteddate','accountingdate'));
    DECLARE @TypeCol   sysname = (SELECT TOP (1) RealName FROM #cols WHERE NormName IN ('transactiontype','transtype','premiumtransactiontype','type'));

    DECLARE @KeyMode varchar(20) =
        CASE
            WHEN @KeyCol IS NOT NULL THEN 'SINGLE'
            WHEN @PolicyCol IS NOT NULL AND @DateCol IS NOT NULL AND @TypeCol IS NOT NULL THEN 'COMPOSITE'
            ELSE 'NONE'
        END;

    IF @KeyMode = 'NONE'
    BEGIN
        PRINT 'DEBUG: bronze premium_transactions columns detected:';
        SELECT column_id, RealName, NormName FROM #cols ORDER BY column_id;
        THROW 50003, 'Could not detect a usable transaction key (single ID or Policy+Date+Type). See DEBUG output.', 1;
    END

    PRINT 'KeyMode: ' + @KeyMode;
    IF @KeyMode = 'SINGLE'
        PRINT 'Using key column: ' + QUOTENAME(@KeyCol);
    ELSE
        PRINT 'Using composite key: ' + QUOTENAME(@PolicyCol) + ' + ' + QUOTENAME(@DateCol) + ' + ' + QUOTENAME(@TypeCol);

    /*===========================================================
      4) Drop targets (repeatable script)
    ===========================================================*/
    IF OBJECT_ID('silver.premium_transactions','U') IS NOT NULL
        DROP TABLE silver.premium_transactions;

    IF OBJECT_ID('silver.premium_transactions_reject','U') IS NOT NULL
        DROP TABLE silver.premium_transactions_reject;

    /*===========================================================
      5) Clone silver table from bronze (exact match)
    ===========================================================*/
    SELECT TOP (0) *
    INTO silver.premium_transactions
    FROM bronze.premium_transactions_raw;

    ALTER TABLE silver.premium_transactions
      ADD SilverLoadDts datetime2(0) NOT NULL
          CONSTRAINT DF_silver_premium_transactions_SilverLoadDts DEFAULT SYSUTCDATETIME();

    /*===========================================================
      6) Reject table
    ===========================================================*/
    CREATE TABLE silver.premium_transactions_reject (
        TransactionKey varchar(400)  NULL,
        RejectReason   varchar(200)  NOT NULL,
        BronzeLoadDts  datetime2(0)  NULL,
        SourceFile     varchar(260)  NULL,
        RejectLoadDts  datetime2(0)  NOT NULL DEFAULT SYSUTCDATETIME()
    );

    /*===========================================================
      7) Build column lists for insert (exclude SilverLoadDts)
    ===========================================================*/
    DECLARE @SilverObjId int = OBJECT_ID(N'silver.premium_transactions');
    DECLARE @InsertCols nvarchar(max);
    DECLARE @SelectCols nvarchar(max);

    SELECT
        @InsertCols = STRING_AGG(QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id),
        @SelectCols = STRING_AGG('l.' + QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.columns c
    WHERE c.object_id = @SilverObjId
      AND c.name <> 'SilverLoadDts';

    /*===========================================================
      8) Build dedupe key expression + missing-key predicate
    ===========================================================*/
    DECLARE @PartitionBy nvarchar(max);
    DECLARE @KeyExpr nvarchar(max);
    DECLARE @MissingKeyWhere nvarchar(max);

    IF @KeyMode = 'SINGLE'
    BEGIN
        SET @PartitionBy = N'b.' + QUOTENAME(@KeyCol);
        SET @KeyExpr = N'CAST(l.' + QUOTENAME(@KeyCol) + N' AS varchar(400))';
        SET @MissingKeyWhere = N'(l.' + QUOTENAME(@KeyCol) + N' IS NULL OR LTRIM(RTRIM(CAST(l.' + QUOTENAME(@KeyCol) + N' AS varchar(400)))) = '''')';
    END
    ELSE
    BEGIN
        SET @PartitionBy = N'b.' + QUOTENAME(@PolicyCol) + N', b.' + QUOTENAME(@DateCol) + N', b.' + QUOTENAME(@TypeCol);

        SET @KeyExpr =
            N'CONCAT('
            + N'CAST(l.' + QUOTENAME(@PolicyCol) + N' AS varchar(150)), ''|'', '
            + N'CAST(l.' + QUOTENAME(@DateCol) + N' AS varchar(150)), ''|'', '
            + N'CAST(l.' + QUOTENAME(@TypeCol) + N' AS varchar(150))'
            + N')';

        SET @MissingKeyWhere =
            N'(l.' + QUOTENAME(@PolicyCol) + N' IS NULL OR LTRIM(RTRIM(CAST(l.' + QUOTENAME(@PolicyCol) + N' AS varchar(150)))) = '''')'
            + N' OR '
            + N'(l.' + QUOTENAME(@DateCol) + N' IS NULL OR LTRIM(RTRIM(CAST(l.' + QUOTENAME(@DateCol) + N' AS varchar(150)))) = '''')'
            + N' OR '
            + N'(l.' + QUOTENAME(@TypeCol) + N' IS NULL OR LTRIM(RTRIM(CAST(l.' + QUOTENAME(@TypeCol) + N' AS varchar(150)))) = '''')';
    END

    /*===========================================================
      9) Dedupe into #Latest, Reject, Insert (dynamic SQL)
    ===========================================================*/
    DECLARE @sql nvarchar(max) = N'
IF OBJECT_ID(''tempdb..#Latest'') IS NOT NULL DROP TABLE #Latest;

;WITH Deduped AS (
    SELECT
        b.*,
        ROW_NUMBER() OVER (
            PARTITION BY ' + @PartitionBy + N'
            ORDER BY b.' + QUOTENAME(@LoadCol) + N' DESC
        ) AS rn
    FROM bronze.premium_transactions_raw b
)
SELECT *
INTO #Latest
FROM Deduped
WHERE rn = 1;

-- Reject missing key
INSERT INTO silver.premium_transactions_reject (TransactionKey, RejectReason, BronzeLoadDts, SourceFile)
SELECT
    ' + @KeyExpr + N' AS TransactionKey,
    ''Missing transaction key'',
    l.' + QUOTENAME(@LoadCol) + N' AS BronzeLoadDts,
    ' + CASE WHEN @FileCol IS NULL THEN N'NULL' ELSE N'l.' + QUOTENAME(@FileCol) END + N' AS SourceFile
FROM #Latest l
WHERE ' + @MissingKeyWhere + N';

-- Insert valid rows
INSERT INTO silver.premium_transactions (' + @InsertCols + N')
SELECT ' + @SelectCols + N'
FROM #Latest l
WHERE NOT (' + @MissingKeyWhere + N');
';

    EXEC sp_executesql @sql;

    /*===========================================================
      10) Validations
    ===========================================================*/
    PRINT 'VALIDATION: counts';
    SELECT COUNT(*) AS BronzeCount FROM bronze.premium_transactions_raw;
    SELECT COUNT(*) AS SilverCount FROM silver.premium_transactions;
    SELECT COUNT(*) AS RejectCount FROM silver.premium_transactions_reject;

    SELECT TOP (50) * FROM silver.premium_transactions ORDER BY SilverLoadDts DESC;
    SELECT TOP (50) * FROM silver.premium_transactions_reject ORDER BY RejectLoadDts DESC;

    PRINT 'DONE: Silver Premium Transactions load complete.';

END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;


SELECT *
FROM silver.premium_transactions
