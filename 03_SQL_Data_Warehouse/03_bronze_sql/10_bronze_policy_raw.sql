/*==============================================================
  PalthanioHomeInsuranceDW
  BRONZE LAYER: bronze.policy_raw
  Source: stg.policy
==============================================================*/

USE PalthanioHomeInsuranceDW;
GO

SET NOCOUNT ON;
GO

/* 1) Ensure bronze schema exists */
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
    EXEC('CREATE SCHEMA bronze');
GO


/* 2) Drop table if exists (repeatable script) */
IF OBJECT_ID('bronze.policy_raw','U') IS NOT NULL
    DROP TABLE bronze.policy_raw;
GO


/* 3) Create bronze table */

CREATE TABLE bronze.policy_raw
(
    BronzePolicyRowID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,

    PolicyID       varchar(30) NULL,
    CustomerID     varchar(30) NULL,
    AddressID      varchar(30) NULL,
    BrokerID       varchar(30) NULL,
    ProductType    varchar(50) NULL,
    InceptionDate  varchar(20) NULL,
    ExpiryDate     varchar(20) NULL,
    PolicyStatus   varchar(30) NULL,
    PaymentPlan    varchar(30) NULL,
    CreatedDate    varchar(20) NULL,

    /* Metadata columns */
    BronzeLoadDts  datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
    SourceSystem   varchar(50)  NOT NULL DEFAULT 'PolicyCSV'
);
GO


/* 4) Load data from staging */

INSERT INTO bronze.policy_raw
(
    PolicyID,
    CustomerID,
    AddressID,
    BrokerID,
    ProductType,
    InceptionDate,
    ExpiryDate,
    PolicyStatus,
    PaymentPlan,
    CreatedDate
)
SELECT
    PolicyID,
    CustomerID,
    AddressID,
    BrokerID,
    ProductType,
    InceptionDate,
    ExpiryDate,
    PolicyStatus,
    PaymentPlan,
    CreatedDate
FROM stg.policy;
GO


/* 5) Validation checks */

-- Row count check
SELECT 
    COUNT(*) AS BronzeRowCount
FROM bronze.policy_raw;


-- Preview data
SELECT TOP (20) *
FROM bronze.policy_raw;


-- Duplicate policy check
SELECT
    PolicyID,
    COUNT(*) AS DuplicateCount
FROM bronze.policy_raw
GROUP BY PolicyID
HAVING COUNT(*) > 1;
GO


