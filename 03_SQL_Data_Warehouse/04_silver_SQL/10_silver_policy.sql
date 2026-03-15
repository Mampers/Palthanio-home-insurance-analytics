/*==============================================================================
  DATABASE:      PalthanioHomeInsuranceDW
  LAYER:         SILVER
  OBJECTS:       silver.policy, silver.policy_reject
  SOURCE:        bronze.policy_raw

  AUTHOR:        Paul Mampilly (Portfolio Project)
  UPDATED:       2026-03-04

  PURPOSE
  -------
  Build silver.policy using a proven, fast pattern:
    1) Clone structure from bronze.policy_raw (0 rows)
    2) Add SilverLoadDts metadata
    3) Deduplicate by PolicyID (keep latest BronzeLoadDts / BronzePolicyRowID)
    4) Reject only hard failures (no data loss)
    5) Load good rows into silver.policy

  IMPORTANT FIX (IDENTITY INSERT ERROR)
  ------------------------------------
  Cloning the table via SELECT INTO copies IDENTITY properties.
  If bronze.policy_raw has an IDENTITY column (e.g., BronzePolicyRowID),
  then silver.policy will also have it.

  When inserting rows, SQL Server will throw:
     Msg 544: Cannot insert explicit value for identity column...

  We solve this by:
     - detecting if silver.policy contains an IDENTITY column
     - enabling IDENTITY_INSERT temporarily during the load

  REJECT POLICY
  -------------
  Reject only:
    - Missing PolicyID
    - ExpiryDate < InceptionDate (only if both columns exist and parse)

==============================================================================*/

USE PalthanioHomeInsuranceDW;
GO
SET NOCOUNT ON;
GO

BEGIN TRY

    /*------------------------------------------------------------
      0) Ensure SILVER schema exists
    ------------------------------------------------------------*/
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
        EXEC('CREATE SCHEMA silver;');

    /*------------------------------------------------------------
      1) Pre-flight: Ensure Bronze source exists and contains rows
    ------------------------------------------------------------*/
    DECLARE @SrcObjId int = OBJECT_ID(N'bronze.policy_raw');
    IF @SrcObjId IS NULL
        THROW 50001, 'Source table bronze.policy_raw not found. Create/load Bronze first.', 1;

    DECLARE @BronzeRowCount int;
    SELECT @BronzeRowCount = COUNT(*) FROM bronze.policy_raw;

    IF @BronzeRowCount = 0
        THROW 50002, 'Source table bronze.policy_raw exists but contains 0 rows. Load Bronze first.', 1;

    PRINT CONCAT('Pre-flight OK. bronze.policy_raw rows = ', @BronzeRowCount);

    /*------------------------------------------------------------
      2) Detect key and metadata columns dynamically
         (pattern-based to tolerate column naming variations)
    ------------------------------------------------------------*/
    IF OBJECT_ID('tempdb..#cols') IS NOT NULL DROP TABLE #cols;

    SELECT
        c.column_id,
        c.name AS RealName,
        LOWER(REPLACE(REPLACE(c.name,' ',''),'_','')) AS NormName
    INTO #cols
    FROM sys.columns c
    WHERE c.object_id = @SrcObjId;

    -- Policy key column (we expect PolicyID)
    DECLARE @KeyCol sysname =
        (SELECT TOP (1) RealName
         FROM #cols
         WHERE NormName IN ('policyid','policykey','policynumber','policyref','policyreference')
         ORDER BY
             CASE NormName
                 WHEN 'policyid' THEN 1
                 WHEN 'policykey' THEN 2
                 WHEN 'policynumber' THEN 3
                 WHEN 'policyref' THEN 4
                 WHEN 'policyreference' THEN 5
                 ELSE 100
             END);

    -- Bronze load timestamp column (required for “latest wins” dedupe)
    DECLARE @LoadCol sysname =
        (SELECT TOP (1) RealName FROM #cols WHERE NormName = 'bronzeloaddts');

    -- Optional row ID to break ties during dedupe (best practice)
    DECLARE @RowIdCol sysname =
        (SELECT TOP (1) RealName
         FROM #cols
         WHERE NormName IN ('bronzepolicyrowid','bronzerowid','rowid'));

    -- Optional source file column (useful for reject traceability)
    DECLARE @FileCol sysname =
        (SELECT TOP (1) RealName
         FROM #cols
         WHERE NormName IN ('sourcefile','sourcefilename','sourcefilepath'));

    -- Optional date columns (only used for Expiry < Inception reject rule)
    DECLARE @InceptionCol sysname =
        (SELECT TOP (1) RealName FROM #cols WHERE NormName IN ('inceptiondate','policyinceptiondate'));

    DECLARE @ExpiryCol sysname =
        (SELECT TOP (1) RealName FROM #cols WHERE NormName IN ('expirydate','expirationdate','policyexpirydate'));

    IF @KeyCol IS NULL OR @LoadCol IS NULL
    BEGIN
        PRINT 'DEBUG: bronze.policy_raw columns detected:';
        SELECT column_id, RealName, NormName FROM #cols ORDER BY column_id;

        THROW 50003, 'Could not detect Policy key and/or BronzeLoadDts on bronze.policy_raw.', 1;
    END

    PRINT 'Using policy key column: ' + QUOTENAME(@KeyCol);
    PRINT 'Using load column: ' + QUOTENAME(@LoadCol);
    IF @RowIdCol IS NOT NULL PRINT 'Using row id column: ' + QUOTENAME(@RowIdCol);
    IF @InceptionCol IS NOT NULL PRINT 'Detected inception date column: ' + QUOTENAME(@InceptionCol);
    IF @ExpiryCol IS NOT NULL PRINT 'Detected expiry date column: ' + QUOTENAME(@ExpiryCol);

    /*------------------------------------------------------------
      3) Drop targets (repeatable dev runs)
    ------------------------------------------------------------*/
    IF OBJECT_ID('silver.policy','U') IS NOT NULL DROP TABLE silver.policy;
    IF OBJECT_ID('silver.policy_reject','U') IS NOT NULL DROP TABLE silver.policy_reject;

    /*------------------------------------------------------------
      4) Create silver.policy by cloning bronze structure (0 rows)
         This preserves column order + types (and identity properties).
    ------------------------------------------------------------*/
    SELECT TOP (0) *
    INTO silver.policy
    FROM bronze.policy_raw;

    /* Add Silver metadata column */
    ALTER TABLE silver.policy
      ADD SilverLoadDts datetime2(0) NOT NULL
          CONSTRAINT DF_silver_policy_SilverLoadDts DEFAULT SYSUTCDATETIME();

    /*------------------------------------------------------------
      5) Create reject table (small + traceable)
    ------------------------------------------------------------*/
    CREATE TABLE silver.policy_reject
    (
        RejectRowID   int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        PolicyKey     varchar(200) NULL,
        RejectReason  varchar(400) NOT NULL,
        BronzeLoadDts datetime2(0) NULL,
        SourceFile    varchar(260) NULL,
        RejectLoadDts datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME()
    );

    /*------------------------------------------------------------
      6) Build insert/select column list dynamically
         We insert all columns except SilverLoadDts (default handles it).
    ------------------------------------------------------------*/
    DECLARE @SilverObjId int = OBJECT_ID(N'silver.policy');
    DECLARE @InsertCols nvarchar(max);
    DECLARE @SelectCols nvarchar(max);

    SELECT
        @InsertCols = STRING_AGG(QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id),
        @SelectCols = STRING_AGG('l.' + QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.columns c
    WHERE c.object_id = @SilverObjId
      AND c.name <> 'SilverLoadDts';

    /*------------------------------------------------------------
      7) Determine ORDER BY for dedupe (latest wins)
         Prefer BronzeLoadDts DESC, then BronzePolicyRowID DESC.
    ------------------------------------------------------------*/
    DECLARE @OrderBy nvarchar(max) =
        CASE
            WHEN @RowIdCol IS NOT NULL
                THEN N' ORDER BY b.' + QUOTENAME(@LoadCol) + N' DESC, b.' + QUOTENAME(@RowIdCol) + N' DESC '
            ELSE
                N' ORDER BY b.' + QUOTENAME(@LoadCol) + N' DESC '
        END;

    /*------------------------------------------------------------
      8) Detect whether silver.policy contains an IDENTITY column
         If yes, we must use IDENTITY_INSERT during load.
    ------------------------------------------------------------*/
    DECLARE @HasIdentity bit = 0;

    IF EXISTS
    (
        SELECT 1
        FROM sys.columns
        WHERE object_id = @SilverObjId
          AND is_identity = 1
    )
    SET @HasIdentity = 1;

    IF @HasIdentity = 1
        PRINT 'IDENTITY detected on silver.policy. IDENTITY_INSERT will be enabled during load.';
    ELSE
        PRINT 'No IDENTITY detected on silver.policy. IDENTITY_INSERT not required.';

    /*------------------------------------------------------------
      9) Optional reject rule for Expiry < Inception (date parse)
         Only generated if both date columns are present.
    ------------------------------------------------------------*/
    DECLARE @ExpiryRejectSql nvarchar(max) = N'';
    IF @InceptionCol IS NOT NULL AND @ExpiryCol IS NOT NULL
    BEGIN
        SET @ExpiryRejectSql = N'
-- Reject Expiry < Inception (only when both parse)
INSERT INTO silver.policy_reject (PolicyKey, RejectReason, BronzeLoadDts, SourceFile)
SELECT
    CAST(l.' + QUOTENAME(@KeyCol) + N' AS varchar(200)) AS PolicyKey,
    ''ExpiryDate < InceptionDate'',
    l.' + QUOTENAME(@LoadCol) + N' AS BronzeLoadDts,
    ' + CASE WHEN @FileCol IS NULL THEN N'NULL' ELSE N'l.' + QUOTENAME(@FileCol) END + N' AS SourceFile
FROM #Latest l
CROSS APPLY (
    SELECT
      COALESCE(
        TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(CAST(l.' + QUOTENAME(@InceptionCol) + N' AS varchar(50)))), ''''), 23),
        TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(CAST(l.' + QUOTENAME(@InceptionCol) + N' AS varchar(50)))), ''''), 103),
        TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(CAST(l.' + QUOTENAME(@InceptionCol) + N' AS varchar(50)))), ''''), 120),
        TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(CAST(l.' + QUOTENAME(@InceptionCol) + N' AS varchar(50)))), ''''), 126)
      ) AS IncepDt,
      COALESCE(
        TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(CAST(l.' + QUOTENAME(@ExpiryCol) + N' AS varchar(50)))), ''''), 23),
        TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(CAST(l.' + QUOTENAME(@ExpiryCol) + N' AS varchar(50)))), ''''), 103),
        TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(CAST(l.' + QUOTENAME(@ExpiryCol) + N' AS varchar(50)))), ''''), 120),
        TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(CAST(l.' + QUOTENAME(@ExpiryCol) + N' AS varchar(50)))), ''''), 126)
      ) AS ExpDt
) d
WHERE d.IncepDt IS NOT NULL
  AND d.ExpDt IS NOT NULL
  AND d.ExpDt < d.IncepDt;
';
    END

    /*------------------------------------------------------------
      10) Main dedupe + reject + insert load (dynamic SQL)
          - Creates #Latest with rn=1 per Policy key
          - Inserts rejects (missing key + optional expiry<inception)
          - Inserts good rows into silver.policy
          - Applies IDENTITY_INSERT fix if required
    ------------------------------------------------------------*/
    DECLARE @IdentityOn  nvarchar(200) = CASE WHEN @HasIdentity = 1 THEN N'SET IDENTITY_INSERT silver.policy ON;'  ELSE N'' END;
    DECLARE @IdentityOff nvarchar(200) = CASE WHEN @HasIdentity = 1 THEN N'SET IDENTITY_INSERT silver.policy OFF;' ELSE N'' END;

    DECLARE @sql nvarchar(max) = N'
IF OBJECT_ID(''tempdb..#Latest'') IS NOT NULL DROP TABLE #Latest;

;WITH Deduped AS
(
    SELECT
        b.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY b.' + QUOTENAME(@KeyCol) + N'
            ' + @OrderBy + N'
        ) AS rn
    FROM bronze.policy_raw b
)
SELECT *
INTO #Latest
FROM Deduped
WHERE rn = 1;

-- Reject: missing policy key
INSERT INTO silver.policy_reject (PolicyKey, RejectReason, BronzeLoadDts, SourceFile)
SELECT
    CAST(l.' + QUOTENAME(@KeyCol) + N' AS varchar(200)) AS PolicyKey,
    ''Missing Policy key'',
    l.' + QUOTENAME(@LoadCol) + N' AS BronzeLoadDts,
    ' + CASE WHEN @FileCol IS NULL THEN N'NULL' ELSE N'l.' + QUOTENAME(@FileCol) END + N' AS SourceFile
FROM #Latest l
WHERE l.' + QUOTENAME(@KeyCol) + N' IS NULL
   OR LTRIM(RTRIM(CAST(l.' + QUOTENAME(@KeyCol) + N' AS varchar(200)))) = '''';

' + @ExpiryRejectSql + N'

-- Insert: good rows
' + @IdentityOn + N'

INSERT INTO silver.policy (' + @InsertCols + N')
SELECT ' + @SelectCols + N'
FROM #Latest l
WHERE l.' + QUOTENAME(@KeyCol) + N' IS NOT NULL
  AND LTRIM(RTRIM(CAST(l.' + QUOTENAME(@KeyCol) + N' AS varchar(200)))) <> ''''
  AND NOT EXISTS
  (
      SELECT 1
      FROM silver.policy_reject r
      WHERE r.PolicyKey = CAST(l.' + QUOTENAME(@KeyCol) + N' AS varchar(200))
        AND r.BronzeLoadDts = l.' + QUOTENAME(@LoadCol) + N'
  );

' + @IdentityOff + N'
';

    EXEC sp_executesql @sql;

    /*------------------------------------------------------------
      11) Helpful indexes (for joins in Gold layer)
    ------------------------------------------------------------*/
    DECLARE @idx nvarchar(max) =
        N'CREATE INDEX IX_silver_policy_key ON silver.policy(' + QUOTENAME(@KeyCol) + N');';
    EXEC sp_executesql @idx;

    /*------------------------------------------------------------
      12) Post-load validations
    ------------------------------------------------------------*/
    PRINT 'VALIDATION: row counts';
    SELECT COUNT(*) AS BronzeCount FROM bronze.policy_raw;
    SELECT COUNT(*) AS SilverCount FROM silver.policy;
    SELECT COUNT(*) AS RejectCount FROM silver.policy_reject;

    PRINT 'VALIDATION: reject reasons';
    SELECT RejectReason, COUNT(*) AS RejectCount
    FROM silver.policy_reject
    GROUP BY RejectReason
    ORDER BY COUNT(*) DESC;

    PRINT 'DONE: silver.policy load completed successfully.';

END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
GO


SELECT COUNT(*) FROM [silver].[policy]

SELECT TOP 50 *
FROM [silver].[policy]

SELECT COUNT (*)
FROM [silver].[policy_reject]
