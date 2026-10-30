
SELECT
    c.FirstName,
    c.LastName,
    a.AccountNumber,
    a.AccountType,
    a.Balance
FROM dbo.Customers c
INNER JOIN dbo.Accounts a
    ON c.CustomerId = a.CustomerId
ORDER BY a.AccountNumber;
