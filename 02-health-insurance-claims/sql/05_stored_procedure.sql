/* =====================================================================
   Script 05: reusable monthly report as a stored procedure
   EXEC core.usp_MonthlyClaimsReport @Month = '2025-11-01';
   ===================================================================== */
USE InsuranceClaims;
GO
CREATE OR ALTER PROCEDURE core.usp_MonthlyClaimsReport
    @Month DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @start DATE = DATEFROMPARTS(YEAR(@Month), MONTH(@Month), 1);
    DECLARE @end   DATE = EOMONTH(@start);

    -- 1) headline KPIs vs previous month
    WITH k AS (
        SELECT CASE WHEN ServiceDate >= @start THEN 'Current' ELSE 'Previous' END AS Period,
               COUNT(*) AS Claims, SUM(ApprovedAmount) AS Approved,
               AVG(CASE WHEN ClaimStatus = 'Rejected' THEN 1.0 ELSE 0 END) AS RejectionRate
        FROM core.vw_ClaimsClean
        WHERE ServiceDate BETWEEN DATEADD(MONTH, -1, @start) AND @end
        GROUP BY CASE WHEN ServiceDate >= @start THEN 'Current' ELSE 'Previous' END
    )
    SELECT Period, Claims, CAST(Approved AS DECIMAL(14,0)) AS Approved, CAST(RejectionRate AS DECIMAL(6,4)) AS RejectionRate
    FROM k ORDER BY Period;

    -- 2) top 5 providers by approved amount in the month
    SELECT TOP 5 ProviderID, ProviderType, COUNT(*) AS Claims, CAST(SUM(ApprovedAmount) AS DECIMAL(14,0)) AS Approved
    FROM core.vw_ClaimFacts
    WHERE ServiceDate BETWEEN @start AND @end
    GROUP BY ProviderID, ProviderType
    ORDER BY SUM(ApprovedAmount) DESC;
END
GO
EXEC core.usp_MonthlyClaimsReport @Month = '2025-11-01';
GO
