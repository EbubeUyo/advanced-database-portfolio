INSERT INTO dbo.Customers
    (FirstName, LastName, Email, PhoneNumber)
VALUES
    ('Amina', 'Yusuf', 'amina@example.com', '08012345678'),
    ('Tunde', 'Ade', 'tunde@example.com', '08023456789'),
    ('Fatima', 'Bello', 'fatima@example.com', '08034567890');
GO

INSERT INTO dbo.Accounts
    (CustomerId, AccountNumber, AccountType, Balance)
VALUES
    (1, '1000000001', 'SAVINGS', 100000.00),
    (1, '1000000002', 'CURRENT', 50000.00),
    (2, '1000000003', 'SAVINGS', 200000.00);
GO