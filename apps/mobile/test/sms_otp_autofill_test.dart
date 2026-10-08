import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/sms_otp_autofill.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('jyotara/otp-autofill');
  var attempt = 0;
  Future<void> deliver(int id, String code) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('code', {'attempt': id, 'code': code}),
          ),
          (_) {},
        );
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    attempt = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'start' ? ++attempt : null,
        );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('only the current approved code fills once', () async {
    final service = SmsOtpAutofill();
    final codes = <String>[];
    await service.start(codes.add);
    await deliver(1, '123456');
    await deliver(1, '123456');
    expect(codes, ['123456']);
    await service.stop();
  });
  test('old attempts and codes after logout are ignored', () async {
    final service = SmsOtpAutofill();
    final codes = <String>[];
    await service.start(codes.add);
    await service.start(codes.add);
    await deliver(1, '123456');
    expect(codes, isEmpty);
    await deliver(2, '654321');
    expect(codes, ['654321']);
    await service.stop();
    await deliver(2, '654321');
    expect(codes, ['654321']);
  });
  test('unavailable Play services preserves manual login', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'unavailable'),
        );
    final service = SmsOtpAutofill();
    await service.start((_) => fail('No code expected'));
    await service.stop();
  });
}
