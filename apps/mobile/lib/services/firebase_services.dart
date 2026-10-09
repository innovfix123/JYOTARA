import 'dart:async';

import 'notification_inbox.dart';
import 'user_journey.dart';
import '../payment_support.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Android displays notification payloads. Never log notification contents.
}

final firebaseServices = FirebaseServices();

class FirebaseServices extends ChangeNotifier with WidgetsBindingObserver {
  bool ready = false;
  bool analytics = false;
  bool crashReports = false;
  bool notifications = false;
  final incoming = StreamController<RemoteMessage>.broadcast();
  static const _topic = 'jyotara_updates';
  SharedPreferences? _prefs;
  AccountService? accountApi;
  String Function()? language;
  final opened = StreamController<String>.broadcast();
  bool _registering = false;
  String? _registration;
  Future<void> offerNotifications(BuildContext context) async {
    await initialize();
    if (!ready ||
        notifications ||
        _prefs?.containsKey('firebase.notifications') == true ||
        _prefs?.getBool('firebase.notificationOffer') == true ||
        !context.mounted) {
      return;
    }
    await _prefs!.setBool('firebase.notificationOffer', true);
    if (!context.mounted) return;
    final tamil = language?.call() == 'ta';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tamil
              ? 'உங்கள் நாளுக்குச் சிறிய வழிகாட்டல்'
              : 'A little guidance for your day',
        ),
        content: Text(
          tamil
              ? 'தினசரி வழிகாட்டல் மற்றும் நினைவூட்டல்களை இயக்கவா? காலை 9 முதல் இரவு 9 வரை தினமும் அதிகபட்சம் இரண்டு. அமைப்புகளில் நிறுத்தலாம்.'
              : 'Enable daily and feature reminders? Up to two per day, between 9 am and 9 pm. You can turn them off in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tamil ? 'இப்போது வேண்டாம்' : 'Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tamil ? 'நினைவூட்டல்களை இயக்கு' : 'Enable reminders'),
          ),
        ],
      ),
    );
    userJourney.event(
      'notification.permission',
      metadata: {
        'feature': 'notification',
        'outcome': accepted == true ? 'started' : 'cancelled',
      },
    );
    if (accepted == true) {
      try {
        final enabled = await setNotifications(true);
        userJourney.event(
          'notification.permission',
          metadata: {
            'feature': 'notification',
            'outcome': enabled ? 'success' : 'blocked',
          },
        );
      } catch (_) {
        /* Settings remains available to retry. */
      }
    }
  }

  Future<void> syncDevice() async {
    final api = accountApi;
    if (ready &&
        !notifications &&
        api?.token() != null &&
        _prefs?.getBool('firebase.notifications') == false) {
      try {
        await api!.post('/api/notifications/disable', {});
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {
        /* Retry revocation on the next resume. */
      }
    }
    if (!ready || !notifications || api == null || api.token() == null) {
      _registration = null;
      return;
    }
    if (_registering) return;
    _registering = true;
    try {
      final permission = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (permission.authorizationStatus != AuthorizationStatus.authorized) {
        await api.post('/api/notifications/disable', {});
        _registration = null;
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final owner = api.account(), lang = language?.call() ?? 'en';
      final stamp = '$owner:$token:$lang';
      if (_registration == stamp) return;
      await api.post('/api/notifications/register', {
        'token': token,
        'language': lang,
        'build': 146,
      });
      if (owner == api.account()) _registration = stamp;
    } catch (_) {
      /* Registration retries on resume; never block app use. */
    } finally {
      _registering = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncDevice());
  }

  Future<void>? _initializing;
  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Firebase.initializeApp();
      _prefs = await SharedPreferences.getInstance();
      analytics = _prefs!.getBool('firebase.analytics') ?? false;
      crashReports = _prefs!.getBool('firebase.crashes') ?? false;
      notifications = _prefs!.getBool('firebase.notifications') ?? false;
      await FirebaseAnalytics.instance.setConsent(
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
        analyticsStorageConsentGranted: analytics,
      );
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(analytics);
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        crashReports,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
      await notificationInbox.restore();
      WidgetsBinding.instance.addObserver(this);
      FirebaseMessaging.instance.onTokenRefresh.listen((_) {
        _registration = null;
        unawaited(syncDevice());
      });
      FirebaseMessaging.onMessage.listen(_receive);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _receive(message, wasOpened: true),
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) await _receive(initial, wasOpened: true);
      final previousHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        previousHandler?.call(details);
        report(details.exception, details.stack ?? StackTrace.current);
      };
      final previousAsyncHandler = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (error, stack) {
        report(error, stack, fatal: true);
        return previousAsyncHandler?.call(error, stack) ?? false;
      };
      ready = true;
      if (notifications) {
        final permission = await FirebaseMessaging.instance
            .getNotificationSettings();
        if (permission.authorizationStatus == AuthorizationStatus.authorized) {
          await FirebaseMessaging.instance.setAutoInitEnabled(true);
          await FirebaseMessaging.instance.subscribeToTopic(_topic);
        } else {
          await setNotifications(false);
        }
      }
    } catch (_) {
      // Monitoring must never prevent sign-in or readings from loading.
      ready = false;
    }
    notifyListeners();
    await syncDevice();
  }

  Future<void> _receive(RemoteMessage message, {bool wasOpened = false}) async {
    if (!notifications) return;
    final campaign = message.data['campaignId'];
    if (campaign is String && RegExp(r'^[a-f0-9]{32}$').hasMatch(campaign)) {
      try {
        final result = await accountApi?.post('/api/notifications/event', {
          'id': campaign,
          'event': wasOpened ? 'opened' : 'received',
        });
        if (result?['accepted'] != true) return;
      } catch (_) {
        return;
      }
    }
    userJourney.event(
      wasOpened ? 'notification.open' : 'notification.received',
      metadata: {
        'feature': 'notification',
        'source': 'push',
        if (campaign is String && RegExp(r'^[a-f0-9]{32}$').hasMatch(campaign))
          'requestRef': campaign,
      },
    );
    if (wasOpened && message.data['feature'] is String) {
      if ({
        'welcome',
        'daily',
        'matching',
        'chat',
      }.contains(message.data['feature'])) {
        opened.add(message.data['feature']);
      }
    }
    final title = message.notification?.title?.trim() ?? '';
    final body = message.notification?.body?.trim() ?? '';
    if (title.isEmpty && body.isEmpty) return;
    await notificationInbox.add(
      AppNotice(
        id:
            message.messageId ??
            '${message.sentTime?.millisecondsSinceEpoch}:$title:$body',
        title: title.isEmpty ? 'Jyotara' : title,
        body: body,
        account: campaign == null ? null : accountApi?.account(),
        time: message.sentTime ?? DateTime.now(),
      ),
    );
    incoming.add(message);
  }

  void report(Object error, StackTrace stack, {bool fatal = false}) {
    if (!ready || !crashReports) return;
    // Exception text can contain names, birth details, chats or request URLs.
    unawaited(
      FirebaseCrashlytics.instance
          .recordError(error.runtimeType.toString(), stack, fatal: fatal)
          .catchError((Object _) {}),
    );
  }

  Future<void> setAnalytics(bool enabled) async {
    if (!ready) {
      throw StateError(
        'Monitoring is unavailable. Restart the app and try again.',
      );
    }
    await FirebaseAnalytics.instance.setConsent(
      analyticsStorageConsentGranted: enabled,
      adStorageConsentGranted: false,
      adUserDataConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
    );
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
    if (!enabled) await FirebaseAnalytics.instance.resetAnalyticsData();
    await _prefs!.setBool('firebase.analytics', enabled);
    analytics = enabled;
    if (enabled) {
      try {
        await FirebaseAnalytics.instance.logEvent(name: 'monitoring_enabled');
      } catch (_) {
        /* Consent is already saved. */
      }
    }
    notifyListeners();
  }

  Future<void> setCrashReports(bool enabled) async {
    if (!ready) {
      throw StateError(
        'Monitoring is unavailable. Restart the app and try again.',
      );
    }
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
    if (!enabled) await FirebaseCrashlytics.instance.deleteUnsentReports();
    await _prefs!.setBool('firebase.crashes', enabled);
    crashReports = enabled;
    notifyListeners();
  }

  Future<bool> setNotifications(bool enabled) async {
    if (!ready) {
      throw StateError(
        'Notifications are unavailable. Restart the app and try again.',
      );
    }
    if (enabled) {
      final permission = await FirebaseMessaging.instance.requestPermission();
      if (permission.authorizationStatus != AuthorizationStatus.authorized) {
        return false;
      }
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      try {
        await FirebaseMessaging.instance.subscribeToTopic(_topic);
      } catch (_) {
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
        await FirebaseMessaging.instance.deleteToken();
        rethrow;
      }
    } else {
      // Save the user's choice before any network operation. An offline phone
      // must still stop accepting reminders and revoke its FCM registration.
      await _prefs!.setBool('firebase.notifications', false);
      notifications = false;
      _registration = null;
      notifyListeners();
      try {
        if (accountApi?.token() != null) {
          await accountApi!.post('/api/notifications/disable', {});
        }
      } catch (_) {
        /* Revocation retries on resume. */
      }
      try {
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {
        /* The saved opt-out remains authoritative locally. */
      }
    }
    await _prefs!.setBool('firebase.notifications', enabled);
    notifications = enabled;
    await syncDevice();
    notifyListeners();
    return true;
  }
}
