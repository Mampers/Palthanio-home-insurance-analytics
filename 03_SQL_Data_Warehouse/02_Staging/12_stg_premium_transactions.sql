-- stg_premium_transactions 

DROP TABLE IF EXISTS stg.premium_transactions;
GO

CREATE TABLE stg.premium_transactions (
    PremiumTransactionID      varchar(50)  NULL,
    PolicyID                  varchar(50)  NULL,
    TransactionDate           varchar(30)  NULL,
    GrossPremium              varchar(50)  NULL,
    IPTPremiumTax             varchar(50)  NULL,
    AdminFee                  varchar(50)  NULL,
    Discount                  varchar(50)  NULL,
    NetPremium                varchar(50)  NULL,
    TransactionStatus         varchar(50)  NULL,
    CalculatedNetPremium      varchar(50)  NULL,
    NetPremiumVariance        varchar(50)  NULL,
    PremiumDataQualityFlag    varchar(20)  NULL,
    PremiumBand               varchar(100) NULL,
    InstallmentNumber         varchar(20)  NULL,
    IsInstallmentPlanFlag     varchar(20)  NULL,
    TransactionType           varchar(100) NULL,
    YearMonth                 varchar(50)  NULL,
    [Year]                    varchar(10)  NULL,
    [Month]                   varchar(10)  NULL,
    IsYTDFlag                 varchar(20)  NULL,
    IsLast12MonthsFlag        varchar(20)  NULL,
    TotalWrittenPremium       varchar(50)  NULL,
    TotalNetWrittenPremium    varchar(50)  NULL,
    IPTRatio                  varchar(50)  NULL,
    DiscountRatio             varchar(50)  NULL
);
GO

-- Bulk Insert stg.premium_transactions


TRUNCATE TABLE stg.premium_transactions;

BULK INSERT stg.premium_transactions
FROM 'C:\Users\Paul Mampilly\Documents\ChatGPT Datasets\Home Insurance\CSV Datasets\Calibrated Raw Data\Enchanced\premium_transactions_enterprise_ready.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0D0A',
    CODEPAGE        = '65001',
    TABLOCK
);

-- Validation Checks

SELECT TOP (25)
    PremiumTransactionID,
    PolicyID,
    TransactionDate,
    TransactionStatus,
    TransactionType,
    YearMonth,
    [Year],
    [Month],
    GrossPremium,
    NetPremium
FROM stg.premium_transactions;


SELECT COUNT(*) AS RC
FROM stg.premium_transactions;

SELECT PremiumTransactionID, COUNT(*) AS Cnt
FROM stg.premium_transactions
GROUP BY PremiumTransactionID
HAVING COUNT(*) > 1;

SELECT TOP 30 *
FROM stg.premium_transactions

SELECT TOP (50) YearMonth
FROM stg.premium_transactions
WHERE LTRIM(RTRIM(ISNULL(YearMonth,''))) <> ''
  AND YearMonth NOT LIKE '[12][0-9][0-9][0-9]-[01][0-9]';


  SELECT TOP (50)
    PremiumDataQualityFlag,
    IsInstallmentPlanFlag,
    IsYTDFlag,
    IsLast12MonthsFlag
FROM stg.premium_transactions
WHERE (LTRIM(RTRIM(ISNULL(PremiumDataQualityFlag,''))) <> '' AND PremiumDataQualityFlag NOT IN ('0','1'))
   OR (LTRIM(RTRIM(ISNULL(IsInstallmentPlanFlag,''))) <> '' AND IsInstallmentPlanFlag NOT IN ('0','1'))
   OR (LTRIM(RTRIM(ISNULL(IsYTDFlag,''))) <> '' AND IsYTDFlag NOT IN ('0','1'))
   OR (LTRIM(RTRIM(ISNULL(IsLast12MonthsFlag,''))) <> '' AND IsLast12MonthsFlag NOT IN ('0','1'));


   SELECT TOP (50) TransactionDate
FROM stg.premium_transactions
WHERE LTRIM(RTRIM(ISNULL(TransactionDate,''))) <> ''
  AND TRY_CONVERT(date, TransactionDate, 103) IS NULL
  AND TRY_CONVERT(date, TransactionDate, 23)  IS NULL;


