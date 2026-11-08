USE SecureBankDB;
GO


CREATE NONCLUSTERED INDEX IX_P2_Transactions_AccountDate
ON dbo.Transactions (AccountId, CreatedAt DESC, TransactionId DESC)
INCLUDE (TransactionType, Amount, TransactionStatus);
GO


CREATE NONCLUSTERED INDEX IX_P2_Transactions_StatusDate
ON dbo.Transactions (CreatedAt DESC, TransactionId DESC)
INCLUDE (AccountId, TransactionType, Amount, TransactionStatus)
WHERE TransactionStatus = 'FAILED';
GO


CREATE NONCLUSTERED INDEX IX_P2_Accounts_CustomerId
ON dbo.Accounts (CustomerId)
INCLUDE (AccountNumber, AccountType, Balance);
GO

/* Evidence: list the indexes that now exist (screenshot this) */
SELECT
    OBJECT_NAME(i.object_id) AS TableName,
    i.name                   AS IndexName,
    i.type_desc              AS IndexType,
    i.has_filter             AS IsFiltered,
    i.filter_definition      AS FilterDefinition
FROM sys.indexes AS i
WHERE i.object_id IN (OBJECT_ID('dbo.Transactions'), OBJECT_ID('dbo.Accounts'))
  AND i.name IS NOT NULL
ORDER BY TableName, IndexName;
GO
