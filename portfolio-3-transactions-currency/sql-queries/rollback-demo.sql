
USE SecureBankDB;
GO

-- BEFORE
SELECT AccountNumber, Balance FROM dbo.Accounts
WHERE AccountNumber IN ('1000000002', '1000000003');

BEGIN TRY
    EXEC dbo.usp_TransferFunds
         @FromAccountNumber = '1000000002',
         @ToAccountNumber   = '1000000003',
         @Amount            = 9999999.00,
         @Reference         = 'P3-ROLLBACK-001';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
END CATCH;

-- AFTER: balances are exactly the same as BEFORE
SELECT AccountNumber, Balance FROM dbo.Accounts
WHERE AccountNumber IN ('1000000002', '1000000003');

-- No transfer was saved
SELECT COUNT(*) AS TransfersSaved
FROM dbo.Transfers WHERE TransferReference = 'P3-ROLLBACK-001';

-- But the failure was audited
SELECT TOP (1) ActionType, EntityId, Description, CreatedAt
FROM dbo.AuditLogs
WHERE EntityId = 'P3-ROLLBACK-001'
ORDER BY AuditLogId DESC;
GO
