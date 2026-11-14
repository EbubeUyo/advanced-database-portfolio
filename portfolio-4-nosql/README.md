# Portfolio 4 – NoSQL and Advanced Data Models (SecureBank in MongoDB)

## Goal

Model the same SecureBank case study as a **document database** (MongoDB), and explain
when this model is a better or worse fit than the relational design in Portfolio 1.

## How to run

1. Create a free MongoDB Atlas cluster (M0), or install MongoDB locally.
2. Run: `mongosh "<connection string>" securebank-mongodb.js`
3. Screenshot the output of Q1–Q6 into `screenshots/`.

Q6 (transactions) needs Atlas or a replica set. On a plain local install it prints
"ROLLED BACK: Transaction numbers are only allowed on a replica set member" – that is expected.

## Data model

```json
// customers collection – accounts EMBEDDED
{ "_id": "CUST-0003", "firstName": "Fatima", "email": "fatima@example.com",
  "accounts": [ { "accountNumber": "1000000003", "type": "SAVINGS", "balance": 200000.00 },
                { "accountNumber": "1000000004", "type": "CURRENT", "balance": 15000.00 } ] }

// transactions collection – REFERENCES the account
{ "accountNumber": "1000000001", "type": "DEPOSIT", "amount": 20000.00,
  "status": "SUCCESS", "createdAt": "2026-10-01T09:00:00Z" }
```

| Relational (Portfolio 1)                     | MongoDB (Portfolio 4)                             | Why                                                                 |
| -------------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------- |
| `Customers` + `Accounts` tables joined by FK | One `customers` document with an `accounts` array | Few accounts per customer, always read together → one read, no JOIN |
| `Transactions` table                         | `transactions` collection                         | Grows without limit; embedding would hit the 16 MB document limit   |
| CHECK constraints                            | `$jsonSchema` validator                           | Rejects negative balances / invalid types (Q5 proves it)            |
| Indexes (Portfolio 2)                        | `createIndex`                                     | Same idea; Q4 shows `IXSCAN` instead of `COLLSCAN`                  |
| `BEGIN TRAN … COMMIT`                        | `session.withTransaction()`                       | Transfer updates two documents and inserts two, all-or-nothing      |

## Results (run on MongoDB Atlas, M0 free cluster)

| Query | Actual result                                                                      | What it proves                                                  |
| ----- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| Q1    | Fatima's document returned with both accounts (1000000003, 1000000004)             | Embedding removes the Customers–Accounts JOIN                   |
| Q2    | 2 transactions for 1000000001, newest first (5 Oct withdrawal, then 1 Oct deposit) | Account history query works                                     |
| Q3    | DEPOSIT: 1 × 20,000.00; WITHDRAWAL: 1 × 5,000.00                                   | Aggregation pipeline = SQL `GROUP BY`                           |
| Q4    | Winning plan `FETCH` → `IXSCAN` on `accountNumber_1_createdAt_-1`                  | Compound index used, no `COLLSCAN`                              |
| Q5    | `Document failed validation`                                                       | `$jsonSchema` blocks a negative balance like a CHECK constraint |
| Q6    | `MDB-TRF-001 COMMITTED`; `MDB-TRF-002 ROLLED BACK: Insufficient funds`             | Multi-document transaction is atomic                            |

Screenshots (`screenshots/`):

- `01`–`05`: mongosh output for Q1–Q6, including the final balances
- `06`: Atlas Data Explorer showing the `customers` collection (3 documents, 3 indexes)
- `07`: Atlas Data Explorer showing the `transactions` collection (6 documents: 4 sample + 2 from transfer MDB-TRF-001)

Balances after Q6: Amina 100,000 → **90,000**, Fatima (1000000003) 200,000 → **210,000**,
Tunde unchanged at **50,000** (the failed transfer changed nothing).

## Suitability – where MongoDB fits SecureBank, and where it does not

**Good fit:**

- Customer profile + accounts screen in the mobile app (one fast read).
- Transaction history: very high insert volume, simple queries by account and date, easy to shard by `accountNumber` (see Portfolio 5).
- Flexible structure: new account products (e.g. a "fixed deposit" with a maturity date) can add fields without altering a table.

**Weaker fit:**

- Moving money between customers needs multi-document transactions, which are slower and need a replica set. The relational database does this naturally.
- Reports that join many entities (e.g. audits across customers, transfers and logs) are easier in SQL.

**Conclusion:** keep the core ledger (balances and transfers) in SQL Server for strong consistency;
MongoDB suits read-heavy customer views and the high-volume transaction history.
