-- stg claim_reserves


DROP TABLE IF EXISTS stg.claim_reserves;
GO

CREATE TABLE stg.claim_reserves (
    ReserveID           varchar(30)  NULL,
    ClaimID             varchar(30)  NULL,
    SnapshotDate        varchar(20)  NULL,   -- UK format likely DD/MM/YYYY
    ReserveAmount       varchar(30)  NULL,
    ReserveStatus       varchar(20)  NULL,   -- Open/Closed
    ReserveType         varchar(30)  NULL,   -- Case Reserve / IBNR
    PreviousReserve     varchar(30)  NULL,
    ReserveChange       varchar(30)  NULL,   -- can be negative
    ReserveMovementType varchar(30)  NULL,   -- Strengthened/Released/No Change
    LargeReserveFlag    varchar(10)  NULL,   -- 0/1
    LatestSnapshotFlag  varchar(10)  NULL,   -- 0/1
    ReserveAgeMonths    varchar(10)  NULL
);
GO


-- bulk insert stg.claim_reserves

TRUNCATE TABLE stg.claim_reserves;

BULK INSERT stg.claim_reserves
FROM 'C:\Users\Paul Mampilly\Documents\ChatGPT Datasets\Home Insurance\CSV Datasets\Calibrated Raw Data\Enchanced\claim_reserves_enterprise_ready.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0D0A',
    CODEPAGE        = '65001',
    TABLOCK
);


-- Validation checks

SELECT COUNT(*) AS NoofRows
FROM stg.claim_reserves

SELECT TOP 50 * 
FROM stg.claim_reserves

SELECT TOP (50)
    ReserveAmount,
    PreviousReserve,
    ReserveChange,
    ReserveAgeMonths
FROM stg.claim_reserves
WHERE ReserveAmount    LIKE '%[^0-9.-]%'
   OR PreviousReserve  LIKE '%[^0-9.-]%'
   OR ReserveChange    LIKE '%[^0-9.-]%'
   OR ReserveAgeMonths LIKE '%[^0-9]%';


   SELECT TOP (50)
    LargeReserveFlag,
    LatestSnapshotFlag
FROM stg.claim_reserves
WHERE LargeReserveFlag NOT IN ('0','1')
   OR LatestSnapshotFlag NOT IN ('0','1');


   SELECT TOP (50) SnapshotDate
FROM stg.claim_reserves
WHERE TRY_CONVERT(date, SnapshotDate, 103) IS NULL;
