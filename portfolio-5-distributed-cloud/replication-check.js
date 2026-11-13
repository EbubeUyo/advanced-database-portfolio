/*
 
  An Atlas free cluster is a 3-node REPLICA SET spread across machines:
  1 PRIMARY (takes writes) + 2 SECONDARIES (copies of the data).
*/
db = db.getSiblingDB('securebank');

print('\n1. Cluster topology - replica set name, all nodes, current primary');
const h = db.hello();
printjson({ setName: h.setName, hosts: h.hosts, primary: h.primary, me: h.me });

print('\n2. Write with writeConcern "majority"');
print('   (only acknowledged after at least 2 of 3 nodes have the data, so it');
print('    survives the primary failing straight after the write)');
const t0 = Date.now();
db.transactions.insertOne(
  { accountNumber: '1000000001', type: 'DEPOSIT', amount: NumberDecimal('1000.00'),
    status: 'SUCCESS', createdAt: new Date(), note: 'P5 majority write' },
  { writeConcern: { w: 'majority', wtimeout: 5000 } });
print('   majority write took ' + (Date.now() - t0) + ' ms');

const t1 = Date.now();
db.transactions.insertOne(
  { accountNumber: '1000000001', type: 'DEPOSIT', amount: NumberDecimal('1000.00'),
    status: 'SUCCESS', createdAt: new Date(), note: 'P5 w:1 write' },
  { writeConcern: { w: 1 } });
print('   w:1 write took      ' + (Date.now() - t1) + ' ms  (faster, but could be lost on failover)');

print('\n3. Read from PRIMARY vs SECONDARY');
const fromPrimary = db.transactions.find({ note: /P5/ }).readPref('primary').toArray().length;
const fromSecondary = db.transactions.find({ note: /P5/ }).readPref('secondary').toArray().length;
print('   primary sees   ' + fromPrimary + ' P5 rows (always up to date)');
print('   secondary sees ' + fromSecondary + ' P5 rows (may briefly lag = eventual consistency)');

print('\n4. Read concern "majority" - only returns data that cannot be rolled back');
printjson(db.runCommand({ find: 'transactions', filter: { note: /P5/ },
                          readConcern: { level: 'majority' } }).cursor.firstBatch.length);
