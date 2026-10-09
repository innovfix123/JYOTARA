import 'chat_availability.dart';
import 'services/ui_language.dart';

import 'package:flutter/material.dart';

import 'birth_form.dart';
import 'discovery_screens.dart';
import 'main.dart' show Guide, ChatScreen, profileSession;
import 'services/profile_session.dart';
import 'services/remote_config.dart';
import 'saved_profile_actions.dart';

String chatProfileDetails(ProfileSession session) {
  final birth = session.birthInput;
  final stamp = birth?.indiaDateTime.toIso8601String();
  return [
    'Full name: ${session.nickname.isEmpty ? 'My profile' : session.nickname}',
    'Gender: ${session.gender?.label ?? 'Not specified'}',
    if (stamp != null) 'Date of birth: ${stamp.substring(0, 10)}',
    if (stamp != null)
      'Birth time: ${birth!.exactTime ? '${stamp.substring(11, 16)} IST' : 'Unknown'}',
    'Birthplace: ${session.birthplaceLabel ?? 'Saved coordinates'}',
    if (session.facts?['rashi'] != null) 'Rasi: ${session.facts!['rashi']}',
    if (session.facts?['nakshatra'] != null)
      'Nakshatra: ${session.facts!['nakshatra']}',
    if (session.facts != null && !session.birthTimeKnown)
      'Birth time unknown: chart details are provisional.',
  ].join('\n');
}

class ChatProfilePicker extends StatefulWidget {
  const ChatProfilePicker({
    super.key,
    required this.guide,
    this.loadProfiles,
    this.removeProfile = KundliLibrary.remove,
    this.generalCoins,
    this.relationshipCoins,
  });
  final Guide guide;
  final Future<List<SavedKundli>> Function()? loadProfiles;
  final Future<void> Function(SavedKundli, List<SavedKundli>) removeProfile;
  final int? generalCoins, relationshipCoins;
  @override
  State<ChatProfilePicker> createState() => _ChatProfilePickerState();
}

class _ChatProfilePickerState extends State<ChatProfilePicker> {
  List<SavedKundli> profiles = [];
  SavedKundli? selected;
  bool busy = true;
  bool _confirmingDeletion = false;
  String? error;
  String? _loadedIndexKey;
  late final int _generalCoins, _relationshipCoins;
  @override
  void initState() {
    super.initState();
    // Keep the chooser's disclosed price while profile selection is open.
    _generalCoins =
        widget.generalCoins ?? remoteConfig.cost('generalStandard', 10);
    _relationshipCoins =
        widget.relationshipCoins ??
        remoteConfig.cost('relationshipStandard', 15);
    _load();
  }

  Future<void> _load() async {
    final targetKey = KundliLibrary.indexKey;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final rows = widget.loadProfiles != null
          ? await widget.loadProfiles!()
          : [
              SavedKundli('personal', profileSession),
              ...await KundliLibrary.load(),
            ];
      if (!mounted) return;
      setState(() {
        profiles = targetKey == KundliLibrary.indexKey ? rows : [];
        _loadedIndexKey = targetKey == KundliLibrary.indexKey
            ? targetKey
            : null;
        selected = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Profiles could not be opened. Please retry.');
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          if (targetKey != KundliLibrary.indexKey) {
            profiles = [];
            selected = null;
            _loadedIndexKey = null;
            error = savedProfileText(
              context,
              'Account changed. Reopen saved profiles.',
              'கணக்கு மாறியுள்ளது. சேமித்த விவரங்களை மீண்டும் திறக்கவும்.',
            );
          }
        });
      }
    }
  }

  Future<void> _edit(SavedKundli row) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BirthForm(session: row.session, onboarding: true),
      ),
    );
    await row.session.flushStorage();
    await _load();
  }

  Future<void> _start() async {
    final row = selected;
    if (row == null || row.session.facts == null || busy) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          guide: widget.guide,
          session: row.session,
          allowProfileSwitch: true,
          generalCoins: _generalCoins,
          relationshipCoins: _relationshipCoins,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _remove(SavedKundli row) async {
    if (busy ||
        _confirmingDeletion ||
        row.id == 'personal' ||
        identical(row.session, profileSession)) {
      return;
    }
    final targetKey = _loadedIndexKey;
    if (targetKey != KundliLibrary.indexKey) {
      await _load();
      return;
    }
    if (row.session.calculating ||
        row.session.answering ||
        row.session.deleting) {
      setState(
        () => error = savedProfileText(
          context,
          'Please wait for this person’s current request to finish.',
          'இந்த நபரின் தற்போதைய கோரிக்கை முடியும் வரை காத்திருக்கவும்.',
        ),
      );
      return;
    }
    setState(() => _confirmingDeletion = true);
    try {
      final confirmed = await confirmSavedProfileDeletion(
        context,
        name: row.session.nickname,
      );
      if (!confirmed || !mounted || targetKey != KundliLibrary.indexKey) return;
      if (row.session.calculating ||
          row.session.answering ||
          row.session.deleting) {
        setState(
          () => error = savedProfileText(
            context,
            'Please wait for this person’s current request to finish.',
            'இந்த நபரின் தற்போதைய கோரிக்கை முடியும் வரை காத்திருக்கவும்.',
          ),
        );
        return;
      }
      setState(() => busy = true);
      await widget.removeProfile(
        row,
        profiles.where((person) => person.id != 'personal').toList(),
      );
      if (!mounted || targetKey != KundliLibrary.indexKey) return;
      if (selected?.id == row.id) selected = null;
      await _load();
    } catch (_) {
      if (mounted && targetKey == KundliLibrary.indexKey) {
        setState(
          () => error = savedProfileText(
            context,
            'This person could not be deleted. Please retry.',
            'இந்த நபரின் விவரங்களை நீக்க முடியவில்லை. மீண்டும் முயலுங்கள்.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          _confirmingDeletion = false;
          if (targetKey != KundliLibrary.indexKey) {
            profiles = [];
            selected = null;
            _loadedIndexKey = null;
            error = savedProfileText(
              context,
              'Account changed. Reopen saved profiles.',
              'கணக்கு மாறியுள்ளது. சேமித்த விவரங்களை மீண்டும் திறக்கவும்.',
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => !publicChatEnabled
      ? const ChatUnavailableScreen()
      : Scaffold(
          appBar: AppBar(title: const Text('Select profile')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const UiText(
                  'Whose Birth Chart?',
                  style: TextStyle(
                    fontFamily: 'JyotaraEditorial',
                    fontSize: 27,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const KundliLibraryScreen(),
                            ),
                          );
                          await _load();
                        },
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Add or manage profiles'),
                ),
                if (busy) const LinearProgressIndicator(),
                if (error != null) ...[
                  Text(error!),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
                for (final row in profiles)
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          key: ValueKey('chat-profile-${row.id}'),
                          leading: Icon(
                            selected?.id == row.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          title: UiText(
                            row.session.nickname.isEmpty
                                ? (row.id == 'personal'
                                      ? 'My profile'
                                      : 'Unfinished Birth Chart')
                                : row.session.nickname,
                          ),
                          onTap: busy
                              ? null
                              : () {
                                  if (row.session.facts == null) {
                                    _edit(row);
                                    return;
                                  }
                                  setState(() => selected = row);
                                  _start();
                                },
                          trailing: IconButton(
                            tooltip: 'Edit profile',
                            onPressed: busy ? null : () => _edit(row),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ),
                        if (row.id != 'personal' &&
                            !identical(row.session, profileSession))
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: SavedProfileDeleteButton(
                                key: ValueKey('chat-delete-profile-${row.id}'),
                                name: row.session.nickname,
                                onPressed: busy ? null : () => _remove(row),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
}
