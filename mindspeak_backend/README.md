# MindSpeak Backend

This independent FastAPI service provides email-verified account registration, login, bearer-token sessions, and email-based password recovery. It uses its own SQLite database under this folder. It does not use the unrelated Node.js service in `Codes/app/server/`.

## Main parts

- `app/main.py` creates the FastAPI app, database tables, health endpoint, and local Flutter web CORS policy. Startup applies additive database changes and marks pre-verification legacy users as verified, preserving their existing accounts.
- `app/routes.py` contains registration, login, protected profile, and password recovery endpoints.
- `app/home_routes.py` contains JWT-protected per-user phrases, speech history, and speech preferences.
- `app/home_schemas.py` validates Home data and response limits.
- `app/schemas.py` validates incoming requests and limits response fields.
- `app/models.py` defines users, verification/reset state, and the additive custom phrase, message history, and speech preference tables.
- `app/security.py` hashes passwords with Argon2, signs JWT access tokens, and creates keyed hashes for reset secrets.
- `app/mailer.py` sends verification and reset codes through SMTP with plain-text and HTML email templates; codes are never logged or returned by API endpoints.
- `app/config.py` reads private settings from environment variables or `.env`.
- `app/database.py` creates a separate SQLite connection and sessions.

## Windows setup (PowerShell)

Open PowerShell in `mindspeak_backend`:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
Copy-Item .env.example .env
```

Generate a private JWT signing key:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Put the generated value in `JWT_SECRET_KEY` in `.env`. The API rejects the example placeholder until it is replaced. Do not commit or share `.env`.

## Enable registration and password-recovery email

Registration verification and password recovery require a complete SMTP configuration. Copy `.env.example` to `.env` and set:

- `SMTP_HOST`: for Gmail, `smtp.gmail.com`.
- `SMTP_PORT`: `587` for STARTTLS.
- `SMTP_USERNAME`: your test Gmail address.
- `SMTP_PASSWORD`: a Google App Password, not your regular Gmail password.
- `SMTP_FROM_EMAIL`: the same Gmail address, or a sender alias permitted by Google.
- `SMTP_USE_STARTTLS`: `true`; authenticated SMTP and verification messages require encrypted transport.

For Gmail, enable 2-Step Verification on a dedicated test account, then create an App Password in that Google Account's security settings. Remove spaces when copying the generated app password into `.env`. The `.env` file is git-ignored. The backend can start with all SMTP values unset, but registration and reset return `503 email_not_configured`. A partial configuration fails settings validation at startup. SMTP errors return `503 email_delivery_failed`; registration does not save a pending record or claim success if delivery fails.

## Run the API

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8001
```

Open `http://127.0.0.1:8001/docs` for interactive Swagger documentation. The first run creates `mindspeak.db` and its tables in this folder. The backend only permits browser requests from localhost during development.

## Authentication rules

- Registration requires exactly four whitespace-separated name words. It sends a verification code and creates a pending row only; there is no user account and login is rejected until the code is verified.
- Registration pending data contains an Argon2 password hash and keyed verification-code hash, never plaintext secrets. The code expires after five minutes, allows five attempts, and can be requested after a 60-second cooldown (maximum three requests per hour). A pending registration expires after 24 hours; expired rows are removed during registration, resend, or verification requests.
- Successful email verification atomically creates the user, records the verified timestamp, removes the pending registration, and returns a JWT.
- Email addresses are validated, normalized to lowercase, and unique.
- Passwords need 8–128 characters, an uppercase and lowercase letter, a number, and a symbol.
- Passwords are stored using Argon2 hashes.
- Login returns a 30-minute JWT bearer token. User responses never include password hashes.
- The Flutter client keeps the token in memory for the current app session; restarting the app requires logging in again.
- Reset codes expire after five minutes, can be requested once per 60 seconds (maximum three requests per hour), and allow five verification attempts.
- A verified reset token expires after ten minutes and can only be used once. Reset codes and reset tokens are stored as keyed hashes, not plaintext.

## Endpoints

All auth paths below are prefixed by `/api/v1`.

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | Check the API and SQLite database. |
| `POST` | `/api/v1/auth/register` | Begin registration and send a code. Requires `name`, `email`, `password`. Returns `202`; does not create a user. |
| `POST` | `/api/v1/auth/verify-email` | Verify `email` and six-digit `code`; creates the user and returns a bearer token. |
| `POST` | `/api/v1/auth/resend-verification-code` | Resend a code for the pending `email`, subject to cooldown and request limits. |
| `POST` | `/api/v1/auth/login` | Authenticate and return an access token. Requires `email`, `password`. |
| `GET` | `/api/v1/me` | Get the current user's profile. Send `Authorization: Bearer <access_token>`. |
| `POST` | `/api/v1/auth/forgot-password` | Request a reset email. Requires `email`; response never contains a code. |
| `POST` | `/api/v1/auth/verify-reset-code` | Verify `email` and six-digit `code`; returns a short-lived `reset_token`. |
| `POST` | `/api/v1/auth/reset-password` | Requires `email`, `reset_token`, and strong `new_password`. |
| `GET` | `/api/v1/home/phrases` | List the signed-in user's custom phrases. |
| `POST` | `/api/v1/home/phrases` | Save a 1–100 character custom phrase. |
| `PUT` | `/api/v1/home/phrases/{phrase_id}` | Edit one of the signed-in user's phrases. |
| `DELETE` | `/api/v1/home/phrases/{phrase_id}` | Delete one of the signed-in user's phrases. |
| `GET` | `/api/v1/home/history?limit=50` | Get up to 100 of the signed-in user's most recent messages. |
| `POST` | `/api/v1/home/history` | Record text accepted by the local TTS engine (maximum 500 characters). |
| `DELETE` | `/api/v1/home/history/{entry_id}` | Delete one of the signed-in user's history entries. |
| `DELETE` | `/api/v1/home/history` | Clear only the signed-in user's history. |
| `GET` | `/api/v1/home/preferences` | Get speech language/voice/rate/volume selections. |
| `PUT` | `/api/v1/home/preferences` | Save the signed-in user's speech settings. |

Registration request example (this begins verification; it does not immediately create a user):

```json
{"name":"Sara Ahmed Ali Hassan","email":"sara@example.com","password":"StrongPass1!"}
```

## Run backend tests

```powershell
python -m pytest -q
```

Tests use temporary SQLite files and a fake mail sender. They verify that a user cannot log in before email verification, pending passwords/codes are hashed, verification creates the user, duplicate emails and invalid data are rejected, resend and attempt limits work, reset is one-time, password replacement works, legacy user data survives the additive schema migration, and Home endpoints enforce per-user isolation. They do not send a real email or modify the configured database.

## Flutter connection

From `mindspeak_flutter`, resolve dependencies, then run the app:

```powershell
flutter pub get
flutter run -d chrome --dart-define=MINDSPEAK_API_URL=http://127.0.0.1:8001/api/v1
```

For an Android emulator, use `http://10.0.2.2:8000/api/v1` as the define value. For a physical device, use the development computer's LAN IP and ensure the backend is bound to an interface reachable on that network. Use HTTPS for non-local deployments. Start the API separately from the Flutter app.

## Admin dashboard

The separate `mindspeak_admin` site is served by FastAPI at `http://127.0.0.1:8001/admin/` and queries the same configured SQLite database. It does not use mock data. Start FastAPI on port 8001, then open that URL in Chrome.

Provision the first administrator locally from this backend directory:

```powershell
.\.venv\Scripts\python.exe -m app.admin_cli create-first-admin
```

The command confirms that the configured database file and existing `users` table are present, creates only the additive `admin_accounts` table, and prompts for an email and a hidden password. The password must be 12–128 characters with uppercase, lowercase, a number, and a symbol; it is stored as an Argon2 hash. The command refuses to create a second administrator. There is no public admin signup and no default admin credential. Do not point `DATABASE_URL` at a new empty database when provisioning.

Admin JWTs use a separately derived signing key and an admin-only audience/type, so normal user tokens are rejected. User listing and statistics require admin authorization on every request. Only the sign-in endpoint is unauthenticated; it is rate-limited to five failures per client IP in 15 minutes. For public deployment, use HTTPS and a shared persistent rate limiter.

See [`../mindspeak_admin/README.md`](../mindspeak_admin/README.md) for complete Windows setup and run instructions.
