/*==============================================================================
  SILVER STAGE: Customer (AUTO-KEY SAFE VERSION)

  Fixes:
  - Avoids hardcoding CustomerID (prevents Msg 207 if names differ)
  - Detects key column from bronze.customer_raw using common candidates
  - Clones silver.customer from bronze.customer_raw (exact structure match)
  - Dedupes by detected key (latest BronzeLoadDts wins)
  - Rejects missing key values
  - Adds SilverLoadDts as Silver metadata

  Source:
    bronze.customer_raw

  Targets:
    silver.customer
    silver.customer_reject
==============================================================================*/

USE PalthanioHomeInsuranceDW;
SET NOCOUNT ON;

BEGIN TRY

    /* 0) Ensure schema */
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
        EXEC('CREATE SCHEMA silver;');

    /* 1) Ensure source exists */
    DECLARE @SrcObjId int = OBJECT_ID(N'bronze.customer_raw');
    IF @SrcObjId IS NULL
        THROW 50001, 'Source table bronze.customer_raw not found in this database.', 1;

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
             'customerid',
             'policyholderid',
             'personid',
             'clientid',
             'insuredid',
             'insuredpersonid',
             'partyid',
             'id'
         )
         ORDER BY
             CASE NormName
                 WHEN 'customerid' THEN 1
                 WHEN 'policyholderid' THEN 2
                 WHEN 'personid' THEN 3
                 WHEN 'clientid' THEN 4
                 WHEN 'insuredid' THEN 5
                 WHEN 'insuredpersonid' THEN 6
                 WHEN 'partyid' THEN 7
                 WHEN 'id' THEN 99
                 ELSE 100
             END);

    DECLARE @LoadCol sysname =
        (SELECT TOP (1) RealName FROM #cols WHERE NormName = 'bronzeloaddts');

    DECLARE @FileCol sysname =
        (SELECT TOP (1) RealName FROM #cols WHERE NormName = 'sourcefile');

    IF @KeyCol IS NULL OR @LoadCol IS NULL
    BEGIN
        PRINT 'DEBUG: bronze.customer_raw columns detected:';
        SELECT column_id, RealName, NormName
        FROM #cols
        ORDER BY column_id;

        THROW 50002, 'Could not detect a key column and/or BronzeLoadDts on bronze.customer_raw. See DEBUG output.', 1;
    END

    PRINT 'Using key column: ' + QUOTENAME(@KeyCol);
    PRINT 'Using load column: ' + QUOTENAME(@LoadCol);

    /* 3) Drop targets */
    IF OBJECT_ID('silver.customer','U') IS NOT NULL DROP TABLE silver.customer;
    IF OBJECT_ID('silver.customer_reject','U') IS NOT NULL DROP TABLE silver.customer_reject;

    /* 4) Clone silver.customer from bronze */
    SELECT TOP (0) *
    INTO silver.customer
    FROM bronze.customer_raw;

    /* Add SilverLoadDts */
    ALTER TABLE silver.customer
      ADD SilverLoadDts datetime2(0) NOT NULL
          CONSTRAINT DF_silver_customer_SilverLoadDts DEFAULT SYSUTCDATETIME();

    /* 5) Reject table */
    CREATE TABLE silver.customer_reject (
        CustomerKey   varchar(200)  NULL,
        RejectReason  varchar(200)  NOT NULL,
        BronzeLoadDts datetime2(0)  NULL,
        SourceFile    varchar(260)  NULL,
        RejectLoadDts datetime2(0)  NOT NULL DEFAULT SYSUTCDATETIME()
    );

    /* 6) Build insert column list from silver.customer excluding SilverLoadDts */
    DECLARE @SilverObjId int = OBJECT_ID(N'silver.customer');
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
    FROM bronze.customer_raw b
)
SELECT *
INTO #Latest
FROM Deduped
WHERE rn = 1;

-- Reject missing key
INSERT INTO silver.customer_reject (CustomerKey, RejectReason, BronzeLoadDts, SourceFile)
SELECT
    CAST(l.' + QUOTENAME(@KeyCol) + N' AS varchar(200)) AS CustomerKey,
    ''Missing Customer key'',
    l.' + QUOTENAME(@LoadCol) + N' AS BronzeLoadDts,
    ' + CASE WHEN @FileCol IS NULL THEN N'NULL' ELSE N'l.' + QUOTENAME(@FileCol) END + N' AS SourceFile
FROM #Latest l
WHERE l.' + QUOTENAME(@KeyCol) + N' IS NULL
   OR LTRIM(RTRIM(CAST(l.' + QUOTENAME(@KeyCol) + N' AS varchar(200)))) = '''';

-- Insert good rows
INSERT INTO silver.customer (' + @InsertCols + N')
SELECT ' + @SelectCols + N'
FROM #Latest l
WHERE l.' + QUOTENAME(@KeyCol) + N' IS NOT NULL
  AND LTRIM(RTRIM(CAST(l.' + QUOTENAME(@KeyCol) + N' AS varchar(200)))) <> '''';
';

    EXEC sp_executesql @sql;

    /* 8) Validations */
    PRINT 'VALIDATION: counts';
    SELECT COUNT(*) AS BronzeCount FROM bronze.customer_raw;
    SELECT COUNT(*) AS SilverCount FROM silver.customer;
    SELECT COUNT(*) AS RejectCount FROM silver.customer_reject;

    SELECT TOP (50) * FROM silver.customer ORDER BY SilverLoadDts DESC;
    SELECT TOP (50) * FROM silver.customer_reject ORDER BY RejectLoadDts DESC;

    PRINT 'DONE: Silver Customer load complete.';

END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
