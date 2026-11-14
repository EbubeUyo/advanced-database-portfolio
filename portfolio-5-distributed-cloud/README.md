# Portfolio 5 – Distributed and Cloud Database Exercise (SecureBank)

## Goal
Show how SecureBank's data can be spread across several machines in the cloud,
and explain replication, sharding, availability and consistency for a bank.

## Practical part – cloud deployment (MongoDB Atlas)
The Portfolio 4 database runs on a free MongoDB Atlas cluster, which is a
**3-node replica set** hosted in the cloud.

1. Run `mongosh "<Atlas connection string>" replication-check.js`
2. Screenshot:
   - the output (topology, write timings, primary vs secondary reads);
   - the Atlas **Overview** page showing the 3 nodes (1 Primary, 2 Secondaries) and the cloud region.

| Evidence | What it proves |
|----------|----------------|
| `hello()` lists 3 hosts and one primary | Data is replicated on 3 servers |
| `w: majority` slower than `w: 1` | Stronger durability costs latency |
| Secondary may show fewer rows briefly | Replication is asynchronous → eventual consistency on secondaries |
| `readConcern: majority` | Reads only data that cannot be rolled back after a failover |

### Actual results (`screenshots/replication-check-output.png`, `screenshots/atlas-cluster-overview.png`)

| Check | Result |
|-------|--------|
| Deployment | MongoDB Atlas free tier (M0), MongoDB 8.0.37, **AWS Paris (eu-west-3)** |
| Replica set | `atlas-ia8bc8-shard-0` with 3 hosts (`ac-8xy2vyb-shard-00-00/01/02`) |
| Primary | `ac-8xy2vyb-shard-00-01` (the other two are secondaries) |
| Write timing | `w: majority` **137 ms** vs `w: 1` **115 ms**, so majority was about 22 ms (≈19%) slower |
| Primary vs secondary read | Both saw 2 P5 rows, so the secondary had already caught up |
| `readConcern: majority` | Returned 2 rows, so both writes were majority-committed |

Interpretation: the extra ~22 ms is the time the primary waits for a secondary to confirm the write.
The gap is small because all three nodes are in the same cloud region. Across regions it would be larger.
The secondary showed no lag in this run because the load was tiny and replication finished before the
read. Under heavy load, a secondary read could briefly return fewer rows (eventual consistency).

Optional: in Atlas, *Database → … → Test Resilience* (paid tiers) triggers a primary failover.
On the free tier, explain it instead: if the primary fails, the two secondaries elect a new
primary within seconds and the application reconnects automatically.

## Discussion

### 1. Replication (availability)
- Copies of the data are kept on several nodes. If one fails, another takes over, so customers can still use the app.
- **Primary–secondary** (MongoDB replica set; SQL Server Always On Availability Groups): all writes go to the primary.
- **Synchronous** replication (SQL Server synchronous commit, MongoDB `w: majority`): no data loss on failover, slightly slower writes. **Used for balances and transfers.**
- **Asynchronous** replication: faster, but the last few writes can be lost. Acceptable for read-only reporting copies.

### 2. Sharding (scalability)
- Splits a large collection across servers, each holding part of the data.
- Proposed shard key for `transactions`: `{ accountNumber: "hashed" }`.
  - Spreads writes evenly across shards (hashing avoids one "hot" shard).
  - "Account history" queries go to one shard only, because they always include `accountNumber`.
  - Bad alternative: `createdAt`. All new transactions would hit the same shard.
- `customers` is small and does not need sharding.
- Trade-off: a transfer between accounts on different shards becomes a **distributed transaction** (two-phase commit), which is slower. This is another reason to keep the core ledger in SQL Server.

### 3. Consistency vs availability (CAP theorem)
During a network partition, a distributed system must choose **Consistency** or **Availability**.

| SecureBank data | Choice | Reason |
|-----------------|--------|--------|
| Balances, transfers | **CP** – consistency first | Showing a wrong balance could allow double-spending; better to briefly reject a transfer |
| Transaction history, statements | **AP** – availability first | A statement a few seconds out of date is acceptable |
| Notifications, analytics | **AP** | Eventual consistency is fine |

### 4. Proposed cloud architecture
```
Mobile / Web app
      │
  API service ──────────────► Azure SQL Database (core ledger)
      │                         - primary + zone-redundant replicas (synchronous)
      │                         - read-only replica for reports
      │                         - automated backups / point-in-time restore
      │
      └─────────────────────► MongoDB Atlas (customer views + transaction history)
                                - 3-node replica set (w: majority)
                                - sharded on hashed accountNumber when volume grows
```
Security: encryption in transit (TLS) and at rest, IP allow-list, least-privilege database users.
