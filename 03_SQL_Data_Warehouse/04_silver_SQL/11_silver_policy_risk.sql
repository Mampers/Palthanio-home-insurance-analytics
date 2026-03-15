/*==============================================================================
  Palthanio Home Insurance Analytics
  Layer: Silver
  Object: silver.policy_risk
  Source: bronze.policy_risk

  ------------------------------------------------------------------------------
  PURPOSE
  ------------------------------------------------------------------------------
  Standardise and deduplicate Policy Risk records from the Bronze layer.

  Business Grain:
      1 row per PolicyID (latest BronzeLoadDts wins)

  Key Rules Applied:
      - Deduplicate by PolicyID using latest BronzeLoadDts
      - Reject rows where PolicyID is NULL/blank
      - Preserve the bronze structure exactly (clone table)
      - Add SilverLoadDts for auditability and lineage

  Outputs:
      - silver.policy_risk
      - silver.policy_risk_reject
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
    ===========================================================*/
    IF OBJECT_ID(N'bronze.policy_risk', 'U') IS NULL
        THROW 50001, 'Source table bronze.policy_risk not found in this database.', 1;

    /*===========================================================
      2) Drop targets (repeatable script)
    ===========================================================*/
    IF OBJECT_ID('silver.policy_risk','U') IS NOT NULL
        DROP TABLE silver.policy_risk;

    IF OBJECT_ID('silver.policy_risk_reject','U') IS NOT NULL
        DROP TABLE silver.policy_risk_reject;

    /*===========================================================
      3) Create silver.policy_risk by cloning bronze structure
         (prevents Msg 207 due to column mismatches)
    ===========================================================*/
    SELECT TOP (0) *
    INTO silver.policy_risk
    FROM bronze.policy_risk;

    /* Add SilverLoadDts */
    ALTER TABLE silver.policy_risk
      ADD SilverLoadDts datetime2(0) NOT NULL
          CONSTRAINT DF_silver_policy_risk_SilverLoadDts DEFAULT SYSUTCDATETIME();

    /*===========================================================
      4) Create reject table (minimal, stable structure)
    ===========================================================*/
    CREATE TABLE silver.policy_risk_reject (
        PolicyID      varchar(50)   NULL,
        RejectReason  varchar(200)  NOT NULL,
        BronzeLoadDts datetime2(0)  NULL,
        SourceFile    varchar(260)  NULL,
        RejectLoadDts datetime2(0)  NOT NULL DEFAULT SYSUTCDATETIME()
    );

    /*===========================================================
      5) Detect whether SourceFile exists in bronze (optional)
    ===========================================================*/
    DECLARE @HasSourceFile bit =
        CASE WHEN COL_LENGTH('bronze.policy_risk', 'SourceFile') IS NOT NULL THEN 1 ELSE 0 END;

    /*===========================================================
      6) Build #Latest once (dedupe)
         NOTE: CTE scope is single statement, so we materialise
    ===========================================================*/
    IF OBJECT_ID('tempdb..#Latest') IS NOT NULL DROP TABLE #Latest;

    ;WITH Deduped AS (
        SELECT
            b.*,
            ROW_NUMBER() OVER (
                PARTITION BY b.PolicyID
                ORDER BY b.BronzeLoadDts DESC
            ) AS rn
        FROM bronze.policy_risk b
    )
    SELECT *
    INTO #Latest
    FROM Deduped
    WHERE rn = 1;

    /*===========================================================
      7) Reject missing PolicyID
    ===========================================================*/
    IF @HasSourceFile = 1
    BEGIN
        INSERT INTO silver.policy_risk_reject (PolicyID, RejectReason, BronzeLoadDts, SourceFile)
        SELECT
            PolicyID,
            'Missing PolicyID',
            BronzeLoadDts,
            SourceFile
        FROM #Latest
        WHERE PolicyID IS NULL OR LTRIM(RTRIM(PolicyID)) = '';
    END
    ELSE
    BEGIN
        INSERT INTO silver.policy_risk_reject (PolicyID, RejectReason, BronzeLoadDts, SourceFile)
        SELECT
            PolicyID,
            'Missing PolicyID',
            BronzeLoadDts,
            NULL
        FROM #Latest
        WHERE PolicyID IS NULL OR LTRIM(RTRIM(PolicyID)) = '';
    END

    /*===========================================================
      8) Insert valid rows into silver.policy_risk
         Use dynamic column list from the silver table to ensure
         perfect alignment and avoid Msg 213 / Msg 207.
    ===========================================================*/
    DECLARE @SilverObjId int = OBJECT_ID(N'silver.policy_risk');
    DECLARE @InsertCols nvarchar(max);
    DECLARE @SelectCols nvarchar(max);

    SELECT
        @InsertCols = STRING_AGG(QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id),
        @SelectCols = STRING_AGG('l.' + QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.columns c
    WHERE c.object_id = @SilverObjId
      AND c.name <> 'SilverLoadDts';  -- default handles this

    DECLARE @sql nvarchar(max) = N'
INSERT INTO silver.policy_risk (' + @InsertCols + N')
SELECT ' + @SelectCols + N'
FROM #Latest l
WHERE l.PolicyID IS NOT NULL
  AND LTRIM(RTRIM(l.PolicyID)) <> '''';';

    EXEC sp_executesql @sql;

    /*===========================================================
      9) Validations
    ===========================================================*/
    PRINT 'VALIDATION: counts';
    SELECT COUNT(*) AS BronzeCount FROM bronze.policy_risk;
    SELECT COUNT(*) AS LatestCount FROM #Latest;
    SELECT COUNT(*) AS SilverCount FROM silver.policy_risk;
    SELECT COUNT(*) AS RejectCount FROM silver.policy_risk_reject;

    PRINT 'DONE: Silver Policy Risk load complete.';

END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;


SELECT *
FROM [silver].[policy_risk]
