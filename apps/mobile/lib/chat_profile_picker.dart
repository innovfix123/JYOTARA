import 'package:flutter/material.dart';

import 'birth_form.dart';
import 'discovery_screens.dart';
import 'main.dart' show Guide, ChatScreen, profileSession;
import 'services/profile_session.dart';

String chatProfileDetails(ProfileSession session) {
  final birth = session.birthInput;
  final stamp = birth?.indiaDateTime.toIso8601String();
  return [
    'Name: ${session.nickname.isEmpty ? 'My profile' : session.nickname}',
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
  const ChatProfilePicker({super.key, required this.guide, this.loadProfiles});
  final Guide guide;
  final Future<List<SavedKundli>> Function()? loadProfiles;
  @override
  State<ChatProfilePicker> createState() => _ChatProfilePickerState();
}

class _ChatProfilePickerState extends State<ChatProfilePicker> {
  List<SavedKundli> profiles = [];
  SavedKundli? selected;
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
        profiles = rows;
        selected = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Profiles could not be opened. Please retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _edit(SavedKundli row) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => BirthForm(session: row.session)),
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
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Select profile')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Chat with ${widget.guide.name}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text('${widget.guide.speciality}\nAI guide · Free tester chat'),
          const SizedBox(height: 16),
          const Text(
            'Choose whose chart this conversation is about. Each profile has its own chat history.',
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
                    title: Text(
                      row.session.nickname.isEmpty
                          ? (row.id == 'personal'
                                ? 'My profile'
                                : 'Unfinished Kundli')
                          : row.session.nickname,
                    ),
                    subtitle: Text(
                      row.session.facts == null
                          ? 'Complete birth details to use this profile.'
                          : chatProfileDetails(row.session),
                    ),
                    onTap: busy
                        ? null
                        : () {
                            if (row.session.facts == null) {
                              _edit(row);
                              return;
                            }
                            setState(() => selected = row);
                          },
                    trailing: IconButton(
                      tooltip: 'Edit profile',
                      onPressed: busy ? null : () => _edit(row),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: selected == null || busy ? null : _start,
            child: Text('Open chat with ${widget.guide.name}'),
          ),
        ],
      ),
    ),
  );
}
