import 'dart:convert';

import 'package:http/http.dart' as http;

import 'jyotara_api.dart';
import 'profile_session.dart';

const backupFields = [
  'version',
  'origin',
  'session',
  'profileKey',
  'nickname',
  'preferredChatLanguage',
  'relationshipStatus',
  'profession',
  'gender',
  'birthplaceLabel',
  'raw',
  'birthTimeKnown',
  'calculatedAt',
];
Map<String, dynamic> birthProfileBackup(Map<String, dynamic> record) => {
  for (final key in backupFields)
    if (record.containsKey(key)) key: record[key],
};
Map<String, dynamic> hydrateProfileBackup(Map<String, dynamic> record) => {
  ...birthProfileBackup(record),
  'conversations': <String, dynamic>{},
  'requestIds': <String, dynamic>{},
  'conversationContexts': <String, dynamic>{},
  'requestContexts': <String, dynamic>{},
  'reportPeople': <String, dynamic>{},
};

class ProfileBackup {
  ProfileBackup({
    required this.token,
    this.testerCode,
    this.baseUrl = defaultApiBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();
  final String Function() token;
  final String? Function()? testerCode;
  final String baseUrl;
  final http.Client _client;
  String? _saved;
  Future<void> _tail = Future.value();
  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/api/account/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${token()}',
            if (testerCode?.call() != null)
              'X-Jyotara-Tester-Code': testerCode!()!,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw const JyotaraApiException(
        'Saved profile could not be restored. Please retry.',
      );
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>?> load() async {
    final result = await _post({'action': 'load'});
    final profile = result['profile'];
    if (profile == null) return null;
    final value = Map<String, dynamic>.from(profile as Map);
    _saved = jsonEncode(birthProfileBackup(value));
    return value;
  }

  Future<void> save(Map<String, dynamic> record) {
    final value = birthProfileBackup(record),
        encoded = jsonEncode(birthProfileBackup(record));
    final next = _tail.then((_) async {
      if (encoded == _saved) return;
      final result = await _post({'action': 'save', 'profile': value});
      if (result['saved'] != true) {
        throw const JyotaraApiException('Profile backup could not be saved.');
      }
      _saved = encoded;
    });
    _tail = next.catchError((Object _) {});
    return next;
  }
}

/// Restore only this account's birth profile. Device chat history stays local.
Future<void> restoreBirthProfile({
  required ProfileBackup backup,
  required ProfileSession session,
}) async {
  await session.flushStorage();
  if (session.savedReadFailed == true) {
    throw StateError('Protected local profile unavailable');
  }
  final local = await session.vault!.load();
  // A pending deletion/calculation must finish before any cloud replacement.
  if (local?['deletionRequested'] == true ||
      local?['kind'] == 'pending-profile') {
    return;
  }
  final cloud = await backup.load();
  if (cloud == null) {
    if (local != null) await backup.save(local);
    return;
  }
  final Map<String, dynamic> restored;
  if (local != null && local['profileKey'] == cloud['profileKey']) {
    restored = {...local};
    for (final key in [
      'nickname',
      'preferredChatLanguage',
      'relationshipStatus',
      'profession',
      'gender',
      'birthplaceLabel',
    ]) {
      if (cloud.containsKey(key)) restored[key] = cloud[key];
    }
  } else {
    // A newer local birth edit may not yet have reached the server.
    final localDate = DateTime.tryParse(
      local?['calculatedAt']?.toString() ?? '',
    );
    final cloudDate = DateTime.tryParse(
      cloud['calculatedAt']?.toString() ?? '',
    );
    restored =
        local != null &&
            localDate != null &&
            cloudDate != null &&
            localDate.isAfter(cloudDate)
        ? local
        : hydrateProfileBackup(cloud);
  }
  await session.vault!.save(restored);
  await session.restore();
  if (session.savedReadFailed == true) {
    throw StateError('Saved profile could not be restored');
  }
  await backup.save(restored);
}
