import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindspeak_flutter/bluetooth/headset_bluetooth.dart';
import 'package:mindspeak_flutter/main.dart';

void main() {
  testWidgets('Continue stays disabled until a BLE connection is confirmed', (
    tester,
  ) async {
    final gateway = _FakeHeadsetGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectHeadsetScreen(
          needsCalibration: false,
          bluetoothGateway: gateway,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Disconnected'), findsOneWidget);
    expect(_continueButton(tester).onPressed, isNull);
    expect(find.text('No BLE device selected'), findsOneWidget);
    expect(find.text('Scan for devices'), findsOneWidget);
    expect(find.text('Open Bluetooth settings'), findsOneWidget);
    expect(find.text('Battery unavailable'), findsOneWidget);
    expect(find.textContaining('signal'), findsNothing);

    gateway.emit(
      const HeadsetSnapshot(
        status: HeadsetConnectionStatus.scanning,
        message: 'Searching for nearby BLE devices…',
      ),
    );
    await tester.pump();
    expect(find.text('Scanning for devices'), findsOneWidget);
    expect(_continueButton(tester).onPressed, isNull);

    gateway.emit(
      const HeadsetSnapshot(
        status: HeadsetConnectionStatus.connecting,
        message: 'Connecting to Test BLE peripheral…',
      ),
    );
    await tester.pump();
    expect(find.text('Connecting'), findsOneWidget);
    expect(_continueButton(tester).onPressed, isNull);

    gateway.emit(
      const HeadsetSnapshot(
        status: HeadsetConnectionStatus.bluetoothUnavailable,
        message: 'Bluetooth is unavailable.',
      ),
    );
    await tester.pump();
    expect(find.text('Bluetooth unavailable'), findsOneWidget);
    expect(_continueButton(tester).onPressed, isNull);

    gateway.emit(
      const HeadsetSnapshot(
        status: HeadsetConnectionStatus.connectionFailed,
        message: 'The connection failed.',
      ),
    );
    await tester.pump();
    expect(find.text('Connection failed'), findsOneWidget);
    expect(_continueButton(tester).onPressed, isNull);

    gateway.dispose();
  });

  testWidgets('selected BLE device can connect and then continue', (
    tester,
  ) async {
    final gateway = _FakeHeadsetGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectHeadsetScreen(
          needsCalibration: false,
          bluetoothGateway: gateway,
        ),
      ),
    );
    await tester.pump();

    const device = HeadsetDevice(id: 'test-id', name: 'Test BLE peripheral');
    gateway.emit(
      const HeadsetSnapshot(
        status: HeadsetConnectionStatus.disconnected,
        devices: [device],
        message: 'Select the headset you want to connect.',
      ),
    );
    await tester.pump();
    final deviceTile = find.ancestor(
      of: find.text('Test BLE peripheral'),
      matching: find.byType(ListTile),
    );
    await tester.ensureVisible(deviceTile);
    await tester.tap(deviceTile);
    await tester.pump();
    expect(find.text('Selected device'), findsOneWidget);
    expect(_continueButton(tester).onPressed, isNull);

    await tester.tap(find.text('Connect to selected device'));
    await tester.pump();
    expect(find.text('Connecting'), findsOneWidget);
    expect(_continueButton(tester).onPressed, isNull);

    gateway.emit(
      const HeadsetSnapshot(
        status: HeadsetConnectionStatus.connected,
        devices: [device],
        selectedDeviceId: 'test-id',
        batteryLevel: 73,
        message: 'Connected to Test BLE peripheral.',
      ),
    );
    await tester.pump();
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Battery 73%'), findsOneWidget);
    expect(_continueButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('YOUR MESSAGE'), findsOneWidget);

    gateway.dispose();
  });

  testWidgets('a live disconnection updates Home without blocking messages', (
    tester,
  ) async {
    final gateway = _FakeHeadsetGateway(
      initial: const HeadsetSnapshot(
        status: HeadsetConnectionStatus.connected,
        devices: [HeadsetDevice(id: 'test-id', name: 'Test BLE peripheral')],
        selectedDeviceId: 'test-id',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectHeadsetScreen(
          needsCalibration: false,
          bluetoothGateway: gateway,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('YOUR MESSAGE'), findsOneWidget);

    gateway.emit(
      const HeadsetSnapshot(
        status: HeadsetConnectionStatus.connectionLost,
        devices: [HeadsetDevice(id: 'test-id', name: 'Test BLE peripheral')],
        selectedDeviceId: 'test-id',
        message: 'The headset disconnected.',
      ),
    );
    await tester.pump();
    expect(
      find.text('Disconnected · EEG device not configured'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home_message_field')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('speak_button')))
          .onPressed,
      isNotNull,
    );

    gateway.dispose();
  });
}

FilledButton _continueButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));

class _FakeHeadsetGateway implements HeadsetBluetoothGateway {
  _FakeHeadsetGateway({HeadsetSnapshot initial = const HeadsetSnapshot()})
    : _snapshot = initial;

  final _controller = StreamController<HeadsetSnapshot>.broadcast(sync: true);
  HeadsetSnapshot _snapshot;

  @override
  HeadsetSnapshot get snapshot => _snapshot;

  @override
  Stream<HeadsetSnapshot> get changes => _controller.stream;

  void emit(HeadsetSnapshot value) {
    _snapshot = value;
    _controller.add(value);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scan() async {
    emit(
      const HeadsetSnapshot(
        status: HeadsetConnectionStatus.scanning,
        message: 'Searching for nearby BLE devices…',
      ),
    );
  }

  @override
  void selectDevice(String? deviceId) {
    emit(
      HeadsetSnapshot(
        status: _snapshot.status,
        devices: _snapshot.devices,
        selectedDeviceId: deviceId,
        message: _snapshot.message,
      ),
    );
  }

  @override
  Future<void> connectSelected() async {
    emit(
      HeadsetSnapshot(
        status: HeadsetConnectionStatus.connecting,
        devices: _snapshot.devices,
        selectedDeviceId: _snapshot.selectedDeviceId,
        message: 'Connecting…',
      ),
    );
  }

  @override
  Future<void> reconnect() async {}

  @override
  Future<bool> openBluetoothSettings() async => false;

  @override
  void dispose() => _controller.close();
}
