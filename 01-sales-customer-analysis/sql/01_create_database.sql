/* =====================================================================
   Project 1 - Sales & Customer Performance Analysis
   Script 01: create database and ERP-style schema
   Target   : Microsoft SQL Server 2019+
   ===================================================================== */

IF DB_ID(N'SalesAnalytics') IS NULL
    CREATE DATABASE SalesAnalytics;
GO
USE SalesAnalytics;
GO

DROP TABLE IF EXISTS dbo.SalesInvoiceLines, dbo.SalesInvoices, dbo.Purchases,
                     dbo.Customers, dbo.Products, dbo.Suppliers, dbo.Branches;
GO

CREATE TABLE dbo.Branches (
    BranchID     INT            NOT NULL PRIMARY KEY,
    BranchCode   VARCHAR(10)    NOT NULL UNIQUE,
    BranchName   NVARCHAR(60)   NOT NULL,
    City         NVARCHAR(40)   NOT NULL,
    Region       NVARCHAR(20)   NOT NULL,
    OpenDate     DATE           NOT NULL
);

CREATE TABLE dbo.Suppliers (
    SupplierID   INT            NOT NULL PRIMARY KEY,
    SupplierName NVARCHAR(80)   NOT NULL,
    City         NVARCHAR(40)   NOT NULL,
    LeadTimeDays INT            NOT NULL
);

CREATE TABLE dbo.Products (
    ProductID    INT            NOT NULL PRIMARY KEY,
    SKU          VARCHAR(20)    NOT NULL UNIQUE,
    ProductName  NVARCHAR(100)  NOT NULL,
    Category     NVARCHAR(40)   NOT NULL,
    SubCategory  NVARCHAR(40)   NOT NULL,
    Brand        NVARCHAR(40)   NOT NULL,
    SupplierID   INT            NOT NULL REFERENCES dbo.Suppliers(SupplierID),
    StandardCost DECIMAL(12,2)  NOT NULL,
    ListPrice    DECIMAL(12,2)  NOT NULL
);

CREATE TABLE dbo.Customers (
    CustomerID   INT            NOT NULL PRIMARY KEY,
    CustomerName NVARCHAR(100)  NOT NULL,
    CustomerType VARCHAR(20)    NOT NULL,   -- Retail / Wholesale / Corporate
    City         NVARCHAR(40)   NOT NULL,
    HomeBranchID INT            NOT NULL REFERENCES dbo.Branches(BranchID),
    JoinDate     DATE           NOT NULL
);

CREATE TABLE dbo.SalesInvoices (
    InvoiceID     INT           NOT NULL PRIMARY KEY,
    InvoiceDate   DATE          NOT NULL,
    BranchID      INT           NOT NULL REFERENCES dbo.Branches(BranchID),
    CustomerID    INT           NOT NULL REFERENCES dbo.Customers(CustomerID),
    PaymentMethod VARCHAR(20)   NOT NULL
);

CREATE TABLE dbo.SalesInvoiceLines (
    LineID       INT            NOT NULL PRIMARY KEY,
    InvoiceID    INT            NOT NULL REFERENCES dbo.SalesInvoices(InvoiceID),
    ProductID    INT            NOT NULL REFERENCES dbo.Products(ProductID),
    Quantity     INT            NOT NULL CHECK (Quantity > 0),
    UnitPrice    DECIMAL(12,2)  NOT NULL,
    DiscountPct  DECIMAL(5,2)   NOT NULL,
    NetAmount    DECIMAL(14,2)  NOT NULL,   -- Quantity * UnitPrice * (1 - DiscountPct), excl. VAT
    UnitCost     DECIMAL(12,2)  NOT NULL
);

CREATE TABLE dbo.Purchases (
    PurchaseID   INT            NOT NULL PRIMARY KEY,
    OrderDate    DATE           NOT NULL,
    ReceiptDate  DATE           NULL,       -- NULL = not received yet
    BranchID     INT            NOT NULL REFERENCES dbo.Branches(BranchID),
    SupplierID   INT            NOT NULL REFERENCES dbo.Suppliers(SupplierID),
    ProductID    INT            NOT NULL REFERENCES dbo.Products(ProductID),
    Quantity     INT            NOT NULL,
    UnitCost     DECIMAL(12,2)  NOT NULL
);
GO

-- Indexes that support the analytical queries (date range scans + joins)
CREATE INDEX IX_SalesInvoices_Date      ON dbo.SalesInvoices(InvoiceDate) INCLUDE (BranchID, CustomerID);
CREATE INDEX IX_SalesInvoices_Customer  ON dbo.SalesInvoices(CustomerID);
CREATE INDEX IX_SalesInvoiceLines_Inv   ON dbo.SalesInvoiceLines(InvoiceID) INCLUDE (ProductID, Quantity, NetAmount, UnitCost);
CREATE INDEX IX_SalesInvoiceLines_Prod  ON dbo.SalesInvoiceLines(ProductID);
GO
