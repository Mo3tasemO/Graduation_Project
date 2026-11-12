# MindSpeak Flutter Frontend

The Flutter app contains the MindSpeak welcome, account, email verification, BLE connection, calibration, and Home flows. The Home Screen uses the existing FastAPI user JWT for its private profile, phrases, message history, and speech preferences.

## Windows setup and run

Open PowerShell in this directory:

```powershell
flutter pub get
flutter run -d chrome --dart-define=MINDSPEAK_API_URL=http://127.0.0.1:8001/api/v1
```

Run FastAPI separately from `mindspeak_backend`:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8001
```

The API must be running and the user must sign in normally to load their personal Home data. The auth token is kept in memory; after a browser/app restart, log in again. Logout clears that in-memory token and returns to Login without deleting the account or its messages.

If `flutter pub get` reports that plugin builds require symlink support on Windows, enable Windows Developer Mode in **Settings → System → For developers**, then rerun `flutter pub get`. Do not bypass sign-in or point the app at an untrusted API.

## Home Screen features

- Type or edit up to 500 characters and tap **Speak message**. Playback is handled by the system/browser TTS engine and is not started automatically. During playback the control becomes **Stop speaking**. English, Arabic, rates, volume, and named voices are offered only when the current device reports them.
- Tap one of the built-in phrases to put it in the editable message field. Custom phrases are private to the signed-in account and can be added, edited, and deleted (with a confirmation).
- A message is sent to private history after the TTS engine accepts it. Recent messages can be spoken again or removed. History is limited to 200 stored messages per account; the screen shows the 50 most recent by default.
- Profile & Settings loads the authenticated name, email, verification timestamp, speech options, and live BLE state. Save applies the locally available speech choices to this account. Logout returns to Login.
- BLE state reflects the real BLE gateway. A generic BLE connection is not treated as an EEG-ready headset. EEG data and predictions are not implemented in this phase. Manual text-to-speech remains usable while BLE is disconnected.

Chrome may require the Speak button click to authorize browser speech. The `flutter_tts` plugin supports web and Android, but actual voices and languages depend on the OS/browser. The project does not promise a male or female voice unless the device exposes one.

## Tests

```powershell
flutter test
flutter analyze
flutter build web
```

Widget tests mock TTS, backend data, and BLE state to check user-visible transitions. They do not prove real audio output or real headset compatibility. Backend API tests use temporary test databases and do not overwrite `mindspeak.db`:

```powershell
Set-Location ..\mindspeak_backend
.\.venv\Scripts\python.exe -m pytest -q
```
