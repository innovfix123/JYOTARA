import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:singular_flutter_sdk/singular.dart';
import 'package:singular_flutter_sdk/singular_config.dart';

final marketingAnalytics = MarketingAnalytics();

/// Optional marketing measurement. Never receives names, phone numbers,
/// birth details, questions, answers or Jyotara authentication tokens.
class MarketingAnalytics extends ChangeNotifier {
  MarketingAnalytics({
    this.sdkKey = const String.fromEnvironment('JYOTARA_SINGULAR_SDK_KEY'),
    this.sdkSecret = const String.fromEnvironment(
      'JYOTARA_SINGULAR_SDK_SECRET',
    ),
    bool? supported,
  }) : supported =
           supported ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  final String sdkKey, sdkSecret;
  final bool supported;
  bool enabled = false;
  bool _started = false;
  Future<void> _queue = Future.value();
  SharedPreferences? _prefs;
  bool get configured => supported && sdkKey.isNotEmpty && sdkSecret.isNotEmpty;

  // The vendor's void methods launch platform futures. Isolate those failures
  // as well as synchronous errors so measurement cannot break login or payment.
  void _native(void Function() action) {
    runZonedGuarded(action, (Object _, StackTrace _) {});
  }

  Future<void> _serialize(Future<void> Function() action) {
    _queue = _queue.then((_) => action()).catchError((Object _) {});
    return _queue;
  }

  Future<void> initialize() => _serialize(() async {
    if (!configured) return;
    _prefs ??= await SharedPreferences.getInstance();
    _applyConsent(_prefs!.getBool('singular.analytics') == true);
  });

  Future<void> setConsent(bool value) => _serialize(() async {
    if (!configured) return;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('singular.analytics', value);
    _applyConsent(value);
  });

  void _applyConsent(bool value) {
    enabled = value;
    notifyListeners();
    if (!value) {
      _native(Singular.stopAllTracking);
      return;
    }
    final firstStart = !_started;
    if (firstStart) {
      final config = SingularConfig(sdkKey, sdkSecret)
        ..limitAdvertisingIdentifiers = true
        ..limitDataSharing = true
        ..enableLogging = false;
      _native(() => Singular.start(config));
      _started = true;
    }
    _native(Singular.resumeAllTracking);
    if (firstStart) {
      _native(() => Singular.event('measurement_started'));
    }
  }

  static const _allowedEvents = {
    'login_success',
    'chat_completed',
    'recharge_started',
  };
  Future<void> event(String name) => _serialize(() async {
    if (!configured || !enabled || !_allowedEvents.contains(name)) return;
    _native(() => Singular.event(name));
  });

  /// Only orders started on this installation are eligible: history scans must
  /// not turn previous purchases, grants or test orders into fresh revenue.
  Future<void> purchaseStarted(String id, String mode) => _serialize(() async {
    if (!configured || !enabled || mode != 'live' || id.isEmpty) return;
    _prefs ??= await SharedPreferences.getInstance();
    final pending = _prefs!.getStringList('singular.pending-orders') ?? [];
    final sent = _prefs!.getStringList('singular.sent-orders') ?? [];
    if (!pending.contains(id) && !sent.contains(id)) {
      await _prefs!.setStringList('singular.pending-orders', [...pending, id]);
      _native(() => Singular.event('recharge_started'));
    }
  });

  Future<void> reconcilePurchases(
    Map<String, dynamic> data,
  ) => _serialize(() async {
    if (!configured || !enabled || data['mode'] != 'live') return;
    _prefs ??= await SharedPreferences.getInstance();
    final pending = _prefs!.getStringList('singular.pending-orders') ?? [];
    final sent = _prefs!.getStringList('singular.sent-orders') ?? [];
    for (final order in (data['orders'] as List? ?? []).whereType<Map>()) {
      final id = order['id'];
      final amount = num.tryParse('${order['amount']}');
      if (id is! String ||
          !pending.contains(id) ||
          sent.contains(id) ||
          order['status'] != 'paid' ||
          order['payment_method'] == 'review_grant' ||
          amount == null ||
          amount <= 0) {
        continue;
      }
      // Persist before dispatch for at-most-once client reporting. The server's
      // captured ledger remains authoritative; this is not accounting data.
      await _prefs!.setStringList('singular.sent-orders', [...sent, id]);
      sent.add(id);
      pending.remove(id);
      await _prefs!.setStringList('singular.pending-orders', pending);
      _native(
        () => Singular.customRevenue('recharge_verified', 'INR', amount / 100),
      );
    }
  });
}
