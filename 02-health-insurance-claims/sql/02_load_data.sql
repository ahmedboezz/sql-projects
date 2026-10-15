/* =====================================================================
   Script 02: load CSV files into staging, then typed core tables
   Set @DataPath to the folder that contains the CSV files (ending with \).
   run_project.py replaces the default path automatically.
   ===================================================================== */
USE InsuranceClaims;
GO
DECLARE @DataPath NVARCHAR(400) = N'F:\CV\DataAnalyst\SQL_Projects\01_Health_Insurance_Claims\data\';
DECLARE @t TABLE (tbl SYSNAME, f NVARCHAR(100));
INSERT @t VALUES ('stg.Policies', 'policies.csv'), ('stg.Members', 'members.csv'), ('stg.Providers', 'providers.csv'),
                 ('stg.Diagnoses', 'diagnoses.csv'), ('stg.Claims', 'claims.csv');
DECLARE @tbl SYSNAME, @f NVARCHAR(100), @sql NVARCHAR(MAX);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT tbl, f FROM @t;
OPEN c; FETCH NEXT FROM c INTO @tbl, @f;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'TRUNCATE TABLE ' + @tbl + N'; BULK INSERT ' + @tbl + N' FROM ''' + @DataPath + @f +
               N''' WITH (FORMAT = ''CSV'', FIRSTROW = 2, CODEPAGE = ''65001'', TABLOCK);';
    EXEC sp_executesql @sql;
    FETCH NEXT FROM c INTO @tbl, @f;
END
CLOSE c; DEALLOCATE c;
GO

/* ---------- staging -> core (TRY_CONVERT never fails; bad rows are caught by script 03) ---------- */
INSERT core.Policies
SELECT PolicyID, EmployerName, Sector, PlanClass, TRY_CONVERT(DATE, StartDate), TRY_CONVERT(DATE, EndDate),
       TRY_CONVERT(DECIMAL(12,2), AnnualPremiumPerMember)
FROM stg.Policies;

INSERT core.Members
SELECT MemberID, PolicyID, Gender, TRY_CONVERT(DATE, BirthDate), Nationality, City, TRY_CONVERT(DATE, EnrollmentDate), RelationToEmployee
FROM stg.Members;

INSERT core.Providers SELECT ProviderID, ProviderName, ProviderType, City, NetworkTier FROM stg.Providers;
INSERT core.Diagnoses SELECT ICD10Code, Description, Chapter, ChapterName FROM stg.Diagnoses;

INSERT core.Claims
SELECT ClaimID, MemberID, ProviderID, TRY_CONVERT(DATE, ServiceDate), TRY_CONVERT(DATE, SubmissionDate), ClaimType, ICD10Code,
       TRY_CONVERT(DECIMAL(12,2), BilledAmount), TRY_CONVERT(DECIMAL(12,2), ApprovedAmount), ClaimStatus,
       NULLIF(RejectionReason, ''), TRY_CONVERT(DATE, NULLIF(PaidDate, ''))
FROM stg.Claims;
GO
SELECT 'Policies' AS TableName, COUNT(*) AS Rows FROM core.Policies UNION ALL
SELECT 'Members', COUNT(*) FROM core.Members UNION ALL
SELECT 'Providers', COUNT(*) FROM core.Providers UNION ALL
SELECT 'Diagnoses', COUNT(*) FROM core.Diagnoses UNION ALL
SELECT 'Claims', COUNT(*) FROM core.Claims;
GO
