/* =====================================================================
   Script 03: analytical view
   One row per invoice line, enriched with date, branch, product and
   customer attributes. All analysis queries read from this view so the
   join logic is written (and reviewed) once.
   ===================================================================== */
USE SalesAnalytics;
GO

CREATE OR ALTER VIEW dbo.vw_SalesLines
AS
SELECT
    l.LineID,
    i.InvoiceID,
    i.InvoiceDate,
    YEAR(i.InvoiceDate)                                AS SalesYear,
    MONTH(i.InvoiceDate)                               AS SalesMonth,
    DATEFROMPARTS(YEAR(i.InvoiceDate), MONTH(i.InvoiceDate), 1) AS MonthStart,
    i.PaymentMethod,
    b.BranchID,  b.BranchCode, b.BranchName, b.City AS BranchCity,
    c.CustomerID, c.CustomerName, c.CustomerType,
    p.ProductID, p.ProductName, p.Category, p.SubCategory, p.Brand,
    l.Quantity,
    l.UnitPrice,
    l.DiscountPct,
    l.Quantity * l.UnitPrice                           AS GrossAmount,
    l.NetAmount,
    l.Quantity * l.UnitCost                            AS CostAmount,
    l.NetAmount - l.Quantity * l.UnitCost              AS GrossProfit
FROM dbo.SalesInvoiceLines AS l
JOIN dbo.SalesInvoices     AS i ON i.InvoiceID  = l.InvoiceID
JOIN dbo.Branches          AS b ON b.BranchID   = i.BranchID
JOIN dbo.Customers         AS c ON c.CustomerID = i.CustomerID
JOIN dbo.Products          AS p ON p.ProductID  = l.ProductID;
GO
