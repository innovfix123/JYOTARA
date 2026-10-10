import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

final userJourney = UserJourney();

/// First-party operational activity only. Never send entered field values,
/// names, birth details, chat text, login codes or payment credentials here.
/// This service is independent of optional Singular, Meta and Firebase consent.
class UserJourney with WidgetsBindingObserver {
  UserJourney({
    http.Client? client,
    DateTime Function()? now,
    String Function()? identifier,
    this.readQueue,
    this.writeQueue,
    this.automaticFlush = true,
  }) : _client = client ?? http.Client(),
       _now = now ?? DateTime.now,
       _identifier = identifier ?? _randomId;

  static String _randomId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  final http.Client _client;
  final DateTime Function() _now;
  final String Function() _identifier;
  final Future<String?> Function()? readQueue;
  final Future<void> Function(String)? writeQueue;
  final bool automaticFlush;
  final List<Map<String, dynamic>> _pending = [];
  Future<void> _writes = Future.value();
  Timer? _flushTimer;
  Timer? _periodic;
  Uri? _base;
  String? Function()? _account;
  String? Function()? _token;
  String? Function()? _testerCode;
  String? _owner;
  String? _session;
  int _sequence = 0;
  String _screen = 'entry';
  bool _initialized = false, _flushing = false, _disposed = false;
  SharedPreferences? _prefs;
  int _lastScroll = 0;
  String? get currentAccount => _owner;
  int get pendingCount => _pending.length;
  String get currentScreen => _screen;
  late final NavigatorObserver navigatorObserver = _JourneyNavigation(this);

  static const events = {
    'app.open',
    'app.foreground',
    'app.background',
    'app.exit',
    'screen.view',
    'screen.leave',
    'interaction.tap',
    'interaction.scroll',
    'navigation.back',
    'navigation.tab',
    'auth.send',
    'auth.verify',
    'auth.restore',
    'auth.logout',
    'auth.delete',
    'profile.create',
    'profile.update',
    'profile.restore',
    'profile.delete',
    'chat.start',
    'chat.trial_offer',
    'chat.trial_start',
    'chat.trial_end',
    'chat.trial_recharge',
    'chat.send',
    'chat.answer',
    'chat.receipt',
    'chat.present',
    'chat.end',
    'chat.back',
    'chat.settings',
    'matching.start',
    'matching.complete',
    'matching.add',
    'matching.delete',
    'matching.share',
    'daily.open',
    'daily.expand',
    'explore.open',
    'explore.reading',
    'payment.start',
    'payment.verify',
    'payment.refresh',
    'payment.checkout',
    'settings.change',
    'notification.open',
    'notification.received',
    'notification.permission',
    'support.send',
    'api.request',
    'api.result',
    'app.error',
  };
  static const screens = {
    'entry',
    'welcome',
    'login',
    'otp',
    'onboarding',
    'birth_details',
    'home',
    'daily',
    'explore',
    'ask',
    'chat',
    'profile',
    'matching',
    'matching_result',
    'matching_studio',
    'wallet',
    'checkout',
    'settings',
    'notifications',
    'support',
    'birth_chart',
    'reading',
    'dialog',
    'other',
  };
  static const metadataValues = <String, Set<String>>{
    'outcome': {
      'started',
      'success',
      'failed',
      'cancelled',
      'pending',
      'unavailable',
      'restored',
      'resumed',
      'blocked',
    },
    'feature': {
      'auth',
      'profile',
      'chat',
      'matching',
      'daily',
      'explore',
      'wallet',
      'settings',
      'notification',
      'support',
      'birth_chart',
      'location',
      'other',
    },
    'control': {
      'primary',
      'back',
      'close',
      'tab',
      'menu',
      'login',
      'otp',
      'resend',
      'save',
      'edit',
      'delete',
      'add_person',
      'select_person',
      'match',
      'share',
      'send',
      'end_chat',
      'language',
      'guide',
      'category',
      'recharge',
      'payment_refresh',
      'consent',
      'notification',
      'support',
      'other',
    },
    'language': {'en', 'ta', 'tanglish'},
    'error': {
      'network',
      'timeout',
      'unauthorized',
      'validation',
      'unavailable',
      'provider',
      'payment',
      'storage',
      'unknown',
    },
    'source': {'touch', 'keyboard', 'system', 'api', 'app', 'push'},
  };
  static Map<String, dynamic> safeMetadata(Map<String, dynamic> values) {
    final safe = <String, dynamic>{};
    for (final entry in values.entries) {
      if (entry.key == 'requestRef' &&
          entry.value is String &&
          RegExp(r'^[A-Za-z0-9_-]{32}$').hasMatch(entry.value)) {
        safe[entry.key] = entry.value;
      } else if (metadataValues[entry.key]?.contains(entry.value) == true) {
        safe[entry.key] = entry.value;
      } else if (const {'status', 'durationMs', 'count'}.contains(entry.key) &&
          entry.value is int &&
          entry.value >= 0 &&
          entry.value <=
              (entry.key == 'status'
                  ? 599
                  : entry.key == 'durationMs'
                  ? 86400000
                  : 1000000)) {
        safe[entry.key] = entry.value;
      }
    }
    return safe;
  }

  Future<void> initialize({
    required String baseUrl,
    required String? Function() account,
    required String? Function() token,
    String? Function()? testerCode,
  }) async {
    if (_initialized || _disposed) return;
    _initialized = true;
    _account = account;
    _token = token;
    _testerCode = testerCode;
    final base = Uri.tryParse(baseUrl);
    if (base?.scheme == 'https' &&
        base!.host.isNotEmpty &&
        base.userInfo.isEmpty) {
      _base = base;
    }
    try {
      if (readQueue == null) _prefs = await SharedPreferences.getInstance();
      final raw =
          await (readQueue?.call() ??
              Future.value(_prefs?.getString('journey.pending.v1')));
      if (raw != null) {
        final saved = jsonDecode(raw);
        if (saved is List) {
          for (final value in saved.whereType<Map>().take(500)) {
            final event = Map<String, dynamic>.from(value);
            if (_validStored(event)) _pending.add(event);
          }
        }
      }
    } catch (_) {
      /* Diagnostic storage failure never blocks app entry. */
    }
    _synchronizeIdentity();
    WidgetsBinding.instance.addObserver(this);
    event('app.open', metadata: {'source': 'app'});
    if (automaticFlush) {
      _periodic = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(flush()),
      );
    }
  }

  bool _validStored(Map<String, dynamic> event) =>
      event.keys.every(
        (k) => const {
          'id',
          'sessionId',
          'sequence',
          'name',
          'screen',
          'at',
          'metadata',
          'owner',
        }.contains(k),
      ) &&
      event['id'] is String &&
      RegExp(r'^[a-f0-9]{32}$').hasMatch(event['id']) &&
      event['sessionId'] is String &&
      RegExp(r'^[a-f0-9]{32}$').hasMatch(event['sessionId']) &&
      event['sequence'] is int &&
      event['sequence'] > 0 &&
      events.contains(event['name']) &&
      screens.contains(event['screen']) &&
      event['at'] is int &&
      event['at'] > 0 &&
      (event['owner'] == null || event['owner'] is String) &&
      event['metadata'] is Map &&
      jsonEncode(event['metadata']) ==
          jsonEncode(
            safeMetadata(Map<String, dynamic>.from(event['metadata'])),
          );

  void _synchronizeIdentity() {
    final account = _token?.call() != null ? _account?.call() : null;
    if (account == _owner && _session != null) return;
    _owner = account;
    _session = _identifier();
    _sequence = 0;
    // Never submit one account's unsent history under another account's login.
    if (account != null) {
      _pending.removeWhere((e) => e['owner'] != null && e['owner'] != account);
    }
    if (account != null) {
      for (final event in _pending.where((e) => e['owner'] == null)) {
        event['owner'] = account;
      }
    }
    _persist();
  }

  void event(String name, {Map<String, dynamic> metadata = const {}}) {
    if (_disposed || !events.contains(name)) return;
    _synchronizeIdentity();
    _pending.add({
      'id': _identifier(),
      'sessionId': _session!,
      'sequence': ++_sequence,
      'name': name,
      'screen': _screen,
      'at': _now().millisecondsSinceEpoch,
      'metadata': safeMetadata(metadata),
      'owner': _owner,
    });
    if (_pending.length > 500) _pending.removeRange(0, _pending.length - 500);
    _persist();
    if (automaticFlush && _owner != null && _flushTimer == null) {
      _flushTimer = Timer(const Duration(seconds: 3), () {
        _flushTimer = null;
        unawaited(flush());
      });
    }
  }

  void screen(String name) {
    if (!screens.contains(name) || name == _screen) return;
    event('screen.leave');
    _screen = name;
    event('screen.view');
    if (name == 'daily') event('daily.open', metadata: {'feature': 'daily'});
    if (name == 'explore') {
      event('explore.open', metadata: {'feature': 'explore'});
    }
  }

  void tap(String control, {String? feature}) => event(
    'interaction.tap',
    metadata: {'control': control, 'feature': feature, 'source': 'touch'},
  );
  void scroll() {
    final now = _now().millisecondsSinceEpoch;
    if (now - _lastScroll < 1500) return;
    _lastScroll = now;
    event('interaction.scroll', metadata: {'source': 'touch'});
  }

  Future<void> _persist() {
    final value = jsonEncode(_pending);
    _writes = _writes
        .then((_) async {
          if (writeQueue != null) {
            await writeQueue!(value);
          } else {
            await _prefs?.setString('journey.pending.v1', value);
          }
        })
        .catchError((Object _) {});
    return _writes;
  }

  Future<void> flush() async {
    if (_flushing || _disposed || _base == null) return;
    _synchronizeIdentity();
    final account = _owner, token = _token?.call();
    if (account == null || token == null) return;
    final batch = _pending
        .where((e) => e['owner'] == account)
        .take(50)
        .toList();
    if (batch.isEmpty) return;
    _flushing = true;
    try {
      final response = await _client
          .post(
            _base!.resolve('/api/user-journey'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              if (_testerCode?.call() case final String tester)
                'X-Jyotara-Tester-Code': tester,
            },
            body: jsonEncode({
              'events': batch.map((e) => {...e}..remove('owner')).toList(),
            }),
          )
          .timeout(const Duration(seconds: 5));
      // Failed/ambiguous batches retain exact IDs for safe retry after reconnect.
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final ids = json is Map && json['accepted'] is List
            ? (json['accepted'] as List).whereType<String>().toSet()
            : <String>{};
        final sent = batch.map((e) => e['id']).toSet();
        _pending.removeWhere(
          (e) =>
              e['owner'] == account &&
              sent.contains(e['id']) &&
              ids.contains(e['id']),
        );
        await _persist();
      } else if (response.statusCode == 422 || response.statusCode == 413) {
        // A corrupted batch cannot permanently block later valid diagnostics.
        final ids = batch.map((e) => e['id']).toSet();
        _pending.removeWhere(
          (e) => e['owner'] == account && ids.contains(e['id']),
        );
        await _persist();
      }
    } catch (_) {
      /* Best effort: no diagnostic error is shown to the user. */
    } finally {
      _flushing = false;
    }
  }

  Future<void> beforeLogout() async {
    event('auth.logout', metadata: {'outcome': 'started', 'feature': 'auth'});
    await flush().timeout(const Duration(milliseconds: 800), onTimeout: () {});
  }

  Future<void> discardAccount() async {
    // Token getters can already be disabled during deletion. Clear the entire
    // departing flow, including anonymous steps, rather than guessing its owner.
    _pending.clear();
    _owner = null;
    _session = _identifier();
    _sequence = 0;
    await _persist();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      event('app.foreground', metadata: {'source': 'system'});
      unawaited(flush());
    } else if (state == AppLifecycleState.paused) {
      event('app.background', metadata: {'source': 'system'});
      unawaited(flush());
    } else if (state == AppLifecycleState.detached) {
      event('app.exit', metadata: {'source': 'system'});
      unawaited(flush());
    }
  }

  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _periodic?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _client.close();
  }
}

/// App-level pointer recording contains only the current screen, never a text
/// field's value, accessibility label, touch coordinates or widget contents.
class UserJourneyBoundary extends StatelessWidget {
  const UserJourneyBoundary({super.key, required this.child, this.journey});
  final Widget child;
  final UserJourney? journey;
  @override
  Widget build(BuildContext context) {
    final service = journey ?? userJourney;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) =>
          service.event('interaction.tap', metadata: {'source': 'touch'}),
      child: NotificationListener<ScrollStartNotification>(
        onNotification: (notification) {
          if (notification.dragDetails != null) service.scroll();
          return false;
        },
        child: child,
      ),
    );
  }
}

class _JourneyNavigation extends NavigatorObserver {
  _JourneyNavigation(this.journey);
  final UserJourney journey;
  final Map<Route<dynamic>, String> _screens = {};
  void _visit(Route<dynamic>? route) {
    final name = route?.settings.name?.replaceFirst(RegExp(r'^/'), '');
    journey.screen(
      UserJourney.screens.contains(name)
          ? name!
          : route is PopupRoute
          ? 'dialog'
          : _screens[route] ?? journey.currentScreen,
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _screens[previousRoute] = journey.currentScreen;
    _visit(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    journey.event('navigation.back', metadata: {'source': 'system'});
    _visit(previousRoute);
    _screens.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _screens.remove(oldRoute);
    _visit(newRoute);
  }
}
