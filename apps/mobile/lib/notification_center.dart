import 'bronze_theme.dart';
import 'route_nav.dart';
import 'coin_wallet.dart';

import 'package:flutter/material.dart';

import 'firebase_preferences.dart';
import 'services/notification_inbox.dart';
import 'services/ui_language.dart';
import 'launch_intro.dart';

class NotificationCenter extends StatefulWidget {
  const NotificationCenter({super.key});
  @override
  State<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends State<NotificationCenter> {
  String filter = 'All';
  @override
  void initState() {
    super.initState();
    notificationInbox.markRead();
    final api = coinAccount;
    final owner = api?.account();
    if (api != null && owner != null) {
      api
          .post('/api/wallet/status', {})
          .then((data) async {
            if (owner == api.account()) {
              await recordWalletNotices(data, owner);
              if (mounted) await notificationInbox.markRead();
            }
          })
          .catchError((Object _) {});
    }
  }

  String category(AppNotice item) {
    final text = '${item.title} ${item.body}'.toLowerCase();
    if (RegExp(r'\b(offer|discount|bonus)\b').hasMatch(text)) return 'Offers';
    if (RegExp(r'\b(tip|practice|learn)\b').hasMatch(text)) return 'Tips';
    return 'Updates';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: const RouteNavigation(selected: 0),
    appBar: AppBar(
      centerTitle: true,
      title: const Text(
        'Jyotara',
        style: TextStyle(fontFamily: 'JyotaraEditorial', fontSize: 25),
      ),
      actions: [
        IconButton(
          tooltip: uiText(context, 'Notification settings'),
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const NotificationSettingsScreen(),
            ),
          ),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: notificationInbox,
      builder: (context, _) {
        final items = notificationInbox.items
            .where(
              (item) =>
                  (item.account == null ||
                      item.account == coinAccount?.account()) &&
                  (filter == 'All' || category(item) == filter),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const UiText(
              'Notifications',
              style: TextStyle(fontFamily: 'JyotaraEditorial', fontSize: 29),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tag in ['All', 'Updates', 'Offers', 'Tips'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        showCheckmark: false,
                        selectedColor: BronzePalette.gold,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          color: filter == tag
                              ? BronzePalette.background
                              : BronzePalette.ink,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        label: UiText(tag),
                        selected: tag == filter,
                        onSelected: (_) => setState(() => filter = tag),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 50,
                  horizontal: 15,
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      size: 48,
                      color: BronzePalette.gold,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      uiText(
                        context,
                        filter == 'All'
                            ? 'A quieter space for updates'
                            : 'No ${filter.toLowerCase()} yet',
                      ),
                      style: const TextStyle(fontFamily: 'JyotaraEditorial', fontSize: 23),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const UiText(
                      'Your Jyotara updates will appear here. Enable notifications in settings to receive them.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            for (final item in items)
              EntranceReveal(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 43,
                            height: 43,
                            decoration: BoxDecoration(
                              color: BronzePalette.raised,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              category(item) == 'Offers'
                                  ? Icons.local_offer_outlined
                                  : category(item) == 'Tips'
                                  ? Icons.auto_awesome_outlined
                                  : Icons.notifications_none,
                              color: BronzePalette.gold,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  item.body,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: BronzePalette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            MaterialLocalizations.of(context)
                                .formatShortDate(item.time.toLocal()),
                            style: const TextStyle(
                              fontSize: 10,
                              color: BronzePalette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                ),
              ),
            if (notificationInbox.items.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: notificationInbox.clear,
                  child: const UiText('Clear updates'),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const UiText('Notification settings')),
    body: const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: FirebasePreferences(),
    ),
  );
}
