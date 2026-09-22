# MindSpeak

Mobile app (React Native + Expo + TypeScript) that turns EEG-decoded imagined speech into text and voice for people who cannot speak.

## Run

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

## Server + cloud database (`server/`)

A real Node.js server (Express + SQLite). Accounts, passwords (bcrypt), verification codes, per-patient data and biometric device tokens all live in **`server/data/mindspeak.db`**.

```bash
cd server
npm install        # first time only
npm start          # http://localhost:4000
```

The app finds the server automatically (web: same PC; phone: the PC running Expo). For a hosted server set `EXPO_PUBLIC_API_URL=https://your-server`.

### See the data (admin dashboard)
Open the address printed when the server starts, e.g. `http://localhost:4000/admin?key=...` (the key is also saved in `server/data/admin.key`). It lists every patient (ID, username, email, phone, birth date, status), and each patient page shows their message history, notifications, settings, caregiver and medical info. Password hashes are never shown. You can also open `server/data/mindspeak.db` with "DB Browser for SQLite".

### Send real emails (Gmail)
1. Use a Gmail account with **2-Step Verification** on.
2. Create an **App password**: https://myaccount.google.com/apppasswords (16 characters).
3. In `server/`, copy `.env.example` to `.env` and fill `SMTP_USER` and `SMTP_PASS`, set `DEV_SHOW_CODE=false`.
4. Restart the server. Codes are now emailed and no longer shown on screen.

Without `.env` the server prints the code in its console and returns it to the app (dev mode).

### Auth API
| Endpoint | Purpose |
|---|---|
| `POST /auth/register` | username, Gmail-only email, password (8+, number, special), birth date, phone (11+ digits), optional photo. Creates an unverified account + unique patient ID, emails a code |
| `POST /auth/verify-email` `/auth/resend-code` | 6-digit code, valid 10 min, 5 attempts |
| `POST /auth/login` | returns a 30-day token + the patient's saved data |
| `POST /auth/forgot-password` `/auth/verify-reset-code` `/auth/reset-password` | email code, then new password |
| `POST /auth/login-biometric` | fingerprint / Face ID login with the phone's device token |
| `GET/PUT /me/data` | load / save profile, settings, history, notifications (the app syncs automatically) |
| `POST /me/biometric/enable` `/disable` | manage the phone's device token |

Going to production: host the server (Render / Railway / a VPS), use HTTPS, keep `server/data` on a persistent disk (or move to Postgres), and never commit `.env`.

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

History, notifications, settings and profile are stored locally for now (`src/store.tsx`); move them to the server when ready.
