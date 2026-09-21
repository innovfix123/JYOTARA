import 'package:flutter/material.dart';

import 'firebase_preferences.dart';
import 'services/notification_inbox.dart';
import 'services/ui_language.dart';

class NotificationCenter extends StatefulWidget {
  const NotificationCenter({super.key});
  @override
  State<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends State<NotificationCenter> {
  @override
  void initState() {
    super.initState();
    notificationInbox.markRead();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const UiText('Notifications'),
      actions: [
        IconButton(
          tooltip: uiText(context, 'Notification settings'),
          icon: const Icon(Icons.tune_rounded),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const UiText('Notification settings')),
                body: const SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: FirebasePreferences(),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: notificationInbox,
      builder: (context, _) {
        final items = notificationInbox.items;
        if (items.isEmpty) {
          return const Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_outlined,
                      size: 64,
                      color: Color(0xFFEEC76D),
                    ),
                    SizedBox(height: 24),
                    UiText(
                      'A quieter space for updates',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12),
                    UiText(
                      'Your Jyotara updates will appear here. Enable notifications in settings to receive them.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: notificationInbox.clear,
                child: const UiText('Clear updates'),
              ),
            ),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(item.body),
                        const SizedBox(height: 14),
                        Text(
                          MaterialLocalizations.of(context)
                              .formatMediumDate(item.time.toLocal()),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
