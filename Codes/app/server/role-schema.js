import fs from 'node:fs';

export const ROLE_MIGRATION = '001-patients-caregivers';

export function needsRoleMigration(db) {
  if (!db.prepare("SELECT 1 FROM sqlite_master WHERE type='table' AND name='schema_migrations'").get()) return true;
  return !db.prepare('SELECT 1 FROM schema_migrations WHERE name=?').get(ROLE_MIGRATION);
}

export function migrateRoles(db) {
  db.exec('BEGIN IMMEDIATE');
  try {
    db.exec("CREATE TABLE IF NOT EXISTS schema_migrations (name TEXT PRIMARY KEY, applied_at TEXT NOT NULL DEFAULT (datetime('now'))) STRICT");
    if (needsRoleMigration(db)) {
      const invalid = db.prepare(`SELECT id FROM users c WHERE role='caregiver' AND NOT EXISTS (
        SELECT 1 FROM users p WHERE p.patient_id=c.linked_patient_id AND p.role='patient' AND p.verified=1
      )`).all();
      if (invalid.length) throw new Error(`Migration stopped: ${invalid.length} caregiver account(s) have invalid patient links. Original accounts are unchanged.`);
      db.exec(fs.readFileSync(new URL('./sql/001-patients-caregivers.sql', import.meta.url), 'utf8'));
      db.prepare('INSERT INTO schema_migrations(name) VALUES(?)').run(ROLE_MIGRATION);
    }
    if (db.prepare('PRAGMA foreign_key_check').all().length) throw new Error('Database foreign-key check failed; migration rolled back.');
    db.exec('COMMIT');
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}
