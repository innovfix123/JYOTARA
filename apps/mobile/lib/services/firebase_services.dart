import 'dart:async';

import 'notification_inbox.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Android displays notification payloads. Never log notification contents.
}

final firebaseServices = FirebaseServices();

class FirebaseServices extends ChangeNotifier {
  bool ready = false;
  bool analytics = false;
  bool crashReports = false;
  bool notifications = false;
  final incoming = StreamController<RemoteMessage>.broadcast();
  static const _topic = 'jyotara_updates';
  SharedPreferences? _prefs;

  Future<void> initialize() async {
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
      FirebaseMessaging.onMessage.listen(_receive);
      FirebaseMessaging.onMessageOpenedApp.listen(_receive);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) await _receive(initial);
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
  }

  Future<void> _receive(RemoteMessage message) async {
    if (!notifications) return;
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
      await FirebaseAnalytics.instance.logEvent(name: 'monitoring_enabled');
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
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
      await FirebaseMessaging.instance.deleteToken();
    }
    await _prefs!.setBool('firebase.notifications', enabled);
    notifications = enabled;
    notifyListeners();
    return true;
  }
}
