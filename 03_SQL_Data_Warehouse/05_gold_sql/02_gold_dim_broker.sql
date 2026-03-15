/*==============================================================================
  Palthanio Home Insurance Analytics
  GOLD DIMENSION: Broker (Dimensional + Surrogate Key)

  Purpose (Silver -> Gold)
  ------------------------
  Silver is cleansed + deduplicated.
  Gold is dimensional (star-schema ready) with surrogate keys for stable joins.

  This script:
  1) Ensures the [gold] schema exists
  2) Recreates:
       - gold.dim_broker
  3) Inserts an UNKNOWN row (BrokerKey = -1)
  4) Loads all rows from silver.broker (Type 1 snapshot load for portfolio)
  5) Outputs validation counts + sample outputs

  Source:
    silver.broker

  Target:
    gold.dim_broker

  Notes for portfolio:
  - Explicit table definition (clear + enterprise readable)
  - Surrogate key added for star schema joins (BrokerKey)
  - Keep lineage columns (BronzeLoadDts / SilverLoadDts / SourceFile)
==============================================================================*/

USE PalthanioHomeInsuranceDW;
SET NOCOUNT ON;

BEGIN TRY

    /*------------------------------------------------------------
      0) Pre-flight checks
    ------------------------------------------------------------*/
    IF OBJECT_ID('silver.broker','U') IS NULL
        THROW 63001, 'Source table silver.broker does not exist. Run Silver first.', 1;

    DECLARE @SilverRowCount int;
    SELECT @SilverRowCount = COUNT(*) FROM silver.broker;

    IF @SilverRowCount = 0
        THROW 63002, 'Source table silver.broker exists but contains 0 rows.', 1;

    PRINT CONCAT('Pre-flight OK. silver.broker rows = ', @SilverRowCount);

    /*------------------------------------------------------------
      1) Ensure schema exists
    ------------------------------------------------------------*/
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
        EXEC('CREATE SCHEMA gold;');

    /*------------------------------------------------------------
      2) Drop & recreate (repeatable script)
    ------------------------------------------------------------*/
    IF OBJECT_ID('gold.dim_broker','U') IS NOT NULL
        DROP TABLE gold.dim_broker;

    /*------------------------------------------------------------
      3) Create gold.dim_broker (explicit structure)
         - BrokerKey is the surrogate key for joins
         - BrokerID is the business key (unique)
         - Keep Silver lineage/metadata columns
    ------------------------------------------------------------*/
    CREATE TABLE gold.dim_broker
    (
        -- Surrogate Key (for star schema joins)
        BrokerKey                int            IDENTITY(1,1) NOT NULL,

        -- Business Key
        BrokerID                 varchar(50)    NOT NULL,

        -- Descriptive attributes (from silver.broker)
        BrokerName               varchar(200)   NULL,
        Channel                  varchar(50)    NULL,
        Region                   varchar(100)   NULL,
        Status                   varchar(50)    NULL,
        AppointmentYear          int            NULL,
        RelationshipTenureYears  int            NULL,
        CommissionRate           decimal(18,4)  NULL,
        CommissionModel          varchar(200)   NULL,
        EstimatedAnnualGWP_GBP   decimal(18,2)  NULL,
        BrokerSizeBand           varchar(50)    NULL,

        -- Lineage (carried from Silver)
        BronzeLoadDts            datetime2(0)   NOT NULL,
        SourceFile               varchar(260)   NULL,
        SilverLoadDts            datetime2(0)   NOT NULL,

        -- Gold metadata
        GoldLoadDts              datetime2(0)   NOT NULL DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_gold_dim_broker__BrokerKey PRIMARY KEY (BrokerKey),
        CONSTRAINT UQ_gold_dim_broker__BrokerID UNIQUE (BrokerID)
    );

    /*------------------------------------------------------------
      4) Insert UNKNOWN row (BrokerKey = -1)
         - Helps avoid broken joins in facts (unknown/missing broker)
         - Provide safe non-null values for required columns
    ------------------------------------------------------------*/
    SET IDENTITY_INSERT gold.dim_broker ON;

    INSERT INTO gold.dim_broker
    (
        BrokerKey,
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
        SourceFile,
        SilverLoadDts
    )
    VALUES
    (
        -1,
        'UNKNOWN',
        'Unknown Broker',
        'Unknown',
        'Unknown',
        'Unknown',
        NULL,
        NULL,
        NULL,
        'Unknown',
        NULL,
        'Unknown',
        CONVERT(datetime2(0), '1900-01-01'),
        NULL,
        CONVERT(datetime2(0), '1900-01-01')
    );

    SET IDENTITY_INSERT gold.dim_broker OFF;

    /*------------------------------------------------------------
      5) Load data from silver.broker
         - Silver already deduped + PK enforced, so we can load directly
         - Apply light trimming again as a safety net
    ------------------------------------------------------------*/
    INSERT INTO gold.dim_broker
    (
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
        SourceFile,
        SilverLoadDts
    )
    SELECT
        LTRIM(RTRIM(BrokerID))                       AS BrokerID,
        NULLIF(LTRIM(RTRIM(BrokerName)), '')         AS BrokerName,
        NULLIF(LTRIM(RTRIM(Channel)), '')            AS Channel,
        NULLIF(LTRIM(RTRIM(Region)), '')             AS Region,
        NULLIF(LTRIM(RTRIM(Status)), '')             AS Status,
        AppointmentYear,
        RelationshipTenureYears,
        CommissionRate,
        NULLIF(LTRIM(RTRIM(CommissionModel)), '')    AS CommissionModel,
        EstimatedAnnualGWP_GBP,
        NULLIF(LTRIM(RTRIM(BrokerSizeBand)), '')     AS BrokerSizeBand,
        BronzeLoadDts,
        SourceFile,
        SilverLoadDts
    FROM silver.broker
    WHERE BrokerID IS NOT NULL
      AND LTRIM(RTRIM(BrokerID)) <> '';

    /*------------------------------------------------------------
      6) Helpful index for joins (Power BI / facts)
    ------------------------------------------------------------*/
    CREATE INDEX IX_gold_dim_broker__BrokerID
        ON gold.dim_broker (BrokerID);

    /*------------------------------------------------------------
      7) Validation queries
    ------------------------------------------------------------*/
    PRINT 'VALIDATION: Row counts';
    SELECT COUNT(*) AS SilverCount FROM silver.broker;
    SELECT COUNT(*) AS GoldDimCount FROM gold.dim_broker;

    PRINT 'VALIDATION: Duplicate BrokerID in gold (should return 0 rows)';
    SELECT BrokerID, COUNT(*) AS Cnt
    FROM gold.dim_broker
    GROUP BY BrokerID
    HAVING COUNT(*) > 1;

    PRINT 'SAMPLE: gold.dim_broker';
    SELECT TOP (50) *
    FROM gold.dim_broker
    ORDER BY GoldLoadDts DESC, BrokerKey DESC;

    PRINT 'DONE: Gold Broker dimension load complete.';

END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;



SELECT TOP 40 *
FROM gold.dim_broker
