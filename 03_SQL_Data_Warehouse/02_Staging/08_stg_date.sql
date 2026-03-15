-- Creating stg.date

DROP TABLE IF EXISTS stg.[date];
GO

CREATE TABLE stg.[date] (
    [Date]                varchar(20)  NULL,
    DateKey               varchar(20)  NULL,
    [Year]                varchar(10)  NULL,
    [Quarter]             varchar(10)  NULL,
    [Month]               varchar(10)  NULL,
    MonthName             varchar(20)  NULL,
    [Day]                 varchar(10)  NULL,
    DayOfWeek             varchar(10)  NULL,
    DayName               varchar(20)  NULL,
    IsWeekend             varchar(10)  NULL,

    WeekOfYear_ISO        varchar(10)  NULL,
    ISOYear               varchar(10)  NULL,
    ISOWeekday            varchar(10)  NULL,

    MonthNameShort        varchar(10)  NULL,
    MonthYear             varchar(20)  NULL,
    YearMonth             varchar(20)  NULL,
    YearMonthKey          varchar(20)  NULL,

    QuarterName           varchar(10)  NULL,
    YearQuarter           varchar(20)  NULL,

    StartOfMonth          varchar(20)  NULL,
    EndOfMonth            varchar(20)  NULL,
    StartOfQuarter        varchar(20)  NULL,
    EndOfQuarter          varchar(20)  NULL,
    StartOfYear           varchar(20)  NULL,
    EndOfYear             varchar(20)  NULL,

    FiscalYear            varchar(10)  NULL,
    FiscalMonthNumber     varchar(10)  NULL,
    FiscalQuarterNumber   varchar(10)  NULL,
    FiscalQuarterName     varchar(10)  NULL,
    FiscalYearQuarter     varchar(20)  NULL,
    FiscalYearMonthKey    varchar(20)  NULL,
    FiscalYearMonth       varchar(20)  NULL,

    IsToday               varchar(10)  NULL,
    IsCurrentMonth        varchar(10)  NULL,
    IsCurrentYear         varchar(10)  NULL,
    IsYTD                 varchar(10)  NULL,
    IsLast7Days           varchar(10)  NULL,
    IsLast30Days          varchar(10)  NULL,
    IsLast90Days          varchar(10)  NULL,

    IsBusinessDay         varchar(10)  NULL,
    IsUKBankHoliday       varchar(10)  NULL,
    HolidayName           varchar(50)  NULL,
    IsWeekendFlag         varchar(10)  NULL
);
GO


-- Bulk Insert stg.date

TRUNCATE TABLE stg.[date];

BULK INSERT stg.[date]
FROM 'C:\Users\Paul Mampilly\Documents\ChatGPT Datasets\Home Insurance\CSV Datasets\Calibrated Raw Data\Enchanced\date_enterprise_ready.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0D0A',
    CODEPAGE        = '65001',
    TABLOCK
);


SELECT COUNT(*) AS RC
FROM stg.[date];

SELECT TOP (20) *
FROM stg.[date]
ORDER BY DateKey;


SELECT DateKey, COUNT(*) AS Cnt
FROM stg.[date]
GROUP BY DateKey
HAVING COUNT(*) > 1;


SELECT TOP (50)
    DateKey, YearMonthKey, FiscalYearMonthKey,
    [Year], [Month], [Day], [Quarter],
    WeekOfYear_ISO, ISOYear, ISOWeekday
FROM stg.[date]
WHERE DateKey LIKE '%[^0-9]%'
   OR YearMonthKey LIKE '%[^0-9]%'
   OR FiscalYearMonthKey LIKE '%[^0-9]%'
   OR [Year] LIKE '%[^0-9]%'
   OR [Month] LIKE '%[^0-9]%'
   OR [Day] LIKE '%[^0-9]%'
   OR [Quarter] LIKE '%[^0-9]%'
   OR WeekOfYear_ISO LIKE '%[^0-9]%'
   OR ISOYear LIKE '%[^0-9]%'
   OR ISOWeekday LIKE '%[^0-9]%';



   SELECT TOP (50)
    IsToday, IsCurrentMonth, IsCurrentYear, IsYTD,
    IsLast7Days, IsLast30Days, IsLast90Days,
    IsBusinessDay, IsUKBankHoliday, IsWeekendFlag
FROM stg.[date]
WHERE (IsToday NOT IN ('0','1') AND IsToday NOT IN ('Y','N'))
   OR (IsCurrentMonth NOT IN ('0','1') AND IsCurrentMonth NOT IN ('Y','N'))
   OR (IsCurrentYear NOT IN ('0','1') AND IsCurrentYear NOT IN ('Y','N'))
   OR (IsYTD NOT IN ('0','1') AND IsYTD NOT IN ('Y','N'))
   OR (IsLast7Days NOT IN ('0','1') AND IsLast7Days NOT IN ('Y','N'))
   OR (IsLast30Days NOT IN ('0','1') AND IsLast30Days NOT IN ('Y','N'))
   OR (IsLast90Days NOT IN ('0','1') AND IsLast90Days NOT IN ('Y','N'))
   OR (IsBusinessDay NOT IN ('0','1') AND IsBusinessDay NOT IN ('Y','N'))
   OR (IsUKBankHoliday NOT IN ('0','1') AND IsUKBankHoliday NOT IN ('Y','N'))
   OR (IsWeekendFlag NOT IN ('0','1') AND IsWeekendFlag NOT IN ('Y','N'));


   SELECT TOP (50) [Date]
FROM stg.[date]
WHERE [Date] IS NOT NULL
  AND LTRIM(RTRIM([Date])) <> ''
  AND TRY_CONVERT(date, [Date], 103) IS NULL
  AND TRY_CONVERT(date, [Date], 23) IS NULL;


  SELECT TOP (50)
    [Date], DateKey
FROM stg.[date]
WHERE TRY_CONVERT(date, [Date], 103) IS NOT NULL
  AND CONVERT(varchar(8), TRY_CONVERT(date, [Date], 103), 112) <> DateKey
  AND TRY_CONVERT(date, [Date], 23) IS NULL;  -- exclude ISO dates in this check



  SELECT TOP (5) DateKey, [Date], YearMonthKey, FiscalYearMonthKey
FROM stg.[date]
ORDER BY DateKey;
