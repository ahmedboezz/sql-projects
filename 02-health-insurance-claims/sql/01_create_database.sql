/* =====================================================================
   Script 01: database, staging and core tables
   Health-insurance claims analytics (simulated data, 2025)
   Engine: SQL Server 2019+ (tested on SQL Server 2025 LocalDB)
   ===================================================================== */
IF DB_ID('InsuranceClaims') IS NOT NULL
BEGIN
    ALTER DATABASE InsuranceClaims SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE InsuranceClaims;
END
GO
CREATE DATABASE InsuranceClaims;
GO
USE InsuranceClaims;
GO
CREATE SCHEMA stg;   -- raw text exactly as received
GO
CREATE SCHEMA core;  -- typed, constrained tables
GO

/* ---------- staging: every column is text, so a bad value never stops the load ---------- */
CREATE TABLE stg.Policies  (PolicyID NVARCHAR(50), EmployerName NVARCHAR(200), Sector NVARCHAR(100), PlanClass NVARCHAR(20),
                            StartDate NVARCHAR(30), EndDate NVARCHAR(30), AnnualPremiumPerMember NVARCHAR(30));
CREATE TABLE stg.Members   (MemberID NVARCHAR(50), PolicyID NVARCHAR(50), Gender NVARCHAR(10), BirthDate NVARCHAR(30),
                            Nationality NVARCHAR(30), City NVARCHAR(50), EnrollmentDate NVARCHAR(30), RelationToEmployee NVARCHAR(30));
CREATE TABLE stg.Providers (ProviderID NVARCHAR(50), ProviderName NVARCHAR(200), ProviderType NVARCHAR(50), City NVARCHAR(50), NetworkTier NVARCHAR(20));
CREATE TABLE stg.Diagnoses (ICD10Code NVARCHAR(10), Description NVARCHAR(200), Chapter NVARCHAR(5), ChapterName NVARCHAR(100));
CREATE TABLE stg.Claims    (ClaimID NVARCHAR(50), MemberID NVARCHAR(50), ProviderID NVARCHAR(50), ServiceDate NVARCHAR(30),
                            SubmissionDate NVARCHAR(30), ClaimType NVARCHAR(30), ICD10Code NVARCHAR(10), BilledAmount NVARCHAR(30),
                            ApprovedAmount NVARCHAR(30), ClaimStatus NVARCHAR(30), RejectionReason NVARCHAR(100), PaidDate NVARCHAR(30));
GO

/* ---------- core model ---------- */
CREATE TABLE core.Policies (
    PolicyID                VARCHAR(10)   NOT NULL PRIMARY KEY,
    EmployerName            NVARCHAR(200) NOT NULL,
    Sector                  NVARCHAR(100) NOT NULL,
    PlanClass               VARCHAR(5)    NOT NULL CHECK (PlanClass IN ('VIP', 'A', 'B', 'C')),
    StartDate               DATE          NOT NULL,
    EndDate                 DATE          NOT NULL,
    AnnualPremiumPerMember  DECIMAL(12,2) NOT NULL CHECK (AnnualPremiumPerMember > 0)
);
CREATE TABLE core.Members (
    MemberID            VARCHAR(10)  NOT NULL PRIMARY KEY,
    PolicyID            VARCHAR(10)  NOT NULL REFERENCES core.Policies (PolicyID),
    Gender              CHAR(1)      NOT NULL CHECK (Gender IN ('M', 'F')),
    BirthDate           DATE         NOT NULL,
    Nationality         VARCHAR(20)  NOT NULL,
    City                NVARCHAR(50) NOT NULL,
    EnrollmentDate      DATE         NOT NULL,
    RelationToEmployee  VARCHAR(20)  NOT NULL
);
CREATE TABLE core.Providers (
    ProviderID    VARCHAR(10)   NOT NULL PRIMARY KEY,
    ProviderName  NVARCHAR(200) NOT NULL,
    ProviderType  VARCHAR(20)   NOT NULL,
    City          NVARCHAR(50)  NOT NULL,
    NetworkTier   VARCHAR(10)   NOT NULL
);
CREATE TABLE core.Diagnoses (
    ICD10Code    VARCHAR(10)   NOT NULL PRIMARY KEY,
    Description  NVARCHAR(200) NOT NULL,
    Chapter      CHAR(1)       NOT NULL,
    ChapterName  NVARCHAR(100) NOT NULL
);
CREATE TABLE core.Claims (
    ClaimID          VARCHAR(12)   NOT NULL PRIMARY KEY,
    MemberID         VARCHAR(10)   NOT NULL REFERENCES core.Members (MemberID),
    ProviderID       VARCHAR(10)   NOT NULL REFERENCES core.Providers (ProviderID),
    ServiceDate      DATE          NOT NULL,
    SubmissionDate   DATE          NOT NULL,
    ClaimType        VARCHAR(20)   NOT NULL,
    ICD10Code        VARCHAR(10)   NOT NULL REFERENCES core.Diagnoses (ICD10Code),
    BilledAmount     DECIMAL(12,2) NOT NULL CHECK (BilledAmount >= 0),
    ApprovedAmount   DECIMAL(12,2) NOT NULL CHECK (ApprovedAmount >= 0),
    ClaimStatus      VARCHAR(20)   NOT NULL CHECK (ClaimStatus IN ('Approved', 'Partially Approved', 'Rejected')),
    RejectionReason  NVARCHAR(100) NULL,
    PaidDate         DATE          NULL,
    CONSTRAINT CK_Claims_Approved CHECK (ApprovedAmount <= BilledAmount),
    CONSTRAINT CK_Claims_Dates    CHECK (SubmissionDate >= ServiceDate)
);
GO
-- indexes that support the analysis queries
CREATE INDEX IX_Claims_ServiceDate ON core.Claims (ServiceDate) INCLUDE (BilledAmount, ApprovedAmount, ClaimStatus);
CREATE INDEX IX_Claims_Member      ON core.Claims (MemberID, ServiceDate);
CREATE INDEX IX_Claims_Provider    ON core.Claims (ProviderID, ClaimType);
GO
