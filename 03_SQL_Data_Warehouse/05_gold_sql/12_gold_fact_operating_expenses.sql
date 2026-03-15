USE PalthanioHomeInsuranceDW;
GO
SET NOCOUNT ON;
GO

/*==============================================================================
  GOLD FACT: gold.fact_operating_expenses
  Grain: one row per operating expense record from silver.operating_expenses

  Notes
  -----
  This version preserves lineage metadata from Silver:
      - BronzeLoadDts
      - SilverLoadDts
      - SourceFile

==============================================================================*/

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC ('CREATE SCHEMA gold;');
GO

IF OBJECT_ID('gold.fact_operating_expenses','U') IS NOT NULL
    DROP TABLE gold.fact_operating_expenses;
GO

CREATE TABLE gold.fact_operating_expenses
(
    OperatingExpenseFactKey INT IDENTITY(1,1) NOT NULL,
    DateKey INT NULL,
    ExpenseCategoryKey INT NOT NULL,

    ExpenseMonthStart DATE NOT NULL,
    ExpenseAmount DECIMAL(18,2) NOT NULL,
    Currency VARCHAR(10) NULL,
    SourceSystem VARCHAR(50) NULL,
    InflationAdjustedAmount DECIMAL(18,2) NULL,
    YearMonth VARCHAR(20) NULL,
    [Year] INT NULL,
    [Month] INT NULL,
    PreviousMonthAmount DECIMAL(18,2) NULL,
    MoMVariance DECIMAL(18,2) NULL,

    BronzeLoadDts DATETIME2(0) NULL,
    SilverLoadDts DATETIME2(0) NULL,
    SourceFile VARCHAR(255) NULL,

    GoldLoadDts DATETIME2(0) NOT NULL
        CONSTRAINT DF_gold_fact_operating_expenses_GoldLoadDts
        DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_gold_fact_operating_expenses
        PRIMARY KEY (OperatingExpenseFactKey),

    CONSTRAINT FK_gold_fact_operating_expenses_dim_expense_category
        FOREIGN KEY (ExpenseCategoryKey)
        REFERENCES gold.dim_expense_category(ExpenseCategoryKey)
);
GO

INSERT INTO gold.fact_operating_expenses
(
    DateKey,
    ExpenseCategoryKey,
    ExpenseMonthStart,
    ExpenseAmount,
    Currency,
    SourceSystem,
    InflationAdjustedAmount,
    YearMonth,
    [Year],
    [Month],
    PreviousMonthAmount,
    MoMVariance,
    BronzeLoadDts,
    SilverLoadDts,
    SourceFile
)
SELECT
    d.DateKey,
    decat.ExpenseCategoryKey,
    CAST(s.ExpenseMonthStart AS DATE) AS ExpenseMonthStart,
    CAST(s.ExpenseAmount AS DECIMAL(18,2)) AS ExpenseAmount,
    s.Currency,
    s.SourceSystem,
    CAST(s.InflationAdjustedAmount AS DECIMAL(18,2)) AS InflationAdjustedAmount,
    s.YearMonth,
    s.[Year],
    s.[Month],
    CAST(s.PreviousMonthAmount AS DECIMAL(18,2)) AS PreviousMonthAmount,
    CAST(s.MoMVariance AS DECIMAL(18,2)) AS MoMVariance,
    s.BronzeLoadDts,
    s.SilverLoadDts,
    s.SourceFile
FROM silver.operating_expenses s
INNER JOIN gold.dim_expense_category decat
    ON LTRIM(RTRIM(s.ExpenseCategory)) = decat.ExpenseCategory
LEFT JOIN gold.dim_date d
    ON d.FullDate = CAST(s.ExpenseMonthStart AS DATE);
GO

CREATE INDEX IX_gold_fact_operating_expenses_DateKey
    ON gold.fact_operating_expenses(DateKey);
GO

CREATE INDEX IX_gold_fact_operating_expenses_ExpenseCategoryKey
    ON gold.fact_operating_expenses(ExpenseCategoryKey);
GO

SELECT TOP 100 *
FROM gold.fact_operating_expenses
ORDER BY OperatingExpenseFactKey;
GO
