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
  });

  final String answer;
  final List<String> evidence;
  final String support;
  final String answerMode;
  final String? limitation;
  final bool replayed;
  final DateTime? answeredAt;

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
    );
  }
}

class JyotaraApiClient {
  JyotaraApiClient({
    http.Client? client,
    String? baseUrl,
    String? Function()? testerCode,
  }) : _testerCode = testerCode ?? (() => null),
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
  final http.Client _client;
  final Uri _baseUri;
  String? _sessionCookie;
  int _sessionRevision = 0;
  String get storageOrigin => _baseUri.toString();
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
        'Unfinished Kundli deletion was not confirmed.',
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
    Map<String, dynamic>? reportPerson,
    String? guide,
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
    final response = await _post('/api/guidance', {
      'category': category,
      'guide': ?guide,
      'question': question,
      'language': language,
      // The current pilot accepts ta/en. The mobile contract carries the
      // requested response style so the backend can add Tanglish without ever
      // exposing a model key in the app.
      'responseStyle': responseStyle,
      'chartTicket': chartTicket,
      'profileId': profileId,
      'researchConsent': researchConsent,
      'ageBand': ?ageBand,
      'requestId': ?requestId,
      'reportPerson': ?reportPerson,
      if (conversationHistory.isNotEmpty)
        'conversationHistory': conversationHistory,
      if (previousUserMessages.isNotEmpty)
        'previousUserMessages': List<String>.from(previousUserMessages),
    });
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

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final sessionRevision = _sessionRevision;
    late http.Response response;
    try {
      response = await _client
          .post(
            _baseUri.resolve(path),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Cookie': ?_sessionCookie,
              'X-Jyotara-Tester-Code': ?_testerCode(),
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 40));
    } on TimeoutException {
      throw const JyotaraApiException(
        'The request timed out before an answer was received.',
        deliveryUncertain: true,
      );
    } on http.ClientException {
      throw const JyotaraApiException(
        'Unable to connect. Check your internet connection.',
        deliveryUncertain: true,
      );
    }

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
