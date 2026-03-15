-- Create table stg.policy

DROP TABLE IF EXISTS stg.policy;
GO

CREATE TABLE stg.policy (
    PolicyID       varchar(30) NULL,
    CustomerID     varchar(30) NULL,
    AddressID      varchar(30) NULL,
    BrokerID       varchar(30) NULL,
    ProductType    varchar(50) NULL,
    InceptionDate  varchar(20) NULL,
    ExpiryDate     varchar(20) NULL,
    PolicyStatus   varchar(30) NULL,
    PaymentPlan    varchar(30) NULL,
    CreatedDate    varchar(20) NULL
);
GO


-- Bulk Insert stg.policy

TRUNCATE TABLE stg.policy;

BULK INSERT stg.policy
FROM 'C:\Users\Paul Mampilly\Documents\ChatGPT Datasets\Home Insurance\CSV Datasets\Calibrated Raw Data\policy_raw.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0D0A',   -- Windows CRLF
    CODEPAGE        = '65001',    -- UTF-8
    TABLOCK
);


-- Preview Data

SELECT TOP 50 *
FROM stg.policy;


SELECT COUNT(*) AS NoOfRows
FROM stg.policy;


SELECT TOP (20) *
FROM stg.policy;


-- Check for duplicate policies

SELECT PolicyID, COUNT(*) AS DuplicateCount
FROM stg.policy
GROUP BY PolicyID
HAVING COUNT(*) > 1;
