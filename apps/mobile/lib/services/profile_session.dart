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
  }) : _api = api ?? JyotaraApiClient(),
       _clock = clock ?? DateTime.now;
  final JyotaraApiClient _api;
  Future<List<List<dynamic>>> searchLocations(String query) =>
      _api.searchLocations(query);
  final DateTime Function() _clock;
  final LanguagePreferences? preferences;
  final LocalProfileVault? vault;
  String? storageError;
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
          'messages': conversation.messages
              .map(
                (m) => {
                  'fromUser': m.fromUser,
                  'text': m.text,
                  'label': m.label,
                },
              )
              .toList(),
        }),
      ),
      'requestIds': Map<String, String>.from(_requestIds),
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
      if (saved == null || revision != _revision) return;
      if (saved['kind'] == 'pending-profile') {
        if (saved['origin'] != _api.storageOrigin ||
            saved['session'] is! String) {
          throw const FormatException('Saved request is incompatible');
        }
        _api.restoreSession(saved['session'] as String);
        profileRequestUnconfirmed = true;
        storageError = null;
        _revision++;
        notifyListeners();
        return;
      }
      if (saved['origin'] != _api.storageOrigin ||
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
      if (chats is! Map<String, dynamic> || chats.length > 20) {
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
          ..rating =
              chat['rating'] is int &&
                  chat['rating'] >= 1 &&
                  chat['rating'] <= 5
              ? chat['rating'] as int
              : null;
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
      _api.restoreSession(saved['session'] as String?);
      _raw = raw;
      _facts = restoredFacts;
      _profileKey = saved['profileKey'];
      nickname = _displayValue(saved['nickname'], 60) ?? '';
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
      storageError = deletionRequested
          ? 'Deletion was requested but not completed on this device. Retry deletion before continuing.'
          : null;
      _revision++;
      notifyListeners();
    } catch (_) {
      if (revision != _revision) return;
      storageError = 'Saved data could not be opened. It has not been deleted or overwritten.';
      notifyListeners();
    }
  }

  String? _profileKey;
  String nickname = '';
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
    if (_requestIds[receipt.key] == receipt.id) _requestIds.remove(receipt.key);
    target.changed(); // Persists the answer and identity removal together.
    await flushStorage();
    if (receipt.revision == _revision &&
        vault != null &&
        storageError != null) {
      // A failed write must not make another send billable. The original disk
      // generation still contains this identity, and memory must agree.
      _requestIds.putIfAbsent(receipt.key, () => receipt.id);
      if (originalContext != null) {
        _requestContexts.putIfAbsent(receipt.key, () => originalContext);
      }
    }
    return true;
  }

  GuideConversation conversation(String guide) => _conversations.putIfAbsent(
    guide,
    () => GuideConversation()
      ..language = preferences?.value ?? 'auto'
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

  bool _sessionIsFresh(DateTime now) {
    if (_raw?['chatAuthorizedAt'] != null || _raw?['chatExpiresAt'] != null) {
      final start = parseChartInstant(_raw?['chatAuthorizedAt']);
      final end = parseChartInstant(_raw?['chatExpiresAt']);
      return start != null &&
          end != null &&
          end.difference(start) == const Duration(hours: 24) &&
          !now.toUtc().isBefore(start) &&
          now.toUtc().isBefore(end);
    }
    final timestamp = calculatedAt;
    if (timestamp == null) return false;
    final age = now.toUtc().difference(timestamp.toUtc());
    return !age.isNegative && age < const Duration(hours: 24);
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
        _clock().toUtc().isBefore(calculatedAt!.toUtc())) {
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
    final result = await _api.renewChartSession(
      chartTicket: ticket,
      profileId: profile,
    );
    if (revision != _revision || deleting || _deletionCapability != null) {
      throw const JyotaraApiException(
        'Your profile changed while chat access was being renewed.',
      );
    }
    final start = parseChartInstant(result['chatAuthorizedAt'])!;
    final end = parseChartInstant(result['chatExpiresAt'])!;
    if (_clock().toUtc().isBefore(start) || !_clock().toUtc().isBefore(end)) {
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
        'Check the nickname and birthplace label.',
      );
    }
    if (_profileKey == key && _facts != null) {
      final savedRevision = _revision;
      var requiresCalculation = false;
      try {
        await renewChatAccess();
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
    final revision = ++_revision;
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
        this.nickname = '';
        this.gender = null;
        this.birthplaceLabel = null;
      }
      if (nickname != null) this.nickname = nickname.trim();
      if (gender != null) this.gender = gender;
      if (birthplaceLabel != null) {
        this.birthplaceLabel = birthplaceLabel.trim();
      }
      researchConsent = false;
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

  Future<GuidanceResponse> ask({
    required String category,
    required String question,
    required String responseStyle,
    String? guide,
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
      final consent = researchConsent;
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
      final requestKey = _requestIds.containsKey(legacyKey) || guide == null
          ? legacyKey
          : jsonEncode([
              profileId,
              category,
              normalizedQuestion,
              responseStyle,
              consent,
              guide,
            ]);
      if (!_requestIds.containsKey(requestKey)) {
        if (_requestIds.length >= 5000) {
          throw const JyotaraApiException(
            'This device request history is full. Please contact support.',
          );
        }
        // The current question is already visible. Only prior user statements
        // from this guide are context; assistant claims are never chart facts.
        final messages = guide == null
            ? <String>[]
            : (_conversations[guide]?.messages ?? <ChatMessage>[])
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
        final input = birthInput;
        if (input != null &&
            input.exactTime &&
            ['male', 'female'].contains(gender?.value) &&
            (birthplaceLabel?.isNotEmpty ?? false)) {
          _reportPeople[requestKey] = {
            'datetime': input.dateTime,
            'latitude': input.latitude,
            'longitude': input.longitude,
            'name': nickname.isEmpty ? 'Jyotara profile' : nickname,
            'gender': gender!.value,
            'place': birthplaceLabel!,
          };
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
        reportPerson: _reportPeople[requestKey],
        guide: guide,
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
        'Use saved chart deletion for a completed Kundli.',
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
    _facts = null;
    _raw = null;
    _profileKey = null;
    nickname = '';
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
