import { normalizePhone } from './account-schema.js';

export function checkDatabase(db) {
  const errors = [];
  const warnings = [];
  const tables = new Set(db.prepare("SELECT name FROM sqlite_master WHERE type='table'").all().map((r) => r.name));
  for (const table of ['users', 'patients', 'caregivers', 'user_data', 'devices', 'otps', 'reset_tokens', 'schema_migrations']) {
    if (!tables.has(table)) errors.push(`Missing SQL table: ${table}`);
  }
  if (errors.length) return { ok: false, counts: null, errors, warnings };
  const integrity = db.prepare('PRAGMA integrity_check').all();
  if (integrity.length !== 1 || integrity[0].integrity_check !== 'ok') errors.push('SQLite integrity check failed');
  if (db.prepare('PRAGMA foreign_key_check').all().length) errors.push('Broken foreign-key references');
  if (!db.prepare('PRAGMA foreign_keys').get().foreign_keys) errors.push('Foreign-key enforcement is disabled');
  const mismatches = db.prepare(`SELECT u.id FROM users u
    LEFT JOIN patients p ON p.user_id=u.id LEFT JOIN caregivers c ON c.user_id=u.id
    WHERE (u.role='patient' AND (p.user_id IS NULL OR p.patient_id!=u.patient_id OR c.user_id IS NOT NULL OR u.linked_patient_id IS NOT NULL))
       OR (u.role='caregiver' AND (c.user_id IS NULL OR c.caregiver_id!=u.patient_id OR c.patient_id IS NOT u.linked_patient_id OR p.user_id IS NOT NULL))
       OR u.role NOT IN ('patient','caregiver')`).all();
  if (mismatches.length) errors.push(`${mismatches.length} account(s) have missing or mismatched role records`);
  const invalidLinks = db.prepare(`SELECT c.user_id FROM caregivers c
    LEFT JOIN patients p ON p.patient_id=c.patient_id LEFT JOIN users u ON u.id=p.user_id
    WHERE u.id IS NULL OR u.role!='patient' OR u.verified!=1`).all();
  if (invalidLinks.length) errors.push(`${invalidLinks.length} caregiver link(s) do not point to verified patients`);
  const phones = db.prepare('SELECT id, phone, phone_key FROM users').all();
  if (phones.some((u) => normalizePhone(u.phone) !== u.phone_key)) errors.push('Stored phone keys do not match phone numbers');
  const invalidPhones = phones.filter((u) => !normalizePhone(u.phone)).length;
  if (invalidPhones) warnings.push(`${invalidPhones} legacy account(s) need valid phone numbers`);
  const duplicates = db.prepare('SELECT COUNT(*) AS n FROM users WHERE phone_key IS NOT NULL GROUP BY phone_key HAVING COUNT(*)>1').all();
  if (duplicates.length) warnings.push(`${duplicates.length} shared phone number(s) across ${duplicates.reduce((n, r) => n + r.n, 0)} legacy accounts; assign distinct numbers through Edit Profile`);
  return {
    ok: errors.length === 0,
    counts: {
      accounts: phones.length,
      patients: db.prepare('SELECT COUNT(*) AS n FROM patients').get().n,
      caregivers: db.prepare('SELECT COUNT(*) AS n FROM caregivers').get().n,
    },
    errors, warnings,
  };
}
