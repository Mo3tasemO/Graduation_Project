-- Shared credentials remain in users so email/phone checks cover both roles.
-- These are persistent tables, not copies of the account list.
CREATE TABLE patients (
  user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  patient_id TEXT NOT NULL UNIQUE
) STRICT;

CREATE TABLE caregivers (
  user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  caregiver_id TEXT NOT NULL UNIQUE,
  patient_id TEXT NOT NULL REFERENCES patients(patient_id) ON UPDATE RESTRICT ON DELETE RESTRICT
) STRICT;
CREATE INDEX caregivers_patient_id ON caregivers(patient_id);

INSERT INTO patients(user_id, patient_id)
  SELECT id, patient_id FROM users WHERE role = 'patient';
INSERT INTO caregivers(user_id, caregiver_id, patient_id)
  SELECT id, patient_id, linked_patient_id FROM users WHERE role = 'caregiver';

-- Reject mismatched account types and IDs even for direct SQL writes.
CREATE TRIGGER patients_validate_insert BEFORE INSERT ON patients BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM users WHERE id = NEW.user_id AND patient_id = NEW.patient_id AND role = 'patient'
  ) THEN RAISE(ABORT, 'BAD_PATIENT_ACCOUNT') END;
END;
CREATE TRIGGER patients_validate_update BEFORE UPDATE ON patients BEGIN
  SELECT CASE WHEN NEW.user_id != OLD.user_id OR NEW.patient_id != OLD.patient_id
    THEN RAISE(ABORT, 'ACCOUNT_ID_IMMUTABLE') END;
END;
CREATE TRIGGER caregivers_validate_insert BEFORE INSERT ON caregivers BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM users WHERE id = NEW.user_id AND patient_id = NEW.caregiver_id
      AND role = 'caregiver' AND linked_patient_id = NEW.patient_id
  ) THEN RAISE(ABORT, 'BAD_CAREGIVER_ACCOUNT') END;
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM patients p JOIN users u ON u.id = p.user_id
      WHERE p.patient_id = NEW.patient_id AND u.verified = 1
  ) THEN RAISE(ABORT, 'BAD_PATIENT_ID') END;
END;
CREATE TRIGGER caregivers_validate_update BEFORE UPDATE ON caregivers BEGIN
  SELECT CASE WHEN NEW.user_id != OLD.user_id OR NEW.caregiver_id != OLD.caregiver_id
    THEN RAISE(ABORT, 'ACCOUNT_ID_IMMUTABLE') END;
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM users WHERE id = NEW.user_id AND role = 'caregiver' AND linked_patient_id = NEW.patient_id
  ) THEN RAISE(ABORT, 'BAD_CAREGIVER_ACCOUNT') END;
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM patients p JOIN users u ON u.id = p.user_id
      WHERE p.patient_id = NEW.patient_id AND u.verified = 1
  ) THEN RAISE(ABORT, 'BAD_PATIENT_ID') END;
END;

-- Account writes and their role records are one atomic SQLite statement.
CREATE TRIGGER users_create_role AFTER INSERT ON users BEGIN
  INSERT INTO patients(user_id, patient_id)
    SELECT NEW.id, NEW.patient_id WHERE NEW.role = 'patient';
  INSERT INTO caregivers(user_id, caregiver_id, patient_id)
    SELECT NEW.id, NEW.patient_id, NEW.linked_patient_id WHERE NEW.role = 'caregiver';
END;
CREATE TRIGGER users_sync_role AFTER UPDATE OF role, linked_patient_id ON users BEGIN
  DELETE FROM caregivers WHERE user_id = NEW.id AND NEW.role = 'patient';
  DELETE FROM patients WHERE user_id = NEW.id AND NEW.role = 'caregiver';
  INSERT INTO patients(user_id, patient_id)
    SELECT NEW.id, NEW.patient_id WHERE NEW.role = 'patient'
    ON CONFLICT(user_id) DO NOTHING;
  INSERT INTO caregivers(user_id, caregiver_id, patient_id)
    SELECT NEW.id, NEW.patient_id, NEW.linked_patient_id WHERE NEW.role = 'caregiver'
    ON CONFLICT(user_id) DO UPDATE SET patient_id = excluded.patient_id;
END;
CREATE TRIGGER users_protect_identity BEFORE UPDATE OF id, patient_id ON users
WHEN NEW.id != OLD.id OR NEW.patient_id != OLD.patient_id BEGIN
  SELECT RAISE(ABORT, 'ACCOUNT_ID_IMMUTABLE');
END;
CREATE TRIGGER users_protect_patient BEFORE UPDATE OF role, verified ON users
WHEN (NEW.role != 'patient' OR NEW.verified != 1)
  AND EXISTS (SELECT 1 FROM caregivers WHERE patient_id = OLD.patient_id) BEGIN
  SELECT RAISE(ABORT, 'PATIENT_HAS_CAREGIVERS');
END;

-- Deleting an account cascades; deleting just its subtype is an invalid partial deletion.
CREATE TRIGGER patients_protect_delete BEFORE DELETE ON patients
WHEN EXISTS (SELECT 1 FROM users WHERE id = OLD.user_id AND role = 'patient') BEGIN
  SELECT RAISE(ABORT, 'DELETE_ACCOUNT_INSTEAD');
END;
CREATE TRIGGER caregivers_protect_delete BEFORE DELETE ON caregivers
WHEN EXISTS (SELECT 1 FROM users WHERE id = OLD.user_id AND role = 'caregiver') BEGIN
  SELECT RAISE(ABORT, 'DELETE_ACCOUNT_INSTEAD');
END;

-- Convenient SQL queries without exposing password hashes or authentication tokens.
CREATE VIEW patient_records AS
  SELECT p.user_id, p.patient_id, u.username, u.email, u.phone, u.birth_date,
    u.verified, u.created_at, u.last_login_at,
    (SELECT COUNT(*) FROM caregivers c WHERE c.patient_id = p.patient_id) AS caregiver_count
  FROM patients p JOIN users u ON u.id = p.user_id;
CREATE VIEW caregiver_records AS
  SELECT c.user_id, c.caregiver_id, c.patient_id, u.username, u.email, u.phone,
    u.birth_date, u.verified, u.created_at, u.last_login_at
  FROM caregivers c JOIN users u ON u.id = c.user_id;
