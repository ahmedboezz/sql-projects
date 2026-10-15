/* =====================================================================
   Script 02: load CSV files with BULK INSERT
   Run with SQLCMD mode so $(DataPath) is replaced, e.g.:
     sqlcmd -S .\SQLEXPRESS -E -C -i 02_load_data.sql -v DataPath="F:\CV\DataAnalyst\portfolio\01-sql-sales-analysis\data"
   In SSMS: enable Query > SQLCMD Mode and uncomment the :setvar line below
   (a :setvar inside the script would override -v on the command line).
   Note: the SQL Server service account must have read access to the folder.
   ===================================================================== */
-- :setvar DataPath "C:\path\to\01-sql-sales-analysis\data"

USE SalesAnalytics;
GO

-- load in dependency order (parents first)
BULK INSERT dbo.Branches          FROM '$(DataPath)\Branches.csv'          WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);
BULK INSERT dbo.Suppliers         FROM '$(DataPath)\Suppliers.csv'         WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);
BULK INSERT dbo.Products          FROM '$(DataPath)\Products.csv'          WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);
BULK INSERT dbo.Customers         FROM '$(DataPath)\Customers.csv'         WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);
BULK INSERT dbo.SalesInvoices     FROM '$(DataPath)\SalesInvoices.csv'     WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);
BULK INSERT dbo.SalesInvoiceLines FROM '$(DataPath)\SalesInvoiceLines.csv' WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);
BULK INSERT dbo.Purchases         FROM '$(DataPath)\Purchases.csv'         WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);
GO

-- quick row-count check
SELECT 'Branches' AS TableName, COUNT(*) AS Rows FROM dbo.Branches
UNION ALL SELECT 'Suppliers',         COUNT(*) FROM dbo.Suppliers
UNION ALL SELECT 'Products',          COUNT(*) FROM dbo.Products
UNION ALL SELECT 'Customers',         COUNT(*) FROM dbo.Customers
UNION ALL SELECT 'SalesInvoices',     COUNT(*) FROM dbo.SalesInvoices
UNION ALL SELECT 'SalesInvoiceLines', COUNT(*) FROM dbo.SalesInvoiceLines
UNION ALL SELECT 'Purchases',         COUNT(*) FROM dbo.Purchases;
GO
