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
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: firebaseServices,
    builder: (context, _) => Card(
      child: Column(
        children: [
          const ListTile(
            title: UiText('Notifications & app improvements'),
            subtitle: UiText(
              'Optional services provided by Google Firebase. Birth details and chat text are not included in analytics events.',
            ),
          ),
          SwitchListTile(
            title: const UiText('Usage analytics'),
            subtitle: const UiText(
              'Share app usage and device information to help improve Jyotara.',
            ),
            value: firebaseServices.analytics,
            onChanged: busy || !firebaseServices.ready
                ? null
                : (v) => change(() => firebaseServices.setAnalytics(v)),
          ),
          SwitchListTile(
            title: const UiText('Crash reports'),
            subtitle: const UiText(
              'Share technical error and device reports to help fix crashes.',
            ),
            value: firebaseServices.crashReports,
            onChanged: busy || !firebaseServices.ready
                ? null
                : (v) => change(() => firebaseServices.setCrashReports(v)),
          ),
          SwitchListTile(
            title: const UiText('App notifications'),
            subtitle: const UiText(
              'Receive Jyotara updates. You can turn these off at any time.',
            ),
            value: firebaseServices.notifications,
            onChanged: busy || !firebaseServices.ready
                ? null
                : (v) => change(() async {
                    final allowed = await firebaseServices.setNotifications(v);
                    if (!allowed && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: UiText(
                            'Allow notifications in Android settings to enable updates.',
                          ),
                        ),
                      );
                    }
                  }),
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
