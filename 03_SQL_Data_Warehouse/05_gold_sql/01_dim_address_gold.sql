/*==============================================================================
  DATABASE:      PalthanioHomeInsuranceDW
  LAYER:         GOLD
  OBJECT:        gold.dim_address
  SOURCE:        silver.address

  AUTHOR:        Paul Mampilly (Portfolio Project)
  UPDATED:       2026-03-04

  PURPOSE
  -------
  Create the Gold Address Dimension for reporting and star schema modelling.

  METADATA / LINEAGE
  ------------------
  BronzeLoadDts : when the record landed in Bronze (lineage)
  SilverLoadDts : when the record was transformed into Silver
  GoldLoadDts   : when Gold dimension was loaded/refreshed

  DIMENSION DESIGN
  ----------------
  - Surrogate key: AddressKey (INT IDENTITY)
  - Business key : AddressID (UNIQUE)
  - Type 1 SCD    : overwrite with latest Silver values
  - Unknown row   : AddressKey = -1 (prevents broken joins)
==============================================================================*/

USE PalthanioHomeInsuranceDW;
GO
SET NOCOUNT ON;
GO

/*==============================================================================
  0) PRE-FLIGHT
==============================================================================*/
IF OBJECT_ID('silver.address','U') IS NULL
BEGIN
    THROW 61001, 'Source table silver.address does not exist. Run Silver first.', 1;
END;

DECLARE @SilverCount int;
SELECT @SilverCount = COUNT(*) FROM silver.address;

IF @SilverCount = 0
BEGIN
    THROW 61002, 'Source table silver.address exists but contains 0 rows.', 1;
END;

PRINT CONCAT('Pre-flight OK. silver.address rows = ', @SilverCount);
GO

/*==============================================================================
  1) ENSURE GOLD SCHEMA EXISTS
==============================================================================*/
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('CREATE SCHEMA gold;');
GO

/*==============================================================================
  2) ENSURE silver.address HAS SilverLoadDts (SAFE ADD)
==============================================================================*/
IF COL_LENGTH('silver.address', 'SilverLoadDts') IS NULL
BEGIN
    ALTER TABLE silver.address
    ADD SilverLoadDts datetime2(0) NOT NULL
        CONSTRAINT DF_silver_address_SilverLoadDts DEFAULT SYSUTCDATETIME();

    PRINT 'Added missing column silver.address.SilverLoadDts (default SYSUTCDATETIME()).';
END;
GO

/*==============================================================================
  3) DROP + RECREATE DIM TABLE (DEV MODE)
==============================================================================*/
IF OBJECT_ID('gold.dim_address','U') IS NOT NULL
    DROP TABLE gold.dim_address;
GO

CREATE TABLE gold.dim_address
(
    -- Surrogate Key
    AddressKey           int IDENTITY(1,1) NOT NULL,

    -- Business Key
    AddressID            varchar(30) NOT NULL,

    -- Address attributes (aligned to your silver.address)
    AddressLine1         varchar(200) NULL,
    AddressLine2         varchar(200) NULL,
    City                 varchar(100) NULL,
    County               varchar(100) NULL,
    PostcodeDistrict     varchar(20)  NULL,
    Region               varchar(100) NULL,
    Postcode             varchar(20)  NULL,
    Country              varchar(100) NULL,

    PropertyType         varchar(50)  NULL,
    Tenure               varchar(50)  NULL,
    BuildYear            int          NULL,
    Bedrooms             int          NULL,
    HouseSizeSqFt        int          NULL,
    PropertySizeBand     varchar(50)  NULL,
    PropertyAgeBand      varchar(50)  NULL,
    RebuildCostEstimate  decimal(18,2) NULL,

    -- Lineage / metadata coming from Silver
    BronzeLoadDts        datetime2(0) NULL,
    SilverLoadDts        datetime2(0) NULL,
    SourceFile           varchar(260) NULL,

    -- Gold metadata
    GoldLoadDts          datetime2(0) NOT NULL
        CONSTRAINT DF_dim_address_GoldLoadDts DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_dim_address PRIMARY KEY (AddressKey),
    CONSTRAINT UQ_dim_address_AddressID UNIQUE (AddressID)
);
GO

/*==============================================================================
  4) INSERT UNKNOWN ROW (AddressKey = -1)
==============================================================================*/
SET IDENTITY_INSERT gold.dim_address ON;

INSERT INTO gold.dim_address
(
    AddressKey,
    AddressID,
    AddressLine1, AddressLine2, City, County, PostcodeDistrict, Region, Postcode, Country,
    PropertyType, Tenure, BuildYear, Bedrooms, HouseSizeSqFt, PropertySizeBand, PropertyAgeBand, RebuildCostEstimate,
    BronzeLoadDts, SilverLoadDts, SourceFile
)
VALUES
(
    -1,
    'UNKNOWN',
    'Unknown', NULL, 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown',
    'Unknown', 'Unknown', NULL, NULL, NULL, 'Unknown', 'Unknown', NULL,
    NULL, NULL, NULL
);

SET IDENTITY_INSERT gold.dim_address OFF;
GO

/*==============================================================================
  5) TYPE 1 UPSERT FROM SILVER (MERGE)
==============================================================================*/
MERGE gold.dim_address AS tgt
USING
(
    SELECT
        s.AddressID,
        s.AddressLine1,
        s.AddressLine2,
        s.City,
        s.County,
        s.PostcodeDistrict,
        s.Region,
        s.Postcode,
        s.Country,
        s.PropertyType,
        s.Tenure,

        TRY_CONVERT(int, s.BuildYear)         AS BuildYear,
        TRY_CONVERT(int, s.Bedrooms)          AS Bedrooms,
        TRY_CONVERT(int, s.HouseSizeSqFt)     AS HouseSizeSqFt,
        s.PropertySizeBand,
        s.PropertyAgeBand,

        TRY_CONVERT(decimal(18,2), s.RebuildCostEstimate) AS RebuildCostEstimate,

        s.BronzeLoadDts,
        s.SilverLoadDts,
        s.SourceFile
    FROM silver.address s
    WHERE s.AddressID IS NOT NULL
      AND LTRIM(RTRIM(s.AddressID)) <> ''
) AS src
ON tgt.AddressID = src.AddressID

WHEN MATCHED AND
(
       ISNULL(tgt.AddressLine1,'')              <> ISNULL(src.AddressLine1,'')
    OR ISNULL(tgt.AddressLine2,'')              <> ISNULL(src.AddressLine2,'')
    OR ISNULL(tgt.City,'')                      <> ISNULL(src.City,'')
    OR ISNULL(tgt.County,'')                    <> ISNULL(src.County,'')
    OR ISNULL(tgt.PostcodeDistrict,'')          <> ISNULL(src.PostcodeDistrict,'')
    OR ISNULL(tgt.Region,'')                    <> ISNULL(src.Region,'')
    OR ISNULL(tgt.Postcode,'')                  <> ISNULL(src.Postcode,'')
    OR ISNULL(tgt.Country,'')                   <> ISNULL(src.Country,'')
    OR ISNULL(tgt.PropertyType,'')              <> ISNULL(src.PropertyType,'')
    OR ISNULL(tgt.Tenure,'')                    <> ISNULL(src.Tenure,'')
    OR ISNULL(tgt.BuildYear,-1)                 <> ISNULL(src.BuildYear,-1)
    OR ISNULL(tgt.Bedrooms,-1)                  <> ISNULL(src.Bedrooms,-1)
    OR ISNULL(tgt.HouseSizeSqFt,-1)             <> ISNULL(src.HouseSizeSqFt,-1)
    OR ISNULL(tgt.PropertySizeBand,'')          <> ISNULL(src.PropertySizeBand,'')
    OR ISNULL(tgt.PropertyAgeBand,'')           <> ISNULL(src.PropertyAgeBand,'')
    OR ISNULL(tgt.RebuildCostEstimate,-1)       <> ISNULL(src.RebuildCostEstimate,-1)
    OR ISNULL(tgt.BronzeLoadDts,'19000101')     <> ISNULL(src.BronzeLoadDts,'19000101')
    OR ISNULL(tgt.SilverLoadDts,'19000101')     <> ISNULL(src.SilverLoadDts,'19000101')
    OR ISNULL(tgt.SourceFile,'')                <> ISNULL(src.SourceFile,'')
)
THEN UPDATE SET
    tgt.AddressLine1        = src.AddressLine1,
    tgt.AddressLine2        = src.AddressLine2,
    tgt.City                = src.City,
    tgt.County              = src.County,
    tgt.PostcodeDistrict    = src.PostcodeDistrict,
    tgt.Region              = src.Region,
    tgt.Postcode            = src.Postcode,
    tgt.Country             = src.Country,
    tgt.PropertyType        = src.PropertyType,
    tgt.Tenure              = src.Tenure,
    tgt.BuildYear           = src.BuildYear,
    tgt.Bedrooms            = src.Bedrooms,
    tgt.HouseSizeSqFt       = src.HouseSizeSqFt,
    tgt.PropertySizeBand    = src.PropertySizeBand,
    tgt.PropertyAgeBand     = src.PropertyAgeBand,
    tgt.RebuildCostEstimate = src.RebuildCostEstimate,
    tgt.BronzeLoadDts       = src.BronzeLoadDts,
    tgt.SilverLoadDts       = src.SilverLoadDts,
    tgt.SourceFile          = src.SourceFile,
    tgt.GoldLoadDts         = SYSUTCDATETIME()

WHEN NOT MATCHED BY TARGET
THEN INSERT
(
    AddressID,
    AddressLine1, AddressLine2, City, County, PostcodeDistrict, Region, Postcode, Country,
    PropertyType, Tenure, BuildYear, Bedrooms, HouseSizeSqFt, PropertySizeBand, PropertyAgeBand, RebuildCostEstimate,
    BronzeLoadDts, SilverLoadDts, SourceFile
)
VALUES
(
    src.AddressID,
    src.AddressLine1, src.AddressLine2, src.City, src.County, src.PostcodeDistrict, src.Region, src.Postcode, src.Country,
    src.PropertyType, src.Tenure, src.BuildYear, src.Bedrooms, src.HouseSizeSqFt, src.PropertySizeBand, src.PropertyAgeBand, src.RebuildCostEstimate,
    src.BronzeLoadDts, src.SilverLoadDts, src.SourceFile
);
GO

/*==============================================================================
  6) PERFORMANCE INDEX
==============================================================================*/
CREATE INDEX IX_dim_address_AddressID ON gold.dim_address(AddressID);
GO

/*==============================================================================
  7) POST-LOAD VALIDATION
==============================================================================*/
SELECT COUNT(*) AS SilverAddressCount FROM silver.address;
SELECT COUNT(*) AS GoldDimAddressCount FROM gold.dim_address;

SELECT * FROM gold.dim_address WHERE AddressKey = -1;

SELECT TOP (25) *
FROM gold.dim_address
ORDER BY AddressKey DESC;
GO
