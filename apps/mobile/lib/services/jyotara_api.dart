import 'user_journey.dart';
import '../coin_wallet.dart';
import '../payment_support.dart' show AccountServiceError;

import 'dart:async';
import 'dart:math';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'chart_instant.dart';

const defaultApiBaseUrl = String.fromEnvironment(
  'JYOTARA_API_BASE_URL',
  defaultValue: String.fromEnvironment(
    'NIRAYANA_API_BASE_URL',
    defaultValue: 'https://api.jyotara.invalid',
  ),
);

class JyotaraApiException implements Exception {
  const JyotaraApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.deliveryUncertain = false,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final bool deliveryUncertain;
  String get chatLabel =>
      deliveryUncertain ? 'ANSWER NOT CONFIRMED' : 'REQUEST NOT COMPLETED';
  String get chatMessage => deliveryUncertain
      ? '$message The request may have reached the server. It has not been resent automatically.'
      : message;

  @override
  String toString() => message;
}

class ChartResponse {
  const ChartResponse({
    required this.sandbox,
    required this.chart,
    required this.moduleStatus,
  });

  final bool sandbox;
  final Map<String, dynamic> chart;
  final Map<String, dynamic> moduleStatus;

  factory ChartResponse.fromJson(Map<String, dynamic> json) {
    if ((json.containsKey('chartCalculatedAt') &&
            parseChartInstant(json['chartCalculatedAt']) == null) ||
        (json.containsKey('profileRecovered') &&
            json['profileRecovered'] is! bool) ||
        (json['profileRecovered'] == true &&
            parseChartInstant(json['chartCalculatedAt']) == null)) {
      throw const JyotaraApiException(
        'Invalid chart recovery information.',
        deliveryUncertain: true,
      );
    }
    return ChartResponse(
      sandbox: json['sandbox'] == true,
      chart: Map<String, dynamic>.from(json),
      moduleStatus: Map<String, dynamic>.from(
        json['moduleStatus'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }
}

class GuidanceResponse {
  const GuidanceResponse({
    required this.answer,
    required this.evidence,
    required this.support,
    required this.answerMode,
    this.limitation,
    this.replayed = false,
    this.answeredAt,
    this.wallet,
  });

  final String answer;
  final List<String> evidence;
  final String support;
  final String answerMode;
  final String? limitation;
  final bool replayed;
  final DateTime? answeredAt;
  final Map<String, dynamic>? wallet;

  factory GuidanceResponse.fromJson(Map<String, dynamic> json) {
    final answer = json['answer'];
    final evidence = json['evidence'];
    final limitation = json['limitation'];
    final support = json['support'];
    final mode = json['answerMode'];
    final answeredAt = json['answeredAt'];
    final replayed = json['replayed'];
    if (answer is! String ||
        answer.trim().isEmpty ||
        answer.length > 20000 ||
        evidence is! List ||
        evidence.length > 100 ||
        evidence.any(
          (item) =>
              item is! String || item.trim().isEmpty || item.length > 2000,
        ) ||
        (limitation != null &&
            (limitation is! String || limitation.length > 5000)) ||
        (support != null && (support is! String || support.length > 80)) ||
        (mode != null && (mode is! String || mode.length > 80)) ||
        (replayed != null && replayed is! bool) ||
        (answeredAt != null && parseChartInstant(answeredAt) == null)) {
      throw const JyotaraApiException(
        'The service returned incomplete or invalid guidance. No answer has been displayed.',
        deliveryUncertain: true,
      );
    }
    return GuidanceResponse(
      answer: answer,
      evidence: List<String>.unmodifiable(evidence.cast<String>()),
      support: support as String? ?? 'unknown',
      answerMode: mode as String? ?? 'unknown',
      limitation: limitation as String?,
      replayed: replayed == true,
      answeredAt: parseChartInstant(answeredAt),
      wallet: json['wallet'] is Map
          ? Map<String, dynamic>.from(json['wallet'])
          : null,
    );
  }
}

class JyotaraApiClient {
  JyotaraApiClient({
    http.Client? client,
    String? baseUrl,
    String? Function()? testerCode,
    String? Function()? phoneToken,
  }) : _phoneToken = phoneToken ?? (() => null),
       _testerCode = testerCode ?? (() => null),
       _client = client ?? http.Client(),
       _baseUri = Uri.parse(baseUrl ?? defaultApiBaseUrl) {
    final localDebug =
        kDebugMode &&
        (const bool.fromEnvironment('JYOTARA_LOCAL_QA') ||
            const bool.fromEnvironment('NIRAYANA_LOCAL_QA')) &&
        _baseUri.scheme == 'http' &&
        _baseUri.host == '127.0.0.1';
    if ((_baseUri.scheme != 'https' && !localDebug) ||
        _baseUri.host.isEmpty ||
        _baseUri.userInfo.isNotEmpty) {
      throw ArgumentError(
        'The backend must use HTTPS without URL credentials.',
      );
    }
  }

  final String? Function() _testerCode;
  final String? Function() _phoneToken;
  final http.Client _client;
  final Uri _baseUri;
  String? _sessionCookie;
  int _sessionRevision = 0;
  String get storageOrigin => _baseUri.toString();
  // The verified Jyotara domain routes to the same backend, ticket key and
  // accounts as the original IP. Only this explicit one-way migration is safe.
  bool acceptsStorageOrigin(Object? origin) =>
      origin == storageOrigin ||
      (storageOrigin == 'https://api.jyotara.in' &&
          origin == 'https://168.144.64.47');
  String? get sessionForStorage => _sessionCookie;
  String ensureSession() {
    if (_sessionCookie != null) return _sessionCookie!;
    final random = Random.secure();
    _sessionRevision++;
    return _sessionCookie =
        'nirayana_pilot_session=${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  }

  void restoreSession(String? value) {
    if (value != null &&
        !RegExp(r'^nirayana_pilot_session=[A-Za-z0-9_-]{1,128}$')
            .hasMatch(value)) {
      throw const FormatException('Invalid saved session');
    }
    _sessionCookie = value;
    _sessionRevision++;
  }

  Future<ChartResponse> calculateChart({
    required String dateTime,
    required double latitude,
    required double longitude,
    required String currentDateTime,
    bool birthTimeKnown = true,
    String language = 'en',
  }) async {
    final birth = parseChartInstant(dateTime);
    if (birth == null ||
        parseChartInstant(currentDateTime) == null ||
        birth.isAfter(DateTime.now()) ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(dateTime)) {
      throw const JyotaraApiException(
        'Check the birth date, timezone and birthplace.',
      );
    }
    final response = await _post('/api/astrology/kundli', {
      'datetime': dateTime,
      'latitude': latitude,
      'longitude': longitude,
      'currentDatetime': currentDateTime,
      'language': language == 'ta' ? 'ta' : 'en',
      'birthTimeKnown': birthTimeKnown,
    });
    return ChartResponse.fromJson(response);
  }

  Future<void> discardPendingChart() async {
    ensureSession();
    final result = await _post('/api/profile/discard', {});
    if (result['deleted'] != true) {
      throw const JyotaraApiException(
        'Unfinished birth chart deletion was not confirmed.',
      );
    }
  }

  Future<List<List<dynamic>>> searchLocations(String query) async {
    final value = query.trim();
    if (value.length < 3 || value.length > 80) {
      throw const JyotaraApiException(
        'Enter a birthplace of 3 to 80 characters.',
      );
    }
    final result = await _post('/api/locations', {'query': value});
    if (result['data'] is! List) {
      throw const JyotaraApiException(
        'Place search returned an invalid response.',
      );
    }
    return (result['data'] as List)
        .whereType<List>()
        .where(
          (row) =>
              row.length >= 8 &&
              row[1] is String &&
              row[2] is String &&
              row[4] == 'IN' &&
              row[5] == 'Asia/Kolkata' &&
              row[6] is num &&
              (row[6] as num).isFinite &&
              (row[6] as num).abs() <= 90 &&
              row[7] is num &&
              (row[7] as num).isFinite &&
              (row[7] as num).abs() <= 180,
        )
        .take(20)
        .map((row) => List<dynamic>.from(row))
        .toList();
  }

  Future<GuidanceResponse> askGuidance({
    required String category,
    required String question,
    required String responseStyle,
    required bool birthTimeKnown,
    required Map<String, dynamic> chart,
    String? chartTicket,
    String? profileId,
    bool researchConsent = false,
    String? ageBand,
    String? requestId,
    List<String> previousUserMessages = const [],
    List<Map<String, String>> conversationHistory = const [],
    String? responseMode,
    String? billingSession,
    List<String> conversationMemory = const [],
    Map<String, dynamic>? reportPerson,
    String? guide,
    String? depth,
    String? upgradeFrom,
    List<String> userMessageBatch = const [],
    void Function(String state)? onDeliveryState,
  }) async {
    final language = responseStyle == 'english' ? 'en' : 'ta';
    if (chartTicket == null ||
        chartTicket.isEmpty ||
        profileId == null ||
        profileId.isEmpty) {
      throw const JyotaraApiException(
        'A protected birth profile is required before asking.',
      );
    }
    var finished = false, checking = false;
    Timer? statusTimer;
    if (onDeliveryState != null && requestId != null) {
      statusTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        if (finished || checking) return;
        checking = true;
        try {
          final status = await _post('/api/guidance/status', {
            'profileId': profileId,
            'chartTicket': chartTicket,
            'requestId': requestId,
          });
          if (!finished &&
              status['requestId'] == requestId &&
              status['profileId'] == profileId &&
              [
                'received',
                'processing',
                'complete',
              ].contains(status['state'])) {
            onDeliveryState(status['state'] as String);
          }
        } catch (_) {
          /* No confirmed receipt means no invented delivery tick. */
        } finally {
          checking = false;
        }
      });
    }
    late Map<String, dynamic> response;
    try {
      response = await _post('/api/guidance', {
        'category': category,
        'guide': ?guide,
        'depth': ?depth,
        'upgradeFrom': ?upgradeFrom,
        'question': question,
        if (userMessageBatch.isNotEmpty) 'userMessageBatch': userMessageBatch,
        'language': language,
        // The current pilot accepts ta/en. The mobile contract carries the
        // requested response style so the backend can add Tanglish without ever
        // exposing a model key in the app.
        'responseStyle': responseStyle,
        'responseMode': ?responseMode,
        if (billingSession != null) ...{
          'billingVersion': 2,
          'billingSession': billingSession,
        },
        if (conversationMemory.isNotEmpty)
          'conversationMemory': conversationMemory,
        'chartTicket': chartTicket,
        'profileId': profileId,
        'researchConsent': researchConsent,
        if (researchConsent && userMessageBatch.isNotEmpty)
          'researchConsentVersion': 'research-conversation-v2',
        'ageBand': ?ageBand,
        'requestId': ?requestId,
        'reportPerson': ?reportPerson,
        if (conversationHistory.isNotEmpty)
          'conversationHistory': conversationHistory,
        if (previousUserMessages.isNotEmpty)
          'previousUserMessages': List<String>.from(previousUserMessages),
      }, onDispatch: () => onDeliveryState?.call('sent'));
    } finally {
      finished = true;
      statusTimer?.cancel();
    }
    if (response['profileId'] != profileId) {
      throw const JyotaraApiException(
        'The answer did not match your birth profile. Please reopen your profile.',
        deliveryUncertain: true,
      );
    }
    return GuidanceResponse.fromJson(response);
  }

  Future<Map<String, dynamic>> renewChartSession({
    required String chartTicket,
    required String profileId,
  }) async {
    final result = await _post('/api/profile/renew', {
      'chartTicket': chartTicket,
      'profileId': profileId,
    });
    final authorized = parseChartInstant(result['chatAuthorizedAt']);
    final expires = parseChartInstant(result['chatExpiresAt']);
    if (result['profileId'] != profileId ||
        result['renewed'] != true ||
        result['natalRecalculated'] != false ||
        result['chartTicket'] is! String ||
        (result['chartTicket'] as String).isEmpty ||
        authorized == null ||
        expires == null ||
        expires.difference(authorized) != const Duration(hours: 24)) {
      throw const JyotaraApiException(
        'The renewed chat access could not be verified. Your saved chart was not replaced.',
      );
    }
    return result;
  }

  Future<void> deleteChartSession({
    required String chartTicket,
    required String profileId,
  }) async {
    if (chartTicket.isEmpty || profileId.isEmpty || _sessionCookie == null) {
      throw const JyotaraApiException(
        'A saved chart is required for server deletion.',
      );
    }
    final response = await _post('/api/profile/delete', {
      'chartTicket': chartTicket,
      'profileId': profileId,
    });
    if (response['deleted'] != true ||
        response['scope'] != 'anonymous_chart_session') {
      throw const JyotaraApiException(
        'Server deletion was not confirmed. Please retry.',
        deliveryUncertain: true,
      );
    }
  }

  Future<void> reportAnswer({
    required String answer,
    required String guide,
    required String reason,
  }) async {
    final result = await _post('/api/answers/report', {
      'answer': answer,
      'guide': guide,
      'reason': reason,
      'consent': true,
    });
    if (result['reported'] != true) {
      throw const JyotaraApiException(
        'Report was not confirmed. Please retry.',
      );
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    void Function()? onDispatch,
  }) async {
    final sessionRevision = _sessionRevision;
    if (coinWalletEnabled &&
        path == '/api/guidance' &&
        body['question'] !=
            'Show the selected profile rasi, nakshatra and current Saturn status.') {
      try {
        body.putIfAbsent('depth', () => 'standard');
        body = await confirmCoins('guidance', body);
      } on AccountServiceError catch (e) {
        throw JyotaraApiException(e.message, code: e.code);
      } catch (e) {
        throw JyotaraApiException(e.toString());
      }
      if (sessionRevision != _sessionRevision) {
        throw const JyotaraApiException(
          'Your profile changed. Please try again.',
        );
      }
    }
    final feature = path.startsWith('/api/guidance')
        ? 'chat'
        : path.contains('/profile') || path == '/api/astrology/kundli'
        ? 'profile'
        : path.contains('matching')
        ? 'matching'
        : path.contains('daily')
        ? 'daily'
        : path.contains('locations')
        ? 'location'
        : 'other';
    userJourney.event(
      'api.request',
      metadata: {'feature': feature, 'source': 'api', 'outcome': 'started'},
    );
    late http.Response response;
    try {
      onDispatch?.call();
      response = await _client
          .post(
            _baseUri.resolve(path),
            headers: {
              'Content-Type': 'application/json',
              if (const bool.fromEnvironment('JYOTARA_MINUTE_BILLING'))
                'X-Jyotara-Wallet-Catalog': '2',
              'X-Jyotara-Wallet-Mode': const String.fromEnvironment(
                'JYOTARA_WALLET_MODE',
                defaultValue: 'test',
              ),
              if (const bool.fromEnvironment('JYOTARA_REQUIRE_PHONE_AUTH'))
                'X-Jyotara-Phone-Auth': 'required',
              'Accept': 'application/json',
              'Cookie': ?_sessionCookie,
              'X-Jyotara-Tester-Code': ?_testerCode(),
              if (_phoneToken() != null)
                'Authorization': 'Bearer ${_phoneToken()}',
            },
            body: jsonEncode(body),
          )
          .timeout(
            Duration(
              seconds: path == '/api/guidance'
                  ? 75
                  : path == '/api/guidance/status'
                  ? 5
                  : 40,
            ),
          );
    } on TimeoutException {
      userJourney.event(
        'api.result',
        metadata: {
          'feature': feature,
          'source': 'api',
          'outcome': 'failed',
          'error': 'timeout',
        },
      );
      throw const JyotaraApiException(
        'The request timed out before an answer was received.',
        deliveryUncertain: true,
      );
    } on http.ClientException {
      userJourney.event(
        'api.result',
        metadata: {
          'feature': feature,
          'source': 'api',
          'outcome': 'failed',
          'error': 'network',
        },
      );
      throw const JyotaraApiException(
        'Unable to connect. Check your internet connection.',
        deliveryUncertain: true,
      );
    }

    userJourney.event(
      'api.result',
      metadata: {
        'feature': feature,
        'source': 'api',
        'status': response.statusCode,
        'outcome': response.statusCode >= 200 && response.statusCode < 300
            ? 'success'
            : 'failed',
      },
    );
    // A deleted/replaced session must not be resurrected by an old response,
    // even if the new session happens to contain the same cookie text.
    if (sessionRevision != _sessionRevision) {
      throw const JyotaraApiException(
        'The session changed while this request was in progress. The old response was not applied.',
        deliveryUncertain: true,
      );
    }
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      final match = RegExp(r'(?:^|,\s*)nirayana_pilot_session=([^;,\s]+)')
          .firstMatch(setCookie);
      if (match != null) {
        final value = match.group(1)!;
        if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value)) {
          throw const JyotaraApiException(
            'The service returned an invalid session.',
            deliveryUncertain: true,
          );
        }
        _sessionCookie = 'nirayana_pilot_session=$value';
      }
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw JyotaraApiException(
        'The service returned an unreadable response.',
        statusCode: response.statusCode,
        deliveryUncertain: true,
      );
    }
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw JyotaraApiException(
        payload['error'] is String &&
                (payload['error'] as String).length <= 1000
            ? payload['error'] as String
            : 'Jyotara service is unavailable.',
        statusCode: response.statusCode,
        code: payload['code'] is String ? payload['code'] as String : null,
        deliveryUncertain:
            response.statusCode >= 500 ||
            payload['code'] == 'request_already_received',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const JyotaraApiException(
        'The service returned an unexpected response.',
        deliveryUncertain: true,
      );
    }
    return payload;
  }

  void close() => _client.close();
}
