# Portfolio 3 – Transactions and Concurrency (SecureBankDB)

## Goal
A bank transfer must never be half-done (money leaves one account but never arrives),
and two people using the same account at the same time must not corrupt balances.
This portfolio shows how SQL Server transactions and locks guarantee that.

## How I ran

| Step | Script(s) | What it shows | Expected evidence |
|------|-----------|---------------|-------------------|
| 1 | `01-transfer-procedure.sql` | Creates `dbo.usp_TransferFunds` (the Portfolio 1 transfer script turned into a procedure) | "Commands completed successfully" |
| 2 | `02-commit-demo.sql` | **COMMIT** – a valid transfer saves all 4 changes together | Balances before/after; 1 transfer + 2 transaction rows |
| 3 | `03-rollback-demo.sql` | **ROLLBACK** – insufficient funds undoes everything | Error 50003; balances unchanged; 0 transfers; 1 audit row |
| 4 | `04a` + `04b` (two windows) | **Isolation levels** – dirty read vs READ COMMITTED | B's first read shows +1,000,000 (dirty); second read waits ~20 s and shows the real balance |
| 5 | `05a` + `05b` (two windows) | **Concurrency problem** – deadlock | Msg 1205 "chosen as the deadlock victim" |
| 6 | `06a` + `06b` (two windows) | **Control mechanism** – lock ordering prevents the deadlock | B waits, then succeeds; no 1205 |

For steps 4–6 open two query windows, start the "A" script, then run the "B" script within a few seconds.
Transfer references must be unique – change `P3-LOCKORDER-A/B` if you run step 6 again.

## Key concepts used

| Concept | Where | Explanation |
|---------|-------|-------------|
| Atomicity | Procedure, `BEGIN TRANSACTION … COMMIT` | Debit, credit and records succeed or fail as one unit |
| `SET XACT_ABORT ON` + `TRY/CATCH` | Procedure | Any error rolls back the whole transaction automatically |
| Audit after rollback | Procedure `CATCH` block | Failed attempts are still recorded because the insert happens after the rollback |
| Dirty read | Step 4 | `READ UNCOMMITTED` can see changes that are later rolled back – unacceptable for balances |
| READ COMMITTED (default) | Step 4 | Readers wait for writers to finish, so only committed data is seen |
| Deadlock | Step 5 | Two transactions lock the same rows in opposite order and wait for each other |
| `UPDLOCK` + consistent lock order | Procedure, Step 6 | Every transfer locks the smaller AccountId first, so the circular wait cannot form |

## Results 
- Step 2: Amina's balance went from 70000 to 60000; Fatima's from 230000 to 240000.
- Step 4: Dirty read returned 1060000; committed read returned 60000 after waiting 0.00010 seconds.
- Step 5: Window B was chosen as deadlock victim.
- Step 6: B started at 16:46:11.8641953, finished at 16:46:11.8641956 (it waited for A), no error.

Screenshots: `screenshots/` folder.
