
USE SecureBankDB;
GO

-- BEFORE
SELECT AccountNumber, Balance FROM dbo.Accounts
WHERE AccountNumber IN ('1000000001', '1000000003');

DECLARE @Ref VARCHAR(50) = CONCAT('P3-COMMIT-', FORMAT(SYSUTCDATETIME(), 'yyyyMMddHHmmss'));

EXEC dbo.usp_TransferFunds
     @FromAccountNumber = '1000000001',
     @ToAccountNumber   = '1000000003',
     @Amount            = 10000.00,
     @Reference         = @Ref;

-- AFTER: balances changed and both records exist
SELECT AccountNumber, Balance FROM dbo.Accounts
WHERE AccountNumber IN ('1000000001', '1000000003');

SELECT t.TransferReference, t.Amount, t.TransferStatus,
       x.TransactionType, x.Amount AS LineAmount
FROM dbo.Transfers AS t
JOIN dbo.Transactions AS x ON x.TransferId = t.TransferId
WHERE t.TransferReference = @Ref;
GO
