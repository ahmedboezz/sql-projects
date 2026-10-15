/* =====================================================================
   Script 04: claims analysis
   Each query is independent and starts with a "-- Q<n>:" header.
   All amounts in SAR. Source: core.vw_ClaimsClean / core.vw_ClaimFacts (duplicates removed).
   ===================================================================== */
USE InsuranceClaims;
GO

-- Q01: Monthly KPIs with month-over-month change (LAG)
WITH m AS (
    SELECT DATEFROMPARTS(YEAR(ServiceDate), MONTH(ServiceDate), 1) AS MonthStart,
           COUNT(*)            AS Claims,
           SUM(BilledAmount)   AS Billed,
           SUM(ApprovedAmount) AS Approved
    FROM core.vw_ClaimsClean
    WHERE ServiceDate < '2026-01-01'
    GROUP BY DATEFROMPARTS(YEAR(ServiceDate), MONTH(ServiceDate), 1)
)
SELECT MonthStart, Claims, Billed, Approved,
       CAST(Approved / Billed AS DECIMAL(6,4))                                              AS ApprovalRatio,
       CAST((Approved - LAG(Approved) OVER (ORDER BY MonthStart))
            / NULLIF(LAG(Approved) OVER (ORDER BY MonthStart), 0) AS DECIMAL(6,4))           AS Approved_MoM
FROM m
ORDER BY MonthStart;
GO

-- Q02: Loss ratio by plan class (approved claims / earned premium)
WITH premium AS (
    SELECT p.PlanClass,
           SUM(p.AnnualPremiumPerMember * (DATEDIFF(MONTH, m.EnrollmentDate, '2025-12-31') + 1) / 12.0) AS EarnedPremium,
           COUNT(*) AS Members
    FROM core.Members AS m JOIN core.Policies AS p ON p.PolicyID = m.PolicyID
    GROUP BY p.PlanClass
), cl AS (
    SELECT PlanClass, SUM(ApprovedAmount) AS ApprovedClaims
    FROM core.vw_ClaimFacts WHERE ServiceDate < '2026-01-01'
    GROUP BY PlanClass
)
SELECT pr.PlanClass, pr.Members, CAST(pr.EarnedPremium AS DECIMAL(14,0)) AS EarnedPremium,
       CAST(cl.ApprovedClaims AS DECIMAL(14,0))                          AS ApprovedClaims,
       CAST(cl.ApprovedClaims / pr.EarnedPremium AS DECIMAL(6,4))        AS LossRatio
FROM premium AS pr JOIN cl ON cl.PlanClass = pr.PlanClass
ORDER BY LossRatio DESC;
GO

-- Q03: Loss ratio by employer sector (which groups need re-pricing at renewal?)
WITH premium AS (
    SELECT p.Sector, SUM(p.AnnualPremiumPerMember * (DATEDIFF(MONTH, m.EnrollmentDate, '2025-12-31') + 1) / 12.0) AS EarnedPremium
    FROM core.Members AS m JOIN core.Policies AS p ON p.PolicyID = m.PolicyID
    GROUP BY p.Sector
)
SELECT f.Sector, CAST(SUM(f.ApprovedAmount) / MAX(pr.EarnedPremium) AS DECIMAL(6,4)) AS LossRatio,
       COUNT(DISTINCT f.MemberID) AS ClaimingMembers
FROM core.vw_ClaimFacts AS f JOIN premium AS pr ON pr.Sector = f.Sector
WHERE f.ServiceDate < '2026-01-01'
GROUP BY f.Sector
ORDER BY LossRatio DESC;
GO

-- Q04: Rejection rate and top reason by provider type
WITH r AS (
    SELECT ProviderType, RejectionReason, COUNT(*) AS n,
           ROW_NUMBER() OVER (PARTITION BY ProviderType ORDER BY COUNT(*) DESC) AS rk
    FROM core.vw_ClaimFacts WHERE ClaimStatus = 'Rejected'
    GROUP BY ProviderType, RejectionReason
)
SELECT f.ProviderType, COUNT(*) AS Claims,
       CAST(AVG(CASE WHEN f.ClaimStatus = 'Rejected' THEN 1.0 ELSE 0 END) AS DECIMAL(6,4)) AS RejectionRate,
       MAX(CASE WHEN r.rk = 1 THEN r.RejectionReason END)                                   AS TopReason
FROM core.vw_ClaimFacts AS f
LEFT JOIN r ON r.ProviderType = f.ProviderType AND r.rk = 1
GROUP BY f.ProviderType
ORDER BY RejectionRate DESC;
GO

-- Q05: Providers whose rejection rate jumped after a rule change (pre-authorisation enforced from June 2025)
WITH r AS (
    SELECT ProviderID, ProviderType,
           AVG(CASE WHEN ServiceDate <  '2025-06-01' AND ClaimStatus = 'Rejected' THEN 1.0
                    WHEN ServiceDate <  '2025-06-01' THEN 0 END) AS RejRate_JanMay,
           AVG(CASE WHEN ServiceDate >= '2025-06-01' AND ClaimStatus = 'Rejected' THEN 1.0
                    WHEN ServiceDate >= '2025-06-01' THEN 0 END) AS RejRate_JunDec,
           SUM(CASE WHEN RejectionReason = 'Missing pre-authorization' THEN 1 ELSE 0 END) AS MissingPreAuth
    FROM core.vw_ClaimFacts
    WHERE ClaimType IN ('Inpatient', 'Outpatient')
    GROUP BY ProviderID, ProviderType
    HAVING COUNT(*) >= 300
)
SELECT TOP 5 ProviderID, ProviderType, CAST(RejRate_JanMay AS DECIMAL(6,4)) AS RejRate_JanMay,
       CAST(RejRate_JunDec AS DECIMAL(6,4)) AS RejRate_JunDec, MissingPreAuth
FROM r
ORDER BY RejRate_JunDec - RejRate_JanMay DESC;
GO
-- Q06: Payment turnaround: median and 90th percentile (PERCENTILE_CONT) and SLA breach (> 30 days)
SELECT DISTINCT ProviderType,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY TurnaroundDays) OVER (PARTITION BY ProviderType) AS MedianDays,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY TurnaroundDays) OVER (PARTITION BY ProviderType) AS P90Days,
       CAST(AVG(CASE WHEN TurnaroundDays > 30 THEN 1.0 ELSE 0 END) OVER (PARTITION BY ProviderType) AS DECIMAL(6,4)) AS SLA_Breach_Rate
FROM core.vw_ClaimFacts
WHERE PaidDate IS NOT NULL
ORDER BY P90Days DESC;
GO

-- Q07: Cost concentration (Pareto): share of approved cost from the top 1% / 5% / 20% of members
WITH mc AS (
    SELECT MemberID, SUM(ApprovedAmount) AS Cost FROM core.vw_ClaimsClean GROUP BY MemberID
), ranked AS (
    SELECT Cost, PERCENT_RANK() OVER (ORDER BY Cost DESC) AS pr FROM mc
)
SELECT CAST(SUM(CASE WHEN pr <= 0.01 THEN Cost END) / SUM(Cost) AS DECIMAL(6,4)) AS Top1PctShare,
       CAST(SUM(CASE WHEN pr <= 0.05 THEN Cost END) / SUM(Cost) AS DECIMAL(6,4)) AS Top5PctShare,
       CAST(SUM(CASE WHEN pr <= 0.20 THEN Cost END) / SUM(Cost) AS DECIMAL(6,4)) AS Top20PctShare,
       COUNT(*) AS ClaimingMembers
FROM ranked;
GO

-- Q08: Chronic-disease members (diabetes, hypertension, lipids) vs others: cost per member
WITH chronic AS (
    SELECT DISTINCT MemberID FROM core.vw_ClaimsClean WHERE ICD10Code IN ('E11.9', 'I10', 'E78.5')
), mc AS (
    SELECT c.MemberID, SUM(c.ApprovedAmount) AS Cost, COUNT(*) AS Claims
    FROM core.vw_ClaimsClean AS c GROUP BY c.MemberID
)
SELECT CASE WHEN ch.MemberID IS NOT NULL THEN 'Chronic' ELSE 'Non-chronic' END AS Segment,
       COUNT(*) AS Members, CAST(AVG(mc.Cost) AS DECIMAL(12,2)) AS AvgCostPerMember,
       CAST(AVG(1.0 * mc.Claims) AS DECIMAL(8,2)) AS AvgClaimsPerMember,
       CAST(SUM(mc.Cost) / SUM(SUM(mc.Cost)) OVER () AS DECIMAL(6,4)) AS ShareOfCost
FROM mc LEFT JOIN chronic AS ch ON ch.MemberID = mc.MemberID
GROUP BY CASE WHEN ch.MemberID IS NOT NULL THEN 'Chronic' ELSE 'Non-chronic' END;
GO

-- Q09: Provider outliers: average billed per outpatient claim vs peers of the same type and city (z-score)
WITH p AS (
    SELECT ProviderID, ProviderType, ProviderCity, COUNT(*) AS Claims, AVG(BilledAmount) AS AvgBilled,
           AVG(CASE WHEN ClaimStatus = 'Partially Approved' THEN 1.0 ELSE 0 END) AS PartialRate
    FROM core.vw_ClaimFacts
    WHERE ClaimType = 'Outpatient'
    GROUP BY ProviderID, ProviderType, ProviderCity
    HAVING COUNT(*) >= 100
), z AS (
    SELECT *, (AvgBilled - AVG(AvgBilled) OVER (PARTITION BY ProviderType))
              / NULLIF(STDEV(AvgBilled) OVER (PARTITION BY ProviderType), 0) AS ZScore
    FROM p
)
SELECT ProviderID, ProviderType, ProviderCity, Claims, CAST(AvgBilled AS DECIMAL(10,2)) AS AvgBilled,
       CAST(ZScore AS DECIMAL(6,2)) AS ZScore, CAST(PartialRate AS DECIMAL(6,4)) AS PartialApprovalRate
FROM z
WHERE ZScore > 3
ORDER BY ZScore DESC;
GO

-- Q10: Respiratory seasonality: claims by ICD chapter and month (PIVOT)
SELECT ChapterName, [1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12]
FROM (
    SELECT ChapterName, MONTH(ServiceDate) AS Mo, ClaimID
    FROM core.vw_ClaimFacts
    WHERE ChapterName IN ('Respiratory', 'Endocrine', 'Musculoskeletal', 'Infectious')
) AS s
PIVOT (COUNT(ClaimID) FOR Mo IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12])) AS pv
ORDER BY ChapterName;
GO

-- Q11: Utilisation per 1,000 members per month (PMPM view) by plan class
WITH cl AS (
    SELECT DATEFROMPARTS(YEAR(ServiceDate), MONTH(ServiceDate), 1) AS MonthStart, PlanClass,
           COUNT(*) AS Claims, SUM(ApprovedAmount) AS Approved
    FROM core.vw_ClaimFacts WHERE ServiceDate < '2026-01-01'
    GROUP BY DATEFROMPARTS(YEAR(ServiceDate), MONTH(ServiceDate), 1), PlanClass
)
SELECT mm.PlanClass,
       CAST(SUM(cl.Claims) * 1000.0 / SUM(mm.MemberMonths) AS DECIMAL(8,1))  AS ClaimsPer1000MemberMonths,
       CAST(SUM(cl.Approved) / SUM(mm.MemberMonths) AS DECIMAL(10,2))        AS CostPMPM
FROM core.vw_MemberMonths AS mm
JOIN cl ON cl.MonthStart = mm.MonthStart AND cl.PlanClass = mm.PlanClass
GROUP BY mm.PlanClass
ORDER BY CostPMPM DESC;
GO

-- Q12: Top 10 diagnoses by approved cost, with rank and cumulative share
WITH d AS (
    SELECT ICD10Code, Diagnosis, COUNT(*) AS Claims, SUM(ApprovedAmount) AS Approved
    FROM core.vw_ClaimFacts GROUP BY ICD10Code, Diagnosis
)
SELECT TOP 10 DENSE_RANK() OVER (ORDER BY Approved DESC) AS CostRank, ICD10Code, Diagnosis, Claims,
       CAST(Approved AS DECIMAL(14,0)) AS Approved,
       CAST(SUM(Approved) OVER (ORDER BY Approved DESC ROWS UNBOUNDED PRECEDING) / SUM(Approved) OVER () AS DECIMAL(6,4)) AS CumulativeShare
FROM d
ORDER BY Approved DESC;
GO

-- Q13: Top 3 hospitals by approved amount in each city (ROW_NUMBER per partition)
WITH h AS (
    SELECT ProviderCity, ProviderID, SUM(ApprovedAmount) AS Approved,
           ROW_NUMBER() OVER (PARTITION BY ProviderCity ORDER BY SUM(ApprovedAmount) DESC) AS rn
    FROM core.vw_ClaimFacts WHERE ProviderType = 'Hospital'
    GROUP BY ProviderCity, ProviderID
)
SELECT ProviderCity, rn AS RankInCity, ProviderID, CAST(Approved AS DECIMAL(14,0)) AS Approved
FROM h WHERE rn <= 3
ORDER BY ProviderCity, rn;
GO

-- Q14: Frequent users: members with 15+ outpatient visits and their profile
SELECT TOP 15 f.MemberID, f.PlanClass, f.Gender, MAX(f.AgeAtService) AS Age, COUNT(*) AS OutpatientVisits,
       CAST(SUM(f.ApprovedAmount) AS DECIMAL(12,0)) AS Approved
FROM core.vw_ClaimFacts AS f
WHERE f.ClaimType = 'Outpatient'
GROUP BY f.MemberID, f.PlanClass, f.Gender
HAVING COUNT(*) >= 15
ORDER BY OutpatientVisits DESC;
GO

-- Q15: Cost per member by age band and relation (CASE bucketing)
SELECT CASE WHEN AgeAtService < 18 THEN '0-17' WHEN AgeAtService < 35 THEN '18-34'
            WHEN AgeAtService < 50 THEN '35-49' ELSE '50+' END AS AgeBand,
       RelationToEmployee,
       COUNT(DISTINCT MemberID) AS ClaimingMembers,
       CAST(SUM(ApprovedAmount) / COUNT(DISTINCT MemberID) AS DECIMAL(10,2)) AS CostPerClaimingMember
FROM core.vw_ClaimFacts
GROUP BY CASE WHEN AgeAtService < 18 THEN '0-17' WHEN AgeAtService < 35 THEN '18-34'
              WHEN AgeAtService < 50 THEN '35-49' ELSE '50+' END, RelationToEmployee
ORDER BY AgeBand, RelationToEmployee;
GO

-- Q16: Year-to-date approved cost by plan class (running total)
WITH m AS (
    SELECT PlanClass, DATEFROMPARTS(2025, MONTH(ServiceDate), 1) AS MonthStart, SUM(ApprovedAmount) AS Approved
    FROM core.vw_ClaimFacts WHERE YEAR(ServiceDate) = 2025
    GROUP BY PlanClass, DATEFROMPARTS(2025, MONTH(ServiceDate), 1)
)
SELECT PlanClass, MonthStart, CAST(Approved AS DECIMAL(14,0)) AS Approved,
       CAST(SUM(Approved) OVER (PARTITION BY PlanClass ORDER BY MonthStart ROWS UNBOUNDED PRECEDING) AS DECIMAL(14,0)) AS ApprovedYTD
FROM m
WHERE MONTH(MonthStart) IN (3, 6, 9, 12)
ORDER BY PlanClass, MonthStart;
GO

-- Q17: Late submissions (> 90 days after service) by provider: candidates for contract enforcement
SELECT TOP 10 ProviderID, ProviderType, COUNT(*) AS Claims,
       SUM(CASE WHEN SubmissionLagDays > 90 THEN 1 ELSE 0 END) AS LateClaims,
       CAST(AVG(CASE WHEN SubmissionLagDays > 90 THEN 1.0 ELSE 0 END) AS DECIMAL(6,4)) AS LateRate
FROM core.vw_ClaimFacts
GROUP BY ProviderID, ProviderType
HAVING COUNT(*) >= 200
ORDER BY LateRate DESC;
GO

-- Q18: Members who claimed in Q1 but never again in the rest of the year, by plan class (EXISTS / NOT EXISTS)
SELECT p.PlanClass, COUNT(*) AS Q1OnlyMembers
FROM core.Members AS m
JOIN core.Policies AS p ON p.PolicyID = m.PolicyID
WHERE EXISTS     (SELECT 1 FROM core.vw_ClaimsClean c WHERE c.MemberID = m.MemberID AND c.ServiceDate <  '2025-04-01')
  AND NOT EXISTS (SELECT 1 FROM core.vw_ClaimsClean c WHERE c.MemberID = m.MemberID AND c.ServiceDate >= '2025-04-01')
GROUP BY p.PlanClass
ORDER BY p.PlanClass;
GO


