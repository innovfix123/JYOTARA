import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'chart_facts.dart';
import 'jyotara_api.dart';
import 'conversation.dart';
import 'language_preferences.dart';
import 'local_profile_vault.dart';
import 'chart_instant.dart';
import 'birth_profile_input.dart';
import 'guidance_message.dart';
import 'profile_gender.dart';

/// Owns one chart and API session for all specialist guides.
class ProfileSession extends ChangeNotifier {
  ProfileSession({
    JyotaraApiClient? api,
    DateTime Function()? clock,
    this.preferences,
    this.vault,
    this.onBirthProfileSaved,
  }) : _api = api ?? JyotaraApiClient(),
       _clock = clock ?? DateTime.now;
  final Future<void> Function(Map<String, dynamic>)? onBirthProfileSaved;
  String? backupError;
  final JyotaraApiClient _api;
  Future<void> reportAnswer({
    required String answer,
    required String guide,
    required String reason,
  }) => _api.reportAnswer(answer: answer, guide: guide, reason: reason);
  Future<List<List<dynamic>>> searchLocations(String query) =>
      _api.searchLocations(query);
  final DateTime Function() _clock;
  final LanguagePreferences? preferences;
  final LocalProfileVault? vault;
  String? storageError;
  bool _savedReadFailed = false;
  bool get savedReadFailed => _savedReadFailed;
  // Explicit opt-in for future requests only; never inferred from chat use.
  // This test-build choice resets on restart or profile deletion/change.
  bool researchConsent = false;
  void setResearchConsent(bool enabled) {
    researchConsent = enabled;
    notifyListeners();
  }

  Future<void> _pendingPersistence = Future.value();
  Future<void> flushStorage() => _pendingPersistence;

  void _persist({bool deletionCheckpoint = false}) {
    if ((!deletionCheckpoint && (deleting || _deletionCapability != null)) ||
        vault == null ||
        _savedReadFailed ||
        _raw == null ||
        _facts == null) {
      return;
    }
    final revision = _revision;
    final snapshot = <String, dynamic>{
      'version': 1,
      'deletionRequested': deletionCheckpoint || _deletionCapability != null,
      'origin': _api.storageOrigin,
      'session': _api.sessionForStorage,
      'profileKey': _profileKey,
      'nickname': nickname,
      'preferredChatLanguage': preferredChatLanguage,
      'relationshipStatus': relationshipStatus,
      'profession': profession,
      'gender': gender?.value,
      'birthplaceLabel': birthplaceLabel,
      'raw': _raw,
      'birthTimeKnown': birthTimeKnown,
      'calculatedAt': calculatedAt?.toUtc().toIso8601String(),
      'conversations': _conversations.map(
        (guide, conversation) => MapEntry(guide, {
          'language': conversation.language,
          'interruptedRequest': conversation.pending,
          'ended': conversation.ended,
          'rating': conversation.rating,
          'depth': conversation.depth,
          'billingAcknowledged': conversation.billingAcknowledged,
          'acceptedGeneralCoins': conversation.acceptedGeneralCoins,
          'acceptedRelationshipCoins': conversation.acceptedRelationshipCoins,
          'updatedAt': conversation.updatedAt?.toIso8601String(),
          'history': conversation.history
              .map(
                (chat) => chat
                    .map(
                      (m) => {
                        'fromUser': m.fromUser,
                        'text': m.text,
                        'label': m.label,
                        'wallet': m.wallet,
                      },
                    )
                    .toList(),
              )
              .toList(),
          'messages': conversation.messages
              .map(
                (m) => {
                  'fromUser': m.fromUser,
                  'text': m.text,
                  'label': m.label,
                  'wallet': m.wallet,
                },
              )
              .toList(),
        }),
      ),
      'requestIds': Map<String, String>.from(_requestIds),
      'conversationContexts': _conversationContexts,
      'conversationModes': _conversationModes,
      'conversationMemory': _conversationMemory,
      'reportPeople': _reportPeople.map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
      ),
      'requestContexts': _requestContexts.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      ),
    };
    _pendingPersistence = vault!
        .save(snapshot)
        .then((_) {
          if (revision != _revision) return;
          storageError = null;
          if (onBirthProfileSaved != null && !deletionCheckpoint) {
            // Account backup contains profile/chart fields only, not chat turns.
            unawaited(
              onBirthProfileSaved!(snapshot)
                  .then((_) {
                    if (revision == _revision) {
                      backupError = null;
                    }
                  })
                  .catchError((Object _) {
                    if (revision == _revision) {
                      backupError =
                          'Profile backup pending. Reopen the app to retry.';
                      notifyListeners();
                    }
                  }),
            );
          }
          notifyListeners();
        })
        .catchError((Object _) {
          if (revision != _revision) return;
          storageError = 'Changes could not be saved on this device. Keep the app open and try again.';
          notifyListeners();
        });
  }

  Future<void> restore() async {
    if (vault == null || deleting) return;
    final revision = _revision;
    try {
      final saved = await vault!.load();
      if (revision != _revision) return;
      if (saved == null) {
        _savedReadFailed = false;
        storageError = null;
        notifyListeners();
        return;
      }
      if (saved['kind'] == 'pending-profile') {
        if (!_api.acceptsStorageOrigin(saved['origin']) ||
            saved['session'] is! String) {
          throw const FormatException('Saved request is incompatible');
        }
        _api.restoreSession(saved['session'] as String);
        profileRequestUnconfirmed = true;
        _savedReadFailed = false;
        storageError = null;
        _revision++;
        notifyListeners();
        return;
      }
      if (!_api.acceptsStorageOrigin(saved['origin']) ||
          saved['raw'] is! Map<String, dynamic> ||
          saved['birthTimeKnown'] is! bool ||
          saved['profileKey'] is! String) {
        throw const FormatException('Saved profile is incompatible');
      }
      final timestamp = parseChartInstant(saved['calculatedAt']);
      if (timestamp == null) {
        throw const FormatException('Saved profile date is invalid');
      }
      final raw = saved['raw'] as Map<String, dynamic>;
      final deletionRequested = saved['deletionRequested'] ?? false;
      if (deletionRequested is! bool ||
          (deletionRequested &&
              (raw['chartTicket'] is! String ||
                  (raw['chartTicket'] as String).isEmpty ||
                  raw['profileId'] is! String ||
                  (raw['profileId'] as String).isEmpty))) {
        throw const FormatException('Saved deletion request is invalid');
      }
      final known = saved['birthTimeKnown'] as bool;
      final restoredFacts = normalizeChartFacts(
        raw,
        birthTimeKnown: known,
        // ChartScreen labels these as the original saved calculation. Chat
        // independently uses current server-selected periods.
        at: timestamp,
      );
      final chats = saved['conversations'];
      final ids = saved['requestIds'] ?? <String, dynamic>{};
      if (ids is! Map<String, dynamic> ||
          ids.length > 5000 ||
          ids.entries.any(
            (entry) =>
                entry.key.length > 2000 ||
                entry.value is! String ||
                !RegExp(r'^[a-f0-9]{32}$').hasMatch(entry.value as String),
          )) {
        throw const FormatException('Invalid saved request identities');
      }
      final contexts = saved['requestContexts'] ?? <String, dynamic>{};
      if (contexts is! Map<String, dynamic> ||
          contexts.length > 5000 ||
          contexts.entries.any(
            (e) =>
                !ids.containsKey(e.key) ||
                e.value is! List ||
                (e.value as List).length > 6 ||
                (e.value as List).any(
                  (v) =>
                      v is! String || v.trim().isEmpty || v.runes.length > 240,
                ),
          )) {
        throw const FormatException('Invalid saved conversation context');
      }
      if (chats is! Map<String, dynamic> || chats.length > 5000) {
        throw const FormatException('Invalid saved conversations');
      }
      final restoredChats = <String, GuideConversation>{};
      for (final entry in chats.entries) {
        final chat = entry.value;
        if (chat is! Map ||
            !LanguagePreferences.allowed.contains(chat['language']) ||
            chat['messages'] is! List ||
            (chat['messages'] as List).length > 5000) {
          throw const FormatException('Invalid saved conversation');
        }
        final conversation = GuideConversation()
          ..language = chat['language'] as String
          ..ended = chat['ended'] == true
          ..billingAcknowledged =
              chat['billingAcknowledged'] == true &&
              chat['acceptedGeneralCoins'] is int &&
              chat['acceptedGeneralCoins'] >= 1 &&
              chat['acceptedGeneralCoins'] <= 500 &&
              chat['acceptedRelationshipCoins'] is int &&
              chat['acceptedRelationshipCoins'] >= 1 &&
              chat['acceptedRelationshipCoins'] <= 500
          ..acceptedGeneralCoins = chat['acceptedGeneralCoins'] is int
              ? chat['acceptedGeneralCoins'] as int
              : null
          ..acceptedRelationshipCoins = chat['acceptedRelationshipCoins'] is int
              ? chat['acceptedRelationshipCoins'] as int
              : null
          ..depth = ['standard', 'detailed'].contains(chat['depth'])
              ? chat['depth'] as String
              : null
          ..updatedAt = DateTime.tryParse(
            chat['updatedAt'] is String ? chat['updatedAt'] : '',
          )
          ..rating =
              chat['rating'] is int &&
                  chat['rating'] >= 1 &&
                  chat['rating'] <= 5
              ? chat['rating'] as int
              : null;
        for (final old in (chat['history'] is List ? chat['history'] : [])) {
          if (old is! List) continue;
          conversation.history.add([
            for (final m in old)
              if (m is Map && m['fromUser'] is bool && m['text'] is String)
                ChatMessage(
                  fromUser: m['fromUser'],
                  text: m['text'],
                  label: m['label'] is String ? m['label'] : null,
                  wallet: m['wallet'] is Map
                      ? Map<String, dynamic>.from(m['wallet'])
                      : null,
                ),
          ]);
        }
        for (final message in chat['messages']) {
          if (message is! Map ||
              message['fromUser'] is! bool ||
              message['text'] is! String ||
              (message['text'] as String).length > 20000 ||
              (message['label'] != null && message['label'] is! String)) {
            throw const FormatException('Invalid saved message');
          }
          conversation.messages.add(
            ChatMessage(
              fromUser: message['fromUser'],
              text: message['text'],
              label: message['label'],
              wallet: message['wallet'] is Map
                  ? Map<String, dynamic>.from(message['wallet'])
                  : null,
            ),
          );
        }
        if (chat['interruptedRequest'] == true) {
          conversation.messages.add(
            const ChatMessage(
              fromUser: false,
              text: 'The app closed before this answer was received. The request may have reached the server. It has not been resent automatically.',
              label: 'INTERRUPTED REQUEST',
            ),
          );
        }
        restoredChats[entry.key] = conversation;
      }
      final restoredTurns = <String, List<Map<String, String>>>{};
      final turns = saved['conversationContexts'];
      if (turns is Map) {
        for (final entry in turns.entries) {
          if (entry.key is! String ||
              !ids.containsKey(entry.key) ||
              entry.value is! List) {
            throw const FormatException('Invalid saved conversation turns');
          }
          final items = entry.value as List;
          if (items.length > 32 ||
              items.any(
                (v) =>
                    v is! Map ||
                    !['user', 'assistant'].contains(v['role']) ||
                    v['content'] is! String ||
                    (v['content'] as String).runes.length > 4000,
              )) {
            throw const FormatException('Invalid saved conversation turns');
          }
          restoredTurns[entry.key] = items
              .map((v) => Map<String, String>.from(v as Map))
              .toList();
        }
      }
      final restoredModes = <String, String>{};
      final modes = saved['conversationModes'];
      if (modes is Map) {
        for (final entry in modes.entries) {
          if (entry.key is! String ||
              !ids.containsKey(entry.key) ||
              entry.value != 'conversation') {
            throw const FormatException('Invalid saved conversation mode');
          }
          restoredModes[entry.key] = 'conversation';
        }
      }
      final restoredMemory = <String, List<String>>{};
      final memory = saved['conversationMemory'];
      if (memory is Map) {
        for (final entry in memory.entries) {
          if (entry.key is! String ||
              !restoredModes.containsKey(entry.key) ||
              entry.value is! List ||
              (entry.value as List).length > 12 ||
              (entry.value as List).any(
                (v) => v is! String || v.runes.length > 1000,
              )) {
            throw const FormatException('Invalid saved conversation memory');
          }
          restoredMemory[entry.key] = List<String>.from(entry.value as List);
        }
      }
      _api.restoreSession(saved['session'] as String?);
      _raw = raw;
      _facts = restoredFacts;
      _profileKey = saved['profileKey'];
      nickname = _displayValue(saved['nickname'], 60) ?? '';
      preferredChatLanguage =
          chatLanguages.contains(saved['preferredChatLanguage'])
          ? saved['preferredChatLanguage'] as String
          : 'auto';
      relationshipStatus =
          relationshipOptions.contains(saved['relationshipStatus'])
          ? saved['relationshipStatus'] as String
          : '';
      profession = professionOptions.contains(saved['profession'])
          ? saved['profession'] as String
          : '';
      gender = ProfileGender.fromStored(saved['gender']);
      birthplaceLabel = _displayValue(saved['birthplaceLabel'], 160);
      birthTimeKnown = known;
      calculatedAt = timestamp;
      profileRequestUnconfirmed = false;
      _clearConversations();
      _conversations.addAll(restoredChats);
      _requestIds
        ..clear()
        ..addAll(ids.cast<String, String>());
      _requestContexts
        ..clear()
        ..addAll(
          contexts.map((k, v) => MapEntry(k, List<String>.from(v as List))),
        );
      _conversationContexts
        ..clear()
        ..addAll(restoredTurns);
      _conversationModes
        ..clear()
        ..addAll(restoredModes);
      _conversationMemory
        ..clear()
        ..addAll(restoredMemory);
      _reportPeople.clear();
      final people = saved['reportPeople'];
      if (people is Map) {
        for (final entry in people.entries) {
          if (entry.key is String &&
              entry.value is Map &&
              _requestIds.containsKey(entry.key)) {
            _reportPeople[entry.key] = Map<String, dynamic>.from(entry.value);
          }
        }
      }
      for (final chat in _conversations.values) {
        chat.addListener(_persist);
      }
      _deletionCapability = deletionRequested
          ? {
              'chartTicket': raw['chartTicket'] as String,
              'profileId': raw['profileId'] as String,
            }
          : null;
      _savedReadFailed = false;
      storageError = deletionRequested
          ? 'Deletion was requested but not completed on this device. Retry deletion before continuing.'
          : null;
      _revision++;
      notifyListeners();
    } catch (_) {
      if (revision != _revision) return;
      _savedReadFailed = true;
      storageError = 'Saved data could not be opened. It has not been deleted or overwritten.';
      notifyListeners();
    }
  }

  String? _profileKey;
  String nickname = '';
  static const chatLanguages = ['auto', 'english', 'tamil', 'tanglish'];
  static const relationshipOptions = [
    '',
    'Single',
    'In a relationship',
    'Married',
    'Separated',
    'Divorced',
    'Widowed',
    'Prefer not to say',
  ];
  static const professionOptions = [
    '',
    'Student',
    'Employed',
    'Self-employed',
    'Business owner',
    'Homemaker',
    'Looking for work',
    'Retired',
    'Other',
    'Prefer not to say',
  ];
  String preferredChatLanguage = 'auto';
  String relationshipStatus = '';
  String profession = '';
  Future<void> saveProfilePreferences({
    required String language,
    required String relationship,
    required String occupation,
  }) async {
    if (!chatLanguages.contains(language) ||
        !relationshipOptions.contains(relationship) ||
        !professionOptions.contains(occupation)) {
      throw ArgumentError('Invalid profile preferences');
    }
    preferredChatLanguage = language;
    relationshipStatus = relationship;
    profession = occupation;
    for (final chat in _conversations.values) {
      chat.language = language;
      chat.changed();
    }
    _persist();
    await flushStorage();
    notifyListeners();
  }

  ProfileGender? gender;
  String? birthplaceLabel;
  BirthProfileInput? get birthInput => BirthProfileInput.fromKey(_profileKey);
  static String? _displayValue(dynamic value, int max) =>
      value is String &&
          value.length <= max &&
          !RegExp(r'[\x00-\x1f]').hasMatch(value)
      ? value.trim()
      : null;
  Map<String, dynamic>? _raw;
  List<Map<String, dynamic>> get dashaTimeline {
    if (!birthTimeKnown) return [];
    final rows = _raw?['dashaPeriods']?['data']?['dasha_periods'];
    if (rows is! List) return [];
    return rows
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  bool get profileRecovered => _raw?['profileRecovered'] == true;
  Map<String, dynamic>? _facts;
  Map<String, dynamic>? get facts =>
      _facts == null ? null : _readOnly(_facts!) as Map<String, dynamic>;

  // Protect nested planet/period structures too, not only the top-level map.
  static dynamic _readOnly(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable(
        value.map((key, item) => MapEntry(key, _readOnly(item))),
      );
    }
    if (value is List) {
      return List<dynamic>.unmodifiable(value.map(_readOnly));
    }
    return value;
  }

  bool calculating = false;
  bool profileRequestUnconfirmed = false;
  bool answering = false;
  bool deleting = false;
  Future<void>? _deletion;
  bool birthTimeKnown = false;
  DateTime? calculatedAt;
  int _revision = 0;
  int get revision => _revision;
  final _conversations = <String, GuideConversation>{};
  final _requestIds = <String, String>{};
  final _reportPeople = <String, Map<String, dynamic>>{};
  final _requestContexts = <String, List<String>>{};
  final _conversationContexts = <String, List<Map<String, String>>>{};
  final _conversationModes = <String, String>{};
  final _conversationMemory = <String, List<String>>{};
  final _responseReceipts = Expando<({String key, String id, int revision})>();

  /// Commit the displayed answer and retire its retry identity in one vault
  /// generation. Until this point, a restart must recover the same request.
  Future<bool> recordGuidanceResponse(
    GuidanceResponse result,
    GuideConversation target,
    String language,
  ) async {
    final receipt = _responseReceipts[result];
    if (receipt == null ||
        receipt.revision != _revision ||
        deleting ||
        _requestIds[receipt.key] != receipt.id ||
        !_conversations.values.any((chat) => identical(chat, target))) {
      return false;
    }
    _responseReceipts[result] = null;
    target.messages.add(guidanceMessage(result, language));
    target.pending = false;
    final originalContext = _requestContexts.remove(receipt.key);
    final originalTurns = _conversationContexts.remove(receipt.key);
    final originalMode = _conversationModes.remove(receipt.key);
    final originalMemory = _conversationMemory.remove(receipt.key);
    if (_requestIds[receipt.key] == receipt.id) _requestIds.remove(receipt.key);
    target.changed(); // Persists the answer and identity removal together.
    await flushStorage();
    if (receipt.revision == _revision &&
        vault != null &&
        storageError != null) {
      // A failed write must not make another send billable. The original disk
      // generation still contains this identity, and memory must agree.
      _requestIds.putIfAbsent(receipt.key, () => receipt.id);
      if (originalMode != null) {
        _conversationModes.putIfAbsent(receipt.key, () => originalMode);
      }
      if (originalMemory != null) {
        _conversationMemory.putIfAbsent(receipt.key, () => originalMemory);
      }
      if (originalTurns != null) {
        _conversationContexts.putIfAbsent(receipt.key, () => originalTurns);
      }
      if (originalContext != null) {
        _requestContexts.putIfAbsent(receipt.key, () => originalContext);
      }
    }
    return true;
  }

  Map<String, GuideConversation> get savedConversations =>
      Map.unmodifiable(_conversations);

  void conversationUpdated() => notifyListeners();

  void startNewConversation(String guide) {
    final chat = conversation(guide);
    if (chat.pending) return;
    if (chat.messages.any((m) => m.fromUser)) {
      chat.history.add(List.of(chat.messages));
    }
    chat.messages.clear();
    chat.ended = false;
    chat.rating = null;
    chat.billingAcknowledged = false;
    chat.acceptedGeneralCoins = null;
    chat.acceptedRelationshipCoins = null;
    chat.changed();
  }

  GuideConversation conversation(String guide) => _conversations.putIfAbsent(
    guide,
    () => GuideConversation()
      ..language = preferredChatLanguage == 'auto'
          ? (preferences?.value ?? 'auto')
          : preferredChatLanguage
      ..addListener(_persist),
  );

  Future<void> setChatLanguage(String language) async {
    if (!LanguagePreferences.allowed.contains(language)) {
      throw ArgumentError('Invalid chat language');
    }
    await preferences?.set(language);
    for (final conversation in _conversations.values) {
      conversation.language = language;
      conversation.changed();
    }
  }

  void _clearConversations() {
    for (final conversation in _conversations.values) {
      conversation.removeListener(_persist);
      conversation.messages.clear();
      conversation.language = 'auto';
      conversation.pending = false;
    }
    _conversations.clear();
  }

  static const _clockTolerance = Duration(minutes: 5);

  bool _sessionIsFresh(DateTime now) {
    if (_raw?['chatAuthorizedAt'] != null || _raw?['chatExpiresAt'] != null) {
      final start = parseChartInstant(_raw?['chatAuthorizedAt']);
      final end = parseChartInstant(_raw?['chatExpiresAt']);
      return start != null &&
          end != null &&
          end.difference(start) == const Duration(hours: 24) &&
          !now.toUtc().add(_clockTolerance).isBefore(start) &&
          now.toUtc().isBefore(end);
    }
    final timestamp = calculatedAt;
    if (timestamp == null) return false;
    final age = now.toUtc().difference(timestamp.toUtc());
    return age >= -_clockTolerance && age < const Duration(hours: 24);
  }

  Future<void>? _renewal;
  Future<void> renewChatAccess() {
    if (deleting || _deletionCapability != null || _raw == null) {
      return Future.error(
        const JyotaraApiException(
          'A saved active profile is required to renew chat access.',
        ),
      );
    }
    if (calculatedAt == null ||
        _clock().toUtc().add(_clockTolerance).isBefore(calculatedAt!.toUtc())) {
      return Future.error(
        const JyotaraApiException(
          'Check the device clock before renewing chat access.',
        ),
      );
    }
    if (_sessionIsFresh(_clock())) return Future.value();
    if (_renewal != null) return _renewal!;
    final completion = Completer<void>();
    _renewal = completion.future;
    _renewChatAccess().then(
      (_) {
        _renewal = null;
        completion.complete();
      },
      onError: (Object error, StackTrace stack) {
        _renewal = null;
        completion.completeError(error, stack);
      },
    );
    return completion.future;
  }

  Future<void> _renewChatAccess() async {
    final revision = _revision;
    final ticket = _raw?['chartTicket'];
    final profile = _raw?['profileId'];
    if (ticket is! String || profile is! String) {
      throw const JyotaraApiException(
        'A protected saved chart is required to renew chat access.',
      );
    }
    final Map<String, dynamic> result;
    try {
      result = await _api.renewChartSession(
        chartTicket: ticket,
        profileId: profile,
      );
    } on JyotaraApiException catch (e) {
      final input = birthInput;
      if ([
            'renewal_unavailable',
            'provider_refresh_required',
          ].contains(e.code) &&
          input != null &&
          revision == _revision &&
          !deleting) {
        await calculate(
          dateTime: input.dateTime,
          latitude: input.latitude,
          longitude: input.longitude,
          exactTime: input.exactTime,
          nickname: nickname,
          gender: gender,
          birthplaceLabel: birthplaceLabel,
          refreshAccess: false,
          forceProviderRefresh: true,
        );
        if (storageError != null || facts == null) {
          throw const JyotaraApiException(
            'Saved profile could not be refreshed. Please retry.',
          );
        }
        return;
      }
      rethrow;
    }
    if (revision != _revision || deleting || _deletionCapability != null) {
      throw const JyotaraApiException(
        'Your profile changed while chat access was being renewed.',
      );
    }
    final start = parseChartInstant(result['chatAuthorizedAt'])!;
    final end = parseChartInstant(result['chatExpiresAt'])!;
    if (_clock().toUtc().add(_clockTolerance).isBefore(start) ||
        !_clock().toUtc().isBefore(end)) {
      throw const JyotaraApiException(
        'Check the device clock before renewing chat access.',
      );
    }
    // Only the capability metadata changes; original birth/chart timestamps,
    // evidence, conversation history and request identities stay intact.
    _raw = Map<String, dynamic>.from(_raw!)
      ..['chartTicket'] = result['chartTicket']
      ..['chatAuthorizedAt'] = result['chatAuthorizedAt']
      ..['chatExpiresAt'] = result['chatExpiresAt'];
    _persist();
    await flushStorage();
    if (revision != _revision) {
      throw const JyotaraApiException(
        'Your profile changed while chat access was being renewed.',
      );
    }
    if (vault != null && storageError != null) {
      throw const JyotaraApiException(
        'Renewed access could not be saved. The question was not sent; please retry.',
      );
    }
  }

  Future<void> calculate({
    required String dateTime,
    required double latitude,
    required double longitude,
    required bool exactTime,
    String? nickname,
    String? birthplaceLabel,
    ProfileGender? gender,
    bool refreshAccess = true,
    bool forceProviderRefresh = false,
  }) async {
    if (deleting || _deletionCapability != null) {
      throw const JyotaraApiException(
        'Please wait until device deletion finishes before creating a profile.',
      );
    }
    if (calculating) {
      throw const JyotaraApiException('A chart is already being calculated.');
    }
    if (answering) {
      throw const JyotaraApiException(
        'Please wait for the current answer before changing your birth profile.',
      );
    }
    final key = '$dateTime|$latitude|$longitude|$exactTime';
    if ((nickname != null && _displayValue(nickname, 60) == null) ||
        (birthplaceLabel != null &&
            _displayValue(birthplaceLabel, 160) == null)) {
      throw const JyotaraApiException(
        'Check the full name and birthplace label.',
      );
    }
    if (_profileKey == key && _facts != null && !forceProviderRefresh) {
      final savedRevision = _revision;
      var requiresCalculation = false;
      try {
        if (refreshAccess) await renewChatAccess();
      } on JyotaraApiException catch (error) {
        if (error.code != 'provider_refresh_required') rethrow;
        // Explicit Calculate action authorizes a new chart only for this status.
        requiresCalculation = true;
      }
      if (savedRevision != _revision) {
        throw const JyotaraApiException(
          'Your profile changed while chat access was being renewed.',
        );
      }
      if (!requiresCalculation) {
        if (nickname != null) this.nickname = nickname.trim();
        if (gender != null) this.gender = gender;
        if (birthplaceLabel != null) {
          this.birthplaceLabel = birthplaceLabel.trim();
        }
        _persist();
        notifyListeners();
        return;
      }
    }
    final revision = forceProviderRefresh ? _revision : ++_revision;
    final previousSession = _api.ensureSession();
    // Keep the saved profile/history until replacement calculations validate.
    // Asking is blocked by calculating, so these facts cannot answer a request
    // intended for the proposed replacement profile.
    calculating = true;
    notifyListeners();
    try {
      if (_raw == null && vault != null) {
        if (storageError != null) {
          throw const JyotaraApiException(
            'Saved data must be recovered or deleted before creating a new chart.',
          );
        }
        try {
          await vault!.save({
            'version': 1,
            'kind': 'pending-profile',
            'origin': _api.storageOrigin,
            'session': previousSession,
          });
        } catch (_) {
          throw const JyotaraApiException(
            'The chart request was not sent because its recovery record could not be saved. Please retry.',
          );
        }
      }
      if (revision != _revision) return;
      profileRequestUnconfirmed = true;
      final now = _clock().toUtc();
      final response = await _api.calculateChart(
        dateTime: dateTime,
        latitude: latitude,
        longitude: longitude,
        currentDateTime: now.toIso8601String(),
        birthTimeKnown: exactTime,
      );
      final originalCalculation =
          parseChartInstant(response.chart['chartCalculatedAt']) ?? now;
      final converted = normalizeChartFacts(
        response.chart,
        birthTimeKnown: exactTime,
        at: originalCalculation,
      );
      if (revision != _revision) return;
      if (_profileKey != key) {
        _clearConversations();
        _requestIds.clear();
        _reportPeople.clear();
        _requestContexts.clear();
        _conversationContexts.clear();
        _conversationModes.clear();
        _conversationMemory.clear();
        this.nickname = '';
        this.gender = null;
        this.birthplaceLabel = null;
      }
      if (nickname != null) this.nickname = nickname.trim();
      if (gender != null) this.gender = gender;
      if (birthplaceLabel != null) {
        this.birthplaceLabel = birthplaceLabel.trim();
      }
      if (!forceProviderRefresh) researchConsent = false;
      _facts = converted;
      _raw = response.chart;
      _profileKey = key;
      birthTimeKnown = exactTime;
      calculatedAt = originalCalculation;
      profileRequestUnconfirmed = false;
      _persist();
    } catch (_) {
      if (revision == _revision) _api.restoreSession(previousSession);
      rethrow;
    } finally {
      if (revision == _revision) {
        calculating = false;
        notifyListeners();
      }
    }
  }

  /// Resolve an unconfirmed saved request before changing its reply mode. This
  /// is recovery, not a new reading; preserve its original receipt identity.
  ({
    String? depth,
    String? upgrade,
    String id,
    String key,
    bool consent,
    String? guide,
  })?
  pendingGuidanceRequest({
    required String category,
    required String question,
    required String responseStyle,
    String? guide,
  }) {
    final profile = _raw?['profileId'];
    final normalized = question.trim().replaceAll(RegExp(r'\s+'), ' ');
    // Prefer this guide, then recover pre-guide legacy requests. Research
    // preference changes affect new requests, never an uncertain receipt.
    for (final legacy in [false, true]) {
      for (final key in _requestIds.keys.toList().reversed) {
        try {
          var base = jsonDecode(key);
          String? depth;
          String? upgrade;
          if (base is List && base.length == 3 && base[0] is String) {
            depth = base[1] as String?;
            upgrade = base[2] as String?;
            base = jsonDecode(base[0] as String);
          }
          if (base is! List ||
              ![5, 6].contains(base.length) ||
              base[0] != profile ||
              base[1] != category ||
              base[2] != normalized ||
              base[3] != responseStyle ||
              base[4] is! bool ||
              (depth != null && !['standard', 'detailed'].contains(depth))) {
            continue;
          }
          final savedGuide = base.length == 6 ? base[5] as String? : null;
          if (legacy ? savedGuide != null : savedGuide != guide) continue;
          return (
            depth: depth,
            upgrade: upgrade,
            id: _requestIds[key]!,
            key: key,
            consent: base[4] as bool,
            guide: savedGuide,
          );
        } catch (_) {
          /* Unrelated legacy identities remain intact. */
        }
      }
    }
    return null;
  }

  Future<GuidanceResponse> ask({
    required String category,
    required String question,
    required String responseStyle,
    String? guide,
    String? conversationKey,
    String? depth,
    String? upgradeFrom,
  }) async {
    var chart = _facts;
    // Reject invalid input before renewing access or making any network call.
    if (question.trim().isEmpty || question.runes.length > 240) {
      throw const JyotaraApiException(
        'Please enter a question of up to 240 characters.',
      );
    }
    if (deleting || _deletionCapability != null) {
      throw const JyotaraApiException(
        'Finish or retry deletion before asking another question.',
      );
    }
    final revision = _revision;
    if (chart == null || calculating) {
      throw const JyotaraApiException(
        'Create your birth chart before asking for personal guidance.',
      );
    }
    final now = _clock().toUtc();
    if (!_sessionIsFresh(now)) {
      await renewChatAccess();
      if (revision != _revision) {
        throw const JyotaraApiException(
          'Your profile changed before the question was sent.',
        );
      }
    }
    final ticket = _raw?['chartTicket'];
    final profileId = _raw?['profileId'];
    if (ticket is! String ||
        ticket.isEmpty ||
        profileId is! String ||
        profileId.isEmpty) {
      throw const JyotaraApiException(
        'This profile needs a protected backend update before chat is available.',
      );
    }
    if (_raw != null) {
      chart = normalizeChartFacts(
        _raw!,
        birthTimeKnown: birthTimeKnown,
        at: now,
      );
      final contextDay = calculatedAt!.add(
        const Duration(hours: 5, minutes: 30),
      );
      final today = now.add(const Duration(hours: 5, minutes: 30));
      if (contextDay.year != today.year ||
          contextDay.month != today.month ||
          contextDay.day != today.day) {
        chart.remove('todayPanchang');
        chart.remove('transits');
      }
    }
    if (answering) {
      throw const JyotaraApiException(
        'Your previous question is still being answered.',
      );
    }
    answering = true;
    notifyListeners();
    try {
      final pending = pendingGuidanceRequest(
        category: category,
        question: question,
        responseStyle: responseStyle,
        guide: guide,
      );
      final consent = pending?.consent ?? researchConsent;
      final requestDepth = pending != null ? pending.depth : depth;
      final requestUpgrade = pending != null ? pending.upgrade : upgradeFrom;
      final requestGuide = pending != null ? pending.guide : guide;
      final normalizedQuestion = question.trim().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      final legacyKey = jsonEncode([
        profileId,
        category,
        normalizedQuestion,
        responseStyle,
        consent,
      ]);
      final baseRequestKey = _requestIds.containsKey(legacyKey) || guide == null
          ? legacyKey
          : jsonEncode([
              profileId,
              category,
              normalizedQuestion,
              responseStyle,
              consent,
              guide,
            ]);
      final requestKey =
          pending?.key ??
          (depth == null && upgradeFrom == null
              ? baseRequestKey
              : jsonEncode([baseRequestKey, depth, upgradeFrom]));
      if (!_requestIds.containsKey(requestKey)) {
        if (_requestIds.length >= 5000) {
          throw const JyotaraApiException(
            'This device request history is full. Please contact support.',
          );
        }
        // The current question is already visible. Only prior user statements
        // from this guide are retained for legacy topic routing.
        final messages = guide == null
            ? <String>[]
            : (_conversations[conversationKey ?? guide]?.messages ??
                      <ChatMessage>[])
                  .where(
                    (m) =>
                        m.fromUser &&
                        m.text.trim().isNotEmpty &&
                        m.text.runes.length <= 240,
                  )
                  .map((m) => m.text.trim().replaceAll(RegExp(r'\s+'), ' '))
                  .toList();
        if (messages.isNotEmpty && messages.last == normalizedQuestion) {
          messages.removeLast();
        }
        _requestContexts[requestKey] = messages
            .skip(max(0, messages.length - 6))
            .toList(growable: false);
        // Freeze both sides for retries. Conversation is memory, not evidence.
        final turns =
            (guide == null
                    ? <ChatMessage>[]
                    : (_conversations[conversationKey ?? guide]?.messages ??
                          <ChatMessage>[]))
                .where(
                  (m) =>
                      m.text.trim().isNotEmpty &&
                      m.wallet?['status'] != 'failed' &&
                      ![
                        'INTERRUPTED REQUEST',
                        'ERROR',
                        'REQUEST FAILED',
                        'ANSWER NOT CONFIRMED',
                        'REQUEST NOT COMPLETED',
                        'SERVICE ERROR',
                      ].contains(m.label),
                )
                .toList();
        if (turns.isNotEmpty &&
            turns.last.fromUser &&
            turns.last.text.trim().replaceAll(RegExp(r'\s+'), ' ') ==
                normalizedQuestion) {
          turns.removeLast();
        }
        final unified = guide != null;
        final contextStart = max(0, turns.length - (unified ? 32 : 12));
        if (unified) {
          _conversationModes[requestKey] = 'conversation';
          final earlier = turns
              .take(contextStart)
              .where((m) => m.fromUser)
              .toList();
          _conversationMemory[requestKey] = earlier
              .skip(max(0, earlier.length - 12))
              .map((m) => String.fromCharCodes(m.text.trim().runes.take(1000)))
              .toList();
        }
        _conversationContexts[requestKey] = turns
            .skip(contextStart)
            .map(
              (m) => <String, String>{
                'role': m.fromUser ? 'user' : 'assistant',
                'content': String.fromCharCodes(
                  m.text.trim().runes.take(unified ? 4000 : 1800),
                ),
              },
            )
            .toList();
        final input = birthInput;
        // General guidance can use optional context even when time is unknown.
        // Never invent a provider birth time or gender to unlock a reading.
        _reportPeople[requestKey] = {
          if (relationshipStatus.isNotEmpty &&
              relationshipStatus != 'Prefer not to say')
            'relationshipStatus': relationshipStatus,
          if (profession.isNotEmpty && profession != 'Prefer not to say')
            'profession': profession,
        };
        if (input != null &&
            input.exactTime &&
            ['male', 'female'].contains(gender?.value) &&
            (birthplaceLabel?.isNotEmpty ?? false)) {
          _reportPeople[requestKey]!.addAll({
            'datetime': input.dateTime,
            'latitude': input.latitude,
            'longitude': input.longitude,
            'name': nickname.isEmpty ? 'Jyotara profile' : nickname,
            'gender': gender!.value,
            'place': birthplaceLabel!,
          });
        }
        final random = Random.secure();
        _requestIds[requestKey] = List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
      }
      final requestId = _requestIds[requestKey]!;
      // Persist identity BEFORE transport so a process restart cannot turn an
      // uncertain delivery into a new billable request. No automatic resubmit.
      _persist();
      await flushStorage();
      if (revision != _revision) {
        throw const JyotaraApiException(
          'Your profile changed before the question was sent.',
        );
      }
      if (vault != null && storageError != null) {
        throw const JyotaraApiException(
          'The question was not sent because its recovery record could not be saved. Please retry.',
        );
      }
      final result = await _api.askGuidance(
        category: category,
        question: question.trim(),
        responseStyle: responseStyle,
        birthTimeKnown: birthTimeKnown,
        chart: chart,
        chartTicket: ticket,
        profileId: profileId,
        researchConsent: consent,
        requestId: requestId,
        previousUserMessages: _requestContexts[requestKey] ?? const [],
        conversationHistory: _conversationContexts[requestKey] ?? const [],
        responseMode: _conversationModes[requestKey],
        conversationMemory: _conversationMemory[requestKey] ?? const [],
        reportPerson: _reportPeople[requestKey],
        guide: requestGuide,
        depth: requestDepth,
        upgradeFrom: requestUpgrade,
      );
      if (revision != _revision) {
        throw const JyotaraApiException(
          'Your profile changed. Please ask again using the new chart.',
        );
      }
      if (result.answer.trim().isEmpty) {
        throw const JyotaraApiException(
          'No answer was returned. Please try again.',
        );
      }
      _responseReceipts[result] = (
        key: requestKey,
        id: requestId,
        revision: revision,
      );
      return result;
    } finally {
      if (revision == _revision) {
        answering = false;
        notifyListeners();
      }
    }
  }

  Map<String, String>? _deletionCapability;
  bool get canDeleteServer =>
      _deletionCapability != null ||
      (_raw?['chartTicket'] is String &&
          (_raw!['chartTicket'] as String).isNotEmpty &&
          _raw?['profileId'] is String &&
          (_raw!['profileId'] as String).isNotEmpty);

  Future<void> discardUnfinished() async {
    if (calculating || answering || deleting) {
      throw const JyotaraApiException(
        'Please wait for the current request to finish.',
      );
    }
    if (_facts != null || _raw != null) {
      throw const JyotaraApiException(
        'Use saved chart deletion for a completed birth chart.',
      );
    }
    deleting = true;
    try {
      if (profileRequestUnconfirmed) await _api.discardPendingChart();
      await clear();
    } finally {
      deleting = false;
    }
  }

  Future<void> clear({bool includeServer = false}) {
    // Repeated confirmations share one operation, including its failure.
    final pending = _deletion;
    if (pending != null) return pending;
    final completion = Completer<void>();
    _deletion = completion.future;
    deleting = true;
    (includeServer ? _deleteServerAndDevice() : _deleteProfile()).then(
      completion.complete,
      onError: completion.completeError,
    );
    return completion.future;
  }

  Future<void> _deleteServerAndDevice() async {
    var serverConfirmed = false;
    try {
      if (!canDeleteServer) {
        throw const JyotaraApiException(
          'A saved chart is required for server deletion.',
        );
      }
      _deletionCapability ??= {
        'chartTicket': _raw!['chartTicket'] as String,
        'profileId': _raw!['profileId'] as String,
      };
      researchConsent = false;
      _revision++;
      // Invalidate older in-flight transports while retaining the deletion
      // credential. No new anonymous identity until both deletions succeed.
      _api.restoreSession(_api.sessionForStorage);
      notifyListeners();
      if (vault != null && _raw != null) {
        // Persist intent before transport, in the same encrypted vault as the
        // existing capability. Reopening must not resume ordinary chat.
        _persist(deletionCheckpoint: true);
        await flushStorage();
        if (storageError != null) {
          throw const JyotaraApiException(
            'Deletion was not sent because its retry state could not be saved. Please retry.',
          );
        }
      }
      await _api.deleteChartSession(
        chartTicket: _deletionCapability!['chartTicket']!,
        profileId: _deletionCapability!['profileId']!,
      );
      serverConfirmed = true;
      await _deleteProfile(keepLocked: true);
      _deletionCapability = null;
      _api.restoreSession(null);
      deleting = false;
      _deletion = null;
      notifyListeners();
    } catch (_) {
      if (!serverConfirmed) {
        storageError = 'Server deletion was not confirmed. Your saved profile is kept so you can retry. No deletion success is claimed.';
      }
      deleting = false;
      _deletion = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _deleteProfile({bool keepLocked = false}) async {
    researchConsent = false;
    _revision++;
    _clearConversations();
    _requestIds.clear();
    _reportPeople.clear();
    _requestContexts.clear();
    _conversationContexts.clear();
    _conversationModes.clear();
    _conversationMemory.clear();
    _facts = null;
    _raw = null;
    _profileKey = null;
    nickname = '';
    preferredChatLanguage = 'auto';
    relationshipStatus = '';
    profession = '';
    gender = null;
    birthplaceLabel = null;
    calculatedAt = null;
    profileRequestUnconfirmed = false;
    calculating = false;
    answering = false;
    birthTimeKnown = false;
    notifyListeners();
    try {
      await vault?.delete();
      storageError = null;
    } catch (_) {
      storageError = 'Device deletion failed. Saved data may return after restart. Please retry deletion.';
      rethrow;
    } finally {
      if (!keepLocked) {
        deleting = false;
        _deletion = null;
      }
      notifyListeners();
    }
  }
}
