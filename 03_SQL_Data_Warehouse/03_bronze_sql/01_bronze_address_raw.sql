/*==============================================================================
  BRONZE: address_raw (MATCHES address_enchanched.csv EXACTLY)
  - Creates bronze.address_raw with the 19 CSV columns (in correct order)
  - BULK INSERT loads cleanly (no column shifting)
  - Adds Bronze metadata columns AFTER load
==============================================================================*/

SET NOCOUNT ON;

BEGIN TRY

    /* 0) Ensure schema */
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
        EXEC('CREATE SCHEMA bronze;');

    /* 1) Reset table */
    IF OBJECT_ID('bronze.address_raw','U') IS NOT NULL
        DROP TABLE bronze.address_raw;

    /* 2) Create table to match CSV header EXACTLY (19 columns) */
    CREATE TABLE bronze.address_raw (
        AddressID            varchar(50)    NULL,
        CustomerID           varchar(50)    NULL,
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
        BuildYear            varchar(10)    NULL,
        Bedrooms             varchar(10)    NULL,
        HouseSizeSqFt        varchar(20)    NULL,
        PropertySizeBand     varchar(50)    NULL,
        PropertyAgeBand      varchar(50)    NULL,
        RebuildCostEstimate  varchar(50)    NULL
    );

    /* 3) BULK INSERT (update filepath if needed) */
    DECLARE @FilePath varchar(4000) =
        'C:\Users\Paul Mampilly\Documents\ChatGPT Datasets\Home Insurance\CSV Datasets\Calibrated Raw Data\Enchanced\address_enchanched.csv';

    DECLARE @BulkSql nvarchar(max) = N'
BULK INSERT bronze.address_raw
FROM ''' + REPLACE(@FilePath,'''','''''') + N'''
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''0x0a'',
    TABLOCK,
    CODEPAGE = ''65001'',
    MAXERRORS = 1000
);';

    EXEC sp_executesql @BulkSql;

    /* 4) Add Bronze metadata AFTER load (so BULK alignment stays correct) */
    ALTER TABLE bronze.address_raw
        ADD BronzeLoadDts datetime2(0) NOT NULL CONSTRAINT DF_bronze_address_raw_BronzeLoadDts DEFAULT SYSUTCDATETIME();

    ALTER TABLE bronze.address_raw
        ADD SourceFile varchar(260) NULL;

    /* 5) Stamp SourceFile for all loaded rows */
    UPDATE bronze.address_raw
    SET SourceFile = @FilePath
    WHERE SourceFile IS NULL;

    /* 6) Validate */
    SELECT COUNT(*) AS BronzeCount FROM bronze.address_raw;

    SELECT TOP 50 *
    FROM bronze.address_raw
    ORDER BY AddressID;

END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
