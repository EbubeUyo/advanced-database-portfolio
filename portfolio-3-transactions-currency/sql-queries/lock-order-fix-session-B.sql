
USE SecureBankDB;
GO

SELECT 'B started' AS Step, SYSDATETIME() AS At;

EXEC dbo.usp_TransferFunds '1000000003', '1000000001', 500.00, 'P3-LOCKORDER-B';

SELECT 'B finished' AS Step, SYSDATETIME() AS At;

SELECT TransferReference, TransferStatus, CreatedAt
FROM dbo.Transfers
WHERE TransferReference IN ('P3-LOCKORDER-A', 'P3-LOCKORDER-B');
GO
