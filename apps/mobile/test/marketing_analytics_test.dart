import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jyotara/services/marketing_analytics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('singular-api');
  late List<MethodCall> calls;
  setUp(() {
    calls = [];
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  MarketingAnalytics service() => MarketingAnalytics(
    supported: true,
    sdkKey: 'sdk-test',
    sdkSecret: 'secret-test',
  );
  test(
    'no SDK start or events before separate consent; ads remain restricted',
    () async {
      final analytics = service();
      await analytics.initialize();
      await analytics.event('login_success');
      expect(calls.map((c) => c.method), ['stopAllTracking']);
      await analytics.setConsent(true);
      final config =
          calls.singleWhere((c) => c.method == 'start').arguments as Map;
      expect(config['limitAdvertisingIdentifiers'], true);
      expect(config['limitDataSharing'], true);
      expect(config.containsKey('customUserId'), false);
      await analytics.event('login_success');
      await analytics.event('user_question');
      expect(
        calls
            .where(
              (c) =>
                  c.method == 'event' &&
                  c.arguments['eventName'] == 'login_success',
            )
            .length,
        1,
      );
      await analytics.setConsent(false);
      await analytics.event('chat_completed');
      expect(
        calls
            .where(
              (c) =>
                  c.method == 'event' &&
                  c.arguments['eventName'] == 'login_success',
            )
            .length,
        1,
      );
    },
  );
  test('server-confirmed live orders only; no grants, test purchases or duplicate revenue', () async {
    final analytics = service();
    await analytics.initialize();
    await analytics.setConsent(true);
    await analytics.purchaseStarted('live-order', 'live');
    await analytics.purchaseStarted('test-order', 'test');
    await analytics.purchaseStarted('grant-order', 'live');
    final data = <String, dynamic>{
      'mode': 'live',
      'orders': [
        {'id': 'live-order', 'amount': 14900, 'status': 'created'},
        {'id': 'historic-order', 'amount': 49900, 'status': 'paid'},
        {
          'id': 'grant-order',
          'amount': 14900,
          'status': 'paid',
          'payment_method': 'review_grant',
        },
        {'id': 'test-order', 'amount': 49900, 'status': 'paid'},
      ],
    };
    await analytics.reconcilePurchases(data);
    expect(calls.where((c) => c.method == 'customRevenue'), isEmpty);
    (data['orders'] as List)[0]['status'] = 'paid';
    await analytics.reconcilePurchases(data);
    await analytics.reconcilePurchases(data);
    final revenues = calls.where((c) => c.method == 'customRevenue').toList();
    expect(revenues.length, 1);
    expect(revenues.single.arguments, {
      'eventName': 'recharge_verified',
      'currency': 'INR',
      'amount': 149.0,
    });
  });
}
