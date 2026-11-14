/*
    Portfolio 3 - Step 4: Isolation levels (WINDOW A)
    Open TWO query windows. Run this in window A, then IMMEDIATELY run
    04b in window B (you have 20 seconds).

    Window A changes Amina's balance but has NOT committed yet.
    After 20 seconds it ROLLS BACK, so the change "never happened".
*/
USE SecureBankDB;
GO

BEGIN TRANSACTION;

UPDATE dbo.Accounts
SET Balance = Balance + 1000000          -- uncommitted, temporary change
WHERE AccountNumber = '1000000001';

SELECT 'A: balance changed but not committed' AS Step, Balance
FROM dbo.Accounts WHERE AccountNumber = '1000000001';

WAITFOR DELAY '00:00:20';                -- hold the change (and its lock) for 20 s

ROLLBACK TRANSACTION;

SELECT 'A: rolled back' AS Step, Balance
FROM dbo.Accounts WHERE AccountNumber = '1000000001';
GO
