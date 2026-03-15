-- Create stg.policy_risk

DROP TABLE IF EXISTS stg.policy_risk;
GO

CREATE TABLE stg.policy_risk (
    PolicyID                  varchar(30)  NULL,
    RiskType                  varchar(50)  NULL,
    RiskScore                 varchar(20)  NULL,
    HasAlarm                  varchar(10)  NULL,   -- Y/N
    PriorClaimsCount          varchar(10)  NULL,
    RiskBand                  varchar(50)  NULL,
    HasAlarmFlag              varchar(10)  NULL,   -- 0/1
    ClaimsHistoryBand         varchar(50)  NULL,
    AlarmRiskAdjustment       varchar(20)  NULL,   -- can be negative
    ClaimsRiskAdjustment      varchar(20)  NULL,
    AdjustedRiskScore         varchar(20)  NULL,
    AdjustedRiskBand          varchar(50)  NULL,
    HighRiskFlag              varchar(10)  NULL,   -- 0/1
    RiskDataCompletenessScore varchar(10)  NULL    -- 0–100
);
GO

-- Bulk Insert stg.policy_risk

TRUNCATE TABLE stg.policy_risk;

BULK INSERT stg.policy_risk
FROM 'C:\Users\Paul Mampilly\Documents\ChatGPT Datasets\Home Insurance\CSV Datasets\Calibrated Raw Data\Enchanced\policy_risk_enterprise_ready.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0D0A',
    CODEPAGE        = '65001',
    TABLOCK
);


-- Validation Checks


SELECT COUNT(*) AS RC
FROM stg.policy_risk;

SELECT TOP (20) *
FROM stg.policy_risk;


SELECT PolicyID, RiskType, COUNT(*) AS Cnt
FROM stg.policy_risk
GROUP BY PolicyID, RiskType
HAVING COUNT(*) > 1;


SELECT *
FROM stg.policy_risk
WHERE PolicyID = 'POL0004197';


SELECT TOP (50)
    HasAlarmFlag,
    HighRiskFlag
FROM stg.policy_risk
WHERE HasAlarmFlag NOT IN ('0','1')
   OR HighRiskFlag NOT IN ('0','1');


   SELECT TOP (50) HasAlarm
FROM stg.policy_risk
WHERE HasAlarm IS NOT NULL
  AND LTRIM(RTRIM(HasAlarm)) <> ''
  AND UPPER(LTRIM(RTRIM(HasAlarm))) NOT IN ('Y','N');


  SELECT TOP (50)
    PolicyID, RiskType,
    RiskScore, AlarmRiskAdjustment, ClaimsRiskAdjustment, AdjustedRiskScore
FROM stg.policy_risk
WHERE TRY_CONVERT(decimal(10,2), RiskScore) IS NOT NULL
  AND TRY_CONVERT(decimal(10,2), AlarmRiskAdjustment) IS NOT NULL
  AND TRY_CONVERT(decimal(10,2), ClaimsRiskAdjustment) IS NOT NULL
  AND TRY_CONVERT(decimal(10,2), AdjustedRiskScore) IS NOT NULL
  AND ABS(
        (TRY_CONVERT(decimal(10,2), RiskScore)
       + TRY_CONVERT(decimal(10,2), AlarmRiskAdjustment)
       + TRY_CONVERT(decimal(10,2), ClaimsRiskAdjustment))
       - TRY_CONVERT(decimal(10,2), AdjustedRiskScore)
  ) > 0.50;


