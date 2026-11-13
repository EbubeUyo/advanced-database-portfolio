
db = db.getSiblingDB('securebank');
db.customers.drop();
db.transactions.drop();

/* ---------- 1. Collections with validation rules (like CHECK constraints) ---------- */
db.createCollection('customers', {
  validator: { $jsonSchema: {
    bsonType: 'object',
    required: ['email', 'firstName', 'lastName', 'accounts'],
    properties: {
      email:    { bsonType: 'string' },
      accounts: { bsonType: 'array', items: {
        bsonType: 'object',
        required: ['accountNumber', 'type', 'balance'],
        properties: {
          type:    { enum: ['SAVINGS', 'CURRENT'] },
          balance: { bsonType: 'decimal', minimum: NumberDecimal('0') }   // no overdraft
        }
      }}
    }
  }}
});

db.createCollection('transactions', {
  validator: { $jsonSchema: {
    bsonType: 'object',
    required: ['accountNumber', 'type', 'amount', 'status', 'createdAt'],
    properties: {
      type:   { enum: ['DEPOSIT', 'WITHDRAWAL', 'TRANSFER_DEBIT', 'TRANSFER_CREDIT'] },
      amount: { bsonType: 'decimal', exclusiveMinimum: true, minimum: NumberDecimal('0') },
      status: { enum: ['PENDING', 'SUCCESS', 'FAILED'] }
    }
  }}
});

/* ---------- 2. Indexes (same ideas as Portfolio 2) ---------- */
db.customers.createIndex({ email: 1 }, { unique: true });
db.customers.createIndex({ 'accounts.accountNumber': 1 }, { unique: true });
db.transactions.createIndex({ accountNumber: 1, createdAt: -1 });   // account history, newest first

/* ---------- 3. Sample data (same customers as Portfolio 1) ---------- */
db.customers.insertMany([
  { _id: 'CUST-0001', firstName: 'Amina',  lastName: 'Yusuf', email: 'amina@example.com',  phone: '08012345678',
    accounts: [ { accountNumber: '1000000001', type: 'SAVINGS', balance: NumberDecimal('100000.00') } ] },
  { _id: 'CUST-0002', firstName: 'Tunde',  lastName: 'Ade',   email: 'tunde@example.com',  phone: '08023456789',
    accounts: [ { accountNumber: '1000000002', type: 'CURRENT', balance: NumberDecimal('50000.00') } ] },
  { _id: 'CUST-0003', firstName: 'Fatima', lastName: 'Bello', email: 'fatima@example.com', phone: '08034567890',
    accounts: [ { accountNumber: '1000000003', type: 'SAVINGS', balance: NumberDecimal('200000.00') },
                { accountNumber: '1000000004', type: 'CURRENT', balance: NumberDecimal('15000.00') } ] }
]);

db.transactions.insertMany([
  { accountNumber: '1000000001', customerId: 'CUST-0001', type: 'DEPOSIT',    amount: NumberDecimal('20000.00'), status: 'SUCCESS', createdAt: new Date('2026-10-01T09:00:00Z') },
  { accountNumber: '1000000001', customerId: 'CUST-0001', type: 'WITHDRAWAL', amount: NumberDecimal('5000.00'),  status: 'SUCCESS', createdAt: new Date('2026-10-05T12:30:00Z') },
  { accountNumber: '1000000002', customerId: 'CUST-0002', type: 'WITHDRAWAL', amount: NumberDecimal('90000.00'), status: 'FAILED',  createdAt: new Date('2026-10-06T15:10:00Z') },
  { accountNumber: '1000000003', customerId: 'CUST-0003', type: 'DEPOSIT',    amount: NumberDecimal('75000.00'), status: 'SUCCESS', createdAt: new Date('2026-10-07T08:45:00Z') }
]);

/* ---------- 4. Queries (screenshot the output) ---------- */
print('\nQ1: Customer login - customer AND all accounts in ONE read (no JOIN)');
printjson(db.customers.findOne({ email: 'fatima@example.com' }));

print('\nQ2: Last 5 transactions for account 1000000001 (uses the compound index)');
printjson(db.transactions.find({ accountNumber: '1000000001' }).sort({ createdAt: -1 }).limit(5).toArray());

print('\nQ3: Totals by type for one account (like SQL GROUP BY)');
printjson(db.transactions.aggregate([
  { $match: { accountNumber: '1000000001', status: 'SUCCESS' } },
  { $group: { _id: '$type', count: { $sum: 1 }, total: { $sum: '$amount' } } },
  { $sort:  { _id: 1 } }
]).toArray());

print('\nQ4: Proof the index is used (look for IXSCAN, not COLLSCAN)');
printjson(db.transactions.find({ accountNumber: '1000000001' }).sort({ createdAt: -1 })
  .explain('executionStats').queryPlanner.winningPlan);

print('\nQ5: Validation rule rejects a negative balance');
try {
  db.customers.insertOne({ firstName: 'Bad', lastName: 'Data', email: 'bad@example.com',
    accounts: [ { accountNumber: '9999999999', type: 'SAVINGS', balance: NumberDecimal('-10') } ] });
} catch (e) { print('Rejected as expected: ' + e.message); }

/* ---------- 5. Transfer as a multi-document ACID transaction (Atlas / replica set) ---------- */
function transfer(from, to, amount, ref) {
  const session = db.getMongo().startSession();
  const s = session.getDatabase('securebank');
  const amt = NumberDecimal(amount);
  try {
    session.withTransaction(() => {
      // Debit only if the balance is enough (condition inside the filter = no race condition)
      const debit = s.customers.updateOne(
        { accounts: { $elemMatch: { accountNumber: from, balance: { $gte: amt } } } },
        { $inc: { 'accounts.$.balance': NumberDecimal('-' + amount) } });
      if (debit.modifiedCount !== 1) throw new Error('Insufficient funds or unknown account');

      const credit = s.customers.updateOne(
        { 'accounts.accountNumber': to },
        { $inc: { 'accounts.$.balance': amt } });
      if (credit.modifiedCount !== 1) throw new Error('Destination account not found');

      s.transactions.insertMany([
        { accountNumber: from, type: 'TRANSFER_DEBIT',  amount: amt, status: 'SUCCESS', transferRef: ref, createdAt: new Date() },
        { accountNumber: to,   type: 'TRANSFER_CREDIT', amount: amt, status: 'SUCCESS', transferRef: ref, createdAt: new Date() }
      ]);
    });
    print('Transfer ' + ref + ' COMMITTED');
  } catch (e) {
    print('Transfer ' + ref + ' ROLLED BACK: ' + e.message);   // nothing was saved
  } finally {
    session.endSession();
  }
}

print('\nQ6: Transactions (needs Atlas or a replica set)');
transfer('1000000001', '1000000003', '10000.00', 'MDB-TRF-001');   // succeeds
transfer('1000000002', '1000000003', '999999.00', 'MDB-TRF-002');  // fails -> rollback
printjson(db.customers.find({}, { _id: 0, firstName: 1, 'accounts.accountNumber': 1, 'accounts.balance': 1 }).toArray());
