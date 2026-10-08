import 'bronze_theme.dart';
import 'rasi_emblem.dart';
import 'south_chart.dart';
import 'birth_form.dart';
import 'coin_wallet.dart';
import 'notification_center.dart';
import 'services/name_display.dart';

import 'package:flutter/material.dart';

import 'discovery_screens.dart' show KundliLibraryScreen;

import 'main.dart'
    show
        profileSession,
        phoneAccess,
        testerAccess,
        AccountSettingsScreen,
        uiLanguagePreferences,
        confirmSignOut,
        MainTabScope;
import 'payment_support.dart';
import 'services/ui_language.dart';
import 'launch_intro.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  AccountService get api => AccountService(
    token: () => phoneAccess.token,
    tester: () => testerAccess.code,
    account: () => phoneAccess.accountId,
  );
  @override
  Widget build(BuildContext context) => Material(
    color: BronzePalette.background,
    child: IconTheme(
      data: const IconThemeData(color: BronzePalette.gold),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'JyotaraSans',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: BronzePalette.ink,
          decoration: TextDecoration.none,
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: profileSession,
            builder: (context, _) {
              final name = profileSession.nickname.trim().isEmpty
                  ? 'Your profile'
                  : profileSession.nickname.trim();
              void open(Widget page) => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => page),
              );
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                children: [
                  if (profileSession.backupError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        profileSession.backupError!,
                        style: const TextStyle(color: BronzePalette.gold),
                      ),
                    ),
                  if (!MainTabScope.contains(context))
                    Row(
                      children: [
                        if (ModalRoute.of(context)?.isFirst == false)
                          BackButton(
                            onPressed: () {
                              // Ignore a second tap after this route starts leaving.
                              if (ModalRoute.of(context)?.isCurrent != true) {
                                return;
                              }
                              Navigator.of(context).maybePop();
                            },
                          )
                        else
                          const SizedBox(width: 48),
                        const Expanded(
                          child: Text(
                            'Jyotara',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'JyotaraSans',
                              fontSize: 23,
                              fontWeight: FontWeight.w400,
                              color: BronzePalette.ink,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Account settings',
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () => open(
                            const Scaffold(body: AccountSettingsScreen()),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  const UiText(
                    'My profile',
                    style: TextStyle(
                      fontFamily: 'JyotaraEditorial',
                      fontSize: 27,
                      fontWeight: FontWeight.w500,
                      color: BronzePalette.ink,
                    ),
                  ),
                  const SizedBox(height: 18),
                  EntranceReveal(
                    child: Container(
                      key: const Key('bronzeProfileCard'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 23,
                      ),
                      decoration: BoxDecoration(
                        color: BronzePalette.card,
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: .9,
                          colors: [
                            Color.alphaBlend(
                              BronzePalette.gold.withValues(alpha: .08),
                              BronzePalette.card,
                            ),
                            BronzePalette.card,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(23),
                        border: Border.all(color: BronzePalette.border),
                      ),
                      child: Column(
                        children: [
                          RasiEmblem(
                            key: const Key('profileRasi'),
                            size: 118,
                            index: SouthIndianChart.signIndex(
                              profileSession.facts?['rashi'],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                context
                                            .dependOnInheritedWidgetOfExactType<
                                              UiLanguageScope
                                            >()
                                            ?.notifier
                                            ?.value ==
                                        'ta'
                                    ? tamilDisplayName(name)
                                    : name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'JyotaraEditorial',
                                  fontSize: 32,
                                  fontWeight: FontWeight.w500,
                                  color: BronzePalette.gold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                phoneAccess.mobile == null
                                    ? 'Your Jyotara account'
                                    : '+91 ${phoneAccess.mobile}',
                                style: const TextStyle(
                                  color: BronzePalette.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _BirthSummary(),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => open(
                              BirthForm(
                                session: profileSession,
                                onboarding: true,
                              ),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const UiText('Edit birth details'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (coinWalletEnabled && coinAccount != null)
                    _ProfileRow(
                      icon: Icons.toll_outlined,
                      title: 'Coin wallet',
                      subtitle: 'Packs, prices and coin activity',
                      onTap: () => open(CoinWalletScreen(api: coinAccount!)),
                    ),
                  _ProfileRow(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Manage notifications and app improvements',
                    onTap: () => open(const NotificationCenter()),
                  ),
                  _ProfileRow(
                    icon: Icons.people_alt_outlined,
                    title: 'My Profiles',
                    subtitle: 'Manage your charts',
                    onTap: () => open(
                      const KundliLibraryScreen(includeOwnProfile: true),
                    ),
                  ),
                  _ProfileRow(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    subtitle: 'Contact us, get help',
                    onTap: () => open(SupportScreen(api: api)),
                  ),
                  _ProfileRow(
                    icon: Icons.chat_bubble_outline,
                    title: 'My Tickets',
                    subtitle: 'View your support requests',
                    onTap: () =>
                        open(SupportScreen(api: api, ticketsOnly: true)),
                  ),
                  const SizedBox(height: 20),
                  if (phoneAccess.authorized)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE89454),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                        side: const BorderSide(color: Color(0xFFB85A21)),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: () async {
                        if (profileSession.calculating ||
                            profileSession.answering) {
                          return;
                        }
                        if (!await confirmSignOut(context) ||
                            !context.mounted) {
                          return;
                        }
                        await profileSession.flushStorage();
                        if (profileSession.storageError != null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(profileSession.storageError!),
                              ),
                            );
                          }
                          return;
                        }
                        await phoneAccess.signOut();
                        if (!phoneAccess.authorized) {
                          await uiLanguagePreferences.set('en');
                        }
                        if (!context.mounted) return;
                        if (!phoneAccess.authorized) {
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                phoneAccess.error ??
                                    'Sign out failed. Please try again.',
                              ),
                            ),
                          );
                        }
                      },
                      child: const UiText('Sign out'),
                    ),
                  TextButton(
                    onPressed: () =>
                        open(const Scaffold(body: AccountSettingsScreen())),
                    child: const Text('Privacy & account settings'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => EntranceReveal(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressFeedback(
        child: Card(
          color: BronzePalette.card,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
            side: const BorderSide(color: BronzePalette.border, width: .6),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 3,
            ),
            leading: Icon(icon, size: 24, color: BronzePalette.gold),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: BronzePalette.ink,
                fontWeight: FontWeight.w400,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: BronzePalette.muted),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              size: 20,
              color: BronzePalette.muted,
            ),
            onTap: onTap,
          ),
        ),
      ),
    ),
  );
}

class _BirthSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final birth = profileSession.birthInput?.indiaDateTime;
    final material = MaterialLocalizations.of(context);
    final rasi = profileSession.facts?['rashi'];
    final rows = [
      ('Birth date', birth == null ? '—' : material.formatShortDate(birth)),
      (
        'Birth time',
        !profileSession.birthTimeKnown || birth == null
            ? '—'
            : material.formatTimeOfDay(TimeOfDay.fromDateTime(birth)),
      ),
      ('Birth place', profileSession.birthplaceLabel ?? '—'),
      ('Rasi', rasi is String ? uiText(context, rasi) : '—'),
    ];
    return Column(
      children: [
        for (var i = 0; i < rows.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i == 0 ? 12 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = i; j < i + 2; j++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UiText(
                            rows[j].$1,
                            style: const TextStyle(
                              fontSize: 11,
                              color: BronzePalette.muted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            rows[j].$2,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: BronzePalette.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
