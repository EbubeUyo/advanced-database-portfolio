USE SecureBankDB;
GO

SET XACT_ABORT ON;

DECLARE @SourceAccountId INT;
DECLARE @DestinationAccountId INT;
DECLARE @TransferId BIGINT;
DECLARE @Amount DECIMAL(18,2) = 30000.00;
DECLARE @Reference VARCHAR(50) = 'TRF-DEMO-001';

SELECT @SourceAccountId = AccountId
FROM dbo.Accounts
WHERE AccountNumber = '1000000001';

SELECT @DestinationAccountId = AccountId
FROM dbo.Accounts
WHERE AccountNumber = '1000000003';

BEGIN TRY
    BEGIN TRANSACTION;

    IF @SourceAccountId IS NULL
       OR @DestinationAccountId IS NULL
       OR @SourceAccountId = @DestinationAccountId
        THROW 50001, 'Invalid account selection.', 1;

    IF EXISTS (
        SELECT 1 FROM dbo.Transfers
        WHERE TransferReference = @Reference
    )
        THROW 50002, 'Duplicate transfer reference.', 1;

    -- Debit only when sufficient funds are available.
    UPDATE dbo.Accounts
    SET Balance = Balance - @Amount
    WHERE AccountId = @SourceAccountId
      AND Balance >= @Amount;

    IF @@ROWCOUNT <> 1
        THROW 50003, 'Insufficient funds.', 1;

    -- Credit the destination account.
    UPDATE dbo.Accounts
    SET Balance = Balance + @Amount
    WHERE AccountId = @DestinationAccountId;

    IF @@ROWCOUNT <> 1
        THROW 50004, 'Destination account not found.', 1;

    -- Record the transfer.
    INSERT INTO dbo.Transfers
    (
        TransferReference,
        SourceAccountId,
        DestinationAccountId,
        Amount,
        TransferStatus
    )
    VALUES
    (
        @Reference,
        @SourceAccountId,
        @DestinationAccountId,
        @Amount,
        'SUCCESS'
    );

    SET @TransferId = SCOPE_IDENTITY();

    -- Record the corresponding account movements.
    INSERT INTO dbo.Transactions
    (
        AccountId,
        TransferId,
        TransactionType,
        Amount,
        TransactionStatus
    )
    VALUES
    (
        @SourceAccountId,
        @TransferId,
        'TRANSFER_DEBIT',
        @Amount,
        'SUCCESS'
    ),
    (
        @DestinationAccountId,
        @TransferId,
        'TRANSFER_CREDIT',
        @Amount,
        'SUCCESS'
    );

    COMMIT TRANSACTION;

    SELECT 'Transfer successful' AS Result;

END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO