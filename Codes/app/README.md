# MindSpeak

Mobile app (React Native + Expo + TypeScript) that turns EEG-decoded imagined speech into text and voice for people who cannot speak.

## Run

On Windows, double-click `run-app-and-server.bat` to check/migrate the SQL database, start the API if it is not already healthy, open the admin dashboard, and launch Expo with the web app. It uses the folder containing the batch file and honors `PORT` in `server/.env`. Install the root and server npm dependencies first. Keep the service windows open. Run `run-app-and-server.bat --check` to verify setup and API health without launching windows. Existing duplicate-phone warnings remain visible but do not block startup; database errors do.

```bash
npm install
npx expo start          # scan the QR code with Expo Go (Android / iOS)
npx expo start --web    # quick preview in the browser
```

## Structure

```
App.tsx                   fonts, providers
src/theme.tsx             design-system colors (light / dark / high contrast) + Poppins typography
src/store.tsx             app state (settings, profile, history, notifications, connection), persisted with AsyncStorage
src/vocab.ts              AAC categories and words
src/services/api.ts       headset / EEG / model (still mock)
src/services/auth.ts      login + account calls to the server
server/                   Node server + SQLite database
src/navigation.tsx        stack + bottom tabs
src/components/           ui kit (Button, Card, Toggle, Slider, Toast, Picker...), charts, logo
src/screens/              the 16 screens from the design
```

## Local SQL database and server (`server/`)

A real Node.js API server (Express) backed by a persistent SQLite SQL database at **`server/data/mindspeak.db`**. Patient and caregiver records have separate tables; shared login credentials enforce email and phone rules across both. Data survives app and server restarts. SQLite runs inside the API process, so no separate database service installation is needed.

```bash
cd server
npm install        # first time only
npm run db:setup   # back up/migrate an existing database and check its structure
npm start          # http://localhost:4000
```

The app finds the server automatically (web: same PC; phone: the PC running Expo). For a hosted server set `EXPO_PUBLIC_API_URL=https://your-server`.

### See the data (admin dashboard)
Open `http://localhost:4000` from this computer to reach the protected admin dashboard. It has **Patients**, **Caregivers**, and **All accounts** lists. Each account page shows saved history, notifications, settings and profile details. Password hashes are never shown. The admin key is printed at startup and saved in `server/data/admin.key` unless overridden by the environment. You can also open `server/data/mindspeak.db` with a SQLite database browser.

### SQL tables and checks

| Table | Purpose |
|---|---|
| `users` | Shared login account, unique email/username, phone, bcrypt password hash and verification status |
| `patients` | One patient record per patient account, with a unique patient ID |
| `caregivers` | One caregiver record per caregiver account, with a unique caregiver ID and required foreign key to `patients.patient_id` |
| `user_data` | Profile extras, settings, message history and notifications belonging to an account |
| `devices`, `otps`, `reset_tokens` | Biometric device credentials, verification codes and password reset sessions |
| `schema_migrations` | Applied database schema versions |

`patient_records` and `caregiver_records` are convenient SQL views joining each role table to account details without password hashes. For example:

```sql
SELECT * FROM patient_records;
SELECT * FROM caregiver_records;
SELECT p.patient_id, p.username AS patient, c.caregiver_id, c.username AS caregiver
FROM patient_records p
LEFT JOIN caregiver_records c ON c.patient_id = p.patient_id;
```

Registration automatically inserts the correct role record within the same SQLite statement as the login account. Foreign keys and triggers reject invalid role records, invalid patient links, and deletion of patients who still have linked caregivers. Shared credentials remain in `users`; application data remains owned by its account, and linking a caregiver does not grant access to the patient's private data.

Before the first upgrade of an existing database, the server saves a consistent snapshot under `server/data/backups/`. The versioned SQL migration is `server/sql/001-patients-caregivers.sql`, and it runs once on setup or server startup. Existing account IDs, passwords and saved data are retained.

```bash
cd server
npm run db:check          # structural integrity, foreign keys, role records, links and phone checks
npm run db:check:strict   # also exits with failure for legacy data warnings
npm test                 # isolated SQL migration, constraints, API and restart tests
```

The checker prints only counts and issues, without credentials or phone numbers. Legacy duplicate phone numbers produce warnings instead of deleting accounts. Change those accounts to distinct numbers through Edit Profile, then run the strict checker again. Setup/check commands initialize or migrate the database if needed.

The protected admin JSON endpoints `/admin/api/patients` and `/admin/api/caregivers` return their respective SQL views; use the admin key as an `x-admin-key` header. Neither endpoint is public.

### Email verification: Gmail, Hotmail, Yahoo and other providers

Users can register with a valid email from Gmail, Hotmail, Yahoo, Outlook or other providers. One configured sender account delivers the six-digit verification codes to all of them; users never provide their mailbox password to this app. Registration remains pending until the user enters the code in the app. Codes expire after 10 minutes, allow five wrong attempts, and work once. Resend creates a new code; a failed delivery does not invalidate the previous code. Password recovery uses the same email delivery flow.

Configure the app's sender locally using a Gmail SMTP account, for example:
1. Use a Gmail account with **2-Step Verification** on.
2. Create an **App password**: https://myaccount.google.com/apppasswords (16 characters).
3. In `server/`, copy `.env.example` to `.env`, set `SMTP_USER` to the sender address and `SMTP_PASS` to its app password, and keep `DEV_SHOW_CODE=false`. Do not put sender credentials in Expo/client files.
4. Run `npm run mail:check` from `server/` to verify the SMTP connection and authentication. This command does not send email and cannot confirm inbox delivery.
5. Restart the API server so it loads the new configuration, then register with an email you control and enter the received code in the app. Check the spam folder if needed. The batch launcher reuses a running server, so close its API window before relaunching to apply changed settings.

For another SMTP sending provider, set its `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER` and `SMTP_PASS`. Port 465 uses immediate TLS; other ports require STARTTLS. `MAIL_FROM` is optional and must be allowed by the sender provider. See [Nodemailer SMTP configuration](https://nodemailer.com/smtp) and [Google app passwords](https://support.google.com/accounts/answer/185833).

Real-email mode is the default. Missing or failed email configuration produces an error rather than claiming a code was sent. For explicit local testing only, set `DEV_SHOW_CODE=true`; the app clearly labels these as test codes and no real email is required. Keep it false when users verify real mailbox ownership.

### Auth API
| Endpoint | Purpose |
|---|---|
| `POST /auth/register` | username, valid email (including Gmail, Hotmail and Yahoo), password (8+, number, special), birth date, phone (11-15 digits), optional photo, role (`patient` or `caregiver`; defaults to patient for older clients). Caregivers must provide `linkedPatientId` for a verified patient. Creates an unverified account + unique account ID and emails a code |
| `POST /auth/verify-email` `/auth/resend-code` | 6-digit code, valid 10 min, 5 attempts |
| `POST /auth/login` | returns a 30-day token + the patient's saved data |
| `POST /auth/forgot-password` `/auth/verify-reset-code` `/auth/reset-password` | email code, then new password; rejects the current password with `SAME_PASSWORD` and keeps the reset token valid for another attempt |
| `POST /auth/login-biometric` | fingerprint / Face ID login with the phone's device token |
| `GET/PUT /me/data` | load / save profile extras, settings, history, notifications (the app syncs automatically); identity fields cannot be changed here |
| `PUT /me/profile` | change the signed-in account's phone; validates format and rejects another account's number with `PHONE_TAKEN` |
| `POST /me/biometric/enable` `/disable` | manage the phone's device token |

Going to production: host the server (Render / Railway / a VPS), use HTTPS, keep `server/data` on a persistent disk (or move to Postgres), and never commit `.env`.

### Account rules and migration

Pending patient and caregiver accounts must verify within **10 minutes of the original registration time**. The server deletes expired unverified accounts on startup, before processing requests, and every 15 seconds while running. Resending a code or retrying a pending registration does not extend this deadline. Removal also deletes associated role records, saved data, devices and email/reset codes. Verified accounts are preserved. Removed accounts can register again using the same email and phone. If the server is stopped, cleanup catches up on its next startup; old backup files are not altered. The app shows an expiry message and a button to register again.

The sign-in and registration pages offer Patient and Caregiver account types. Caregiver registration stores a link to an existing verified patient; the linked ID appears on Home, Profile, and the admin dashboard. This link does not grant access to another account's private data. Login responses include `role` and `linkedPatientId`; password and biometric login accept an optional `role` to check the selected category.

On server restart, existing accounts become patients and phone keys are backfilled in a transaction. Phone comparison ignores formatting and recognizes Egyptian local mobile numbers (`01012345678`) as equivalent to international formats (`+201012345678`, `00201012345678`). Other countries should use a consistent international format.

SQLite triggers prevent new or changed phone numbers from duplicating any registered number, including pending accounts, even under concurrent requests. Existing duplicate accounts are preserved so no account data is lost; their owners need to change to distinct numbers through Edit Profile. Background sync cannot overwrite account identity or undo a phone change.

Run `cd server` then `npm test` for isolated database migration and HTTP account tests. Tests use a temporary database and never send email. `MINDSPEAK_DATA_DIR` can override the server data directory for isolated runs. Run `npx tsc --noEmit` from the project root to check the app.

## Backend contract (`src/services/api.ts`)

Every function is currently a mock (fake latency + simulated EEG). Replace the bodies, keep the signatures.

| Function | Suggested real call | Purpose |
|---|---|---|
| `scanDevices(onFound)` | BLE scan (`react-native-ble-plx`) | find headsets |
| `connect(device)` | BLE connect | pair, returns battery + signal quality |
| `streamEEG(onFrame)` | BLE notify / WebSocket | 8-channel µV frames (~14 Hz) |
| `decode(onProgress)` | `POST /predict` (send the EEG window) | returns `{ word, confidence, alternatives[] }` |
| `recordCalibration(word, onProgress)` | `POST /calibration/sample` | personalise the model |
| `sendEmergencyAlert()` | `POST /alerts/emergency` | push/SMS to caregiver |

History, notifications, settings and profile extras are cached locally in `src/store.tsx` and synced to the SQL database through `/me/data`.
