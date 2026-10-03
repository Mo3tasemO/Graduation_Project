// Local Egyptian mobile numbers and their international spelling share one key.
export function normalizePhone(value) {
  if (typeof value !== 'string' || !/^\+?[\d\s().-]+$/.test(value.trim())) return null;
  let digits = value.replace(/\D/g, '').replace(/^00/, '');
  if (/^01[0125]\d{8}$/.test(digits)) digits = '20' + digits.slice(1);
  return digits.length >= 11 && digits.length <= 15 ? digits : null;
}

export function migrateAccounts(db) {
  db.exec('BEGIN IMMEDIATE');
  try {
    const columns = new Set(db.prepare('PRAGMA table_info(users)').all().map((c) => c.name));
    if (!columns.has('role')) db.exec("ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'patient' CHECK (role IN ('patient', 'caregiver'))");
    if (!columns.has('linked_patient_id')) db.exec('ALTER TABLE users ADD COLUMN linked_patient_id TEXT REFERENCES users(patient_id)');
    if (!columns.has('phone_key')) {
      db.exec('ALTER TABLE users ADD COLUMN phone_key TEXT');
      const update = db.prepare('UPDATE users SET phone_key = ? WHERE id = ?');
      for (const u of db.prepare('SELECT id, phone FROM users').all()) update.run(normalizePhone(u.phone), u.id);
    }
    // Keep legacy duplicate accounts intact. SQLite serializes these checks with the
    // write, so concurrent requests cannot introduce any new duplicate numbers.
    db.exec(`
      CREATE INDEX IF NOT EXISTS users_phone_key ON users(phone_key);
      CREATE TRIGGER IF NOT EXISTS users_phone_insert BEFORE INSERT ON users BEGIN
        SELECT CASE WHEN NEW.phone_key IS NULL THEN RAISE(ABORT, 'BAD_PHONE') END;
        SELECT CASE WHEN EXISTS (SELECT 1 FROM users WHERE phone_key = NEW.phone_key)
          THEN RAISE(ABORT, 'PHONE_TAKEN') END;
      END;
      CREATE TRIGGER IF NOT EXISTS users_phone_update BEFORE UPDATE OF phone_key ON users
      WHEN NEW.phone_key IS NOT OLD.phone_key BEGIN
        SELECT CASE WHEN NEW.phone_key IS NULL THEN RAISE(ABORT, 'BAD_PHONE') END;
        SELECT CASE WHEN EXISTS (SELECT 1 FROM users WHERE phone_key = NEW.phone_key AND id != NEW.id)
          THEN RAISE(ABORT, 'PHONE_TAKEN') END;
      END;
      CREATE TRIGGER IF NOT EXISTS users_role_insert BEFORE INSERT ON users BEGIN
        SELECT CASE WHEN
          (NEW.role = 'patient' AND NEW.linked_patient_id IS NOT NULL) OR
          (NEW.role = 'caregiver' AND NOT EXISTS (
            SELECT 1 FROM users WHERE patient_id = NEW.linked_patient_id AND role = 'patient' AND verified = 1
          )) THEN RAISE(ABORT, 'BAD_PATIENT_ID') END;
      END;
      CREATE TRIGGER IF NOT EXISTS users_role_update BEFORE UPDATE OF role, linked_patient_id ON users BEGIN
        SELECT CASE WHEN
          (NEW.role = 'patient' AND NEW.linked_patient_id IS NOT NULL) OR
          (NEW.role = 'caregiver' AND NOT EXISTS (
            SELECT 1 FROM users WHERE patient_id = NEW.linked_patient_id AND role = 'patient' AND verified = 1 AND id != NEW.id
          )) THEN RAISE(ABORT, 'BAD_PATIENT_ID') END;
      END;
    `);
    db.exec('COMMIT');
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}
