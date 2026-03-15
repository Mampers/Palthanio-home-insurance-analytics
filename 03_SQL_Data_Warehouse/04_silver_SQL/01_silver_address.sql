/*==============================================================================
  SILVER STAGE: address (CLEAN + DEDUPED)
  Source: bronze.address_raw  -->  Target: silver.address

  Key behaviours:
  - Deduplicate AddressID (latest BronzeLoadDts wins)
  - Clean strings (trim, empty -> NULL)
  - Fix RebuildCostEstimate conversion by stripping CR/LF (CHAR(13)/CHAR(10))
  - Load rejects for missing AddressID and for non-convertible rebuild cost
==============================================================================*/

USE PalthanioHomeInsuranceDW;
GO
SET NOCOUNT ON;
GO

BEGIN TRY

    /*------------------------------------------------------------
      0) Ensure schema
    ------------------------------------------------------------*/
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
        EXEC('CREATE SCHEMA silver;');

    /*------------------------------------------------------------
      1) HARD CLEANUP: Drop any existing constraint with the same name
         (This avoids Msg 2714 "already an object named ...")
    ------------------------------------------------------------*/
    DECLARE @sql nvarchar(max) = N'';

    SELECT @sql = @sql + N'
    ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(t.schema_id)) + N'.' + QUOTENAME(t.name) +
    N' DROP CONSTRAINT ' + QUOTENAME(dc.name) + N';'
    FROM sys.default_constraints dc
    JOIN sys.tables t
      ON dc.parent_object_id = t.object_id
    WHERE dc.name = 'DF_silver_address_SilverLoadDts';

    IF (@sql <> N'')
        EXEC sp_executesql @sql;

    /*------------------------------------------------------------
      2) Drop target tables (repeatable)
    ------------------------------------------------------------*/
    IF OBJECT_ID('silver.address','U') IS NOT NULL
        DROP TABLE silver.address;

    IF OBJECT_ID('silver.address_reject','U') IS NOT NULL
        DROP TABLE silver.address_reject;

    /*------------------------------------------------------------
      3) Create tables
    ------------------------------------------------------------*/
    CREATE TABLE silver.address
    (
        AddressID            varchar(50)    NOT NULL,
        CustomerID           varchar(50)    NOT NULL,

        AddressLine1         varchar(200)   NULL,
        AddressLine2         varchar(200)   NULL,
        City                 varchar(100)   NULL,
        County               varchar(100)   NULL,

        PostcodeArea         varchar(20)    NULL,
        PostcodeDistrict     varchar(20)    NULL,
        Region               varchar(100)   NULL,
        Postcode             varchar(20)    NULL,
        Country              varchar(100)   NULL,

        PropertyType         varchar(100)   NULL,
        Tenure               varchar(50)    NULL,
        BuildYear            int            NULL,
        Bedrooms             int            NULL,
        HouseSizeSqFt        int            NULL,
        PropertySizeBand     varchar(50)    NULL,
        PropertyAgeBand      varchar(50)    NULL,

        RebuildCostEstimate  decimal(18,2)  NULL,

        BronzeLoadDts        datetime2(0)   NOT NULL,
        SourceFile           varchar(260)   NULL,

        SilverLoadDts        datetime2(0)   NOT NULL
            CONSTRAINT DF_silver_address_SilverLoadDts DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_silver_address PRIMARY KEY (AddressID)
    );

    CREATE TABLE silver.address_reject
    (
        AddressID      varchar(50)   NULL,
        RejectReason   varchar(200)  NOT NULL,
        BronzeLoadDts  datetime2(0)  NULL,
        SourceFile     varchar(260)  NULL,
        RejectLoadDts  datetime2(0)  NOT NULL DEFAULT SYSUTCDATETIME()
    );

    /*------------------------------------------------------------
      4) Deduplicate (latest BronzeLoadDts per AddressID)
    ------------------------------------------------------------*/
    IF OBJECT_ID('tempdb..#LatestAddress') IS NOT NULL DROP TABLE #LatestAddress;

    ;WITH Deduped AS
    (
        SELECT
            b.*,
            ROW_NUMBER() OVER
            (
                PARTITION BY b.AddressID
                ORDER BY b.BronzeLoadDts DESC
            ) AS rn
        FROM bronze.address_raw b
    )
    SELECT *
    INTO #LatestAddress
    FROM Deduped
    WHERE rn = 1;

    /*------------------------------------------------------------
      5) Reject: missing AddressID
    ------------------------------------------------------------*/
    INSERT INTO silver.address_reject (AddressID, RejectReason, BronzeLoadDts, SourceFile)
    SELECT
        AddressID,
        'Missing AddressID',
        BronzeLoadDts,
        SourceFile
    FROM #LatestAddress
    WHERE AddressID IS NULL
       OR LTRIM(RTRIM(AddressID)) = '';

    /*------------------------------------------------------------
      6) Load valid rows
         FIX: strip CR/LF/TAB and common artefacts before numeric convert
    ------------------------------------------------------------*/
    INSERT INTO silver.address
    (
        AddressID, CustomerID,
        AddressLine1, AddressLine2, City, County,
        PostcodeArea, PostcodeDistrict, Region, Postcode, Country,
        PropertyType, Tenure, BuildYear, Bedrooms, HouseSizeSqFt,
        PropertySizeBand, PropertyAgeBand,
        RebuildCostEstimate,
        BronzeLoadDts, SourceFile
    )
    SELECT
        LTRIM(RTRIM(l.AddressID)),
        LTRIM(RTRIM(l.CustomerID)),

        NULLIF(LTRIM(RTRIM(l.AddressLine1)), ''),
        NULLIF(LTRIM(RTRIM(l.AddressLine2)), ''),
        NULLIF(LTRIM(RTRIM(l.City)), ''),
        NULLIF(LTRIM(RTRIM(l.County)), ''),

        NULLIF(LTRIM(RTRIM(l.PostcodeArea)), ''),
        NULLIF(LTRIM(RTRIM(l.PostcodeDistrict)), ''),
        NULLIF(LTRIM(RTRIM(l.Region)), ''),
        NULLIF(LTRIM(RTRIM(l.Postcode)), ''),
        NULLIF(LTRIM(RTRIM(l.Country)), ''),

        NULLIF(LTRIM(RTRIM(l.PropertyType)), ''),
        NULLIF(LTRIM(RTRIM(l.Tenure)), ''),

        l.BuildYear,
        l.Bedrooms,
        l.HouseSizeSqFt,

        NULLIF(LTRIM(RTRIM(l.PropertySizeBand)), ''),
        NULLIF(LTRIM(RTRIM(l.PropertyAgeBand)), ''),

        TRY_CONVERT(decimal(18,2),
            NULLIF(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    LTRIM(RTRIM(CONVERT(varchar(50), l.RebuildCostEstimate))),
                    CHAR(13), ''),   -- CR
                    CHAR(10), ''),   -- LF
                    CHAR(9),  ''),   -- TAB
                    ',',     ''),    -- commas
                    '£',     ''),    -- currency
                '')
        ),

        l.BronzeLoadDts,
        l.SourceFile
    FROM #LatestAddress l
    WHERE l.AddressID IS NOT NULL
      AND LTRIM(RTRIM(l.AddressID)) <> '';

    /*------------------------------------------------------------
      7) Reject: rebuild cost present but not convertible
    ------------------------------------------------------------*/
    INSERT INTO silver.address_reject (AddressID, RejectReason, BronzeLoadDts, SourceFile)
    SELECT
        l.AddressID,
        'RebuildCostEstimate could not be converted to decimal(18,2)',
        l.BronzeLoadDts,
        l.SourceFile
    FROM #LatestAddress l
    WHERE l.RebuildCostEstimate IS NOT NULL
      AND TRY_CONVERT(decimal(18,2),
            NULLIF(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    LTRIM(RTRIM(CONVERT(varchar(50), l.RebuildCostEstimate))),
                    CHAR(13), ''), CHAR(10), ''), CHAR(9), ''), ',', ''), '£', ''),
                '')
          ) IS NULL;

    /*------------------------------------------------------------
      8) Validations
    ------------------------------------------------------------*/
    PRINT 'Validation: Row Counts';
    SELECT COUNT(*) AS BronzeCount FROM bronze.address_raw;
    SELECT COUNT(*) AS SilverCount FROM silver.address;
    SELECT COUNT(*) AS RejectCount FROM silver.address_reject;

    PRINT 'Validation: RebuildCostEstimate Non-Null';
    SELECT
        (SELECT COUNT(*) FROM bronze.address_raw WHERE RebuildCostEstimate IS NOT NULL) AS BronzeNonNull,
        (SELECT COUNT(*) FROM silver.address     WHERE RebuildCostEstimate IS NOT NULL) AS SilverNonNull;

    PRINT 'DONE: silver.address load complete.';

END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
GO

SELECT TOP 25 *
FROM silver.address
ORDER BY AddressID;
GO

SELECT TOP 25 *
FROM silver.address_reject
ORDER BY RejectLoadDts DESC;
GO



SELECT *
FROM [silver].[address]
