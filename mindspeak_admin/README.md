# MindSpeak Admin Dashboard

This separate, plain HTML/CSS/JavaScript dashboard is served by the existing FastAPI app at `http://127.0.0.1:8001/admin/`. It reads real records from the configured MindSpeak SQLite database. It does not contain mock user data and does not modify the Flutter application.

## Provision the first administrator

Run PowerShell in `mindspeak_backend` after confirming `.env` points to the existing database:

```powershell
.\.venv\Scripts\python.exe -m app.admin_cli create-first-admin
```

The command verifies that the configured SQLite file already contains the `users` table, then adds only the `admin_accounts` table. It refuses to create an administrator if one already exists. Enter the email at the prompt and choose a 12–128 character password with uppercase, lowercase, a number, and a symbol. Password input is hidden. The command stores an Argon2 hash, not the password. No default password is used.

There is no public admin signup endpoint. The dashboard login endpoint is the only unauthenticated admin API route; statistics, profile, and user listing require the separate admin token. A normal MindSpeak user JWT is not accepted as an admin token.

## Run locally

In a PowerShell window, start the backend from its folder:

```powershell
cd "C:\python learning\Graduation_Project_copy\mindspeak_backend"
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8001
```

Leave that window open and visit **http://127.0.0.1:8001/admin/** in Chrome. The dashboard and API use the same origin, so there is no separate npm server or frontend build step.

After restarting the computer, run the same backend command again, then reopen the URL. To stop the backend, press **Ctrl+C** in its PowerShell window.

The browser keeps the short-lived admin token in `sessionStorage` for the current tab session. Signing out clears it. The local login rate limit allows five failures per client IP per 15 minutes; for a public deployment, replace the in-process limiter with a shared persistent limiter and deploy behind HTTPS.

## Admin API

- `POST /api/v1/admin/auth/login` — administrator sign-in; generic credential errors and rate limiting.
- `GET /api/v1/admin/auth/me` — current administrator profile; admin token required.
- `GET /api/v1/admin/dashboard/stats` — overview; admin token required.
- `GET /api/v1/admin/users` — searchable, paginated user list; admin token required.

Responses contain only the fields needed by the dashboard. Password hashes, verification codes, and JWT signing secrets are never returned.
