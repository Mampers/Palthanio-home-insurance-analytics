/*==============================================================================
    DATABASE:      PalthanioHomeInsuranceDW
    LAYER:         GOLD
    OBJECT:        gold.fact_policy_coverage
    SOURCE:        silver.coverage
    DEPENDS ON:    gold.dim_coverage

    PURPOSE
    -------
    Build gold.fact_policy_coverage from silver.coverage using the exact source
    columns, while linking each row to gold.dim_coverage via CoverageType.
==============================================================================*/

USE PalthanioHomeInsuranceDW;
SET NOCOUNT ON;

BEGIN TRY

    /*==========================================================================
      0) PRE-FLIGHT CHECKS
    ==========================================================================*/
    IF OBJECT_ID('silver.coverage', 'U') IS NULL
        THROW 68001, 'Source table silver.coverage does not exist.', 1;

    IF OBJECT_ID('gold.dim_coverage', 'U') IS NULL
        THROW 68002, 'Required table gold.dim_coverage does not exist.', 1;

    IF COL_LENGTH('silver.coverage', 'CoverageType') IS NULL
        THROW 68003, 'Required column CoverageType does not exist in silver.coverage.', 1;

    IF COL_LENGTH('gold.dim_coverage', 'CoverageKey') IS NULL
        THROW 68004, 'Required column CoverageKey does not exist in gold.dim_coverage.', 1;

    IF COL_LENGTH('gold.dim_coverage', 'CoverageType') IS NULL
        THROW 68005, 'Required column CoverageType does not exist in gold.dim_coverage.', 1;

    DECLARE @SilverCoverageRowCount int;
    SELECT @SilverCoverageRowCount = COUNT(*)
    FROM silver.coverage;

    IF @SilverCoverageRowCount = 0
        THROW 68006, 'Source table silver.coverage exists but contains 0 rows.', 1;

    PRINT 'Pre-flight OK. silver.coverage rows = ' + CAST(@SilverCoverageRowCount AS varchar(20));

    /*==========================================================================
      1) DROP TARGET TABLE
    ==========================================================================*/
    IF OBJECT_ID('gold.fact_policy_coverage', 'U') IS NOT NULL
        DROP TABLE gold.fact_policy_coverage;

    /*==========================================================================
      2) CREATE FACT TABLE BY CLONING SILVER EXACTLY
    ==========================================================================*/
    SELECT TOP (0) *
    INTO gold.fact_policy_coverage
    FROM silver.coverage;

    /*==========================================================================
      3) ADD GOLD-SPECIFIC COLUMNS
    ==========================================================================*/
    ALTER TABLE gold.fact_policy_coverage
    ADD
        PolicyCoverageFactKey bigint IDENTITY(1,1) NOT NULL,
        CoverageKey int NULL,
        GoldLoadDts datetime2(0) NOT NULL
            CONSTRAINT DF_gold_fact_policy_coverage_GoldLoadDts DEFAULT GETUTCDATE();

    /*==========================================================================
      4) ADD PRIMARY KEY
    ==========================================================================*/
    ALTER TABLE gold.fact_policy_coverage
    ADD CONSTRAINT PK_gold_fact_policy_coverage
        PRIMARY KEY (PolicyCoverageFactKey);

    /*==========================================================================
      5) LOAD FACT DATA USING EXACT SILVER COLUMNS
    ==========================================================================*/
    DECLARE @InsertCols nvarchar(max);
    DECLARE @SelectCols nvarchar(max);
    DECLARE @LoadSql nvarchar(max);

    SELECT @InsertCols =
        STUFF((
            SELECT ',' + QUOTENAME(c.name)
            FROM sys.columns c
            WHERE c.object_id = OBJECT_ID('gold.fact_policy_coverage')
              AND c.name NOT IN ('PolicyCoverageFactKey', 'CoverageKey', 'GoldLoadDts')
            ORDER BY c.column_id
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)'), 1, 1, '');

    SELECT @SelectCols =
        STUFF((
            SELECT ',s.' + QUOTENAME(c.name)
            FROM sys.columns c
            WHERE c.object_id = OBJECT_ID('gold.fact_policy_coverage')
              AND c.name NOT IN ('PolicyCoverageFactKey', 'CoverageKey', 'GoldLoadDts')
            ORDER BY c.column_id
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)'), 1, 1, '');

    SET @LoadSql = N'
        INSERT INTO gold.fact_policy_coverage (' + @InsertCols + N')
        SELECT ' + @SelectCols + N'
        FROM silver.coverage s;
    ';

    EXEC sp_executesql @LoadSql;

    /*==========================================================================
      6) POPULATE COVERAGEKEY FROM DIMENSION
    ==========================================================================*/
    DECLARE @UpdateSql nvarchar(max);

    SET @UpdateSql = N'
        UPDATE f
        SET f.CoverageKey = d.CoverageKey
        FROM gold.fact_policy_coverage f
        INNER JOIN gold.dim_coverage d
            ON d.CoverageType =
               CASE
                   WHEN f.CoverageType IS NULL
                     OR LTRIM(RTRIM(CAST(f.CoverageType AS varchar(100)))) = ''''
                        THEN ''UNKNOWN''
                   ELSE LTRIM(RTRIM(CAST(f.CoverageType AS varchar(100))))
               END;
    ';

    EXEC sp_executesql @UpdateSql;

    /*==========================================================================
      7) DEFAULT UNMATCHED ROWS TO UNKNOWN MEMBER
    ==========================================================================*/
    DECLARE @UnknownSql nvarchar(max);

    SET @UnknownSql = N'
        UPDATE gold.fact_policy_coverage
        SET CoverageKey = -1
        WHERE CoverageKey IS NULL;
    ';

    EXEC sp_executesql @UnknownSql;

    /*==========================================================================
      8) ENFORCE NOT NULL ON COVERAGEKEY
    ==========================================================================*/
    EXEC sp_executesql N'
        ALTER TABLE gold.fact_policy_coverage
        ALTER COLUMN CoverageKey int NOT NULL;
    ';

    /*==========================================================================
      9) ADD FOREIGN KEY
    ==========================================================================*/
    EXEC sp_executesql N'
        ALTER TABLE gold.fact_policy_coverage
        ADD CONSTRAINT FK_gold_fact_policy_coverage_dim_coverage
            FOREIGN KEY (CoverageKey)
            REFERENCES gold.dim_coverage (CoverageKey);
    ';

    /*==========================================================================
      10) INDEXES
    ==========================================================================*/
    EXEC sp_executesql N'
        CREATE INDEX IX_gold_fact_policy_coverage_CoverageKey
            ON gold.fact_policy_coverage (CoverageKey);
    ';

    IF COL_LENGTH('gold.fact_policy_coverage', 'CoverageType') IS NOT NULL
        EXEC sp_executesql N'
            CREATE INDEX IX_gold_fact_policy_coverage_CoverageType
                ON gold.fact_policy_coverage (CoverageType);
        ';

    IF COL_LENGTH('gold.fact_policy_coverage', 'PolicyID') IS NOT NULL
        EXEC sp_executesql N'
            CREATE INDEX IX_gold_fact_policy_coverage_PolicyID
                ON gold.fact_policy_coverage (PolicyID);
        ';

    /*==========================================================================
      11) VALIDATION
    ==========================================================================*/
    SELECT COUNT(*) AS SilverCoverageRows
    FROM silver.coverage;

    SELECT COUNT(*) AS FactPolicyCoverageRows
    FROM gold.fact_policy_coverage;

    EXEC sp_executesql N'
        SELECT TOP (50) *
        FROM gold.fact_policy_coverage
        ORDER BY PolicyCoverageFactKey;
    ';

END TRY
BEGIN CATCH
    DECLARE @ErrNum int;
    DECLARE @ErrLine int;
    DECLARE @ErrMsg nvarchar(4000);
    DECLARE @CatchMsg nvarchar(2047);

    SELECT
        @ErrNum  = ERROR_NUMBER(),
        @ErrLine = ERROR_LINE(),
        @ErrMsg  = ERROR_MESSAGE();

    SET @CatchMsg =
        N'Gold fact_policy_coverage build failed. Error ' + CAST(@ErrNum AS nvarchar(20)) +
        N' at line ' + CAST(@ErrLine AS nvarchar(20)) +
        N': ' + @ErrMsg;

    THROW 69000, @CatchMsg, 1;
END CATCH;
