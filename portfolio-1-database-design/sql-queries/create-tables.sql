USE SecureBankDB;
GO

CREATE TABLE dbo.Customers
(
    CustomerId INT IDENTITY(1,1) PRIMARY KEY,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Email NVARCHAR(100) NOT NULL UNIQUE,
    CreatedAt DATETIME2 NOT NULL
        DEFAULT SYSUTCDATETIME()
);


CREATE TABLE dbo.Accounts
(
    AccountId INT IDENTITY(1,1) PRIMARY KEY,
    CustomerId INT NOT NULL,
    AccountNumber VARCHAR(10) NOT NULL UNIQUE,
    AccountType VARCHAR(20) NOT NULL,
    Balance DECIMAL(18,2) NOT NULL
        DEFAULT 0,

    CONSTRAINT FK_Accounts_Customers
        FOREIGN KEY (CustomerId)
        REFERENCES dbo.Customers(CustomerId),

    CONSTRAINT CK_Accounts_AccountType
        CHECK (AccountType IN ('SAVINGS', 'CURRENT')),

    CONSTRAINT CK_Accounts_Balance
        CHECK (Balance >= 0)
);


CREATE TABLE dbo.Transfers
(
    TransferId BIGINT IDENTITY(1,1) PRIMARY KEY,

    TransferReference VARCHAR(50) NOT NULL UNIQUE,

    SourceAccountId INT NOT NULL,
    DestinationAccountId INT NOT NULL,

    Amount DECIMAL(18,2) NOT NULL,

    TransferStatus VARCHAR(20) NOT NULL
        DEFAULT 'PENDING',

    CreatedAt DATETIME2 NOT NULL
        DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_Transfers_SourceAccount
        FOREIGN KEY (SourceAccountId)
        REFERENCES dbo.Accounts(AccountId),

    CONSTRAINT FK_Transfers_DestinationAccount
        FOREIGN KEY (DestinationAccountId)
        REFERENCES dbo.Accounts(AccountId),

    CONSTRAINT CK_Transfers_Amount
        CHECK (Amount > 0),

    CONSTRAINT CK_Transfers_Status
        CHECK (TransferStatus IN
            ('PENDING', 'SUCCESS', 'FAILED')),

    CONSTRAINT CK_Transfers_DifferentAccounts
        CHECK (SourceAccountId <> DestinationAccountId)
);


CREATE TABLE dbo.Transactions
(
    TransactionId BIGINT IDENTITY(1,1) PRIMARY KEY,

    AccountId INT NOT NULL,
    TransferId BIGINT NULL,

    TransactionType VARCHAR(20) NOT NULL,

    Amount DECIMAL(18,2) NOT NULL,

    TransactionStatus VARCHAR(20) NOT NULL
        DEFAULT 'PENDING',

    CreatedAt DATETIME2 NOT NULL
        DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_Transactions_Accounts
        FOREIGN KEY (AccountId)
        REFERENCES dbo.Accounts(AccountId),

    CONSTRAINT FK_Transactions_Transfers
        FOREIGN KEY (TransferId)
        REFERENCES dbo.Transfers(TransferId),

    CONSTRAINT CK_Transactions_Type
        CHECK (TransactionType IN
            ('DEPOSIT', 'WITHDRAWAL',
             'TRANSFER_DEBIT', 'TRANSFER_CREDIT')),

    CONSTRAINT CK_Transactions_Amount
        CHECK (Amount > 0),

    CONSTRAINT CK_Transactions_Status
        CHECK (TransactionStatus IN
            ('PENDING', 'SUCCESS', 'FAILED'))
);


CREATE TABLE dbo.AuditLogs
(
    AuditLogId BIGINT IDENTITY(1,1) PRIMARY KEY,

    CustomerId INT NULL,

    ActionType VARCHAR(50) NOT NULL,

    EntityName VARCHAR(50) NOT NULL,

    EntityId VARCHAR(50) NULL,

    Description NVARCHAR(500) NULL,

    CreatedAt DATETIME2 NOT NULL
        DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_AuditLogs_Customers
        FOREIGN KEY (CustomerId)
        REFERENCES dbo.Customers(CustomerId)
);
GO

