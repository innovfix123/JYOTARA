import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One new SMS approved by the user, without inbox access.
/// The login screen decides when a complete code should be verified.
class SmsOtpAutofill {
  static const _channel = MethodChannel('jyotara/otp-autofill');
  int? _attempt;
  int _generation = 0;
  void Function(String)? _onCode;

  Future<void> start(void Function(String) onCode) async {
    final generation = ++_generation;
    _attempt = null;
    _onCode = onCode;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'code') {
        return;
      }
      final data = call.arguments;
      if (data is! Map || data['attempt'] != _attempt || _attempt == null) {
        return;
      }
      final code = data['code'];
      if (code is String && RegExp(r'^[0-9]{6}$').hasMatch(code)) {
        _attempt = null;
        _onCode?.call(code);
      }
    });
    try {
      final attempt = await _channel
          .invokeMethod<int>('start')
          .timeout(const Duration(seconds: 2));
      if (generation == _generation) _attempt = attempt;
    } catch (_) {
      // Missing Play services must never prevent normal SMS login.
    }
  }

  Future<void> stop() async {
    _generation++;
    _attempt = null;
    _onCode = null;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }
}
