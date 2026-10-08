import 'services/meta_measurement.dart';
import 'services/marketing_analytics.dart';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'services/ui_language.dart';

import 'services/firebase_services.dart';

class FirebasePreferences extends StatefulWidget {
  const FirebasePreferences({super.key});
  @override
  State<FirebasePreferences> createState() => _FirebasePreferencesState();
}

class _FirebasePreferencesState extends State<FirebasePreferences> {
  bool busy = false;
  bool? pendingAnalytics, pendingCrashes, pendingNotifications;
  Future<void> change(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: UiText('Could not save this setting. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          pendingAnalytics = null;
          pendingCrashes = null;
          pendingNotifications = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      firebaseServices,
      marketingAnalytics,
      metaMeasurement,
    ]),
    builder: (context, _) => Card(
      child: Column(
        children: [
          const ListTile(
            title: UiText('Notifications & app improvements'),
            subtitle: UiText(
              'Optional services provided by Google Firebase, Singular and Meta. Birth details and chat text are not included in analytics events.',
            ),
          ),
          SwitchListTile(
            title: const UiText('Usage analytics'),
            subtitle: const UiText(
              'Share app usage and device information with Firebase to help improve Jyotara.',
            ),
            value: pendingAnalytics ?? firebaseServices.analytics,
            onChanged: busy || !firebaseServices.ready
                ? null
                : (v) {
                    setState(() => pendingAnalytics = v);
                    change(() => firebaseServices.setAnalytics(v));
                  },
          ),
          if (marketingAnalytics.configured)
            SwitchListTile(
              title: const UiText('Marketing measurement'),
              subtitle: const UiText(
                'Allow Singular to measure installs, app usage and verified recharge amounts. No birth details or chat text are shared.',
              ),
              value: marketingAnalytics.enabled,
              onChanged: busy
                  ? null
                  : (value) =>
                        change(() => marketingAnalytics.setConsent(value)),
            ),
          if (metaMeasurement.configured)
            SwitchListTile(
              title: const UiText('Meta measurement'),
              subtitle: const UiText(
                'Allow Meta to measure app opens, successful sign-ins and completed readings. Device information is shared; birth details and chat text are excluded.',
              ),
              value: metaMeasurement.enabled,
              onChanged: busy
                  ? null
                  : (value) => change(() => metaMeasurement.setConsent(value)),
            ),
          SwitchListTile(
            title: const UiText('Crash reports'),
            subtitle: const UiText(
              'Share technical error and device reports to help fix crashes.',
            ),
            value: pendingCrashes ?? firebaseServices.crashReports,
            onChanged: busy || !firebaseServices.ready
                ? null
                : (v) {
                    setState(() => pendingCrashes = v);
                    change(() => firebaseServices.setCrashReports(v));
                  },
          ),
          SwitchListTile(
            title: const UiText('App notifications'),
            subtitle: const UiText(
              'Receive Jyotara updates. You can turn these off at any time.',
            ),
            value: pendingNotifications ?? firebaseServices.notifications,
            onChanged: busy || !firebaseServices.ready
                ? null
                : (v) {
                    setState(() => pendingNotifications = v);
                    change(() async {
                      final allowed = await firebaseServices.setNotifications(
                        v,
                      );
                      if (!allowed && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: UiText(
                              'Allow notifications in Android settings to enable updates.',
                            ),
                          ),
                        );
                      }
                    });
                  },
          ),
          if (const bool.fromEnvironment('JYOTARA_FIREBASE_QA'))
            TextButton(
              onPressed: !firebaseServices.notifications
                  ? null
                  : () async {
                      final token = await FirebaseMessaging.instance.getToken();
                      if (token != null) {
                        if (context.mounted) {
                          await showDialog<void>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Notification test token'),
                              content: SelectableText(token),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        }
                      }
                    },
              child: const UiText('Show notification test token'),
            ),
          if (!firebaseServices.ready)
            const Padding(
              padding: EdgeInsets.all(12),
              child: UiText(
                'Connecting app services. If this continues, restart the app.',
              ),
            ),
        ],
      ),
    ),
  );
}
