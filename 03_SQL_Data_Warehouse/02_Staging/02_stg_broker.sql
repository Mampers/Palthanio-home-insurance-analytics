-- stg.broker


DROP TABLE IF EXISTS stg.broker;
GO

CREATE TABLE stg.broker (
    BrokerID               varchar(20)  NULL,
    BrokerName             varchar(200) NULL,
    Channel                varchar(50)  NULL,
    Region                 varchar(50)  NULL,
    Status                 varchar(20)  NULL,
    AppointmentYear        varchar(10)  NULL,
    RelationshipTenureYears varchar(10) NULL,
    CommissionRate         varchar(20)  NULL,
    CommissionModel        varchar(50)  NULL,
    EstimatedAnnualGWP_GBP varchar(30)  NULL,
    BrokerSizeBand         varchar(50)  NULL
);
GO


-- Bulk Insert stg.broker

TRUNCATE TABLE stg.broker;

BULK INSERT stg.broker
FROM 'C:\Users\Paul Mampilly\Documents\ChatGPT Datasets\Home Insurance\CSV Datasets\Calibrated Raw Data\Enchanced\broker_enhanced.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0D0A',   -- Windows CRLF
    CODEPAGE        = '65001',   -- UTF-8
    TABLOCK
);



-- Validation check

SELECT COUNT(*) AS NoOfRows
FROM stg.broker;

SELECT TOP 20 *
FROM stg.broker;

-- suspicious numeric fields (should be numeric-looking only)
SELECT TOP (50)
    AppointmentYear, RelationshipTenureYears, CommissionRate, EstimatedAnnualGWP_GBP
FROM stg.broker
WHERE AppointmentYear LIKE '%[^0-9]%'
   OR RelationshipTenureYears LIKE '%[^0-9]%'
   OR CommissionRate LIKE '%[^0-9.]%'
   OR EstimatedAnnualGWP_GBP LIKE '%[^0-9]%';
