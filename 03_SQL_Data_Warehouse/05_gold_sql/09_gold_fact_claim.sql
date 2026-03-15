/*==============================================================================
  DATABASE:      PalthanioHomeInsuranceDW
  LAYER:         GOLD
  OBJECT:        gold.fact_claim
  SOURCE:        silver.claims

  AUTHOR:        Paul Mampilly (Portfolio Project)
  CREATED:       2026-03-04

  PURPOSE
  -------
  Create the Gold CLAIM FACT table (one row per ClaimID) for star-schema
  analytics and downstream joins to claim payments/reserves.

  WHY FACT (NOT DIM)?
  -------------------
  A claim is an event/transaction and typically sits as a fact table:
    - it has event dates (Loss/Reported/Closed)
    - it has measures and flags (duration, fraud, reopened, etc.)
    - it links to other facts (payments/reserves) and dimensions (status/type)

  DESIGN
  ------
  Grain: 1 row per ClaimID (claim header)
  Keys:
    - ClaimID is the natural/business key for this portfolio dataset
    - (Optional future) add surrogate ClaimKey if you want
  Dates:
    - LossDate / ReportedDate / ClosedDate are stored as DATE
    - Robust parsing handles common incoming formats from CSV strings

  LINEAGE
  -------
  - BronzeLoadDts, SilverLoadDts, SourceFile carried into Gold
  - GoldLoadDts indicates when the Gold row was loaded/refreshed

==============================================================================*/

USE PalthanioHomeInsuranceDW;
GO
SET NOCOUNT ON;
GO

/*==============================================================================
  0) PRE-FLIGHT CHECKS
==============================================================================*/
IF OBJECT_ID('silver.claims','U') IS NULL
BEGIN
    THROW 65001, 'Source table silver.claims does not exist. Run Silver first.', 1;
END;

DECLARE @SilverRowCount int;
SELECT @SilverRowCount = COUNT(*) FROM silver.claims;

IF @SilverRowCount = 0
BEGIN
    THROW 65002, 'Source table silver.claims exists but contains 0 rows.', 1;
END;

PRINT CONCAT('Pre-flight OK. silver.claims rows = ', @SilverRowCount);
GO

/*==============================================================================
  1) ENSURE GOLD SCHEMA EXISTS
==============================================================================*/
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='gold')
    EXEC('CREATE SCHEMA gold;');
GO

/*==============================================================================
  2) DROP + RECREATE (REPEATABLE DEV MODE)
==============================================================================*/
IF OBJECT_ID('gold.fact_claim','U') IS NOT NULL
    DROP TABLE gold.fact_claim;
GO

/*==============================================================================
  3) CREATE FACT TABLE
==============================================================================*/
CREATE TABLE gold.fact_claim
(
    -- Business key (grain = 1 row per ClaimID)
    ClaimID             varchar(50)   NOT NULL,

    -- Relationships (natural keys for now; can be replaced with surrogate keys later)
    PolicyID            varchar(50)   NULL,

    -- Event dates (typed)
    LossDate            date          NULL,
    ReportedDate        date          NULL,
    ClosedDate          date          NULL,

    -- Descriptive attributes (can be replaced with dim keys later)
    ClaimType           varchar(50)   NULL,
    Severity            varchar(50)   NULL,
    ClaimStatus         varchar(50)   NULL,
    ClaimComplexity     varchar(50)   NULL,

    -- Operational measures/flags
    ReportingDelayDays  int           NULL,
    ClaimDurationDays   int           NULL,
    ReopenedFlag        bit           NULL,
    FraudFlag           bit           NULL,
    CatEventFlag        bit           NULL,

    -- Lineage
    BronzeLoadDts       datetime2(0)  NOT NULL,
    SourceFile          varchar(260)  NULL,
    SilverLoadDts       datetime2(0)  NOT NULL,

    -- Gold metadata
    GoldLoadDts         datetime2(0)  NOT NULL
        CONSTRAINT DF_gold_fact_claim_GoldLoadDts DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_gold_fact_claim PRIMARY KEY (ClaimID)
);
GO

/*==============================================================================
  4) LOAD DATA (BULLET-PROOF DATE PARSING)
==============================================================================*/
;WITH Normalised AS
(
    SELECT
        s.ClaimID,
        s.PolicyID,
        s.ClaimType,
        s.Severity,
        s.ClaimStatus,
        s.ReportingDelayDays,
        s.ClaimDurationDays,
        s.ReopenedFlag,
        s.FraudFlag,
        s.CatEventFlag,
        s.ClaimComplexity,
        s.BronzeLoadDts,
        s.SourceFile,
        s.SilverLoadDts,

        -- Normalise date strings (handles: quotes, ISO T, whitespace)
        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(CAST(s.LossDate     AS varchar(50)),'"',''),'T',' '))), '') AS LossDateNorm,
        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(CAST(s.ReportedDate AS varchar(50)),'"',''),'T',' '))), '') AS ReportedDateNorm,
        NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(CAST(s.ClosedDate   AS varchar(50)),'"',''),'T',' '))), '') AS ClosedDateNorm
    FROM silver.claims s
    WHERE s.ClaimID IS NOT NULL
      AND LTRIM(RTRIM(s.ClaimID)) <> ''
),
Typed AS
(
    SELECT
        n.*,

        COALESCE(
            TRY_CONVERT(date, n.LossDateNorm, 103),  -- dd/mm/yyyy
            TRY_CONVERT(date, n.LossDateNorm, 23),   -- yyyy-mm-dd
            TRY_CONVERT(date, n.LossDateNorm, 120),  -- yyyy-mm-dd hh:mm:ss
            TRY_CONVERT(date, n.LossDateNorm, 126)   -- ISO8601
        ) AS LossDate_Typed,

        COALESCE(
            TRY_CONVERT(date, n.ReportedDateNorm, 103),
            TRY_CONVERT(date, n.ReportedDateNorm, 23),
            TRY_CONVERT(date, n.ReportedDateNorm, 120),
            TRY_CONVERT(date, n.ReportedDateNorm, 126)
        ) AS ReportedDate_Typed,

        COALESCE(
            TRY_CONVERT(date, n.ClosedDateNorm, 103),
            TRY_CONVERT(date, n.ClosedDateNorm, 23),
            TRY_CONVERT(date, n.ClosedDateNorm, 120),
            TRY_CONVERT(date, n.ClosedDateNorm, 126)
        ) AS ClosedDate_Typed
    FROM Normalised n
)
INSERT INTO gold.fact_claim
(
    ClaimID,
    PolicyID,
    LossDate,
    ReportedDate,
    ClosedDate,
    ClaimType,
    Severity,
    ClaimStatus,
    ClaimComplexity,
    ReportingDelayDays,
    ClaimDurationDays,
    ReopenedFlag,
    FraudFlag,
    CatEventFlag,
    BronzeLoadDts,
    SourceFile,
    SilverLoadDts
)
SELECT
    LTRIM(RTRIM(ClaimID))                          AS ClaimID,
    NULLIF(LTRIM(RTRIM(PolicyID)),'')              AS PolicyID,
    LossDate_Typed                                 AS LossDate,
    ReportedDate_Typed                             AS ReportedDate,
    ClosedDate_Typed                               AS ClosedDate,
    NULLIF(LTRIM(RTRIM(ClaimType)),'')             AS ClaimType,
    NULLIF(LTRIM(RTRIM(Severity)),'')              AS Severity,
    NULLIF(LTRIM(RTRIM(ClaimStatus)),'')           AS ClaimStatus,
    NULLIF(LTRIM(RTRIM(ClaimComplexity)),'')       AS ClaimComplexity,
    ReportingDelayDays,
    ClaimDurationDays,
    ReopenedFlag,
    FraudFlag,
    CatEventFlag,
    BronzeLoadDts,
    SourceFile,
    SilverLoadDts
FROM Typed;
GO

/*==============================================================================
  5) INDEXES (JOIN PERFORMANCE)
==============================================================================*/
CREATE INDEX IX_gold_fact_claim_PolicyID
ON gold.fact_claim(PolicyID);
GO

/*==============================================================================
  6) POST-LOAD VALIDATION
==============================================================================*/
-- Row count check
SELECT COUNT(*) AS SilverRows FROM silver.claims;
SELECT COUNT(*) AS GoldRows   FROM gold.fact_claim;

-- Date parsing quality
SELECT
    SUM(CASE WHEN LossDate     IS NULL THEN 1 ELSE 0 END) AS NullLossDate,
    SUM(CASE WHEN ReportedDate IS NULL THEN 1 ELSE 0 END) AS NullReportedDate,
    SUM(CASE WHEN ClosedDate   IS NULL THEN 1 ELSE 0 END) AS NullClosedDate,
    COUNT(*) AS TotalRows
FROM gold.fact_claim;

-- Quick sample (best to view populated rows)
SELECT TOP 25 ClaimID, LossDate, ReportedDate, ClosedDate, ClaimStatus
FROM gold.fact_claim
WHERE LossDate IS NOT NULL
ORDER BY LossDate DESC;
GO



SELECT *
FROM gold.fact_claim
ORDER BY ClaimID DESC

SELECT *
FROM silver.claims
ORDER BY ClaimID DESC
