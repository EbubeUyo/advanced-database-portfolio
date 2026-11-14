
USE SecureBankDB;
GO

BEGIN TRANSACTION;

UPDATE dbo.Accounts SET Balance = Balance - 1 WHERE AccountNumber = '1000000001';  -- lock Amina
WAITFOR DELAY '00:00:10';
UPDATE dbo.Accounts SET Balance = Balance + 1 WHERE AccountNumber = '1000000003';  -- now want Fatima

ROLLBACK TRANSACTION;   -- demo only: leave balances unchanged
GO
