
USE SecureBankDB;
GO
SET NOCOUNT ON;

IF (SELECT COUNT(*) FROM sys.indexes
    WHERE name IN ('IX_P2_Transactions_AccountDate',
                   'IX_P2_Transactions_StatusDate',
                   'IX_P2_Accounts_CustomerId')) <> 3
    THROW 51030, 'Indexes missing: run 03-create-indexes.sql first.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE Email = 'p2.customer.000001@securebank.test')
    THROW 51021, 'Run 01-generate-test-data.sql first.', 1;

DECLARE @TestAccountId INT = (
    SELECT AccountId FROM dbo.Accounts WHERE AccountNumber = '1000000001'
);
DECLARE @AsOf DATETIME2(0) = SYSUTCDATETIME();

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

PRINT 'Q1: Recent history for one account';
SELECT TOP (50)
    t.TransactionId, t.AccountId, t.TransactionType,
    t.Amount, t.TransactionStatus, t.CreatedAt
FROM dbo.Transactions AS t
WHERE t.AccountId = @TestAccountId
ORDER BY t.CreatedAt DESC, t.TransactionId DESC
OPTION (RECOMPILE);

PRINT 'Q2: Recent failed transactions';
SELECT TOP (100)
    t.TransactionId, t.AccountId, t.TransactionType,
    t.Amount, t.TransactionStatus, t.CreatedAt
FROM dbo.Transactions AS t
WHERE t.TransactionStatus = 'FAILED'
  AND t.CreatedAt >= DATEADD(DAY, -30, @AsOf)
ORDER BY t.CreatedAt DESC, t.TransactionId DESC
OPTION (RECOMPILE);

PRINT 'Q3: Accounts belonging to a customer';
SELECT
    c.CustomerId, c.Email, a.AccountId,
    a.AccountNumber, a.AccountType, a.Balance
FROM dbo.Customers AS c
INNER JOIN dbo.Accounts AS a ON a.CustomerId = c.CustomerId
WHERE c.Email = 'p2.customer.000001@securebank.test'
ORDER BY a.AccountNumber
OPTION (RECOMPILE);

PRINT 'Q4: Transaction totals grouped by type, one account';
SELECT
    t.TransactionType,
    COUNT_BIG(*) AS TransactionCount,
    SUM(t.Amount) AS TotalAmount
FROM dbo.Transactions AS t
WHERE t.AccountId = @TestAccountId
  AND t.CreatedAt >= DATEADD(DAY, -365, @AsOf)
GROUP BY t.TransactionType
ORDER BY t.TransactionType
OPTION (RECOMPILE);

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;