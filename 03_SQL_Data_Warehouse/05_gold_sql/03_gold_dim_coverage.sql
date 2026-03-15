USE PalthanioHomeInsuranceDW;
SET NOCOUNT ON;

/*==============================================================================
  GOLD DIMENSION: gold.dim_coverage
  Grain: one row per CoverageType
==============================================================================*/

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('CREATE SCHEMA gold;');

IF OBJECT_ID('gold.dim_coverage','U') IS NOT NULL
    DROP TABLE gold.dim_coverage;

CREATE TABLE gold.dim_coverage
(
    CoverageKey   int IDENTITY(1,1) NOT NULL,
    CoverageType  varchar(100) NOT NULL,
    GoldLoadDts   datetime2(0) NOT NULL
        CONSTRAINT DF_gold_dim_coverage_GoldLoadDts DEFAULT GETUTCDATE(),
    CONSTRAINT PK_gold_dim_coverage PRIMARY KEY (CoverageKey),
    CONSTRAINT UQ_gold_dim_coverage_CoverageType UNIQUE (CoverageType)
);

/* Unknown row */
SET IDENTITY_INSERT gold.dim_coverage ON;

INSERT INTO gold.dim_coverage
(
    CoverageKey,
    CoverageType,
    GoldLoadDts
)
VALUES
(
    -1,
    'UNKNOWN',
    GETUTCDATE()
);

SET IDENTITY_INSERT gold.dim_coverage OFF;

/* Load distinct coverage types from Silver */
INSERT INTO gold.dim_coverage
(
    CoverageType
)
SELECT DISTINCT
    CASE
        WHEN CoverageType IS NULL OR LTRIM(RTRIM(CoverageType)) = '' THEN 'UNKNOWN'
        ELSE LTRIM(RTRIM(CoverageType))
    END AS CoverageType
FROM silver.coverage
WHERE NOT EXISTS
(
    SELECT 1
    FROM gold.dim_coverage d
    WHERE d.CoverageType =
        CASE
            WHEN silver.coverage.CoverageType IS NULL OR LTRIM(RTRIM(silver.coverage.CoverageType)) = '' THEN 'UNKNOWN'
            ELSE LTRIM(RTRIM(silver.coverage.CoverageType))
        END
);

/* Validation */
SELECT *
FROM gold.dim_coverage
ORDER BY CoverageKey;
