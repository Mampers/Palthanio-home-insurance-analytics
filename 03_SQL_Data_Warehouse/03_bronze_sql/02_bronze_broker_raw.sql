/*=========================================================
  BRONZE LOAD: Broker
  Source: stg.broker
  Target: bronze.broker_raw
=========================================================*/

-----------------------------------------------------------
-- 0) Ensure bronze schema exists
-----------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
BEGIN
    EXEC('CREATE SCHEMA bronze');
END
GO

-----------------------------------------------------------
-- 1) Drop & recreate bronze table (clone stg schema)
-----------------------------------------------------------
DROP TABLE IF EXISTS bronze.broker_raw;
GO

SELECT TOP (0) *
INTO bronze.broker_raw
FROM stg.broker;
GO

-----------------------------------------------------------
-- 2) Add Bronze metadata columns
-----------------------------------------------------------
ALTER TABLE bronze.broker_raw
ADD
    BronzeLoadDts datetime2(0) NOT NULL
        CONSTRAINT DF_bronze_broker_raw_BronzeLoadDts DEFAULT SYSUTCDATETIME(),
    SourceFile varchar(260) NULL;
GO

-----------------------------------------------------------
-- 3) Load data from stg into bronze
--    (Explicit column list so metadata columns are excluded)
-----------------------------------------------------------
INSERT INTO bronze.broker_raw
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
    BrokerSizeBand
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
    BrokerSizeBand
FROM stg.broker;
GO

-----------------------------------------------------------
-- 4) Stamp source filename (optional)
-----------------------------------------------------------
UPDATE bronze.broker_raw
SET SourceFile = 'broker_enhanced.csv'
WHERE SourceFile IS NULL;
GO

-----------------------------------------------------------
-- 5) Validation checks
-----------------------------------------------------------

-- 5A) Row counts should match
SELECT 'stg.broker' AS TableName, COUNT(*) AS RC
FROM stg.broker;

SELECT 'bronze.broker_raw' AS TableName, COUNT(*) AS RC
FROM bronze.broker_raw;
GO

-- 5B) Sample
SELECT TOP (20) *
FROM bronze.broker_raw
ORDER BY BronzeLoadDts DESC;
GO

-- 5C) Duplicate BrokerID check (ideally 0 rows)
SELECT BrokerID, COUNT(*) AS Cnt
FROM bronze.broker_raw
GROUP BY BrokerID
HAVING COUNT(*) > 1;
GO

-- 5D) Null/blank BrokerID check
SELECT
    SUM(CASE WHEN BrokerID IS NULL OR LTRIM(RTRIM(BrokerID)) = '' THEN 1 ELSE 0 END) AS NullOrBlank_BrokerID
FROM bronze.broker_raw;
GO
