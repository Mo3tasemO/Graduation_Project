import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { setTimeout as delay } from 'node:timers/promises';
import { migrateAccounts } from './account-schema.js';
import { migrateRoles } from './role-schema.js';
import { cleanupExpiredPendingAccounts, startPendingAccountCleanup, PENDING_ACCOUNT_TTL_MS } from './pending-accounts.js';

const sqlDate = (ms) => new Date(ms).toISOString().slice(0, 19).replace('T', ' ');
function fixture() {
  const db = new DatabaseSync(':memory:');
  db.exec(`PRAGMA foreign_keys=ON;
    CREATE TABLE users(id INTEGER PRIMARY KEY, patient_id TEXT UNIQUE NOT NULL, email TEXT UNIQUE,
      username TEXT, phone TEXT, birth_date TEXT, verified INTEGER, created_at TEXT, last_login_at TEXT);
    CREATE TABLE user_data(user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE);
    CREATE TABLE devices(user_id INTEGER REFERENCES users(id) ON DELETE CASCADE);
    CREATE TABLE otps(email TEXT, purpose TEXT, expires INTEGER);
    CREATE TABLE reset_tokens(email TEXT);
  `);
  migrateAccounts(db);
  migrateRoles(db);
  const add = (id, verified, createdAt, role = 'patient', linked = null) => {
    db.prepare(`INSERT INTO users(id,patient_id,email,phone,phone_key,verified,created_at,role,linked_patient_id)
      VALUES(?,?,?,?,?,?,?,?,?)`).run(id, `p${id}`, `user${id}@gmail.com`, `0101234567${id}`, `20101234567${id}`, verified, sqlDate(createdAt), role, linked);
  };
  return { db, add };
}

test('10-minute boundary deletes only expired pending patients and caregivers with their related data', () => {
  const { db, add } = fixture();
  const now = Date.parse('2026-10-02T12:00:00Z');
  try {
    add(1, 1, now - 86400000);
    add(2, 0, now - PENDING_ACCOUNT_TTL_MS); // exactly ten minutes
    add(3, 0, now - PENDING_ACCOUNT_TTL_MS - 1000, 'caregiver', 'p1');
    add(4, 0, now - PENDING_ACCOUNT_TTL_MS + 1000); // not yet expired
    add(5, 1, now - 86400000, 'caregiver', 'p1');
    for (const id of [1, 2, 3, 4, 5]) {
      db.prepare('INSERT INTO user_data VALUES(?)').run(id);
      db.prepare('INSERT INTO devices VALUES(?)').run(id);
      // A newly resent code must not extend the account lifetime.
      db.prepare('INSERT INTO otps VALUES(?,?,?)').run(`user${id}@gmail.com`, 'register', now + PENDING_ACCOUNT_TTL_MS);
      db.prepare('INSERT INTO reset_tokens VALUES(?)').run(`user${id}@gmail.com`);
    }
    assert.equal(cleanupExpiredPendingAccounts(db, now), 2);
    assert.deepEqual(db.prepare('SELECT id FROM users ORDER BY id').all().map((r) => r.id), [1, 4, 5]);
    for (const table of ['user_data', 'devices', 'otps', 'reset_tokens']) assert.equal(db.prepare(`SELECT COUNT(*) AS n FROM ${table}`).get().n, 3);
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM patients').get().n, 2);
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM caregivers').get().n, 1);
    assert.equal(db.prepare('PRAGMA foreign_key_check').all().length, 0);
    assert.equal(cleanupExpiredPendingAccounts(db, now), 0);
    add(2, 0, now); // released email and phone can register again
    assert.equal(db.prepare('SELECT id FROM users WHERE id=2').get().id, 2);
  } finally { db.close(); }
});

test('cleanup is atomic when a database error prevents account deletion', () => {
  const { db, add } = fixture();
  try {
    add(1, 0, Date.now() - PENDING_ACCOUNT_TTL_MS - 1000);
    db.exec(`INSERT INTO otps VALUES('user1@gmail.com','register',0); INSERT INTO reset_tokens VALUES('user1@gmail.com');
      CREATE TRIGGER block_delete BEFORE DELETE ON users BEGIN SELECT RAISE(ABORT,'test failure'); END;`);
    assert.throws(() => cleanupExpiredPendingAccounts(db), /test failure/);
    for (const table of ['users', 'otps', 'reset_tokens']) assert.equal(db.prepare(`SELECT COUNT(*) AS n FROM ${table}`).get().n, 1);
  } finally { db.close(); }
});

test('cleanup runs immediately on startup and in the background without requests', async () => {
  const { db, add } = fixture();
  let stop;
  try {
    add(1, 0, Date.now() - PENDING_ACCOUNT_TTL_MS - 1000);
    stop = startPendingAccountCleanup(db, { intervalMs: 20 });
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM users').get().n, 0);
    add(2, 0, Date.now() - PENDING_ACCOUNT_TTL_MS - 1000);
    const deadline = Date.now() + 2000;
    while (db.prepare('SELECT COUNT(*) AS n FROM users').get().n && Date.now() < deadline) await delay(20);
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM users').get().n, 0);
  } finally { stop?.(); db.close(); }
});
