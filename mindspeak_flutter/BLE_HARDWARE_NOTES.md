# MindSpeak BLE hardware integration notes

The headset connection screen now uses real Bluetooth Low Energy (BLE) events.
It does not report a device as connected until FlutterBluePlus confirms a BLE
connection. The dashboard can discover devices, ask the user to select one,
connect, react to a disconnection, and read a battery level when the standard
BLE Battery Service is exposed by that device.

## Supported preview and platform paths

- **Chrome on Windows:** uses Chrome's Web Bluetooth chooser from the user's
  Scan for devices tap. Run the web app at `localhost` or over HTTPS; Chrome
  restricts Web Bluetooth to secure contexts and requires a user gesture.
- **Android:** uses the native BLE implementation with Android Bluetooth
  permissions. The Open Bluetooth settings button opens Android's Bluetooth
  settings page.
- **Other browsers and native targets:** support depends on their BLE
  implementation. A browser without Web Bluetooth shows Bluetooth unavailable.
  The current FlutterBluePlus package does not provide native Windows desktop
  Bluetooth support; use Chrome Web Bluetooth on Windows for this project.

## Still needed from the NINA headset vendor

The physical headset is not available yet, so the app intentionally does not
assume a NINA device name, filter by a guessed service, or read EEG data. Before
adding headset-specific behavior, obtain and verify:

1. The BLE advertising name or a reliable device-identification rule.
2. The EEG GATT service and characteristic UUIDs.
3. The data packet layout, sample rate, units, encoding, and notification/write
   protocol.
4. Any pairing, bonding, authentication, or connection timing requirements.
5. Whether the device exposes the standard Battery Service and whether its
   Battery Level characteristic supports read, notification, or both.

Only the standardized Battery Service (`0x180F`) and Battery Level
characteristic (`0x2A19`) are queried. If the service is absent, inaccessible,
or unreadable, the screen displays **Battery unavailable**. No battery or EEG
values are simulated.

## Manual hardware check when the headset is available

1. Turn on the headset and open MindSpeak on a supported platform.
2. Tap **Scan for devices** and select the headset in Chrome's device chooser
   or the Android scan list.
3. Tap the discovered device, then **Connect to selected device**.
4. Confirm the screen reports Connected only after the connection completes.
5. Confirm battery appears only if the standard service is available.
6. Power off or move the headset out of range; confirm the screen immediately
   reports Connection lost and blocks Continue and headset-dependent screens.
7. Tap **Reconnect headset** or scan again and confirm connection can be
   restored.

Automated widget tests use a fake gateway only to exercise UI state changes.
They do not emulate or claim a real Bluetooth connection.
