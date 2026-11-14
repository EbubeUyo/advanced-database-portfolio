# Portfolio 2 – Query Processing and Optimisation (SecureBankDB)

## Goal
Show how SQL Server executes four everyday SecureBank queries, find the slow parts
in the execution plans, add targeted indexes, and measure the improvement.

## How I ran in this order

| Step | Script | What it does |
|------|--------|--------------|
| 1 | `sql-queries/01-generate-test-data.sql` | Adds 20,000 customers, 30,000 accounts, ~502,000 transactions so the plans are realistic |
| 2 | `sql-queries/02-baseline-queries.sql` | Runs Q1–Q4 **before** indexing, with `STATISTICS IO/TIME` and the actual execution plan |
| 3 | `sql-queries/03-create-indexes.sql` | Creates three targeted indexes |
| 4 | `sql-queries/04-optimised-queries.sql` | Runs the **same** Q1–Q4 again after indexing |

Evidence is saved in `execution-plans-results/before`, `execution-plans-results/after` (screenshots)


## The four queries

| Query | Business purpose |
|-------|------------------|
| Q1 | Last 50 transactions of one account (mobile-app statement screen) |
| Q2 | Failed transactions in the last 30 days (fraud / support team) |
| Q3 | All accounts of a customer, found by email (customer login) |
| Q4 | Totals by transaction type for one account over the last year (monthly report) |

## Indexes added and why

| Index | Supports | Reason |
|-------|----------|--------|
| `IX_P2_Transactions_AccountDate (AccountId, CreatedAt DESC, TransactionId DESC) INCLUDE (...)` | Q1, Q4 | Turns a full table scan into a seek on one account; rows are already in newest-first order so the Sort disappears; INCLUDE makes it covering (no Key Lookup) |
| `IX_P2_Transactions_StatusDate ... WHERE TransactionStatus = 'FAILED'` | Q2 | Filtered index holding only ~2% of rows, ordered by date |
| `IX_P2_Accounts_CustomerId (CustomerId) INCLUDE (...)` | Q3 | SQL Server does not index foreign keys automatically; this lets the join seek |




