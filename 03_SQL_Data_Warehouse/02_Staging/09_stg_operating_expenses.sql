-- Create stg.operating_expenses

DROP TABLE IF EXISTS stg.operating_expenses;
GO

CREATE TABLE stg.operating_expenses (
    ExpenseMonthStart        varchar(20)  NULL,
    ExpenseCategory          varchar(50)  NULL,
    ExpenseAmount            varchar(30)  NULL,
    Currency                 varchar(10)  NULL,
    SourceSystem             varchar(50)  NULL,

    ExpenseType              varchar(20)  NULL,
    CostCentre               varchar(50)  NULL,
    ImpactsExpenseRatioFlag  varchar(10)  NULL,

    InflationAdjustedAmount  varchar(30)  NULL,
    ExpenseBand              varchar(50)  NULL,

    YearMonth                varchar(20)  NULL,
    [Year]                   varchar(10)  NULL,
    [Month]                  varchar(10)  NULL,

    PreviousMonthAmount      varchar(30)  NULL,
    MoMVariance              varchar(30)  NULL,
    MoMVarianceFlag          varchar(20)  NULL
);
GO


-- Bulk Insert stg.operating_expenses

TRUNCATE TABLE stg.operating_expenses;

BULK INSERT stg.operating_expenses
FROM 'C:\Users\Paul Mampilly\Documents\ChatGPT Datasets\Home Insurance\CSV Datasets\Calibrated Raw Data\Enchanced\operating_expenses_enterprise_ready.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0D0A',   -- Windows CRLF
    CODEPAGE        = '65001',    -- UTF-8
    TABLOCK
);



== Validation Checks

SELECT COUNT(*) AS RowNumbers
FROM stg.operating_expenses;

SELECT TOP (20) *
FROM stg.operating_expenses
ORDER BY ExpenseMonthStart, ExpenseCategory;


SELECT TOP (50) ExpenseMonthStart
FROM stg.operating_expenses
WHERE ExpenseMonthStart IS NOT NULL
  AND LTRIM(RTRIM(ExpenseMonthStart)) <> ''
  AND TRY_CONVERT(date, ExpenseMonthStart, 23) IS NULL
  AND TRY_CONVERT(date, ExpenseMonthStart, 103) IS NULL;


  SELECT TOP (50)
    ExpenseAmount,
    InflationAdjustedAmount,
    PreviousMonthAmount,
    MoMVariance
FROM stg.operating_expenses
WHERE ExpenseAmount           LIKE '%[^0-9.-]%'
   OR InflationAdjustedAmount LIKE '%[^0-9.-]%'
   OR PreviousMonthAmount     LIKE '%[^0-9.-]%'
   OR MoMVariance             LIKE '%[^0-9.-]%';


   SELECT TOP (50) ImpactsExpenseRatioFlag
FROM stg.operating_expenses
WHERE ImpactsExpenseRatioFlag NOT IN ('0','1');



SELECT Currency, COUNT(*) AS Cnt
FROM stg.operating_expenses
GROUP BY Currency;


SELECT TOP (50) Currency
FROM stg.operating_expenses
WHERE Currency IS NOT NULL
  AND LTRIM(RTRIM(Currency)) <> ''
  AND UPPER(LTRIM(RTRIM(Currency))) <> 'GBP';


  SELECT ExpenseMonthStart, ExpenseCategory, COUNT(*) AS Cnt
FROM stg.operating_expenses
GROUP BY ExpenseMonthStart, ExpenseCategory
HAVING COUNT(*) > 1;


SELECT TOP (50)
    ExpenseMonthStart,
    ExpenseCategory,
    InflationAdjustedAmount,
    PreviousMonthAmount,
    MoMVariance
FROM stg.operating_expenses
WHERE TRY_CONVERT(decimal(18,2), InflationAdjustedAmount) IS NOT NULL
  AND TRY_CONVERT(decimal(18,2), PreviousMonthAmount) IS NOT NULL
  AND TRY_CONVERT(decimal(18,2), MoMVariance) IS NOT NULL
  AND ABS(
        TRY_CONVERT(decimal(18,2), InflationAdjustedAmount)
      - TRY_CONVERT(decimal(18,2), PreviousMonthAmount)
      - TRY_CONVERT(decimal(18,2), MoMVariance)
  ) > 0.50;



