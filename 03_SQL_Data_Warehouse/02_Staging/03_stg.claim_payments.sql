-- stg.claim_payment

DROP TABLE IF EXISTS stg.claim_payments;
GO

CREATE TABLE stg.claim_payments (
    PaymentID          varchar(30)  NULL,
    ClaimID            varchar(30)  NULL,
    PaymentDate        varchar(20)  NULL,
    PaymentAmount      varchar(30)  NULL,
    PaymentMethod      varchar(50)  NULL,
    PaymentStatus      varchar(30)  NULL,
    ClaimType          varchar(50)  NULL,
    ClaimSeverityBand  varchar(50)  NULL,
    OutstandingReserve varchar(30)  NULL,
    IncurredAmount     varchar(30)  NULL,
    LargeLossFlag      varchar(10)  NULL
);
GO

-- Bulk Insert stg.claim_payments

TRUNCATE TABLE stg.claim_payments;

BULK INSERT stg.claim_payments
FROM 'C:\Users\Paul Mampilly\Documents\ChatGPT Datasets\Home Insurance\CSV Datasets\Calibrated Raw Data\Enchanced\claim_payments_realistic_interview_ready.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0D0A',
    CODEPAGE        = '65001',
    TABLOCK
);


-- Validation checks

SELECT COUNT(*) AS NoOfRows
FROM stg.claim_payments;

SELECT TOP 50 *
FROM stg.claim_payments;


SELECT TOP (50)
    PaymentAmount,
    OutstandingReserve,
    IncurredAmount,
    LargeLossFlag
FROM stg.claim_payments
WHERE PaymentAmount LIKE '%[^0-9.]%'
   OR OutstandingReserve LIKE '%[^0-9.]%'
   OR IncurredAmount LIKE '%[^0-9.]%'
   OR LargeLossFlag LIKE '%[^0-9]%';



   SELECT TOP (50) PaymentDate
FROM stg.claim_payments
WHERE TRY_CONVERT(date, PaymentDate) IS NULL;
