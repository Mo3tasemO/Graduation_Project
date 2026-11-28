import 'dart:async';

import 'package:mindspeak_flutter/animated_waves.dart';

/// Runs before every test file. The background waves animate forever, which
/// would stop `pumpAndSettle` from ever finishing, so tests hold them still.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AnimatedWaves.animate = false;
  await testMain();
}
