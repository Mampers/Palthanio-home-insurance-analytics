/*==============================================================================
  Palthanio Home Insurance Analytics
  SILVER STAGE: Claim Payments (Clean + Type + Dedupe + Rejects)

  Purpose (Bronze -> Silver)
  --------------------------
  Bronze = raw ingestion (minimal rules; keep what arrived).
  Silver = cleansed + standardised + typed + deduplicated data, ready for
           Gold facts/dimensions and KPI calculations.

  This script:
  1) Ensures [silver] schema exists
  2) Recreates:
       - silver.claim_payments         (typed, deduped, clean)
       - silver.claim_payments_reject  (bad rows + reason)
  3) Deduplicates on PaymentID (latest BronzeLoadDts wins)
  4) Applies:
       - trim strings
       - UK date parsing (style 103)
       - numeric parsing to decimals
       - LargeLossFlag parsing to bit
  5) Outputs validation counts + duplicates check + sample rows

  Source:
    bronze.claim_payments_raw

  Targets:
    silver.claim_payments
    silver.claim_payments_reject
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
    ------------------------------------------------------------*/
    IF OBJECT_ID('silver.claim_payments','U') IS NOT NULL
        DROP TABLE silver.claim_payments;

    IF OBJECT_ID('silver.claim_payments_reject','U') IS NOT NULL
        DROP TABLE silver.claim_payments_reject;

    /*------------------------------------------------------------
      2) Create silver.claim_payments (explicit typed structure)
    ------------------------------------------------------------*/
    CREATE TABLE silver.claim_payments (
        PaymentID           varchar(50)    NOT NULL,
        ClaimID             varchar(50)    NOT NULL,

        PaymentDate         date           NULL,
        PaymentAmount       decimal(18,2)  NULL,

        PaymentMethod       varchar(50)    NULL,
        PaymentStatus       varchar(50)    NULL,

        ClaimType           varchar(100)   NULL,
        ClaimSeverityBand   varchar(50)    NULL,

        OutstandingReserve  decimal(18,2)  NULL,
        IncurredAmount      decimal(18,2)  NULL,

        LargeLossFlag       bit            NULL,

        -- lineage
        BronzeLoadDts       datetime2(0)   NOT NULL,
        SourceFile          varchar(260)  NULL,

        -- silver metadata
        SilverLoadDts       datetime2(0)   NOT NULL DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_silver_claim_payments__PaymentID PRIMARY KEY (PaymentID)
    );

    /*------------------------------------------------------------
      3) Create reject table
    ------------------------------------------------------------*/
    CREATE TABLE silver.claim_payments_reject (
        PaymentID      varchar(50)   NULL,
        ClaimID        varchar(50)   NULL,
        RejectReason   varchar(200)  NOT NULL,

        PaymentDateRaw        varchar(50)   NULL,
        PaymentAmountRaw      varchar(50)   NULL,
        OutstandingReserveRaw varchar(50)   NULL,
        IncurredAmountRaw     varchar(50)   NULL,
        LargeLossFlagRaw      varchar(50)   NULL,

        BronzeLoadDts   datetime2(0)  NULL,
        SourceFile      varchar(260)  NULL,
        RejectLoadDts   datetime2(0)  NOT NULL DEFAULT SYSUTCDATETIME()
    );

    /*------------------------------------------------------------
      4) Deduplicate source into #Latest (latest BronzeLoadDts wins)
         - #Latest is reused for both reject + good inserts
    ------------------------------------------------------------*/
    IF OBJECT_ID('tempdb..#Latest') IS NOT NULL
        DROP TABLE #Latest;

    ;WITH Deduped AS (
        SELECT
            b.*,
            ROW_NUMBER() OVER (
                PARTITION BY b.PaymentID
                ORDER BY b.BronzeLoadDts DESC
            ) AS rn
        FROM bronze.claim_payments_raw b
    )
    SELECT
        PaymentID,
        ClaimID,
        PaymentDate,
        PaymentAmount,
        PaymentMethod,
        PaymentStatus,
        ClaimType,
        ClaimSeverityBand,
        OutstandingReserve,
        IncurredAmount,
        LargeLossFlag,
        BronzeLoadDts,
        SourceFile
    INTO #Latest
    FROM Deduped
    WHERE rn = 1;

    /*------------------------------------------------------------
      5) Reject rows (missing keys or invalid type conversions)
         - UK dates expected: TRY_CONVERT(date, <text>, 103)
         - Numerics expected for amounts/reserve/incurred
         - LargeLossFlag expected: '0' or '1'
    ------------------------------------------------------------*/
    INSERT INTO silver.claim_payments_reject (
        PaymentID, ClaimID, RejectReason,
        PaymentDateRaw, PaymentAmountRaw, OutstandingReserveRaw, IncurredAmountRaw, LargeLossFlagRaw,
        BronzeLoadDts, SourceFile
    )
    SELECT
        l.PaymentID,
        l.ClaimID,
        CASE
            WHEN l.PaymentID IS NULL OR LTRIM(RTRIM(l.PaymentID)) = '' THEN 'Missing PaymentID'
            WHEN l.ClaimID   IS NULL OR LTRIM(RTRIM(l.ClaimID))   = '' THEN 'Missing ClaimID'
            WHEN LTRIM(RTRIM(ISNULL(l.PaymentDate,''))) <> ''
                 AND TRY_CONVERT(date, l.PaymentDate, 103) IS NULL THEN 'Invalid PaymentDate (expected UK dd/mm/yyyy)'
            WHEN LTRIM(RTRIM(ISNULL(l.PaymentAmount,''))) <> ''
                 AND TRY_CONVERT(decimal(18,2), l.PaymentAmount) IS NULL THEN 'Invalid PaymentAmount (not numeric)'
            WHEN LTRIM(RTRIM(ISNULL(l.OutstandingReserve,''))) <> ''
                 AND TRY_CONVERT(decimal(18,2), l.OutstandingReserve) IS NULL THEN 'Invalid OutstandingReserve (not numeric)'
            WHEN LTRIM(RTRIM(ISNULL(l.IncurredAmount,''))) <> ''
                 AND TRY_CONVERT(decimal(18,2), l.IncurredAmount) IS NULL THEN 'Invalid IncurredAmount (not numeric)'
            WHEN LTRIM(RTRIM(ISNULL(l.LargeLossFlag,''))) <> ''
                 AND l.LargeLossFlag NOT IN ('0','1') THEN 'Invalid LargeLossFlag (expected 0/1)'
            ELSE 'Rejected (unspecified)'
        END AS RejectReason,
        l.PaymentDate,
        l.PaymentAmount,
        l.OutstandingReserve,
        l.IncurredAmount,
        l.LargeLossFlag,
        l.BronzeLoadDts,
        l.SourceFile
    FROM #Latest l
    WHERE
        (l.PaymentID IS NULL OR LTRIM(RTRIM(l.PaymentID)) = '')
        OR (l.ClaimID IS NULL OR LTRIM(RTRIM(l.ClaimID)) = '')
        OR (LTRIM(RTRIM(ISNULL(l.PaymentDate,''))) <> '' AND TRY_CONVERT(date, l.PaymentDate, 103) IS NULL)
        OR (LTRIM(RTRIM(ISNULL(l.PaymentAmount,''))) <> '' AND TRY_CONVERT(decimal(18,2), l.PaymentAmount) IS NULL)
        OR (LTRIM(RTRIM(ISNULL(l.OutstandingReserve,''))) <> '' AND TRY_CONVERT(decimal(18,2), l.OutstandingReserve) IS NULL)
        OR (LTRIM(RTRIM(ISNULL(l.IncurredAmount,''))) <> '' AND TRY_CONVERT(decimal(18,2), l.IncurredAmount) IS NULL)
        OR (LTRIM(RTRIM(ISNULL(l.LargeLossFlag,''))) <> '' AND l.LargeLossFlag NOT IN ('0','1'));

    /*------------------------------------------------------------
      6) Insert valid rows into silver.claim_payments (typed)
    ------------------------------------------------------------*/
    INSERT INTO silver.claim_payments (
        PaymentID,
        ClaimID,
        PaymentDate,
        PaymentAmount,
        PaymentMethod,
        PaymentStatus,
        ClaimType,
        ClaimSeverityBand,
        OutstandingReserve,
        IncurredAmount,
        LargeLossFlag,
        BronzeLoadDts,
        SourceFile
    )
    SELECT
        LTRIM(RTRIM(l.PaymentID)) AS PaymentID,
        LTRIM(RTRIM(l.ClaimID))   AS ClaimID,

        CASE
            WHEN LTRIM(RTRIM(ISNULL(l.PaymentDate,''))) = '' THEN NULL
            ELSE TRY_CONVERT(date, l.PaymentDate, 103)
        END AS PaymentDate,

        CASE
            WHEN LTRIM(RTRIM(ISNULL(l.PaymentAmount,''))) = '' THEN NULL
            ELSE TRY_CONVERT(decimal(18,2), l.PaymentAmount)
        END AS PaymentAmount,

        NULLIF(LTRIM(RTRIM(l.PaymentMethod)), '')     AS PaymentMethod,
        NULLIF(LTRIM(RTRIM(l.PaymentStatus)), '')     AS PaymentStatus,
        NULLIF(LTRIM(RTRIM(l.ClaimType)), '')         AS ClaimType,
        NULLIF(LTRIM(RTRIM(l.ClaimSeverityBand)), '') AS ClaimSeverityBand,

        CASE
            WHEN LTRIM(RTRIM(ISNULL(l.OutstandingReserve,''))) = '' THEN NULL
            ELSE TRY_CONVERT(decimal(18,2), l.OutstandingReserve)
        END AS OutstandingReserve,

        CASE
            WHEN LTRIM(RTRIM(ISNULL(l.IncurredAmount,''))) = '' THEN NULL
            ELSE TRY_CONVERT(decimal(18,2), l.IncurredAmount)
        END AS IncurredAmount,

        CASE
            WHEN LTRIM(RTRIM(ISNULL(l.LargeLossFlag,''))) = '' THEN NULL
            WHEN l.LargeLossFlag IN ('0','1') THEN CONVERT(bit, CONVERT(int, l.LargeLossFlag))
            ELSE NULL
        END AS LargeLossFlag,

        l.BronzeLoadDts,
        l.SourceFile
    FROM #Latest l
    WHERE
        -- key checks
        l.PaymentID IS NOT NULL AND LTRIM(RTRIM(l.PaymentID)) <> ''
        AND l.ClaimID IS NOT NULL AND LTRIM(RTRIM(l.ClaimID)) <> ''
        -- type checks
        AND (LTRIM(RTRIM(ISNULL(l.PaymentDate,''))) = '' OR TRY_CONVERT(date, l.PaymentDate, 103) IS NOT NULL)
        AND (LTRIM(RTRIM(ISNULL(l.PaymentAmount,''))) = '' OR TRY_CONVERT(decimal(18,2), l.PaymentAmount) IS NOT NULL)
        AND (LTRIM(RTRIM(ISNULL(l.OutstandingReserve,''))) = '' OR TRY_CONVERT(decimal(18,2), l.OutstandingReserve) IS NOT NULL)
        AND (LTRIM(RTRIM(ISNULL(l.IncurredAmount,''))) = '' OR TRY_CONVERT(decimal(18,2), l.IncurredAmount) IS NOT NULL)
        AND (LTRIM(RTRIM(ISNULL(l.LargeLossFlag,''))) = '' OR l.LargeLossFlag IN ('0','1'));

    /*------------------------------------------------------------
      7) Validations (portfolio-friendly)
    ------------------------------------------------------------*/
    PRINT 'VALIDATION: Row counts';
    SELECT COUNT(*) AS BronzeCount FROM bronze.claim_payments_raw;
    SELECT COUNT(*) AS LatestCount FROM #Latest;
    SELECT COUNT(*) AS SilverCount FROM silver.claim_payments;
    SELECT COUNT(*) AS RejectCount FROM silver.claim_payments_reject;

    PRINT 'VALIDATION: Duplicate PaymentID in silver (should be 0 rows)';
    SELECT PaymentID, COUNT(*) AS Cnt
    FROM silver.claim_payments
    GROUP BY PaymentID
    HAVING COUNT(*) > 1;

    PRINT 'SAMPLE: silver.claim_payments';
    SELECT TOP (50) *
    FROM silver.claim_payments
    ORDER BY SilverLoadDts DESC, PaymentID;

    PRINT 'SAMPLE: silver.claim_payments_reject';
    SELECT TOP (50) *
    FROM silver.claim_payments_reject
    ORDER BY RejectLoadDts DESC;

    PRINT 'DONE: Silver Claim Payments load complete.';

END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
