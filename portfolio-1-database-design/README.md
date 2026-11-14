# Portfolio 1 – Database Design and Modelling (SecureBankDB)

## 1. Case study
**Organisation:** SecureBank – a simulated Nigerian retail bank / fintech platform.

| Item | Description |
|------|-------------|
| Nature of business | Customers hold savings and current accounts and move money between them (deposits, withdrawals, transfers) |
| Database users | Customers (via mobile app), bank tellers/support staff, fraud & audit team, system administrators |
| Major data stored | Customers, accounts, transfers, individual account transactions, audit logs |
| Key operations | Open account, deposit, withdraw, transfer funds between accounts, reject transfers with insufficient funds, view transaction history, audit activity |

The same case study is used in all five portfolio activities.

## 2. Diagram

Relationships:
- One **Customer** has many **Accounts** (1 : N)
- One **Account** has many **Transactions** (1 : N)
- One **Transfer** links two accounts (source and destination – two 1 : N relationships to Accounts)
- One **Transfer** produces two **Transactions** (a debit and a credit), so `Transactions.TransferId` is optional (NULL for plain deposits/withdrawals)
- One **Customer** can have many **AuditLogs** (optional – system events may have no customer)

## 3. Relational schema
```
Customers   (CustomerId PK, FirstName, LastName, Email UQ, PhoneNumber, CreatedAt)
Accounts    (AccountId PK, CustomerId FK→Customers, AccountNumber UQ, AccountType, Balance, CreatedAt)
Transfers   (TransferId PK, TransferReference UQ, SourceAccountId FK→Accounts,
             DestinationAccountId FK→Accounts, Amount, TransferStatus, CreatedAt)
Transactions(TransactionId PK, AccountId FK→Accounts, TransferId FK→Transfers NULL,
             TransactionType, Amount, TransactionStatus, CreatedAt)
AuditLogs   (AuditLogId PK, CustomerId FK→Customers NULL, ActionType, EntityName,
             EntityId, Description, CreatedAt)
```

## 4. Keys and constraints (and why)

| Constraint | Business rule it enforces |
|------------|---------------------------|
| `IDENTITY` surrogate primary keys | Stable, small keys that never change even if an email or account number changes |
| `UNIQUE (Email)`, `UNIQUE (AccountNumber)`, `UNIQUE (TransferReference)` | No duplicate customers, account numbers, or duplicate submissions of the same transfer |
| Foreign keys | An account must belong to a real customer; a transaction must belong to a real account |
| `CHECK (Balance >= 0)` | An account can never go overdrawn – even if application code has a bug |
| `CHECK (Amount > 0)` | No zero or negative transfers/transactions |
| `CHECK (SourceAccountId <> DestinationAccountId)` | Cannot transfer to the same account |
| `CHECK (AccountType IN ...)`, `CHECK (... Status IN ...)`, `CHECK (TransactionType IN ...)` | Only valid codes are stored |
| `DECIMAL(18,2)` for money | Exact arithmetic; FLOAT would cause rounding errors |
| `DEFAULT SYSUTCDATETIME()` | Every row is time-stamped in UTC automatically |

## 5. Normalisation
- **1NF:** every column holds a single value (no lists such as "phone1, phone2"), and every table has a primary key.
- **2NF:** every table has a single-column primary key, so no column can depend on only *part* of a key.
- **3NF:** no column depends on another non-key column. For example, the customer's name is stored only in `Customers`, not repeated in `Accounts` or `Transactions`; we reach it through `CustomerId`.

Design decision (deliberate): `Accounts.Balance` could in theory be calculated from `Transactions`, so it is derived data. It is kept because reading one row is much faster than summing thousands of transactions on every balance check, and it is protected by updating it inside the same database transaction as the `Transactions` insert (see Portfolio 3).

## 6. Scripts I ran in order
1. `sql-queries/create-database-queries.sql` – creates `SecureBankDB`
2. `sql-queries/create-tables.sql` – creates the five tables with all constraints
3. `sql-queries/insert-data.sql` – adds 3 sample customers and accounts
4. `sql-queries/verify.sql` – joins Customers and Accounts to confirm the data

Screenshots of each step are in `diagrams/`.
