/*==============================================================================
  PalthanioHomeInsuranceDW
  GOLD LAYER – DIMENSION TABLE
  Table: gold.dim_customers

  Purpose
  -------
  Creates the Gold Customer dimension from silver.customer using the exact
  column structure that already exists in Silver.

  This version is metadata-driven so that it:
      - does NOT invent column names
      - uses the real columns from silver.customer
      - automatically detects the customer business key
      - adds a surrogate key for dimensional modelling
      - excludes technical metadata columns from the business dimension

  Source
  ------
      silver.customer

  Target
  ------
      gold.dim_customers

  Grain
  -----
      One row per customer business key

  Notes
  -----
      - This script is designed to be safe where Silver was cloned directly
        from Bronze and column names may vary.
      - Common technical metadata columns are excluded from the Gold business
        dimension where present:
            SilverLoadDts
            BronzeLoadDts
            SourceFile

==============================================================================*/

USE PalthanioHomeInsuranceDW;
GO
SET NOCOUNT ON;
GO

BEGIN TRY

    /*==========================================================================
      1. Ensure Gold Schema Exists
    ==========================================================================*/
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
        EXEC('CREATE SCHEMA gold;');

    /*==========================================================================
      2. Ensure Source Table Exists
    ==========================================================================*/
    DECLARE @SrcObjId INT = OBJECT_ID(N'silver.customer');

    IF @SrcObjId IS NULL
        THROW 50001, 'Source table silver.customer not found.', 1;

    /*==========================================================================
      3. Detect Customer Business Key Column
         We only use real column names that exist in silver.customer
    ==========================================================================*/
    IF OBJECT_ID('tempdb..#cols') IS NOT NULL
        DROP TABLE #cols;

    SELECT
        c.column_id,
        c.name AS RealName,
        t.name AS TypeName,
        c.max_length,
        c.precision,
        c.scale,
        c.is_nullable,
        LOWER(REPLACE(REPLACE(c.name,' ',''),'_','')) AS NormName
    INTO #cols
    FROM sys.columns c
    INNER JOIN sys.types t
        ON c.user_type_id = t.user_type_id
    WHERE c.object_id = @SrcObjId
      AND c.is_computed = 0;

    DECLARE @KeyCol SYSNAME =
    (
        SELECT TOP (1) RealName
        FROM #cols
        WHERE NormName IN
        (
            'customerid',
            'policyholderid',
            'personid',
            'clientid',
            'insuredid',
            'insuredpersonid',
            'partyid',
            'id'
        )
        ORDER BY
            CASE NormName
                WHEN 'customerid' THEN 1
                WHEN 'policyholderid' THEN 2
                WHEN 'personid' THEN 3
                WHEN 'clientid' THEN 4
                WHEN 'insuredid' THEN 5
                WHEN 'insuredpersonid' THEN 6
                WHEN 'partyid' THEN 7
                WHEN 'id' THEN 99
                ELSE 100
            END
    );

    IF @KeyCol IS NULL
    BEGIN
        PRINT 'DEBUG: silver.customer columns found:';
        SELECT column_id, RealName, TypeName, NormName
        FROM #cols
        ORDER BY column_id;

        THROW 50002, 'Could not detect customer key column in silver.customer.', 1;
    END

    PRINT 'Detected customer business key column: ' + QUOTENAME(@KeyCol);

    /*==========================================================================
      4. Drop Existing Gold Table If Rebuilding
    ==========================================================================*/
    IF OBJECT_ID('gold.dim_customers','U') IS NOT NULL
        DROP TABLE gold.dim_customers;

    /*==========================================================================
      5. Build Exact Gold Column List From silver.customer
         Excluding technical metadata columns where present
    ==========================================================================*/
    DECLARE @BusinessColumns TABLE
    (
        column_id     INT,
        RealName      SYSNAME,
        TypeName      SYSNAME,
        max_length    INT,
        precision_val INT,
        scale_val     INT,
        is_nullable   BIT
    );

    INSERT INTO @BusinessColumns
    (
        column_id,
        RealName,
        TypeName,
        max_length,
        precision_val,
        scale_val,
        is_nullable
    )
    SELECT
        column_id,
        RealName,
        TypeName,
        max_length,
        precision,
        scale,
        is_nullable
    FROM #cols
    WHERE RealName NOT IN ('SilverLoadDts', 'BronzeLoadDts', 'SourceFile')
    ORDER BY column_id;

    DECLARE @CreateCols NVARCHAR(MAX);
    DECLARE @InsertCols NVARCHAR(MAX);
    DECLARE @SelectCols NVARCHAR(MAX);
    DECLARE @SQL NVARCHAR(MAX);

    /* Build CREATE TABLE column definitions using exact source datatypes */
    SELECT @CreateCols =
        STRING_AGG(
            '    ' + QUOTENAME(RealName) + ' ' +
            CASE
                WHEN TypeName IN ('varchar','char','varbinary','binary')
                    THEN TypeName + '(' + CASE WHEN max_length = -1 THEN 'MAX' ELSE CAST(max_length AS VARCHAR(10)) END + ')'
                WHEN TypeName IN ('nvarchar','nchar')
                    THEN TypeName + '(' + CASE WHEN max_length = -1 THEN 'MAX' ELSE CAST(max_length / 2 AS VARCHAR(10)) END + ')'
                WHEN TypeName IN ('decimal','numeric')
                    THEN TypeName + '(' + CAST(precision_val AS VARCHAR(10)) + ',' + CAST(scale_val AS VARCHAR(10)) + ')'
                WHEN TypeName IN ('datetime2','time','datetimeoffset')
                    THEN TypeName + '(' + CAST(scale_val AS VARCHAR(10)) + ')'
                ELSE TypeName
            END +
            CASE WHEN is_nullable = 1 THEN ' NULL' ELSE ' NOT NULL' END
        , ',' + CHAR(13) + CHAR(10))
    FROM @BusinessColumns;

    /* Build INSERT column list */
    SELECT @InsertCols =
        STRING_AGG(QUOTENAME(RealName), ', ')
    FROM @BusinessColumns;

    /* Build SELECT column list */
    SELECT @SelectCols =
        STRING_AGG('s.' + QUOTENAME(RealName), ', ')
    FROM @BusinessColumns;

    /*==========================================================================
      6. Create Gold Dimension Table
    ==========================================================================*/
    SET @SQL = N'
CREATE TABLE gold.dim_customers
(
    CustomerKey INT IDENTITY(1,1) NOT NULL,
' + @CreateCols + ',
    GoldLoadDts DATETIME2(0) NOT NULL
        CONSTRAINT DF_gold_dim_customers_GoldLoadDts DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_gold_dim_customers PRIMARY KEY (CustomerKey)
);';

    EXEC sp_executesql @SQL;

    /*==========================================================================
      7. Load Gold Dimension
         Deduplicate by detected business key if duplicates exist in Silver
    ==========================================================================*/
    SET @SQL = N'
;WITH Deduped AS
(
    SELECT
        ' + @SelectCols + ',
        ROW_NUMBER() OVER
        (
            PARTITION BY s.' + QUOTENAME(@KeyCol) + '
            ORDER BY
                CASE WHEN COL_LENGTH(''silver.customer'',''SilverLoadDts'') IS NOT NULL THEN 1 ELSE 2 END,
                s.' + QUOTENAME(@KeyCol) + '
        ) AS rn
    FROM silver.customer s
    WHERE s.' + QUOTENAME(@KeyCol) + ' IS NOT NULL
      AND LTRIM(RTRIM(CAST(s.' + QUOTENAME(@KeyCol) + ' AS VARCHAR(200)))) <> ''''
)
INSERT INTO gold.dim_customers
(
    ' + @InsertCols + '
)
SELECT
    ' + @SelectCols + '
FROM Deduped s
WHERE rn = 1;';

    EXEC sp_executesql @SQL;

    /*==========================================================================
      8. Optional Unique Constraint On Business Key
    ==========================================================================*/
    SET @SQL = N'
ALTER TABLE gold.dim_customers
ADD CONSTRAINT UQ_gold_dim_customers_' + REPLACE(@KeyCol, ' ', '_') + '
UNIQUE (' + QUOTENAME(@KeyCol) + ');';

    BEGIN TRY
        EXEC sp_executesql @SQL;
    END TRY
    BEGIN CATCH
        PRINT 'WARNING: Unique constraint not added. Review duplicate business keys if needed.';
        PRINT ERROR_MESSAGE();
    END CATCH;

    /*==========================================================================
      9. Validation Checks
    ==========================================================================*/
    PRINT 'Validation Results';

    DECLARE @ValSQL NVARCHAR(MAX) = N'
    SELECT COUNT(*) AS SilverCustomerRows
    FROM silver.customer;

    SELECT COUNT(*) AS GoldDimCustomerRows
    FROM gold.dim_customers;

    SELECT TOP (20) *
    FROM gold.dim_customers
    ORDER BY CustomerKey;';

    EXEC sp_executesql @ValSQL;

    PRINT 'SUCCESS: gold.dim_customers created successfully.';

END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
GO
