/* =====================================================================
   Script 04: sales & customer performance analysis
   Each query is independent and starts with a "-- Q<n>:" header.
   Amounts are net sales in SAR, excluding VAT.
   ===================================================================== */
USE SalesAnalytics;
GO

-- Q01: Executive KPIs by year, with year-over-year growth (LAG)
WITH yearly AS (
    SELECT
        SalesYear,
        SUM(NetAmount)              AS Revenue,
        SUM(GrossProfit)            AS GrossProfit,
        COUNT(DISTINCT InvoiceID)   AS Invoices,
        COUNT(DISTINCT CustomerID)  AS ActiveCustomers
    FROM dbo.vw_SalesLines
    GROUP BY SalesYear
)
SELECT
    SalesYear,
    CAST(Revenue AS DECIMAL(14,0))                                   AS Revenue,
    CAST(GrossProfit AS DECIMAL(14,0))                               AS GrossProfit,
    CAST(100.0 * GrossProfit / Revenue AS DECIMAL(5,1))              AS GrossMarginPct,
    Invoices,
    ActiveCustomers,
    CAST(Revenue / Invoices AS DECIMAL(10,0))                        AS AvgInvoiceValue,
    CAST(100.0 * (Revenue - LAG(Revenue) OVER (ORDER BY SalesYear))
         / LAG(Revenue) OVER (ORDER BY SalesYear) AS DECIMAL(5,1))   AS RevenueYoYPct
FROM yearly
ORDER BY SalesYear;
GO

-- Q02: Monthly trend - MoM growth, same month last year (YoY), YTD running total, 3-month moving average
WITH monthly AS (
    SELECT MonthStart, SalesYear, SUM(NetAmount) AS Revenue
    FROM dbo.vw_SalesLines
    GROUP BY MonthStart, SalesYear
)
SELECT
    MonthStart,
    CAST(Revenue AS DECIMAL(14,0)) AS Revenue,
    CAST(100.0 * (Revenue - LAG(Revenue, 1)  OVER (ORDER BY MonthStart))
         / LAG(Revenue, 1)  OVER (ORDER BY MonthStart) AS DECIMAL(6,1))           AS MoMPct,
    CAST(100.0 * (Revenue - LAG(Revenue, 12) OVER (ORDER BY MonthStart))
         / LAG(Revenue, 12) OVER (ORDER BY MonthStart) AS DECIMAL(6,1))           AS YoYPct,
    CAST(SUM(Revenue) OVER (PARTITION BY SalesYear ORDER BY MonthStart
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS DECIMAL(14,0)) AS RevenueYTD,
    CAST(AVG(Revenue) OVER (ORDER BY MonthStart
                            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS DECIMAL(14,0))         AS MovingAvg3M
FROM monthly
ORDER BY MonthStart;
GO

-- Q03: Branch performance by year - revenue, share of company, YoY, rank
WITH branch_year AS (
    SELECT BranchCode, BranchName, SalesYear,
           SUM(NetAmount)   AS Revenue,
           SUM(GrossProfit) AS GrossProfit
    FROM dbo.vw_SalesLines
    GROUP BY BranchCode, BranchName, SalesYear
)
SELECT
    SalesYear,
    BranchCode,
    BranchName,
    CAST(Revenue AS DECIMAL(14,0))                                               AS Revenue,
    CAST(100.0 * Revenue / SUM(Revenue) OVER (PARTITION BY SalesYear) AS DECIMAL(5,1)) AS SharePct,
    CAST(100.0 * GrossProfit / Revenue AS DECIMAL(5,1))                          AS GrossMarginPct,
    CAST(100.0 * (Revenue - LAG(Revenue) OVER (PARTITION BY BranchCode ORDER BY SalesYear))
         / LAG(Revenue) OVER (PARTITION BY BranchCode ORDER BY SalesYear) AS DECIMAL(6,1)) AS YoYPct,
    RANK() OVER (PARTITION BY SalesYear ORDER BY Revenue DESC)                   AS RankInYear
FROM branch_year
ORDER BY SalesYear, RankInYear;
GO

-- Q04: Category contribution - revenue vs. profit share (which categories "earn" vs. "sell")
SELECT
    Category,
    CAST(SUM(NetAmount) AS DECIMAL(14,0))                                          AS Revenue,
    CAST(100.0 * SUM(NetAmount)   / SUM(SUM(NetAmount))   OVER () AS DECIMAL(5,1)) AS RevenueSharePct,
    CAST(SUM(GrossProfit) AS DECIMAL(14,0))                                        AS GrossProfit,
    CAST(100.0 * SUM(GrossProfit) / SUM(SUM(GrossProfit)) OVER () AS DECIMAL(5,1)) AS ProfitSharePct,
    CAST(100.0 * SUM(GrossProfit) / SUM(NetAmount) AS DECIMAL(5,1))                AS GrossMarginPct
FROM dbo.vw_SalesLines
GROUP BY Category
ORDER BY Revenue DESC;
GO

-- Q05: Top 10 products by revenue in the latest year, with last year's rank for comparison
WITH product_year AS (
    SELECT SalesYear, ProductName, Category,
           SUM(NetAmount)   AS Revenue,
           SUM(GrossProfit) AS GrossProfit,
           SUM(Quantity)    AS Units
    FROM dbo.vw_SalesLines
    GROUP BY SalesYear, ProductName, Category
),
ranked AS (
    SELECT *,
           DENSE_RANK() OVER (PARTITION BY SalesYear ORDER BY Revenue DESC) AS RevenueRank
    FROM product_year
)
SELECT TOP (10)
    cur.RevenueRank,
    cur.ProductName,
    cur.Category,
    cur.Units,
    CAST(cur.Revenue AS DECIMAL(14,0))                                   AS Revenue2025,
    CAST(100.0 * cur.GrossProfit / cur.Revenue AS DECIMAL(5,1))          AS MarginPct,
    prev.RevenueRank                                                     AS Rank2024,
    CAST(100.0 * (cur.Revenue - prev.Revenue) / prev.Revenue AS DECIMAL(6,1)) AS YoYPct
FROM ranked AS cur
LEFT JOIN ranked AS prev
       ON prev.ProductName = cur.ProductName
      AND prev.SalesYear   = cur.SalesYear - 1
WHERE cur.SalesYear = 2025
ORDER BY cur.RevenueRank;
GO

-- Q06: Best 3 products inside each category (ROW_NUMBER per partition) - all years
WITH product_totals AS (
    SELECT Category, ProductName,
           SUM(NetAmount)   AS Revenue,
           SUM(GrossProfit) AS GrossProfit
    FROM dbo.vw_SalesLines
    GROUP BY Category, ProductName
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY Category ORDER BY Revenue DESC) AS rn,
           100.0 * Revenue / SUM(Revenue) OVER (PARTITION BY Category)     AS ShareOfCategory
    FROM product_totals
)
SELECT Category, rn AS RankInCategory, ProductName,
       CAST(Revenue AS DECIMAL(14,0))            AS Revenue,
       CAST(ShareOfCategory AS DECIMAL(5,1))     AS ShareOfCategoryPct
FROM ranked
WHERE rn <= 3
ORDER BY Category, rn;
GO

-- Q07: Products whose sales collapsed in 2025 (biggest YoY drop) - candidates for stock review
WITH py AS (
    SELECT ProductName, Category,
           SUM(CASE WHEN SalesYear = 2024 THEN Quantity ELSE 0 END) AS Units2024,
           SUM(CASE WHEN SalesYear = 2025 THEN Quantity ELSE 0 END) AS Units2025
    FROM dbo.vw_SalesLines
    GROUP BY ProductName, Category
)
SELECT TOP (5)
    ProductName, Category, Units2024, Units2025,
    CAST(100.0 * (Units2025 - Units2024) / NULLIF(Units2024, 0) AS DECIMAL(6,1)) AS UnitsYoYPct
FROM py
ORDER BY UnitsYoYPct ASC;
GO

-- Q08: Pareto (80/20) - cumulative revenue share by customer
WITH customer_revenue AS (
    SELECT CustomerID, CustomerName, CustomerType, SUM(NetAmount) AS Revenue
    FROM dbo.vw_SalesLines
    GROUP BY CustomerID, CustomerName, CustomerType
),
cumulative AS (
    SELECT *,
           SUM(Revenue) OVER (ORDER BY Revenue DESC, CustomerID
                              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
             / SUM(Revenue) OVER ()                                    AS CumShare,
           ROW_NUMBER() OVER (ORDER BY Revenue DESC, CustomerID)       AS CustomerRank,
           COUNT(*) OVER ()                                            AS TotalCustomers
    FROM customer_revenue
),
classified AS (
    SELECT *,
           CASE WHEN CumShare <= 0.80 THEN 'A (top 80% of revenue)'
                WHEN CumShare <= 0.95 THEN 'B (next 15%)'
                ELSE                       'C (last 5%)' END AS ParetoClass
    FROM cumulative
)
SELECT
    ParetoClass,
    COUNT(*)                                                              AS Customers,
    CAST(100.0 * COUNT(*) / MAX(TotalCustomers) AS DECIMAL(5,1))          AS PctOfCustomers,
    CAST(SUM(Revenue) AS DECIMAL(14,0))                                   AS Revenue,
    CAST(100.0 * SUM(Revenue) / SUM(SUM(Revenue)) OVER () AS DECIMAL(5,1)) AS PctOfRevenue,
    CAST(AVG(Revenue) AS DECIMAL(12,0))                                   AS AvgRevenuePerCustomer
FROM classified
GROUP BY ParetoClass
ORDER BY ParetoClass;
GO

-- Q09: Top 10 customers - revenue, share, type, last purchase and recency
WITH customer_stats AS (
    SELECT CustomerID, CustomerName, CustomerType,
           SUM(NetAmount)            AS Revenue,
           COUNT(DISTINCT InvoiceID) AS Invoices,
           MAX(InvoiceDate)          AS LastPurchase
    FROM dbo.vw_SalesLines
    GROUP BY CustomerID, CustomerName, CustomerType
)
SELECT TOP (10)
    RANK() OVER (ORDER BY Revenue DESC)                                    AS [Rank],
    CustomerName, CustomerType, Invoices,
    CAST(Revenue AS DECIMAL(14,0))                                         AS Revenue,
    CAST(100.0 * Revenue / SUM(Revenue) OVER () AS DECIMAL(5,2))           AS SharePct,
    LastPurchase,
    DATEDIFF(DAY, LastPurchase, '2025-12-31')                              AS DaysSinceLastPurchase
FROM customer_stats
ORDER BY Revenue DESC;
GO

-- Q10: Customer type mix - who buys, how often, how much
SELECT
    CustomerType,
    COUNT(DISTINCT CustomerID)                                              AS Customers,
    CAST(SUM(NetAmount) AS DECIMAL(14,0))                                   AS Revenue,
    CAST(100.0 * SUM(NetAmount) / SUM(SUM(NetAmount)) OVER () AS DECIMAL(5,1)) AS RevenueSharePct,
    CAST(SUM(NetAmount) / COUNT(DISTINCT InvoiceID) AS DECIMAL(10,0))       AS AvgInvoiceValue,
    CAST(1.0 * COUNT(DISTINCT InvoiceID) / COUNT(DISTINCT CustomerID) AS DECIMAL(8,1)) AS InvoicesPerCustomer,
    CAST(100.0 * SUM(GrossProfit) / SUM(NetAmount) AS DECIMAL(5,1))         AS GrossMarginPct
FROM dbo.vw_SalesLines
GROUP BY CustomerType
ORDER BY Revenue DESC;
GO

-- Q11: Seasonality - average revenue per calendar month across 2023-2025 as an index (100 = average month)
WITH monthly AS (
    SELECT SalesYear, SalesMonth, SUM(NetAmount) AS Revenue
    FROM dbo.vw_SalesLines
    GROUP BY SalesYear, SalesMonth
),
by_month AS (
    SELECT SalesMonth, AVG(Revenue) AS AvgRevenue
    FROM monthly
    GROUP BY SalesMonth
)
SELECT
    SalesMonth,
    DATENAME(MONTH, DATEFROMPARTS(2025, SalesMonth, 1))                       AS MonthName,
    CAST(AvgRevenue AS DECIMAL(14,0))                                         AS AvgRevenue,
    CAST(100.0 * AvgRevenue / AVG(AvgRevenue) OVER () AS DECIMAL(5,0))        AS SeasonalIndex,
    RANK() OVER (ORDER BY AvgRevenue DESC)                                    AS StrengthRank
FROM by_month
ORDER BY SalesMonth;
GO

-- Q12: Which categories drive each peak? Category revenue per month-of-year vs. its own average
WITH cat_month AS (
    SELECT Category, SalesMonth, SUM(NetAmount) / COUNT(DISTINCT SalesYear) AS AvgRevenue
    FROM dbo.vw_SalesLines
    GROUP BY Category, SalesMonth
),
indexed AS (
    SELECT *,
           100.0 * AvgRevenue / AVG(AvgRevenue) OVER (PARTITION BY Category) AS SeasonalIndex,
           ROW_NUMBER() OVER (PARTITION BY Category ORDER BY AvgRevenue DESC) AS rn
    FROM cat_month
)
SELECT Category,
       DATENAME(MONTH, DATEFROMPARTS(2025, SalesMonth, 1)) AS PeakMonth,
       CAST(SeasonalIndex AS DECIMAL(5,0))                 AS PeakIndex
FROM indexed
WHERE rn = 1
ORDER BY PeakIndex DESC;
GO

-- Q13: Day-of-week pattern (Saudi weekend = Friday/Saturday)
WITH daily AS (
    SELECT InvoiceDate, SUM(NetAmount) AS Revenue
    FROM dbo.vw_SalesLines
    GROUP BY InvoiceDate
)
SELECT
    DATENAME(WEEKDAY, InvoiceDate)                                           AS DayName,
    CAST(AVG(Revenue) AS DECIMAL(12,0))                                      AS AvgDailyRevenue,
    CAST(100.0 * AVG(Revenue) / (SELECT AVG(Revenue) FROM daily) AS DECIMAL(5,0)) AS IndexVsAvg
FROM daily
GROUP BY DATENAME(WEEKDAY, InvoiceDate), DATEPART(WEEKDAY, InvoiceDate)
ORDER BY AvgDailyRevenue DESC;
GO

-- Q14: Customer retention - of the customers who bought in year N, how many came back in year N+1?
WITH active AS (
    SELECT DISTINCT CustomerID, SalesYear FROM dbo.vw_SalesLines
)
SELECT
    a.SalesYear                                                AS BaseYear,
    COUNT(*)                                                   AS ActiveCustomers,
    COUNT(n.CustomerID)                                        AS ReturnedNextYear,
    CAST(100.0 * COUNT(n.CustomerID) / COUNT(*) AS DECIMAL(5,1)) AS RetentionPct
FROM active AS a
LEFT JOIN active AS n
       ON n.CustomerID = a.CustomerID
      AND n.SalesYear  = a.SalesYear + 1
WHERE a.SalesYear < 2025
GROUP BY a.SalesYear
ORDER BY a.SalesYear;
GO

-- Q15: RFM segmentation (Recency, Frequency, Monetary) with NTILE scoring 1-5
WITH rfm_base AS (
    SELECT CustomerID,
           DATEDIFF(DAY, MAX(InvoiceDate), '2025-12-31') AS RecencyDays,
           COUNT(DISTINCT InvoiceID)                     AS Frequency,
           SUM(NetAmount)                                AS Monetary
    FROM dbo.vw_SalesLines
    GROUP BY CustomerID
),
scored AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY RecencyDays DESC) AS R,   -- 5 = bought most recently
           NTILE(5) OVER (ORDER BY Frequency  ASC)   AS F,
           NTILE(5) OVER (ORDER BY Monetary   ASC)   AS M
    FROM rfm_base
),
segmented AS (
    SELECT *,
           CASE
               WHEN R >= 4 AND F >= 4 AND M >= 4 THEN '1. Champions'
               WHEN R >= 3 AND F >= 3            THEN '2. Loyal'
               WHEN R >= 4 AND F <= 2            THEN '3. New / Promising'
               WHEN R <= 2 AND F >= 3            THEN '4. At Risk (were good, now inactive)'
               WHEN R <= 2 AND F <= 2            THEN '5. Lost / Hibernating'
               ELSE                                   '6. Needs Attention'
           END AS Segment
    FROM scored
)
SELECT
    Segment,
    COUNT(*)                                                              AS Customers,
    CAST(AVG(1.0 * RecencyDays) AS DECIMAL(8,0))                          AS AvgRecencyDays,
    CAST(AVG(1.0 * Frequency) AS DECIMAL(8,1))                            AS AvgInvoices,
    CAST(SUM(Monetary) AS DECIMAL(14,0))                                  AS Revenue,
    CAST(100.0 * SUM(Monetary) / SUM(SUM(Monetary)) OVER () AS DECIMAL(5,1)) AS RevenueSharePct
FROM segmented
GROUP BY Segment
ORDER BY Segment;
GO

-- Q16: Discount cost - how much revenue and margin each discount level gives away
SELECT
    CONCAT(CAST(DiscountPct * 100 AS INT), '%')                              AS Discount,
    COUNT(*)                                                                 AS Lines,
    CAST(SUM(NetAmount) AS DECIMAL(14,0))                                    AS Revenue,
    CAST(SUM(GrossAmount - NetAmount) AS DECIMAL(14,0))                      AS DiscountGiven,
    CAST(100.0 * SUM(GrossProfit) / SUM(NetAmount) AS DECIMAL(5,1))          AS GrossMarginPct
FROM dbo.vw_SalesLines
GROUP BY DiscountPct
ORDER BY DiscountPct;
GO

-- Q17: Makkah branch ramp-up - monthly revenue since opening vs. the average mature branch
WITH branch_month AS (
    SELECT BranchCode, MonthStart, SUM(NetAmount) AS Revenue
    FROM dbo.vw_SalesLines
    WHERE MonthStart >= '2024-07-01'
    GROUP BY BranchCode, MonthStart
)
SELECT
    m.MonthStart,
    CAST(m.Revenue AS DECIMAL(12,0))                                AS MakkahRevenue,
    CAST(o.AvgOther AS DECIMAL(12,0))                               AS AvgOtherBranches,
    CAST(100.0 * m.Revenue / o.AvgOther AS DECIMAL(5,0))            AS PctOfAvgBranch
FROM branch_month AS m
CROSS APPLY (
    SELECT AVG(x.Revenue) AS AvgOther
    FROM branch_month AS x
    WHERE x.MonthStart = m.MonthStart AND x.BranchCode <> 'MKK-01'
) AS o
WHERE m.BranchCode = 'MKK-01'
ORDER BY m.MonthStart;
GO

-- Q18: Root cause of the December 2025 drop - which categories fell vs. December 2024?
WITH dec AS (
    SELECT Category,
           SUM(CASE WHEN MonthStart = '2024-12-01' THEN NetAmount ELSE 0 END) AS Dec2024,
           SUM(CASE WHEN MonthStart = '2025-12-01' THEN NetAmount ELSE 0 END) AS Dec2025
    FROM dbo.vw_SalesLines
    WHERE MonthStart IN ('2024-12-01', '2025-12-01')
    GROUP BY Category
)
SELECT
    Category,
    CAST(Dec2024 AS DECIMAL(12,0))                                   AS Dec2024,
    CAST(Dec2025 AS DECIMAL(12,0))                                   AS Dec2025,
    CAST(Dec2025 - Dec2024 AS DECIMAL(12,0))                         AS ChangeSAR,
    CAST(100.0 * (Dec2025 - Dec2024) / Dec2024 AS DECIMAL(6,1))      AS ChangePct
FROM dec
ORDER BY ChangeSAR;
GO

-- Q19: Supplier lead time - normal vs. December 2025 (open POs counted up to 2026-01-15 as "still waiting")
WITH po AS (
    SELECT SupplierID,
           CASE WHEN OrderDate >= '2025-12-01' THEN 'Dec2025' ELSE 'Before' END   AS Period,
           DATEDIFF(DAY, OrderDate, COALESCE(ReceiptDate, '2026-01-15'))          AS LeadDays,
           CASE WHEN ReceiptDate IS NULL THEN 1 ELSE 0 END                        AS IsOpen
    FROM dbo.Purchases
)
SELECT
    s.SupplierName,
    AVG(CASE WHEN po.Period = 'Before'  THEN po.LeadDays END) AS AvgLeadDaysNormal,
    AVG(CASE WHEN po.Period = 'Dec2025' THEN po.LeadDays END) AS AvgLeadDaysDec2025,
    SUM(po.IsOpen)                                            AS OpenPOsAtYearEnd
FROM po
JOIN dbo.Suppliers AS s ON s.SupplierID = po.SupplierID
GROUP BY s.SupplierName
ORDER BY AVG(CASE WHEN po.Period = 'Dec2025' THEN po.LeadDays END)
       - AVG(CASE WHEN po.Period = 'Before' THEN po.LeadDays END) DESC;
GO
