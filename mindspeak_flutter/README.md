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

## When a teammate runs it

From this directory, run:

```powershell
flutter create .
flutter pub get
flutter run -d chrome
```

`flutter create .` generates platform folders such as `web/` or `android/` without replacing the files in `lib/`. Android tooling is only needed when building an Android app.
