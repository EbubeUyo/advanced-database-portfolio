# MIT 8103 Advanced Database Systems – Portfolio Documentation

**Student:** Ajodo Agnes Uyo
**StudentID: ** 301885216
**GitHub repository:** https://github.com/EbubeUyo/advanced-database-portfolio.git
**Tools:** Microsoft SQL Server, [SSMS / VS Code mssql extension], MongoDB Atlas, mongosh, drawSQL

## 1. Selected case study – SecureBank
SecureBank is a simulated Nigerian retail bank / fintech platform. **Users:** Customers (mobile app),
tellers and support staff, the fraud/audit team and administrators. **Data stored:** Customers, savings and
current accounts, transfers, account transactions and audit logs. **Key operations:** Open accounts,
deposit, withdraw, transfer funds, reject transfers with insufficient funds, view transaction history and
audit activity. The same case study is used in all five portfolios.

## 2. Portfolio 1 – Database design and modelling
Five tables: Customers, Accounts, Transfers, Transactions and AuditLogs (Diagram: `portfolio-1-database-design/diagrams/schema.jpeg`).
A customer has many accounts; an account has many transactions; a transfer links a source and a destination
account and produces one debit and one credit transaction. Integrity is enforced in the database itself:
surrogate primary keys, UNIQUE email/account number/transfer reference, foreign keys, and CHECK constraints
(no negative balance, amount > 0, no transfer to the same account, valid status codes). Money uses DECIMAL(18,2).
The schema is in 3NF; `Balance` is deliberately stored (derived data) for fast reads and kept correct by
updating it inside the same transaction as the ledger rows.

## 3. Portfolio 2 – Query processing and optimization

This activity focused on improving SQL Server query performance using indexing and execution-plan analysis. Test transactions were generated to evaluate four business queries covering account history, failed transactions, customer account lookup and yearly transaction summaries.
Performance was analysed using `STATISTICS IO`, `STATISTICS TIME` and actual execution plans. Three targeted indexes were introduced: a composite index on `(AccountId, CreatedAt DESC)`, a filtered index for failed transactions and an index on `Accounts.CustomerId`.
The execution plans showed improved data access through index seeks instead of scans for the targeted queries. The exercise demonstrated that appropriate indexing improves query efficiency, although excessive indexing can increase storage requirements and slow data modifications.

## 4. Portfolio 3 – Transactions and concurrency
The transfer logic was turned into the stored procedure `usp_TransferFunds`. It uses `XACT_ABORT` and TRY/CATCH so that
the debit, credit and ledger rows commit or roll back together. Demos show: a successful **commit**; a **rollback**
on insufficient funds, with balances unchanged and the failure still written to AuditLogs; a **dirty read** under
READ UNCOMMITTED compared with blocking under READ COMMITTED; a **deadlock** (error 1205) caused by locking two
accounts in opposite order; and the **fix**: UPDLOCK with a consistent lock order (smaller AccountId first),
which turns the deadlock into a short wait.

## 5. Portfolio 4 – NoSQL (MongoDB document model)
Accounts are embedded in customer documents (few per customer and read together, so no join is needed).
Transactions are a separate referenced collection because they grow without limit. `$jsonSchema` validators
act like CHECK constraints, and indexes are confirmed with `explain()` (IXSCAN). Transfers use a multi-document
transaction. Results on Atlas: Q4 used `IXSCAN` on `accountNumber_1_createdAt_-1`; a negative balance was rejected
("Document failed validation"); transfer MDB-TRF-001 committed (Amina 100,000 → 90,000, Fatima 200,000 → 210,000)
and MDB-TRF-002 rolled back for insufficient funds, leaving Tunde's 50,000 unchanged. Conclusion: MongoDB suits customer views and high-volume history, while the core ledger stays relational.

## 6. Portfolio 5 – Distributed and cloud database
The MongoDB database was deployed on a MongoDB Atlas 3-node replica set (`atlas-ia8bc8-shard-0`, MongoDB 8.0.37, free tier, region: AWS Paris eu-west-3).
`hello()` listed 3 hosts with `shard-00-01` as primary. A `w: majority` write took 137ms against 115ms for `w: 1`,
which is the cost of waiting for a secondary to confirm. Both primary and secondary returned 2 rows, so the secondary
had caught up in this small test, but under load secondary reads can lag (eventual consistency).
Discussion: synchronous replication for balances, a hashed `accountNumber` shard key for transactions, and CAP
choices (CP for balances and transfers, AP for statements and notifications). A cloud architecture is proposed
using Azure SQL for the ledger and Atlas for history.

## 7. Individual technical reflection
One design decision I am most confident about is enforcing data integrity at the database level through primary keys, foreign keys, UNIQUE constraints and CHECK constraints. This ensures that important business rules are maintained regardless of the application accessing the database. I also chose to store account balances while updating them within the same transaction as the corresponding ledger entries. This provides faster access to balances while helping maintain consistency.
During implementation, I encountered issues with the initial test-data scripts, including hard-coded CustomerId values that did not always correspond to the generated records. I addressed this by reviewing the insertion order and ensuring that the correct identifiers were used. Another important learning experience was implementing database transactions and observing how concurrent operations can lead to deadlocks. Applying a consistent account-locking order helped address this issue.
The most interesting part of the project was seeing how database indexes affected query execution and how MongoDB's document model differed from SQL Server's relational structure. I also gained a better understanding of replication and consistency involved in distributed databases. 

## 8. AI use declaration
- **Tool:** Claude (Anthropic)  and ChatGPT (OpenAI).
- **Used for:** Reviewing SQL scripts, troubleshooting implementation issues, refining technical explanations and organizing portfolio documentation.
- **How I verified it:**  I ran every script on my own SQL Server and Atlas cluster, fixed errors, checked the plans and numbers myself, and rewrote explanations in my own words.

## 9. References
- Microsoft (2026) *SQL Server documentation: Transaction locking and row versioning guide; Index design guide*. learn.microsoft.com
- MongoDB Inc. (2026) *MongoDB Manual: Data modeling, Transactions, Replication, Sharding*. mongodb.com/docs
- Elmasri, R. and Navathe, S. (2016) *Fundamentals of Database Systems*. 7th edn. Pearson.
