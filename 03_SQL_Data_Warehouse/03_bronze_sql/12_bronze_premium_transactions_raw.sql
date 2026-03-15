/*==============================================================================
    (SIMPLE, LIKE YOUR policy_risk SCRIPT)
    stg.premium_transactions  -->  bronze.premium_transactions_raw

    IMPORTANT (why this is “Option A”):
    - Run this in TWO SECTIONS using the GO separators.
    - Section 1 adds any missing STG columns.
    - Section 2 builds + loads BRONZE.
    - This avoids dynamic SQL and avoids the compile-time “Invalid column name” errors.
==============================================================================*/

/*==============================================================================
  SECTION 1: Ensure STG has required columns (RUN ONCE / AS NEEDED)
==============================================================================*/
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stg')
    EXEC('CREATE SCHEMA stg;');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
    EXEC('CREATE SCHEMA bronze;');

IF OBJECT_ID('stg.premium_transactions','U') IS NULL
BEGIN
    RAISERROR('Table stg.premium_transactions does not exist. Create/load STG first.', 16, 1);
    RETURN;
END

IF COL_LENGTH('stg.premium_transactions', 'CalculatedNetPremium') IS NULL
    ALTER TABLE stg.premium_transactions ADD CalculatedNetPremium varchar(50) NULL;

IF COL_LENGTH('stg.premium_transactions', 'NetPremiumVariance') IS NULL
    ALTER TABLE stg.premium_transactions ADD NetPremiumVariance varchar(50) NULL;

IF COL_LENGTH('stg.premium_transactions', 'PremiumDataQualityFlag') IS NULL
    ALTER TABLE stg.premium_transactions ADD PremiumDataQualityFlag varchar(20) NULL;

IF COL_LENGTH('stg.premium_transactions', 'PremiumBand') IS NULL
    ALTER TABLE stg.premium_transactions ADD PremiumBand varchar(100) NULL;

IF COL_LENGTH('stg.premium_transactions', 'InstallmentNumber') IS NULL
    ALTER TABLE stg.premium_transactions ADD InstallmentNumber varchar(20) NULL;

IF COL_LENGTH('stg.premium_transactions', 'IsInstallmentPlanFlag') IS NULL
    ALTER TABLE stg.premium_transactions ADD IsInstallmentPlanFlag varchar(20) NULL;

IF COL_LENGTH('stg.premium_transactions', 'TransactionType') IS NULL
    ALTER TABLE stg.premium_transactions ADD TransactionType varchar(100) NULL;

IF COL_LENGTH('stg.premium_transactions', 'YearMonth') IS NULL
    ALTER TABLE stg.premium_transactions ADD YearMonth varchar(50) NULL;

IF COL_LENGTH('stg.premium_transactions', 'Year') IS NULL
    ALTER TABLE stg.premium_transactions ADD [Year] varchar(10) NULL;

IF COL_LENGTH('stg.premium_transactions', 'Month') IS NULL
    ALTER TABLE stg.premium_transactions ADD [Month] varchar(10) NULL;

IF COL_LENGTH('stg.premium_transactions', 'IsYTDFlag') IS NULL
    ALTER TABLE stg.premium_transactions ADD IsYTDFlag varchar(20) NULL;

IF COL_LENGTH('stg.premium_transactions', 'IsLast12MonthsFlag') IS NULL
    ALTER TABLE stg.premium_transactions ADD IsLast12MonthsFlag varchar(20) NULL;

IF COL_LENGTH('stg.premium_transactions', 'TotalWrittenPremium') IS NULL
    ALTER TABLE stg.premium_transactions ADD TotalWrittenPremium varchar(50) NULL;

IF COL_LENGTH('stg.premium_transactions', 'TotalNetWrittenPremium') IS NULL
    ALTER TABLE stg.premium_transactions ADD TotalNetWrittenPremium varchar(50) NULL;

IF COL_LENGTH('stg.premium_transactions', 'IPTRatio') IS NULL
    ALTER TABLE stg.premium_transactions ADD IPTRatio varchar(50) NULL;

IF COL_LENGTH('stg.premium_transactions', 'DiscountRatio') IS NULL
    ALTER TABLE stg.premium_transactions ADD DiscountRatio varchar(50) NULL;

IF COL_LENGTH('stg.premium_transactions', 'SourceSystem') IS NULL
    ALTER TABLE stg.premium_transactions ADD SourceSystem varchar(50) NULL;

GO


/*==============================================================================
  SECTION 2: FULL BRONZE BUILD + LOAD + VALIDATIONS (RUN WHENEVER)
==============================================================================*/
SET NOCOUNT ON;

BEGIN TRY
    /*--------------------------------------------
      0) Ensure bronze schema
    --------------------------------------------*/
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
        EXEC('CREATE SCHEMA bronze;');

    /*--------------------------------------------
      1) (Re)Create bronze table
    --------------------------------------------*/
    DROP TABLE IF EXISTS bronze.premium_transactions_raw;

    CREATE TABLE bronze.premium_transactions_raw (
        PremiumTransactionID       varchar(50)   NULL,
        PolicyID                   varchar(50)   NULL,

        TransactionDate            date          NULL,

        GrossPremium               decimal(18,2) NULL,
        IPTPremiumTax              decimal(18,2) NULL,
        AdminFee                   decimal(18,2) NULL,
        Discount                   decimal(18,2) NULL,
        NetPremium                 decimal(18,2) NULL,

        TransactionStatus          varchar(50)   NOT NULL,
        CalculatedNetPremium       decimal(18,2) NULL,
        NetPremiumVariance         decimal(18,2) NULL,

        PremiumDataQualityFlag     bit           NULL,
        PremiumBand                varchar(100)  NULL,

        InstallmentNumber          int           NULL,
        IsInstallmentPlanFlag      bit           NULL,

        TransactionType            varchar(100)  NOT NULL,

        YearMonth                  char(7)       NULL,  -- YYYY-MM
        [Year]                     int           NULL,
        [Month]                    int           NULL,

        IsYTDFlag                  bit           NULL,
        IsLast12MonthsFlag         bit           NULL,

        TotalWrittenPremium        decimal(18,2) NULL,
        TotalNetWrittenPremium     decimal(18,2) NULL,

        IPTRatio                   decimal(9,4)  NULL,
        DiscountRatio              decimal(9,4)  NULL,

        BronzeLoadDts              datetime2(0)  NOT NULL
            CONSTRAINT DF_bronze_premtrans_BronzeLoadDts DEFAULT (SYSUTCDATETIME()),
        SourceSystem               varchar(50)   NOT NULL
            CONSTRAINT DF_bronze_premtrans_SourceSystem DEFAULT ('CalibratedCSV')
    );

    /*--------------------------------------------
      2) Load: stg -> bronze
         - Default text fields to 'Unknown' when blank (portfolio-friendly)
    --------------------------------------------*/
    TRUNCATE TABLE bronze.premium_transactions_raw;

    INSERT INTO bronze.premium_transactions_raw (
        PremiumTransactionID,
        PolicyID,
        TransactionDate,
        GrossPremium,
        IPTPremiumTax,
        AdminFee,
        Discount,
        NetPremium,
        TransactionStatus,
        CalculatedNetPremium,
        NetPremiumVariance,
        PremiumDataQualityFlag,
        PremiumBand,
        InstallmentNumber,
        IsInstallmentPlanFlag,
        TransactionType,
        YearMonth,
        [Year],
        [Month],
        IsYTDFlag,
        IsLast12MonthsFlag,
        TotalWrittenPremium,
        TotalNetWrittenPremium,
        IPTRatio,
        DiscountRatio,
        SourceSystem
    )
    SELECT
        NULLIF(LTRIM(RTRIM(s.PremiumTransactionID)), '') AS PremiumTransactionID,
        NULLIF(LTRIM(RTRIM(s.PolicyID)), '')             AS PolicyID,

        COALESCE(
            TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(s.TransactionDate)), ''), 23),   -- yyyy-mm-dd
            TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(s.TransactionDate)), ''), 103)   -- dd/mm/yyyy
        ) AS TransactionDate,

        TRY_CONVERT(decimal(18,2), NULLIF(LTRIM(RTRIM(s.GrossPremium)), ''))   AS GrossPremium,
        TRY_CONVERT(decimal(18,2), NULLIF(LTRIM(RTRIM(s.IPTPremiumTax)), ''))  AS IPTPremiumTax,
        TRY_CONVERT(decimal(18,2), NULLIF(LTRIM(RTRIM(s.AdminFee)), ''))       AS AdminFee,
        TRY_CONVERT(decimal(18,2), NULLIF(LTRIM(RTRIM(s.Discount)), ''))       AS Discount,
        TRY_CONVERT(decimal(18,2), NULLIF(LTRIM(RTRIM(s.NetPremium)), ''))     AS NetPremium,

        COALESCE(NULLIF(LTRIM(RTRIM(s.TransactionStatus)), ''), 'Unknown')     AS TransactionStatus,

        TRY_CONVERT(decimal(18,2), NULLIF(LTRIM(RTRIM(s.CalculatedNetPremium)), '')) AS CalculatedNetPremium,
        TRY_CONVERT(decimal(18,2), NULLIF(LTRIM(RTRIM(s.NetPremiumVariance)), ''))   AS NetPremiumVariance,

        CASE
            WHEN NULLIF(LTRIM(RTRIM(s.PremiumDataQualityFlag)), '') IS NULL THEN NULL
            WHEN UPPER(LTRIM(RTRIM(s.PremiumDataQualityFlag))) IN ('1','Y','YES','TRUE') THEN CAST(1 AS bit)
            WHEN UPPER(LTRIM(RTRIM(s.PremiumDataQualityFlag))) IN ('0','N','NO','FALSE') THEN CAST(0 AS bit)
            ELSE NULL
        END AS PremiumDataQualityFlag,

        NULLIF(LTRIM(RTRIM(s.PremiumBand)), '') AS PremiumBand,

        TRY_CONVERT(int, NULLIF(LTRIM(RTRIM(s.InstallmentNumber)), '')) AS InstallmentNumber,

        CASE
            WHEN NULLIF(LTRIM(RTRIM(s.IsInstallmentPlanFlag)), '') IS NULL THEN NULL
            WHEN UPPER(LTRIM(RTRIM(s.IsInstallmentPlanFlag))) IN ('1','Y','YES','TRUE') THEN CAST(1 AS bit)
            WHEN UPPER(LTRIM(RTRIM(s.IsInstallmentPlanFlag))) IN ('0','N','NO','FALSE') THEN CAST(0 AS bit)
            ELSE NULL
        END AS IsInstallmentPlanFlag,

        COALESCE(NULLIF(LTRIM(RTRIM(s.TransactionType)), ''), 'Unknown') AS TransactionType,

        CASE
            WHEN NULLIF(LTRIM(RTRIM(s.YearMonth)), '') IS NULL THEN NULL
            WHEN LTRIM(RTRIM(s.YearMonth)) LIKE '[12][0-9][0-9][0-9]-[01][0-9]'
                THEN LEFT(LTRIM(RTRIM(s.YearMonth)), 7)
            ELSE NULL
        END AS YearMonth,

        TRY_CONVERT(int, NULLIF(LTRIM(RTRIM(s.[Year])), ''))  AS [Year],
        TRY_CONVERT(int, NULLIF(LTRIM(RTRIM(s.[Month])), '')) AS [Month],

        CASE
            WHEN NULLIF(LTRIM(RTRIM(s.IsYTDFlag)), '') IS NULL THEN NULL
            WHEN UPPER(LTRIM(RTRIM(s.IsYTDFlag))) IN ('1','Y','YES','TRUE') THEN CAST(1 AS bit)
            WHEN UPPER(LTRIM(RTRIM(s.IsYTDFlag))) IN ('0','N','NO','FALSE') THEN CAST(0 AS bit)
            ELSE NULL
        END AS IsYTDFlag,

        CASE
            WHEN NULLIF(LTRIM(RTRIM(s.IsLast12MonthsFlag)), '') IS NULL THEN NULL
            WHEN UPPER(LTRIM(RTRIM(s.IsLast12MonthsFlag))) IN ('1','Y','YES','TRUE') THEN CAST(1 AS bit)
            WHEN UPPER(LTRIM(RTRIM(s.IsLast12MonthsFlag))) IN ('0','N','NO','FALSE') THEN CAST(0 AS bit)
            ELSE NULL
        END AS IsLast12MonthsFlag,

        TRY_CONVERT(decimal(18,2), NULLIF(LTRIM(RTRIM(s.TotalWrittenPremium)), ''))     AS TotalWrittenPremium,
        TRY_CONVERT(decimal(18,2), NULLIF(LTRIM(RTRIM(s.TotalNetWrittenPremium)), ''))  AS TotalNetWrittenPremium,

        TRY_CONVERT(decimal(9,4), NULLIF(LTRIM(RTRIM(s.IPTRatio)), ''))       AS IPTRatio,
        TRY_CONVERT(decimal(9,4), NULLIF(LTRIM(RTRIM(s.DiscountRatio)), ''))  AS DiscountRatio,

        COALESCE(NULLIF(LTRIM(RTRIM(s.SourceSystem)), ''), 'CalibratedCSV')   AS SourceSystem
    FROM stg.premium_transactions s;

    /*--------------------------------------------
      3) VALIDATION PACK
    --------------------------------------------*/
    PRINT 'VALIDATION: Row counts';
    SELECT COUNT(*) AS StgRowCount FROM stg.premium_transactions;
    SELECT COUNT(*) AS BronzeRowCount FROM bronze.premium_transactions_raw;

    PRINT 'VALIDATION: Missing keys (PremiumTransactionID / PolicyID)';
    SELECT TOP (50) *
    FROM bronze.premium_transactions_raw
    WHERE PremiumTransactionID IS NULL OR PolicyID IS NULL;

    PRINT 'VALIDATION: Duplicate PremiumTransactionID';
    SELECT PremiumTransactionID, COUNT(*) AS Cnt
    FROM bronze.premium_transactions_raw
    WHERE PremiumTransactionID IS NOT NULL
    GROUP BY PremiumTransactionID
    HAVING COUNT(*) > 1;

    PRINT 'VALIDATION: TransactionStatus defaults applied (Unknown count)';
    SELECT
        SUM(CASE WHEN TransactionStatus = 'Unknown' THEN 1 ELSE 0 END) AS UnknownStatusRows,
        COUNT(*) AS TotalRows
    FROM bronze.premium_transactions_raw;

    PRINT 'VALIDATION: TransactionType defaults applied (Unknown count)';
    SELECT
        SUM(CASE WHEN TransactionType = 'Unknown' THEN 1 ELSE 0 END) AS UnknownTypeRows,
        COUNT(*) AS TotalRows
    FROM bronze.premium_transactions_raw;

    PRINT 'VALIDATION: TransactionDate parse failures (stg has date text, bronze is NULL)';
    SELECT TOP (50)
        s.PremiumTransactionID,
        s.TransactionDate AS StgTransactionDate
    FROM stg.premium_transactions s
    LEFT JOIN bronze.premium_transactions_raw b
      ON b.PremiumTransactionID = NULLIF(LTRIM(RTRIM(s.PremiumTransactionID)), '')
    WHERE NULLIF(LTRIM(RTRIM(s.TransactionDate)), '') IS NOT NULL
      AND b.TransactionDate IS NULL
    ORDER BY s.PremiumTransactionID;

    PRINT 'VALIDATION: YearMonth format issues in STG';
    SELECT TOP (50) s.YearMonth
    FROM stg.premium_transactions s
    WHERE LTRIM(RTRIM(ISNULL(s.YearMonth,''))) <> ''
      AND s.YearMonth NOT LIKE '[12][0-9][0-9][0-9]-[01][0-9]';

    PRINT 'VALIDATION: Variance check (if all present, tolerance > 0.50)';
    SELECT TOP (50)
        PremiumTransactionID,
        NetPremium,
        CalculatedNetPremium,
        NetPremiumVariance,
        (NetPremium - CalculatedNetPremium) AS CalcVariance,
        ABS((NetPremium - CalculatedNetPremium) - NetPremiumVariance) AS Diff
    FROM bronze.premium_transactions_raw
    WHERE NetPremium IS NOT NULL
      AND CalculatedNetPremium IS NOT NULL
      AND NetPremiumVariance IS NOT NULL
      AND ABS((NetPremium - CalculatedNetPremium) - NetPremiumVariance) > 0.50;

    PRINT 'DONE: stg.premium_transactions -> bronze.premium_transactions_raw completed.';

END TRY
BEGIN CATCH
    DECLARE @ErrMsg nvarchar(4000) = ERROR_MESSAGE();
    DECLARE @ErrSev int = ERROR_SEVERITY();
    DECLARE @ErrState int = ERROR_STATE();

    PRINT 'ERROR in stg -> bronze script:';
    PRINT @ErrMsg;

    RAISERROR(@ErrMsg, @ErrSev, @ErrState);
END CATCH;

-- Sample output
SELECT TOP (60) *
FROM bronze.premium_transactions_raw
ORDER BY BronzeLoadDts DESC;


SELECT *
FROM bronze.premium_transactions_raw
