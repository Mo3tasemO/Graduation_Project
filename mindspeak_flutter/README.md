# MindSpeak Flutter Frontend

Lightweight Flutter version of the MindSpeak mobile interface. It starts without Android Studio, an Android emulator, or third-party runtime packages.

## What is included now

- Flutter application entry point
- MindSpeak colour theme
- Responsive, iPhone-proportioned patient interface
- Patient-only flow: welcome → access → connect headset → calibration → home
- NINA BLE connection interface with device status, Connect, and Bluetooth-settings entry point
- Calibration appears only for a new account; an existing user continues to connection then home
- Navy-and-blue MindSpeak branding, welcome lockup, and accessible connection states

## Bluetooth status

The current BLE page is a frontend prototype, so it does not claim to connect to hardware yet. It is ready to be wired once the hardware team shares the NINA BLE advertised device name, GATT service UUID, notification characteristic UUID, and packet format. This keeps the app lightweight until the real device protocol is available.

## Backend integration

The Flutter access screen is connected to the team backend's patient endpoints:

- `POST /auth/register` — creates a patient account
- `POST /auth/verify-email` — confirms the six-digit email code
- `POST /auth/login` — returns an authenticated session and calibration state
- `PUT /me/data` — saves that a new patient has completed calibration

The backend runs on port `4000`. From `Codes/app/server`, the backend teammate can run:

```powershell
npm install
npm start
```

For a Chrome preview on the same laptop, run Flutter normally; it uses
`http://localhost:4000` by default. For a real Android phone on the same Wi-Fi,
use the laptop's local IP address instead:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:4000
```

Replace `192.168.x.x` with the backend laptop's Wi-Fi IPv4 address. The backend
must be running before attempting login or registration. Email verification also
requires its SMTP settings, or `DEV_SHOW_CODE=true` for local development only.

## When a teammate runs it

From this directory, run:

```powershell
flutter create .
flutter pub get
flutter run -d chrome
```

`flutter create .` generates platform folders such as `web/` or `android/` without replacing the files in `lib/`. Android tooling is only needed when building an Android app.
