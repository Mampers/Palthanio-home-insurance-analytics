/*==============================================================================
  Palthanio Home Insurance Analytics
  SILVER STAGE: Broker (Clean + Dedupe + Rejects)

  Purpose (Bronze -> Silver)
  --------------------------
  Bronze is raw ingestion (minimal typing/validation, keep what arrived).
  Silver is cleansed + standardised + deduplicated data ready to be used to
  build Dimensions/Facts in the Gold layer (or a curated Silver Dim).

  This script:
  1) Ensures the [silver] schema exists
  2) Recreates:
       - silver.broker        (clean, deduped, standardised)
       - silver.broker_reject (records rejected for missing key)
  3) Deduplicates on BrokerID, keeping the latest record by BronzeLoadDts
  4) Applies light cleansing (trim strings, convert blanks to NULL)
  5) Loads data + outputs validation counts

  Source:
    bronze.broker_raw

  Targets:
    silver.broker
    silver.broker_reject

  Notes for portfolio:
  - Use explicit column lists on INSERT statements (prevents column-order issues)
  - Use #Latest temp table to avoid CTE scope problems across multiple INSERTs
  - Enforce a primary key on BrokerID to guarantee uniqueness in Silver
==============================================================================*/

USE PalthanioHomeInsuranceDW;
SET NOCOUNT ON;

BEGIN TRY

    /*------------------------------------------------------------
      0) Ensure schema exists
    ------------------------------------------------------------*/
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
        EXEC('CREATE SCHEMA silver;');

    /*------------------------------------------------------------
      1) Drop & recreate target tables (repeatable script)
         - For portfolio: keep scripts re-runnable to support demos
    ------------------------------------------------------------*/
    IF OBJECT_ID('silver.broker','U') IS NOT NULL
        DROP TABLE silver.broker;

    IF OBJECT_ID('silver.broker_reject','U') IS NOT NULL
        DROP TABLE silver.broker_reject;

    /*------------------------------------------------------------
      2) Create silver.broker (explicit structure)
         - Stores one row per BrokerID
         - SilverLoadDts is set automatically at load time
    ------------------------------------------------------------*/
    CREATE TABLE silver.broker (
        BrokerID                  varchar(50)    NOT NULL,
        BrokerName                varchar(200)   NULL,
        Channel                   varchar(50)    NULL,
        Region                    varchar(100)   NULL,
        Status                    varchar(50)    NULL,
        AppointmentYear           int            NULL,
        RelationshipTenureYears   int            NULL,
        CommissionRate            decimal(18,4)  NULL,
        CommissionModel           varchar(200)   NULL,
        EstimatedAnnualGWP_GBP    decimal(18,2)  NULL,
        BrokerSizeBand            varchar(50)    NULL,

        -- Bronze metadata retained for lineage and debugging
        BronzeLoadDts             datetime2(0)   NOT NULL,
        SourceFile                varchar(260)   NULL,

        -- Silver metadata
        SilverLoadDts             datetime2(0)   NOT NULL DEFAULT SYSUTCDATETIME(),

        -- Enforce uniqueness per business key in Silver
        CONSTRAINT PK_silver_broker__BrokerID PRIMARY KEY (BrokerID)
    );

    /*------------------------------------------------------------
      3) Create reject table
         - Captures rows that cannot be loaded due to missing key
         - Helps quantify data quality issues in the pipeline
    ------------------------------------------------------------*/
    CREATE TABLE silver.broker_reject (
        BrokerID      varchar(50)   NULL,
        RejectReason  varchar(200)  NOT NULL,
        BronzeLoadDts datetime2(0)  NULL,
        SourceFile    varchar(260)  NULL,
        RejectLoadDts datetime2(0)  NOT NULL DEFAULT SYSUTCDATETIME()
    );

    /*------------------------------------------------------------
      4) Deduplicate source data into #Latest
         - Keep the latest record per BrokerID using BronzeLoadDts
         - #Latest is used so we can reuse it for both inserts (reject + good)
    ------------------------------------------------------------*/
    IF OBJECT_ID('tempdb..#Latest') IS NOT NULL DROP TABLE #Latest;

    ;WITH Deduped AS (
        SELECT
            b.*,
            ROW_NUMBER() OVER (
                PARTITION BY b.BrokerID
                ORDER BY b.BronzeLoadDts DESC
            ) AS rn
        FROM bronze.broker_raw b
    )
    SELECT
        BrokerID,
        BrokerName,
        Channel,
        Region,
        Status,
        AppointmentYear,
        RelationshipTenureYears,
        CommissionRate,
        CommissionModel,
        EstimatedAnnualGWP_GBP,
        BrokerSizeBand,
        BronzeLoadDts,
        SourceFile
    INTO #Latest
    FROM Deduped
    WHERE rn = 1;

    /*------------------------------------------------------------
      5) Reject rows with missing business key
         - BrokerID is required to uniquely identify broker records
    ------------------------------------------------------------*/
    INSERT INTO silver.broker_reject (BrokerID, RejectReason, BronzeLoadDts, SourceFile)
    SELECT
        BrokerID,
        'Missing BrokerID' AS RejectReason,
        BronzeLoadDts,
        SourceFile
    FROM #Latest
    WHERE BrokerID IS NULL OR LTRIM(RTRIM(BrokerID)) = '';

    /*------------------------------------------------------------
      6) Insert valid rows into silver.broker
         Cleansing rules:
         - TRIM string fields to remove accidental whitespace
         - Convert empty strings to NULL using NULLIF(...,'')
         - Keep numeric fields as-is (assumes Bronze types are correct)
    ------------------------------------------------------------*/
    INSERT INTO silver.broker (
        BrokerID,
        BrokerName,
        Channel,
        Region,
        Status,
        AppointmentYear,
        RelationshipTenureYears,
        CommissionRate,
        CommissionModel,
        EstimatedAnnualGWP_GBP,
        BrokerSizeBand,
        BronzeLoadDts,
        SourceFile
    )
    SELECT
        LTRIM(RTRIM(BrokerID))                        AS BrokerID,
        NULLIF(LTRIM(RTRIM(BrokerName)), '')          AS BrokerName,
        NULLIF(LTRIM(RTRIM(Channel)), '')             AS Channel,
        NULLIF(LTRIM(RTRIM(Region)), '')              AS Region,
        NULLIF(LTRIM(RTRIM(Status)), '')              AS Status,
        AppointmentYear,
        RelationshipTenureYears,
        CommissionRate,
        NULLIF(LTRIM(RTRIM(CommissionModel)), '')     AS CommissionModel,
        EstimatedAnnualGWP_GBP,
        NULLIF(LTRIM(RTRIM(BrokerSizeBand)), '')      AS BrokerSizeBand,
        BronzeLoadDts,
        SourceFile
    FROM #Latest
    WHERE BrokerID IS NOT NULL AND LTRIM(RTRIM(BrokerID)) <> '';

    /*------------------------------------------------------------
      7) Validation queries (portfolio-friendly)
         - Row counts
         - Duplicates check (should be zero)
         - Sample outputs
    ------------------------------------------------------------*/
    PRINT 'VALIDATION: Row counts';
    SELECT COUNT(*) AS BronzeCount FROM bronze.broker_raw;
    SELECT COUNT(*) AS LatestCount FROM #Latest;
    SELECT COUNT(*) AS SilverCount FROM silver.broker;
    SELECT COUNT(*) AS RejectCount FROM silver.broker_reject;

    PRINT 'VALIDATION: Duplicate BrokerID in silver (should return 0 rows)';
    SELECT BrokerID, COUNT(*) AS Cnt
    FROM silver.broker
    GROUP BY BrokerID
    HAVING COUNT(*) > 1;

    PRINT 'SAMPLE: silver.broker';
    SELECT TOP (50) *
    FROM silver.broker
    ORDER BY SilverLoadDts DESC, BrokerID;

    PRINT 'SAMPLE: silver.broker_reject';
    SELECT TOP (50) *
    FROM silver.broker_reject
    ORDER BY RejectLoadDts DESC;

    PRINT 'DONE: Silver Broker load complete.';

END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;


SELECT *
FROM silver.broker

