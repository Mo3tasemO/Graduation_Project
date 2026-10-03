import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';
import { migrateAccounts } from './account-schema.js';
import { migrateRoles, needsRoleMigration } from './role-schema.js';

export const DATA_DIR = path.resolve(process.env.MINDSPEAK_DATA_DIR || path.join(import.meta.dirname, 'data'));
fs.mkdirSync(DATA_DIR, { recursive: true });

/** Local SQL storage, served to the app through the Express API. */
export const DATABASE_PATH = path.join(DATA_DIR, 'mindspeak.db');
export const db = new DatabaseSync(DATABASE_PATH, { timeout: 5000 });

// VACUUM INTO takes a consistent snapshot, including data in the WAL file.
if (needsRoleMigration(db) && db.prepare("SELECT 1 FROM sqlite_master WHERE type='table' AND name='users'").get()) {
  const backups = path.join(DATA_DIR, 'backups');
  fs.mkdirSync(backups, { recursive: true });
  const backup = path.join(backups, `before-patient-caregiver-${Date.now()}.db`);
  db.prepare('VACUUM INTO ?').run(backup);
  console.log(`Database backup saved: ${backup}`);
}

db.exec(`
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  patient_id    TEXT UNIQUE NOT NULL,
  username      TEXT NOT NULL,
  username_lc   TEXT UNIQUE NOT NULL,
  email         TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  birth_date    TEXT NOT NULL,
  phone         TEXT NOT NULL,
  photo         TEXT,
  verified      INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  last_login_at TEXT
);

-- everything the app saves for a patient (profile extras, settings, history, notifications)
CREATE TABLE IF NOT EXISTS user_data (
  user_id       INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  profile       TEXT,
  settings      TEXT,
  history       TEXT,
  notifications TEXT,
  calibrated    INTEGER NOT NULL DEFAULT 0,
  updated_at    TEXT
);

CREATE TABLE IF NOT EXISTS otps (
  email     TEXT NOT NULL,
  purpose   TEXT NOT NULL,
  code_hash TEXT NOT NULL,
  expires   INTEGER NOT NULL,
  attempts  INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (email, purpose)
);

CREATE TABLE IF NOT EXISTS reset_tokens (
  email      TEXT PRIMARY KEY,
  token_hash TEXT NOT NULL,
  expires    INTEGER NOT NULL
);

-- phones that enabled fingerprint / Face ID login
CREATE TABLE IF NOT EXISTS devices (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
`);

migrateAccounts(db);
migrateRoles(db);
db.exec('CREATE INDEX IF NOT EXISTS users_pending_created_at ON users(created_at) WHERE verified=0');
