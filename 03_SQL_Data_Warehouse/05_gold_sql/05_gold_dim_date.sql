/*==============================================================================
  PalthanioHomeInsuranceDW
  GOLD LAYER – DIMENSION TABLE
  Table: gold.dim_date

  Purpose
  -------
  Creates the enterprise Date dimension used across the warehouse.

  Unlike other dimensions, Date dimensions are generated rather than sourced
  from transactional tables because they require rich calendar attributes
  used for analytics, reporting and time intelligence.

  Grain
  -----
      One row per calendar date

  Typical Uses
  ------------
      - Policy start and end dates
      - Claim reported dates
      - Payment transaction dates
      - Reserve snapshot dates
      - Financial reporting periods

  Author
  ------
      Palthanio Analytics Portfolio
==============================================================================*/

USE PalthanioHomeInsuranceDW;
GO
SET NOCOUNT ON;
GO

/*==============================================================================
  1. Ensure Gold Schema Exists
==============================================================================*/
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
BEGIN
    EXEC('CREATE SCHEMA gold');
END
GO


/*==============================================================================
  2. Drop Table If Rebuilding
==============================================================================*/
IF OBJECT_ID('gold.dim_date','U') IS NOT NULL
    DROP TABLE gold.dim_date;
GO


/*==============================================================================
  3. Create Date Dimension Table
==============================================================================*/
CREATE TABLE gold.dim_date
(
    DateKey INT PRIMARY KEY,              -- YYYYMMDD format

    FullDate DATE NOT NULL,

    DayNumberOfMonth TINYINT,
    DayName VARCHAR(10),

    DayOfWeekNumber TINYINT,

    DayOfYear SMALLINT,

    WeekNumberOfYear TINYINT,

    MonthNumber TINYINT,
    MonthName VARCHAR(10),

    QuarterNumber TINYINT,

    YearNumber SMALLINT,

    MonthYear VARCHAR(20),

    IsWeekend BIT,

    GoldLoadDts DATETIME2(0)
        DEFAULT SYSUTCDATETIME()
);
GO


/*==============================================================================
  4. Populate Date Dimension
     Range can be adjusted as required
==============================================================================*/

DECLARE @StartDate DATE = '2015-01-01';
DECLARE @EndDate DATE   = '2035-12-31';

;WITH DateGenerator AS
(
    SELECT @StartDate AS TheDate

    UNION ALL

    SELECT DATEADD(DAY,1,TheDate)
    FROM DateGenerator
    WHERE TheDate < @EndDate
)

INSERT INTO gold.dim_date
(
    DateKey,
    FullDate,
    DayNumberOfMonth,
    DayName,
    DayOfWeekNumber,
    DayOfYear,
    WeekNumberOfYear,
    MonthNumber,
    MonthName,
    QuarterNumber,
    YearNumber,
    MonthYear,
    IsWeekend
)

SELECT
    CONVERT(INT,FORMAT(TheDate,'yyyyMMdd')) AS DateKey,

    TheDate AS FullDate,

    DAY(TheDate),

    DATENAME(WEEKDAY,TheDate),

    DATEPART(WEEKDAY,TheDate),

    DATEPART(DAYOFYEAR,TheDate),

    DATEPART(WEEK,TheDate),

    MONTH(TheDate),

    DATENAME(MONTH,TheDate),

    DATEPART(QUARTER,TheDate),

    YEAR(TheDate),

    CONCAT(DATENAME(MONTH,TheDate),' ',YEAR(TheDate)),

    CASE
        WHEN DATENAME(WEEKDAY,TheDate) IN ('Saturday','Sunday')
        THEN 1
        ELSE 0
    END

FROM DateGenerator
OPTION (MAXRECURSION 0);
GO


/*==============================================================================
  5. Validation Checks
==============================================================================*/

PRINT 'Validation Results';

SELECT COUNT(*) AS DateRows
FROM gold.dim_date;

SELECT TOP 20 *
FROM gold.dim_date
ORDER BY FullDate;

PRINT 'SUCCESS: gold.dim_date created successfully.';
GO
