/*==============================================================================
  Palthanio Home Insurance Analytics
  SILVER STAGE: Claims (SAFE + Dedupe + Rejects)

  Why "SAFE"?
  ----------
  Claims datasets often evolve (extra columns get added/renamed).
  This script avoids Msg 207 errors by NOT guessing claim column names.
  Instead, it:
    - clones the Silver table structure from the Bronze table (exact match)
    - dedupes on ClaimID (latest BronzeLoadDts wins)
    - rejects missing/blank ClaimID
    - adds SilverLoadDts as the Silver metadata timestamp

  Source:
    bronze.claims_raw

  Targets:
    silver.claims
    silver.claims_reject
==============================================================================*/

USE PalthanioHomeInsuranceDW;
SET NOCOUNT ON;

BEGIN TRY

    /*------------------------------------------------------------
      0) Ensure silver schema exists
    ------------------------------------------------------------*/
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
        EXEC('CREATE SCHEMA silver;');

    /*------------------------------------------------------------
      1) Drop targets (repeatable script)
    ------------------------------------------------------------*/
    IF OBJECT_ID('silver.claims','U') IS NOT NULL
        DROP TABLE silver.claims;

    IF OBJECT_ID('silver.claims_reject','U') IS NOT NULL
        DROP TABLE silver.claims_reject;

    /*------------------------------------------------------------
      2) Create silver.claims by cloning bronze structure
         - Ensures column names + order match exactly
    ------------------------------------------------------------*/
    SELECT TOP (0) *
    INTO silver.claims
    FROM bronze.claims_raw;

    /* Add SilverLoadDts (Silver metadata) */
    ALTER TABLE silver.claims
      ADD SilverLoadDts datetime2(0) NOT NULL
          CONSTRAINT DF_silver_claims_SilverLoadDts DEFAULT SYSUTCDATETIME();

    /*------------------------------------------------------------
      3) Create reject table (minimal but useful)
    ------------------------------------------------------------*/
    CREATE TABLE silver.claims_reject (
        ClaimID       varchar(200)  NULL,
        RejectReason  varchar(200)  NOT NULL,
        BronzeLoadDts datetime2(0)  NULL,
        SourceFile    varchar(260)  NULL,
        RejectLoadDts datetime2(0)  NOT NULL DEFAULT SYSUTCDATETIME()
    );

    /*------------------------------------------------------------
      4) Build INSERT column list from silver.claims
         - Excludes SilverLoadDts (default will populate it)
    ------------------------------------------------------------*/
    DECLARE @SilverObjId int = OBJECT_ID(N'silver.claims');
    DECLARE @InsertCols nvarchar(max);
    DECLARE @SelectCols nvarchar(max);

    SELECT
        @InsertCols = STRING_AGG(QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id),
        @SelectCols = STRING_AGG('l.' + QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.columns c
    WHERE c.object_id = @SilverObjId
      AND c.name <> 'SilverLoadDts';

    /*------------------------------------------------------------
      5) Dedupe + reject + insert
         - Uses #Latest (materialised) to avoid CTE scope issues
         - Uses dynamic SQL only to safely apply the generated column lists
    ------------------------------------------------------------*/
    DECLARE @sql nvarchar(max) = N'
IF OBJECT_ID(''tempdb..#Latest'') IS NOT NULL DROP TABLE #Latest;

;WITH Deduped AS (
    SELECT
        b.*,
        ROW_NUMBER() OVER (
            PARTITION BY b.[ClaimID]
            ORDER BY b.[BronzeLoadDts] DESC
        ) AS rn
    FROM bronze.claims_raw b
)
SELECT *
INTO #Latest
FROM Deduped
WHERE rn = 1;

-- Reject missing ClaimID
INSERT INTO silver.claims_reject (ClaimID, RejectReason, BronzeLoadDts, SourceFile)
SELECT
    CAST(l.[ClaimID] AS varchar(200)),
    ''Missing ClaimID'',
    l.[BronzeLoadDts],
    l.[SourceFile]
FROM #Latest l
WHERE l.[ClaimID] IS NULL
   OR LTRIM(RTRIM(CAST(l.[ClaimID] AS varchar(200)))) = '''';

-- Insert good rows (exact structure match; SilverLoadDts uses default)
INSERT INTO silver.claims (' + @InsertCols + N')
SELECT ' + @SelectCols + N'
FROM #Latest l
WHERE l.[ClaimID] IS NOT NULL
  AND LTRIM(RTRIM(CAST(l.[ClaimID] AS varchar(200)))) <> '''';
';

    EXEC sp_executesql @sql;

    /*------------------------------------------------------------
      6) Validations (portfolio-friendly)
    ------------------------------------------------------------*/
    PRINT 'VALIDATION: Row counts';
    SELECT COUNT(*) AS BronzeCount FROM bronze.claims_raw;
    SELECT COUNT(*) AS SilverCount FROM silver.claims;
    SELECT COUNT(*) AS RejectCount FROM silver.claims_reject;

    PRINT 'SAMPLE: silver.claims';
    SELECT TOP (50) * FROM silver.claims ORDER BY SilverLoadDts DESC;

    PRINT 'SAMPLE: silver.claims_reject';
    SELECT TOP (50) * FROM silver.claims_reject ORDER BY RejectLoadDts DESC;

    PRINT 'DONE: Silver Claims load complete.';

END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
