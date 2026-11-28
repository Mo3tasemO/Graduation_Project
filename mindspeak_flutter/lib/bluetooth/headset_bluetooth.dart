import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum HeadsetConnectionStatus {
  bluetoothUnavailable,
  disconnected,
  scanning,
  connecting,
  connected,
  connectionLost,
  connectionFailed,
}

@immutable
class HeadsetDevice {
  const HeadsetDevice({required this.id, required this.name});

  final String id;
  final String name;
}

@immutable
class HeadsetSnapshot {
  const HeadsetSnapshot({
    this.status = HeadsetConnectionStatus.disconnected,
    this.isInitializing = false,
    this.devices = const [],
    this.selectedDeviceId,
    this.batteryLevel,
    this.message,
  });

  final HeadsetConnectionStatus status;
  final bool isInitializing;
  final List<HeadsetDevice> devices;
  final String? selectedDeviceId;
  final int? batteryLevel;
  final String? message;

  bool get isConnected => status == HeadsetConnectionStatus.connected;
}

abstract interface class HeadsetBluetoothGateway {
  HeadsetSnapshot get snapshot;
  Stream<HeadsetSnapshot> get changes;

  Future<void> initialize();
  Future<void> scan();
  void selectDevice(String? deviceId);
  Future<void> connectSelected();
  Future<void> reconnect();
  Future<bool> openBluetoothSettings();
  void dispose();
}

final HeadsetBluetoothGateway mindSpeakHeadsetBluetooth =
    FlutterBlueHeadsetGateway();

/// BLE implementation shared by Android and supported Web Bluetooth browsers.
/// It deliberately has no NINA-specific filters because those specifications
/// have not yet been supplied by the hardware vendor.
class FlutterBlueHeadsetGateway implements HeadsetBluetoothGateway {
  static const _settingsChannel = MethodChannel('mindspeak/bluetooth_settings');
  static final _batteryService = Guid('180F');
  static final _batteryLevelCharacteristic = Guid('2A19');

  final _changes = StreamController<HeadsetSnapshot>.broadcast();
  final Map<String, BluetoothDevice> _knownDevices = {};

  HeadsetSnapshot _snapshot = const HeadsetSnapshot(isInitializing: true);
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _batterySubscription;
  Timer? _batteryPollTimer;
  BluetoothCharacteristic? _batteryCharacteristic;
  bool _supported = false;
  bool _hasBeenConnected = false;
  bool _initializeStarted = false;
  bool _disposed = false;

  @override
  HeadsetSnapshot get snapshot => _snapshot;

  @override
  Stream<HeadsetSnapshot> get changes => _changes.stream;

  @override
  Future<void> initialize() async {
    if (_initializeStarted || _disposed) return;
    _initializeStarted = true;
    try {
      _supported = await FlutterBluePlus.isSupported;
      if (!_supported) {
        _update(
          status: HeadsetConnectionStatus.bluetoothUnavailable,
          isInitializing: false,
          message:
              'Bluetooth is not available in this browser or on this device.',
        );
        return;
      }

      if (kIsWeb) {
        // Web Bluetooth has no adapter-state stream. The browser chooser is
        // invoked only from the user's Scan button.
        _update(
          status: HeadsetConnectionStatus.disconnected,
          isInitializing: false,
          message: null,
        );
        return;
      }

      _adapterSubscription = FlutterBluePlus.adapterState.listen(
        _onAdapterState,
        onError: (_) => _handleUnavailable(),
      );
      _onAdapterState(FlutterBluePlus.adapterStateNow);
      _update(isInitializing: false);
    } catch (_) {
      _handleUnavailable();
      _update(isInitializing: false);
    }
  }

  void _onAdapterState(BluetoothAdapterState state) {
    if (state == BluetoothAdapterState.on) {
      if (_snapshot.status == HeadsetConnectionStatus.bluetoothUnavailable) {
        _update(status: HeadsetConnectionStatus.disconnected, message: null);
      }
      return;
    }

    if (_hasBeenConnected) {
      _hasBeenConnected = false;
      _update(
        status: HeadsetConnectionStatus.connectionLost,
        batteryLevel: null,
        message: 'Bluetooth was turned off. Turn it back on, then reconnect.',
      );
    } else {
      _handleUnavailable();
    }
  }

  void _handleUnavailable() {
    _update(
      status: HeadsetConnectionStatus.bluetoothUnavailable,
      batteryLevel: null,
      message: 'Bluetooth is unavailable or its permission was not granted.',
    );
  }

  @override
  Future<void> scan() async {
    if (_disposed) return;
    if (_snapshot.isInitializing) return;
    if (!_supported) {
      _handleUnavailable();
      return;
    }
    if (!kIsWeb &&
        FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      _handleUnavailable();
      return;
    }

    // On Web this call remains directly in the button's click path. Chrome
    // requires requestDevice() to be initiated by a user gesture.
    _knownDevices.clear();
    _update(
      status: HeadsetConnectionStatus.scanning,
      devices: const [],
      clearSelectedDevice: true,
      batteryLevel: null,
      message: kIsWeb
          ? 'Choose a nearby BLE device in the browser dialog.'
          : 'Searching for nearby BLE devices…',
    );

    final previousScanSubscription = _scanResultsSubscription;
    _scanResultsSubscription = null;
    if (previousScanSubscription != null) {
      unawaited(previousScanSubscription.cancel());
    }
    _scanResultsSubscription = FlutterBluePlus.onScanResults.listen(
      _onScanResults,
      onError: (_) => _update(
        status: HeadsetConnectionStatus.connectionFailed,
        message: 'The Bluetooth scan failed. Check permissions and try again.',
      ),
    );

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        oneByOne: true,
        androidCheckLocationServices: true,
        webOptionalServices: [_batteryService],
      );
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.isScanning.where((scanning) => !scanning).first;
      }
      if (_snapshot.status == HeadsetConnectionStatus.scanning) {
        _update(
          status: HeadsetConnectionStatus.disconnected,
          message: _snapshot.devices.isEmpty
              ? 'No BLE devices were selected or found. Try scanning again.'
              : 'Select the headset you want to connect.',
        );
      }
    } catch (error) {
      final description = error.toString().toLowerCase();
      final wasCancelled =
          description.contains('cancel') || description.contains('not found');
      final permissionDenied = description.contains('permission');
      final locationServicesOff = description.contains('location services');
      _update(
        status: wasCancelled
            ? HeadsetConnectionStatus.disconnected
            : HeadsetConnectionStatus.connectionFailed,
        message: wasCancelled
            ? 'No device was selected. Tap Scan for devices to try again.'
            : locationServicesOff
            ? 'Turn on Location services to scan on Android 11 or earlier.'
            : permissionDenied
            ? 'Allow the Bluetooth or Nearby devices permission, then scan again.'
            : 'Bluetooth scanning could not start. Check Bluetooth and try again.',
      );
    } finally {
      final scanSubscription = _scanResultsSubscription;
      _scanResultsSubscription = null;
      if (scanSubscription != null) await scanSubscription.cancel();
    }
  }

  void _onScanResults(List<ScanResult> results) {
    final devices = <HeadsetDevice>[];
    for (final result in results) {
      final device = result.device;
      final id = device.remoteId.str;
      _knownDevices[id] = device;
      final advertisedName = result.advertisementData.advName.trim();
      final platformName = device.platformName.trim();
      final name = advertisedName.isNotEmpty
          ? advertisedName
          : platformName.isNotEmpty
          ? platformName
          : 'Unnamed BLE device';
      devices.add(HeadsetDevice(id: id, name: name));
    }
    final deduplicated = {for (final device in devices) device.id: device}
        .values
        .toList();
    _update(devices: deduplicated);
  }

  @override
  void selectDevice(String? deviceId) {
    if (deviceId != null && !_knownDevices.containsKey(deviceId)) return;
    _update(
      selectedDeviceId: deviceId,
      clearSelectedDevice: deviceId == null,
      message: null,
    );
  }

  @override
  Future<void> connectSelected() async {
    final id = _snapshot.selectedDeviceId;
    if (id == null) return;
    final device = _knownDevices[id];
    if (device == null) {
      _update(
        status: HeadsetConnectionStatus.connectionFailed,
        message:
            'That device is no longer available. Scan again and select it.',
      );
      return;
    }

    await _connect(device);
  }

  @override
  Future<void> reconnect() async {
    final id = _snapshot.selectedDeviceId;
    if (id == null) {
      await scan();
      return;
    }
    final device = _knownDevices[id];
    if (device == null) {
      await scan();
      return;
    }
    await _connect(device);
  }

  Future<void> _connect(BluetoothDevice device) async {
    await _stopScanIfNeeded();
    _hasBeenConnected = false;
    await _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen(_onConnectionState);
    _update(
      status: HeadsetConnectionStatus.connecting,
      selectedDeviceId: device.remoteId.str,
      batteryLevel: null,
      message: 'Connecting to ${_displayNameFor(device.remoteId.str)}…',
    );

    try {
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
      );
      if (!device.isConnected) {
        await device.connectionState
            .where((state) => state == BluetoothConnectionState.connected)
            .first
            .timeout(const Duration(seconds: 15));
      }
      if (!device.isConnected) throw StateError('BLE link was not confirmed.');

      _hasBeenConnected = true;
      _update(
        status: HeadsetConnectionStatus.connected,
        message: 'Connected to ${_displayNameFor(device.remoteId.str)}.',
      );
      await _readBattery(device);
    } catch (_) {
      if (_snapshot.status != HeadsetConnectionStatus.connectionLost) {
        _update(
          status: HeadsetConnectionStatus.connectionFailed,
          batteryLevel: null,
          message: 'Could not connect to this BLE device. Check it is nearby and try again.',
        );
      }
    }
  }

  void _onConnectionState(BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.connected) {
      _hasBeenConnected = true;
      return;
    }
    if (!_hasBeenConnected) return;

    _hasBeenConnected = false;
    _stopBatteryUpdates();
    _update(
      status: HeadsetConnectionStatus.connectionLost,
      batteryLevel: null,
      message: 'The headset disconnected. Reconnect before continuing.',
    );
  }

  Future<void> _readBattery(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      if (!device.isConnected) {
        _update(batteryLevel: null);
        return;
      }
      BluetoothCharacteristic? battery;
      for (final service in services) {
        if (service.uuid == _batteryService) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid == _batteryLevelCharacteristic) {
              battery = characteristic;
              break;
            }
          }
        }
      }

      if (battery == null) {
        _stopBatteryUpdates();
        _update(batteryLevel: null);
        return;
      }

      _batteryCharacteristic = battery;
      _batteryPollTimer?.cancel();
      await _batterySubscription?.cancel();
      _batterySubscription = null;

      if (battery.properties.read) {
        _publishBattery(await battery.read());
      }
      if (battery.properties.notify || battery.properties.indicate) {
        await battery.setNotifyValue(true);
        _batterySubscription = battery.onValueReceived.listen(_publishBattery);
      } else if (battery.properties.read) {
        _batteryPollTimer = Timer.periodic(
          const Duration(minutes: 1),
          (_) => unawaited(_pollBattery()),
        );
      }
    } catch (_) {
      // Battery access is optional; a valid BLE connection remains connected.
      _stopBatteryUpdates();
      _update(batteryLevel: null);
    }
  }

  Future<void> _pollBattery() async {
    final characteristic = _batteryCharacteristic;
    if (characteristic == null || !_snapshot.isConnected) return;
    try {
      _publishBattery(await characteristic.read());
    } catch (_) {
      _update(batteryLevel: null);
    }
  }

  void _stopBatteryUpdates() {
    _batteryPollTimer?.cancel();
    _batteryPollTimer = null;
    _batterySubscription?.cancel();
    _batterySubscription = null;
    _batteryCharacteristic = null;
  }

  void _publishBattery(List<int> value) {
    if (!_snapshot.isConnected) {
      _update(batteryLevel: null);
      return;
    }
    if (value.isEmpty || value.first < 0 || value.first > 100) {
      _update(batteryLevel: null);
      return;
    }
    _update(batteryLevel: value.first);
  }

  String _displayNameFor(String id) {
    for (final device in _snapshot.devices) {
      if (device.id == id) return device.name;
    }
    return 'BLE device';
  }

  Future<void> _stopScanIfNeeded() async {
    if (!FlutterBluePlus.isScanningNow) return;
    try {
      if (!kIsWeb) await FlutterBluePlus.stopScan();
    } catch (_) {
      // Connecting can continue if the scan already stopped on its own.
    }
  }

  @override
  Future<bool> openBluetoothSettings() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _settingsChannel.invokeMethod<void>('openBluetoothSettings');
      return true;
    }
    return false;
  }

  void _update({
    HeadsetConnectionStatus? status,
    List<HeadsetDevice>? devices,
    String? selectedDeviceId,
    bool clearSelectedDevice = false,
    bool? isInitializing,
    int? batteryLevel,
    String? message,
  }) {
    if (_disposed) return;
    _snapshot = HeadsetSnapshot(
      status: status ?? _snapshot.status,
      isInitializing: isInitializing ?? _snapshot.isInitializing,
      devices: devices ?? _snapshot.devices,
      selectedDeviceId: clearSelectedDevice
          ? null
          : selectedDeviceId ?? _snapshot.selectedDeviceId,
      batteryLevel: batteryLevel,
      message: message,
    );
    _changes.add(_snapshot);
  }

  @override
  void dispose() {
    _disposed = true;
    _scanResultsSubscription?.cancel();
    _adapterSubscription?.cancel();
    _connectionSubscription?.cancel();
    _stopBatteryUpdates();
    _changes.close();
  }
}
