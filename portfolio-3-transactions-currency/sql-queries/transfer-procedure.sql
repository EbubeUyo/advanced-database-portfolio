USE SecureBankDB;
GO

CREATE OR ALTER PROCEDURE dbo.usp_TransferFunds
    @FromAccountNumber VARCHAR(10),
    @ToAccountNumber   VARCHAR(10),
    @Amount            DECIMAL(18,2),
    @Reference         VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;   -- any runtime error automatically rolls back the whole transaction

    DECLARE @FromId INT, @ToId INT, @FromBalance DECIMAL(18,2), @TransferId BIGINT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @FromId = AccountId FROM dbo.Accounts WHERE AccountNumber = @FromAccountNumber;
        SELECT @ToId   = AccountId FROM dbo.Accounts WHERE AccountNumber = @ToAccountNumber;

        IF @FromId IS NULL OR @ToId IS NULL OR @FromId = @ToId
            THROW 50001, 'Invalid account selection.', 1;

        IF @Amount <= 0
            THROW 50005, 'Amount must be greater than zero.', 1;

        DECLARE @FirstId  INT = IIF(@FromId < @ToId, @FromId, @ToId);
        DECLARE @SecondId INT = IIF(@FromId < @ToId, @ToId, @FromId);
        DECLARE @Ignore DECIMAL(18,2);

        SELECT @Ignore = Balance FROM dbo.Accounts WITH (UPDLOCK, ROWLOCK) WHERE AccountId = @FirstId;
        SELECT @Ignore = Balance FROM dbo.Accounts WITH (UPDLOCK, ROWLOCK) WHERE AccountId = @SecondId;

        -- Safe to read now: no one else can change this row until we finish.
        SELECT @FromBalance = Balance FROM dbo.Accounts WHERE AccountId = @FromId;

        IF @FromBalance < @Amount
            THROW 50003, 'Insufficient funds.', 1;

        UPDATE dbo.Accounts SET Balance = Balance - @Amount WHERE AccountId = @FromId;
        UPDATE dbo.Accounts SET Balance = Balance + @Amount WHERE AccountId = @ToId;

        INSERT INTO dbo.Transfers
            (TransferReference, SourceAccountId, DestinationAccountId, Amount, TransferStatus)
        VALUES (@Reference, @FromId, @ToId, @Amount, 'SUCCESS');   -- UNIQUE reference blocks duplicates

        SET @TransferId = SCOPE_IDENTITY();

        INSERT INTO dbo.Transactions (AccountId, TransferId, TransactionType, Amount, TransactionStatus)
        VALUES (@FromId, @TransferId, 'TRANSFER_DEBIT',  @Amount, 'SUCCESS'),
               (@ToId,   @TransferId, 'TRANSFER_CREDIT', @Amount, 'SUCCESS');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;          -- undo every change made above

        INSERT INTO dbo.AuditLogs (CustomerId, ActionType, EntityName, EntityId, Description)
        SELECT a.CustomerId, 'TRANSFER_FAILED', 'Transfers', @Reference, ERROR_MESSAGE()
        FROM (SELECT 1 AS x) AS d
        LEFT JOIN dbo.Accounts AS a ON a.AccountNumber = @FromAccountNumber;

        THROW;                             -- pass the original error back to the caller
    END CATCH;
END;
GO
