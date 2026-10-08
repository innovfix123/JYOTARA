import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jyotara/services/meta_measurement.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<MethodCall> calls;
  var available = true;
  setUp(() {
    available = true;
    calls = [];
    SharedPreferences.setMockInitialValues({'singular.analytics': true});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MetaMeasurement.channel, (call) async {
          calls.add(call);
          if (call.method == 'configured') return available;
          if (call.method == 'consent') return call.arguments;
          return null;
        });
  });
  test(
    'Singular consent does not enable Meta; revocation blocks future events',
    () async {
      final service = MetaMeasurement(supported: true);
      await service.initialize();
      await service.event('chat_completed');
      expect(service.enabled, false);
      expect(calls.where((c) => c.method == 'event'), isEmpty);
      await service.setConsent(true);
      await service.event('login_success');
      await service.event('question_text');
      expect(calls.where((c) => c.method == 'event').map((c) => c.arguments), [
        'fb_mobile_activate_app',
        'login_success',
      ]);
      await service.setConsent(false);
      await service.event('chat_completed');
      expect(calls.where((c) => c.method == 'event').length, 2);
    },
  );
  test('unconfigured build never initializes native SDK', () async {
    available = false;
    final service = MetaMeasurement(supported: true);
    await service.initialize();
    await service.setConsent(true);
    await service.event('login_success');
    expect(calls.map((c) => c.method), ['configured']);
    expect(service.configured, false);
  });
  test('stored Meta consent restores one app-open event', () async {
    SharedPreferences.setMockInitialValues({'meta.measurement': true});
    final service = MetaMeasurement(supported: true);
    await service.initialize();
    expect(service.enabled, true);
    expect(
      calls.where((c) => c.method == 'event').single.arguments,
      'fb_mobile_activate_app',
    );
  });
}
