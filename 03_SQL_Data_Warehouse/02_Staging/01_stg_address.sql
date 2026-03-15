-- Create table stg.address


DROP TABLE IF EXISTS stg.address;
GO

CREATE TABLE stg.address (
    AddressID           varchar(20)  NULL,
    CustomerID          varchar(20)  NULL,
    AddressLine1        varchar(200) NULL,
    AddressLine2        varchar(200) NULL,
    City                varchar(100) NULL,
    County              varchar(100) NULL,
    PostcodeArea        varchar(20)  NULL,
    PostcodeDistrict    varchar(20)  NULL,
    Region              varchar(50)  NULL,
    Postcode            varchar(20)  NULL,
    Country             varchar(50)  NULL,
    PropertyType        varchar(50)  NULL,
    Tenure              varchar(50)  NULL,
    BuildYear           varchar(10)  NULL,
    Bedrooms            varchar(10)  NULL,
    HouseSizeSqFt       varchar(20)  NULL,
    PropertySizeBand    varchar(50)  NULL,
    PropertyAgeBand     varchar(50)  NULL,
    RebuildCostEstimate varchar(30)  NULL
);
GO


-- Bulk Insert stg.address

TRUNCATE TABLE stg.address;

BULK INSERT stg.address
FROM 'C:\Users\Paul Mampilly\Documents\ChatGPT Datasets\Home Insurance\CSV Datasets\Calibrated Raw Data\Enchanced\address_enchanched.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0D0A',   -- Windows CRLF
    CODEPAGE        = '65001',   -- UTF-8
    TABLOCK
);


SELECT TOP 50 *
FROM stg.address



SELECT COUNT(*) AS NofoRows
FROM stg.address;

SELECT TOP (20) *
FROM stg.address;

-- Check suspicious values quickly
SELECT TOP (50) Bedrooms, BuildYear, HouseSizeSqFt, RebuildCostEstimate
FROM stg.address
WHERE Bedrooms LIKE '%[^0-9.]%'
   OR BuildYear LIKE '%[^0-9]%'
   OR RebuildCostEstimate LIKE '%[^0-9.]%';



