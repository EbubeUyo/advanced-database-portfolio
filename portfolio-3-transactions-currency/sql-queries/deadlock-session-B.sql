
USE SecureBankDB;
GO

BEGIN TRANSACTION;

UPDATE dbo.Accounts SET Balance = Balance - 1 WHERE AccountNumber = '1000000003';  -- lock Fatima
WAITFOR DELAY '00:00:10';
UPDATE dbo.Accounts SET Balance = Balance + 1 WHERE AccountNumber = '1000000001';  -- now want Amina

ROLLBACK TRANSACTION;
GO
