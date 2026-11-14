
USE SecureBankDB;
GO

BEGIN TRANSACTION;

EXEC dbo.usp_TransferFunds '1000000001', '1000000003', 500.00, 'P3-LOCKORDER-A';

WAITFOR DELAY '00:00:10';   -- keep both account locks for 10 s

COMMIT TRANSACTION;
SELECT 'A committed' AS Result, SYSDATETIME() AS At;
GO
