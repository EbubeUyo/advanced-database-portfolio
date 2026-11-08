USE SecureBankDB;
GO
SET NOCOUNT ON;

DECLARE @CustomerCount INT = 20000;
DECLARE @TxnRows       INT = 500000;
DECLARE @DemoTxnRows   INT = 2000;
DECLARE @Now DATETIME2(0)  = SYSUTCDATETIME();

IF EXISTS (SELECT 1 FROM dbo.Customers WHERE Email LIKE 'p2.customer.%@securebank.test')
    THROW 51010, 'Portfolio 2 test data already exists. Skip this script.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.Accounts WHERE AccountNumber = '1000000001')
    THROW 51011, 'Demo account 1000000001 is missing. Run the Portfolio 1 scripts first.', 1;

/* ---------- Numbers (tally) table: 1 .. @TxnRows ---------- */
IF OBJECT_ID('tempdb..#Numbers') IS NOT NULL DROP TABLE #Numbers;

SELECT TOP (@TxnRows)
    n = CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS INT)
INTO #Numbers
FROM sys.all_objects AS a
CROSS JOIN sys.all_objects AS b
CROSS JOIN sys.all_objects AS c;

CREATE UNIQUE CLUSTERED INDEX CX_Numbers ON #Numbers(n);

/* ---------- 1. Customers ---------- */
INSERT INTO dbo.Customers (FirstName, LastName, Email, PhoneNumber, CreatedAt)
SELECT
    CONCAT(N'Cust', n),
    CONCAT(N'Test', n % 500),
    CONCAT(N'p2.customer.', RIGHT(CONCAT('000000', n), 6), N'@securebank.test'),
    CONCAT('080', RIGHT(CONCAT('00000000', n), 8)),
    DATEADD(DAY, -(n % 1000), @Now)
FROM #Numbers
WHERE n <= @CustomerCount;

PRINT CONCAT('Customers inserted: ', @@ROWCOUNT);

/* ---------- 2. Accounts ---------- */
-- Account numbers start with 2 so they never clash with the Portfolio 1 accounts (1000000001-3).
;WITH P2Customers AS
(
    SELECT
        c.CustomerId,
        rn = CAST(SUBSTRING(c.Email, 13, 6) AS INT)   -- the 6-digit number in the email
    FROM dbo.Customers AS c
    WHERE c.Email LIKE 'p2.customer.%@securebank.test'
)
INSERT INTO dbo.Accounts (CustomerId, AccountNumber, AccountType, Balance)
SELECT CustomerId,
       CONCAT('2', RIGHT(CONCAT('000000000', rn), 9)),
       'SAVINGS',
       CAST(ABS(CAST(CHECKSUM(NEWID()) AS BIGINT)) % 5000000 AS DECIMAL(18,2))
FROM P2Customers
UNION ALL
SELECT CustomerId,
       CONCAT('3', RIGHT(CONCAT('000000000', rn), 9)),
       'CURRENT',
       CAST(ABS(CAST(CHECKSUM(NEWID()) AS BIGINT)) % 2000000 AS DECIMAL(18,2))
FROM P2Customers
WHERE rn % 2 = 0;

PRINT CONCAT('Accounts inserted: ', @@ROWCOUNT);

/* ---------- 3. Transactions ---------- */
-- Give every P2 account a sequential position so random numbers can be mapped to it.
IF OBJECT_ID('tempdb..#Acc') IS NOT NULL DROP TABLE #Acc;

SELECT AccountId,
       pos = CAST(ROW_NUMBER() OVER (ORDER BY AccountId) AS INT)
INTO #Acc
FROM dbo.Accounts
WHERE AccountNumber LIKE '[23]%';

CREATE UNIQUE CLUSTERED INDEX CX_Acc ON #Acc(pos);

DECLARE @AccCount INT = (SELECT COUNT(*) FROM #Acc);

-- Generate the random values once and store them, so each row keeps the same values.
-- (CAST to BIGINT before ABS avoids a rare overflow when CHECKSUM returns the minimum INT.)
IF OBJECT_ID('tempdb..#Rand') IS NOT NULL DROP TABLE #Rand;

SELECT
    n,
    rAcc    = CAST(ABS(CAST(CHECKSUM(NEWID()) AS BIGINT)) % @AccCount AS INT) + 1,
    rType   = CAST(ABS(CAST(CHECKSUM(NEWID()) AS BIGINT)) % 100 AS INT),
    rStatus = CAST(ABS(CAST(CHECKSUM(NEWID()) AS BIGINT)) % 100 AS INT),
    rAmount = CAST(ABS(CAST(CHECKSUM(NEWID()) AS BIGINT)) % 49990000 AS INT),           -- in kobo
    rSecs   = CAST(ABS(CAST(CHECKSUM(NEWID()) AS BIGINT)) % (730 * 86400) AS INT)       -- up to 2 years back
INTO #Rand
FROM #Numbers;

INSERT INTO dbo.Transactions
    (AccountId, TransferId, TransactionType, Amount, TransactionStatus, CreatedAt)
SELECT
    a.AccountId,
    NULL,
    CASE WHEN r.rType < 50 THEN 'DEPOSIT' ELSE 'WITHDRAWAL' END,
    CAST((r.rAmount + 10000) / 100.0 AS DECIMAL(18,2)),    -- NGN 100.00 to 500,000.00
    CASE WHEN r.rStatus < 97 THEN 'SUCCESS'
         WHEN r.rStatus < 99 THEN 'FAILED'                 -- ~2% failed
         ELSE 'PENDING' END,
    DATEADD(SECOND, -r.rSecs, @Now)
FROM #Rand AS r
INNER JOIN #Acc AS a ON a.pos = r.rAcc;

PRINT CONCAT('Bulk transactions inserted: ', @@ROWCOUNT);

-- Busy demo account used by Q1 and Q4.
INSERT INTO dbo.Transactions
    (AccountId, TransferId, TransactionType, Amount, TransactionStatus, CreatedAt)
SELECT
    acc.AccountId,
    NULL,
    CASE WHEN r.rType < 50 THEN 'DEPOSIT' ELSE 'WITHDRAWAL' END,
    CAST((r.rAmount + 10000) / 100.0 AS DECIMAL(18,2)),
    CASE WHEN r.rStatus < 97 THEN 'SUCCESS' WHEN r.rStatus < 99 THEN 'FAILED' ELSE 'PENDING' END,
    DATEADD(SECOND, -r.rSecs, @Now)
FROM #Rand AS r
CROSS JOIN (SELECT AccountId FROM dbo.Accounts WHERE AccountNumber = '1000000001') AS acc
WHERE r.n <= @DemoTxnRows;

PRINT CONCAT('Demo-account transactions inserted: ', @@ROWCOUNT);

/* ---------- 4. Fresh statistics so the optimiser sees the real row counts ---------- */
UPDATE STATISTICS dbo.Customers    WITH FULLSCAN;
UPDATE STATISTICS dbo.Accounts     WITH FULLSCAN;
UPDATE STATISTICS dbo.Transactions WITH FULLSCAN;

/* ---------- 5. Summary (screenshot this) ---------- */
SELECT 'Customers'    AS TableName, COUNT_BIG(*) AS RowsNow FROM dbo.Customers
UNION ALL SELECT 'Accounts',     COUNT_BIG(*) FROM dbo.Accounts
UNION ALL SELECT 'Transactions', COUNT_BIG(*) FROM dbo.Transactions;

SELECT TransactionStatus, COUNT_BIG(*) AS Cnt
FROM dbo.Transactions
GROUP BY TransactionStatus;

DROP TABLE #Rand;
DROP TABLE #Acc;
DROP TABLE #Numbers;
GO
