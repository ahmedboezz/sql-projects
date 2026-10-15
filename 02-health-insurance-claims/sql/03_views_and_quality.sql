/* =====================================================================
   Script 03: duplicate handling, analysis views, data-quality report
   ===================================================================== */
USE InsuranceClaims;
GO
/* Clean claims view: a re-submitted duplicate (same member, provider, service date, amount and type)
   keeps only the earliest submission. ROW_NUMBER is the standard de-duplication pattern. */
CREATE OR ALTER VIEW core.vw_ClaimsClean AS
WITH ranked AS (
    SELECT c.*,
           ROW_NUMBER() OVER (PARTITION BY MemberID, ProviderID, ServiceDate, ClaimType, BilledAmount
                              ORDER BY SubmissionDate, ClaimID) AS rn
    FROM core.Claims AS c
)
SELECT ClaimID, MemberID, ProviderID, ServiceDate, SubmissionDate, ClaimType, ICD10Code, BilledAmount, ApprovedAmount,
       ClaimStatus, RejectionReason, PaidDate,
       DATEDIFF(DAY, ServiceDate, SubmissionDate) AS SubmissionLagDays,
       DATEDIFF(DAY, SubmissionDate, PaidDate)    AS TurnaroundDays
FROM ranked
WHERE rn = 1;
GO
/* One wide view for BI tools: claim + member + policy + provider + diagnosis */
CREATE OR ALTER VIEW core.vw_ClaimFacts AS
SELECT c.*, m.Gender, m.Nationality, m.RelationToEmployee, m.City AS MemberCity,
       DATEDIFF(YEAR, m.BirthDate, c.ServiceDate)
         - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, m.BirthDate, c.ServiceDate), m.BirthDate) > c.ServiceDate THEN 1 ELSE 0 END AS AgeAtService,
       p.PolicyID, p.Sector, p.PlanClass, pr.ProviderType, pr.City AS ProviderCity, pr.NetworkTier,
       d.Chapter, d.ChapterName, d.Description AS Diagnosis
FROM core.vw_ClaimsClean AS c
JOIN core.Members   AS m  ON m.MemberID = c.MemberID
JOIN core.Policies  AS p  ON p.PolicyID = m.PolicyID
JOIN core.Providers AS pr ON pr.ProviderID = c.ProviderID
JOIN core.Diagnoses AS d  ON d.ICD10Code = c.ICD10Code;
GO
/* Member-months per plan class and month (needed for utilisation per 1,000 members).
   A recursive CTE builds the month spine. */
CREATE OR ALTER VIEW core.vw_MemberMonths AS
WITH months AS (
    SELECT CAST('2025-01-01' AS DATE) AS MonthStart
    UNION ALL
    SELECT DATEADD(MONTH, 1, MonthStart) FROM months WHERE MonthStart < '2025-12-01'
)
SELECT mo.MonthStart, p.PlanClass, COUNT(*) AS MemberMonths
FROM months AS mo
JOIN core.Members  AS m ON m.EnrollmentDate <= EOMONTH(mo.MonthStart)
JOIN core.Policies AS p ON p.PolicyID = m.PolicyID
GROUP BY mo.MonthStart, p.PlanClass;
GO

/* ---------- Data-quality report ---------- */
-- DQ1: row counts staging vs core (nothing lost in conversion)
SELECT 'Claims' AS Entity, (SELECT COUNT(*) FROM stg.Claims) AS StagingRows, (SELECT COUNT(*) FROM core.Claims) AS CoreRows,
       (SELECT COUNT(*) FROM core.vw_ClaimsClean) AS CleanRows;

-- DQ2: duplicate re-submissions found and their value
SELECT COUNT(*) AS DuplicateClaims, SUM(BilledAmount) AS DuplicateBilled, SUM(ApprovedAmount) AS DuplicateApprovedAtRisk
FROM (SELECT c.*, ROW_NUMBER() OVER (PARTITION BY MemberID, ProviderID, ServiceDate, ClaimType, BilledAmount
                                     ORDER BY SubmissionDate, ClaimID) AS rn
      FROM core.Claims AS c) AS x
WHERE rn > 1;

-- DQ3: business-rule checks on the clean claims
SELECT
    SUM(CASE WHEN ClaimStatus = 'Rejected' AND ApprovedAmount > 0 THEN 1 ELSE 0 END)          AS RejectedButApproved,
    SUM(CASE WHEN ClaimStatus <> 'Rejected' AND PaidDate IS NULL THEN 1 ELSE 0 END)            AS ApprovedNotPaid,
    SUM(CASE WHEN SubmissionLagDays > 90 THEN 1 ELSE 0 END)                                     AS LateSubmissions_Over90Days,
    SUM(CASE WHEN ClaimStatus = 'Rejected' AND RejectionReason IS NULL THEN 1 ELSE 0 END)      AS RejectedWithoutReason
FROM core.vw_ClaimsClean;
GO
