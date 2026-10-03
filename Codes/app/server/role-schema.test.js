import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { migrateAccounts } from './account-schema.js';
import { migrateRoles } from './role-schema.js';
import { checkDatabase } from './database-checks.js';

function legacyDatabase() {
  const db = new DatabaseSync(':memory:');
  db.exec(`PRAGMA foreign_keys=ON;
    CREATE TABLE users (id INTEGER PRIMARY KEY, patient_id TEXT UNIQUE NOT NULL,
      username TEXT, email TEXT, phone TEXT, birth_date TEXT, verified INTEGER,
      created_at TEXT, last_login_at TEXT);
    INSERT INTO users(id,patient_id,phone,verified) VALUES(1,'p1','01012345678',1),(2,'p2','01112345678',1);
    CREATE TABLE user_data(user_id INTEGER PRIMARY KEY REFERENCES users(id));
    CREATE TABLE devices(id INTEGER PRIMARY KEY);
    CREATE TABLE otps(email TEXT);
    CREATE TABLE reset_tokens(email TEXT);
  `);
  migrateAccounts(db);
  return db;
}

test('role migration backfills patients and caregivers, and is safe to run again', () => {
  const db = legacyDatabase();
  try {
    db.exec("UPDATE users SET role='caregiver', linked_patient_id='p1' WHERE id=2");
    const before = db.prepare('SELECT * FROM users ORDER BY id').all();
    migrateRoles(db);
    migrateRoles(db);
    assert.deepEqual(db.prepare('SELECT * FROM users ORDER BY id').all(), before);
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM schema_migrations').get().n, 1);
    assert.equal(db.prepare('SELECT * FROM patients').get().patient_id, 'p1');
    assert.equal(db.prepare('SELECT * FROM caregivers').get().patient_id, 'p1');
    assert.equal(db.prepare('SELECT caregiver_count FROM patient_records').get().caregiver_count, 1);
    assert.deepEqual(checkDatabase(db), { ok: true, counts: { accounts: 2, patients: 1, caregivers: 1 }, errors: [], warnings: [] });
  } finally { db.close(); }
});

test('SQL constraints block invalid role records, broken links and partial deletion', () => {
  const db = legacyDatabase();
  try {
    migrateRoles(db);
    db.prepare(`INSERT INTO users(id,patient_id,phone,phone_key,verified,role,linked_patient_id)
      VALUES(3,'c3','01212345678','201212345678',0,'caregiver','p1')`).run();
    assert.equal(db.prepare('SELECT patient_id FROM caregivers WHERE user_id=3').get().patient_id, 'p1');
    assert.throws(() => db.exec("INSERT INTO patients VALUES(3,'c3')"), /BAD_PATIENT_ACCOUNT/);
    assert.throws(() => db.exec("INSERT INTO caregivers VALUES(2,'p2','p1')"), /BAD_CAREGIVER_ACCOUNT/);
    assert.throws(() => db.exec("UPDATE caregivers SET patient_id='missing' WHERE user_id=3"), /BAD_CAREGIVER_ACCOUNT/);
    assert.throws(() => db.exec("UPDATE users SET linked_patient_id='missing' WHERE id=3"), /BAD_PATIENT_ID/);
    assert.throws(() => db.exec('UPDATE users SET verified=0 WHERE id=1'), /PATIENT_HAS_CAREGIVERS/);
    assert.throws(() => db.exec("UPDATE users SET patient_id='new' WHERE id=1"), /ACCOUNT_ID_IMMUTABLE/);
    assert.throws(() => db.exec('DELETE FROM patients WHERE user_id=2'), /DELETE_ACCOUNT_INSTEAD/);
    assert.throws(() => db.exec('DELETE FROM caregivers WHERE user_id=3'), /DELETE_ACCOUNT_INSTEAD/);
    assert.throws(() => db.exec('DELETE FROM users WHERE id=1'), /FOREIGN KEY/);
    db.exec("UPDATE users SET linked_patient_id='p2' WHERE id=3");
    assert.equal(db.prepare('SELECT patient_id FROM caregivers WHERE user_id=3').get().patient_id, 'p2');
    db.exec("UPDATE users SET role='patient', linked_patient_id=NULL WHERE id=3");
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM caregivers').get().n, 0);
    assert.equal(db.prepare('SELECT patient_id FROM patients WHERE user_id=3').get().patient_id, 'c3');
    db.exec('DELETE FROM users WHERE id=3');
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM patients').get().n, 2);
    assert.equal(checkDatabase(db).ok, true);
  } finally { db.close(); }
});

test('database checker detects legacy duplicate phones and inconsistent SQL writes', () => {
  const db = legacyDatabase();
  try {
    migrateRoles(db);
    db.exec("UPDATE users SET phone='01012345678' WHERE id=2");
    assert.equal(checkDatabase(db).ok, false);
    db.exec('DROP TRIGGER users_phone_update');
    db.exec("UPDATE users SET phone_key='201012345678' WHERE id=2");
    const result = checkDatabase(db);
    assert.equal(result.ok, true);
    assert.match(result.warnings[0], /shared phone/);
  } finally { db.close(); }
});

test('invalid legacy links roll back the role migration without changing accounts', () => {
  const db = legacyDatabase();
  try {
    db.exec('DROP TRIGGER users_role_update');
    db.exec("UPDATE users SET role='caregiver', linked_patient_id='p2' WHERE id=2");
    const before = db.prepare('SELECT * FROM users ORDER BY id').all();
    assert.throws(() => migrateRoles(db), /invalid patient links/);
    assert.deepEqual(db.prepare('SELECT * FROM users ORDER BY id').all(), before);
    assert.equal(db.prepare("SELECT 1 FROM sqlite_master WHERE name='patients'").get(), undefined);
    assert.equal(checkDatabase(db).ok, false);
  } finally { db.close(); }
});
