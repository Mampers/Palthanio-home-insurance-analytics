/*==============================================================================
    FULL ONE-SCRIPT PACKAGE (FIXED)
    stg.policy_risk  -->  bronze.policy_risk

    Includes:
      1) bronze schema + table creation
      2) load from stg (truncate + insert with cleaning/typing)
         - FIX: RiskType blanks default to 'Unknown'
      3) validation checks (rowcounts, duplicates, domains, ranges, math check)
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
    DROP TABLE IF EXISTS bronze.policy_risk;

    CREATE TABLE bronze.policy_risk (
        PolicyID                   varchar(30)   NULL,
        RiskType                   varchar(50)   NOT NULL, -- enforce after defaulting to 'Unknown'

        RiskScore                  decimal(10,2) NULL,
        PriorClaimsCount           int           NULL,

        HasAlarm                   char(1)       NULL,     -- Y/N/NULL

        RiskBand                   varchar(50)   NULL,
        HasAlarmFlag               bit           NULL,
        ClaimsHistoryBand          varchar(50)   NULL,

        AlarmRiskAdjustment        decimal(10,2) NULL,
        ClaimsRiskAdjustment       decimal(10,2) NULL,
        AdjustedRiskScore          decimal(10,2) NULL,

        AdjustedRiskBand           varchar(50)   NULL,
        HighRiskFlag               bit           NULL,

        RiskDataCompletenessScore  int           NULL,

        BronzeLoadDts              datetime2(0)  NOT NULL
            CONSTRAINT DF_bronze_policy_risk_BronzeLoadDts DEFAULT (SYSUTCDATETIME()),
        SourceSystem               varchar(50)   NOT NULL
            CONSTRAINT DF_bronze_policy_risk_SourceSystem DEFAULT ('CalibratedCSV')
    );

    /*--------------------------------------------
      2) Load: stg -> bronze
         FIX: RiskType defaults to 'Unknown' when blank
    --------------------------------------------*/
    TRUNCATE TABLE bronze.policy_risk;

    INSERT INTO bronze.policy_risk (
        PolicyID,
        RiskType,
        RiskScore,
        HasAlarm,
        PriorClaimsCount,
        RiskBand,
        HasAlarmFlag,
        ClaimsHistoryBand,
        AlarmRiskAdjustment,
        ClaimsRiskAdjustment,
        AdjustedRiskScore,
        AdjustedRiskBand,
        HighRiskFlag,
        RiskDataCompletenessScore,
        SourceSystem
    )
    SELECT
        NULLIF(LTRIM(RTRIM(PolicyID)), '') AS PolicyID,

        -- ✅ FIX HERE
        COALESCE(NULLIF(LTRIM(RTRIM(RiskType)), ''), 'Unknown') AS RiskType,

        TRY_CONVERT(decimal(10,2), NULLIF(LTRIM(RTRIM(RiskScore)), '')) AS RiskScore,

        CASE
            WHEN NULLIF(LTRIM(RTRIM(HasAlarm)), '') IS NULL THEN NULL
            WHEN UPPER(LTRIM(RTRIM(HasAlarm))) IN ('Y','YES','1','TRUE') THEN 'Y'
            WHEN UPPER(LTRIM(RTRIM(HasAlarm))) IN ('N','NO','0','FALSE') THEN 'N'
            ELSE NULL
        END AS HasAlarm,

        TRY_CONVERT(int, NULLIF(LTRIM(RTRIM(PriorClaimsCount)), '')) AS PriorClaimsCount,

        NULLIF(LTRIM(RTRIM(RiskBand)), '') AS RiskBand,

        CASE
            WHEN NULLIF(LTRIM(RTRIM(HasAlarmFlag)), '') IS NULL THEN NULL
            WHEN UPPER(LTRIM(RTRIM(HasAlarmFlag))) IN ('1','Y','YES','TRUE') THEN CAST(1 AS bit)
            WHEN UPPER(LTRIM(RTRIM(HasAlarmFlag))) IN ('0','N','NO','FALSE') THEN CAST(0 AS bit)
            ELSE NULL
        END AS HasAlarmFlag,

        NULLIF(LTRIM(RTRIM(ClaimsHistoryBand)), '') AS ClaimsHistoryBand,

        TRY_CONVERT(decimal(10,2), NULLIF(LTRIM(RTRIM(AlarmRiskAdjustment)), ''))  AS AlarmRiskAdjustment,
        TRY_CONVERT(decimal(10,2), NULLIF(LTRIM(RTRIM(ClaimsRiskAdjustment)), '')) AS ClaimsRiskAdjustment,
        TRY_CONVERT(decimal(10,2), NULLIF(LTRIM(RTRIM(AdjustedRiskScore)), ''))    AS AdjustedRiskScore,

        NULLIF(LTRIM(RTRIM(AdjustedRiskBand)), '') AS AdjustedRiskBand,

        CASE
            WHEN NULLIF(LTRIM(RTRIM(HighRiskFlag)), '') IS NULL THEN NULL
            WHEN UPPER(LTRIM(RTRIM(HighRiskFlag))) IN ('1','Y','YES','TRUE') THEN CAST(1 AS bit)
            WHEN UPPER(LTRIM(RTRIM(HighRiskFlag))) IN ('0','N','NO','FALSE') THEN CAST(0 AS bit)
            ELSE NULL
        END AS HighRiskFlag,

        TRY_CONVERT(int, NULLIF(LTRIM(RTRIM(RiskDataCompletenessScore)), '')) AS RiskDataCompletenessScore,

        'CalibratedCSV' AS SourceSystem
    FROM stg.policy_risk;

    /*--------------------------------------------
      3) VALIDATION PACK
         - For "pass/fail", bad-row queries should return 0 rows.
    --------------------------------------------*/

    PRINT 'VALIDATION: Row counts';
    SELECT COUNT(*) AS StgRowCount FROM stg.policy_risk;
    SELECT COUNT(*) AS BronzeRowCount FROM bronze.policy_risk;

    PRINT 'VALIDATION: RiskType defaults applied (Unknown count)';
    SELECT
        SUM(CASE WHEN RiskType = 'Unknown' THEN 1 ELSE 0 END) AS UnknownRiskTypeRows,
        COUNT(*) AS TotalRows
    FROM bronze.policy_risk;

    PRINT 'VALIDATION: Missing keys (PolicyID or RiskType)';
    SELECT TOP (50) *
    FROM bronze.policy_risk
    WHERE PolicyID IS NULL OR RiskType IS NULL OR LTRIM(RTRIM(RiskType)) = '';

    PRINT 'VALIDATION: Duplicate grain (PolicyID + RiskType)';
    SELECT PolicyID, RiskType, COUNT(*) AS Cnt
    FROM bronze.policy_risk
    GROUP BY PolicyID, RiskType
    HAVING COUNT(*) > 1;

    PRINT 'VALIDATION: HasAlarm domain (Y/N/NULL)';
    SELECT HasAlarm, COUNT(*) AS Cnt
    FROM bronze.policy_risk
    GROUP BY HasAlarm
    ORDER BY COUNT(*) DESC;

    PRINT 'VALIDATION: Bit flags distribution (0/1/NULL)';
    SELECT HasAlarmFlag, HighRiskFlag, COUNT(*) AS Cnt
    FROM bronze.policy_risk
    GROUP BY HasAlarmFlag, HighRiskFlag
    ORDER BY COUNT(*) DESC;

    PRINT 'VALIDATION: Numeric conversion failures from STG (diagnostic)';
    SELECT TOP (50)
        PolicyID, RiskType,
        RiskScore, PriorClaimsCount,
        AlarmRiskAdjustment, ClaimsRiskAdjustment, AdjustedRiskScore,
        RiskDataCompletenessScore
    FROM stg.policy_risk
    WHERE (NULLIF(LTRIM(RTRIM(RiskScore)),'') IS NOT NULL AND TRY_CONVERT(decimal(10,2), LTRIM(RTRIM(RiskScore))) IS NULL)
       OR (NULLIF(LTRIM(RTRIM(PriorClaimsCount)),'') IS NOT NULL AND TRY_CONVERT(int, LTRIM(RTRIM(PriorClaimsCount))) IS NULL)
       OR (NULLIF(LTRIM(RTRIM(AlarmRiskAdjustment)),'') IS NOT NULL AND TRY_CONVERT(decimal(10,2), LTRIM(RTRIM(AlarmRiskAdjustment))) IS NULL)
       OR (NULLIF(LTRIM(RTRIM(ClaimsRiskAdjustment)),'') IS NOT NULL AND TRY_CONVERT(decimal(10,2), LTRIM(RTRIM(ClaimsRiskAdjustment))) IS NULL)
       OR (NULLIF(LTRIM(RTRIM(AdjustedRiskScore)),'') IS NOT NULL AND TRY_CONVERT(decimal(10,2), LTRIM(RTRIM(AdjustedRiskScore))) IS NULL)
       OR (NULLIF(LTRIM(RTRIM(RiskDataCompletenessScore)),'') IS NOT NULL AND TRY_CONVERT(int, LTRIM(RTRIM(RiskDataCompletenessScore))) IS NULL);

    PRINT 'VALIDATION: Completeness score range (0-100)';
    SELECT TOP (50) *
    FROM bronze.policy_risk
    WHERE RiskDataCompletenessScore IS NOT NULL
      AND (RiskDataCompletenessScore < 0 OR RiskDataCompletenessScore > 100);

    PRINT 'VALIDATION: Adjusted score math check (tolerance > 0.50)';
    SELECT TOP (50)
        PolicyID, RiskType,
        RiskScore, AlarmRiskAdjustment, ClaimsRiskAdjustment, AdjustedRiskScore,
        (RiskScore + AlarmRiskAdjustment + ClaimsRiskAdjustment) AS CalcAdjusted,
        ABS((RiskScore + AlarmRiskAdjustment + ClaimsRiskAdjustment) - AdjustedRiskScore) AS Diff
    FROM bronze.policy_risk
    WHERE RiskScore IS NOT NULL
      AND AlarmRiskAdjustment IS NOT NULL
      AND ClaimsRiskAdjustment IS NOT NULL
      AND AdjustedRiskScore IS NOT NULL
      AND ABS((RiskScore + AlarmRiskAdjustment + ClaimsRiskAdjustment) - AdjustedRiskScore) > 0.50;

    PRINT 'DONE: stg.policy_risk -> bronze.policy_risk load + validations completed.';

END TRY
BEGIN CATCH
    DECLARE @ErrMsg nvarchar(4000) = ERROR_MESSAGE();
    DECLARE @ErrSev int = ERROR_SEVERITY();
    DECLARE @ErrState int = ERROR_STATE();

    PRINT 'ERROR in stg -> bronze script:';
    PRINT @ErrMsg;

    RAISERROR(@ErrMsg, @ErrSev, @ErrState);
END CATCH;



SELECT TOP 60 *
FROM [bronze].[policy_risk]
