USE PalthanioHomeInsuranceDW;
GO
SET NOCOUNT ON;
GO

/*==============================================================================
  GOLD DIMENSION: gold.dim_expense_category
  Grain: one row per ExpenseCategory
==============================================================================*/

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC ('CREATE SCHEMA gold;');
GO

IF OBJECT_ID('gold.dim_expense_category','U') IS NOT NULL
    DROP TABLE gold.dim_expense_category;
GO

CREATE TABLE gold.dim_expense_category
(
    ExpenseCategoryKey INT IDENTITY(1,1) NOT NULL,
    ExpenseCategory VARCHAR(100) NOT NULL,
    ExpenseType VARCHAR(50) NULL,
    CostCentre VARCHAR(100) NULL,
    ImpactsExpenseRatioFlag BIT NULL,
    ExpenseBand VARCHAR(50) NULL,
    GoldLoadDts DATETIME2(0) NOT NULL
        CONSTRAINT DF_gold_dim_expense_category_GoldLoadDts
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_gold_dim_expense_category
        PRIMARY KEY (ExpenseCategoryKey)
);
GO

/*------------------------------------------------------------------------------
  Insert one row per ExpenseCategory
------------------------------------------------------------------------------*/
;WITH Deduped AS
(
    SELECT
        LTRIM(RTRIM(ExpenseCategory)) AS ExpenseCategory,
        ExpenseType,
        CostCentre,
        ImpactsExpenseRatioFlag,
        ExpenseBand,
        ROW_NUMBER() OVER
        (
            PARTITION BY LTRIM(RTRIM(ExpenseCategory))
            ORDER BY LTRIM(RTRIM(ExpenseCategory))
        ) AS rn
    FROM silver.operating_expenses
    WHERE ExpenseCategory IS NOT NULL
      AND LTRIM(RTRIM(ExpenseCategory)) <> ''
)
INSERT INTO gold.dim_expense_category
(
    ExpenseCategory,
    ExpenseType,
    CostCentre,
    ImpactsExpenseRatioFlag,
    ExpenseBand
)
SELECT
    ExpenseCategory,
    ExpenseType,
    CostCentre,
    ImpactsExpenseRatioFlag,
    ExpenseBand
FROM Deduped
WHERE rn = 1;
GO

/*------------------------------------------------------------------------------
  Validation
------------------------------------------------------------------------------*/
SELECT *
FROM gold.dim_expense_category
ORDER BY ExpenseCategoryKey;
GO
