/*
    Portfolio 3 - Step 6: Proving the deadlock fix (WINDOW A)
    Same opposite-direction situation as script 05, but using the procedure.
    Run this in window A, then IMMEDIATELY run 06b in window B.

    A: transfer Amina -> Fatima, then keep the transaction open for 10 s.
    B: transfer Fatima -> Amina at the same time.
    Expected: B simply WAITS (blocking), then succeeds. No error 1205.
*/
USE SecureBankDB;
GO

BEGIN TRANSACTION;

EXEC dbo.usp_TransferFunds '1000000001', '1000000003', 500.00, 'P3-LOCKORDER-A';

WAITFOR DELAY '00:00:10';   -- keep both account locks for 10 s

COMMIT TRANSACTION;
SELECT 'A committed' AS Result, SYSDATETIME() AS At;
GO
