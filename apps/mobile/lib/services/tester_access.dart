import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'jyotara_api.dart';

class TesterAccess extends ChangeNotifier {
  TesterAccess({http.Client? client, String? baseUrl,
    Future<String?> Function()? read, Future<void> Function(String)? write})
      : _client = client ?? http.Client(), _base = Uri.parse(baseUrl ?? defaultApiBaseUrl),
        _read = read ?? (() => const FlutterSecureStorage().read(key: 'jyotara.tester-access.v1')),
        _write = write ?? ((value) => const FlutterSecureStorage().write(key: 'jyotara.tester-access.v1', value: value));
  final http.Client _client;
  final Uri _base;
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  bool authorized = false, busy = false;
  String? _code;
  String? error;
  String? get code => authorized ? _code : null;

  Future<void> restore() async {
    try { final saved = await _read(); if (saved != null) await verify(saved); }
    catch (_) { error = 'Tester access could not be restored. Enter your code again.'; notifyListeners(); }
  }
  Future<void> verify(String input) async {
    if (busy) return;
    final candidate = input.trim();
    if (!RegExp(r'^[a-f0-9]{48}$').hasMatch(candidate)) {
      error = 'Enter the complete tester access code.'; notifyListeners(); return;
    }
    busy = true; error = null; notifyListeners();
    try {
      if (_base.scheme != 'https' || _base.userInfo.isNotEmpty || _base.host.isEmpty) throw StateError('HTTPS required');
      final response = await _client.post(_base.resolve('/api/tester/check'), headers: {
        'X-Jyotara-Tester-Code': candidate, 'Content-Type': 'application/json',
      }, body: '{}').timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        error = response.statusCode == 401 ? 'The tester code is invalid or expired.' : 'Unable to verify access. Please try again.';
        return;
      }
      final body = jsonDecode(response.body);
      if (body is! Map || body['access'] != 'granted') throw const FormatException();
      await _write(candidate);
      _code = candidate; authorized = true;
    } catch (_) { error = 'Unable to verify or save access. Check your connection and try again.'; }
    finally { busy = false; notifyListeners(); }
  }
}
