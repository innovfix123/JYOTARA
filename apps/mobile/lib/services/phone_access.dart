import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'jyotara_api.dart';

class PhoneAccess extends ChangeNotifier {
  PhoneAccess({
    required this.testerCode,
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
  }) : _client = client ?? http.Client(),
       _base = Uri.parse(baseUrl ?? defaultApiBaseUrl),
       _read =
           read ??
           (() => const FlutterSecureStorage().read(
             key: 'jyotara.phone-access.v1',
           )),
       _write =
           write ??
           ((v) => const FlutterSecureStorage().write(
             key: 'jyotara.phone-access.v1',
             value: v,
           ));
  final String? Function() testerCode;
  final http.Client _client;
  final Uri _base;
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  String? _token, _account, _challenge, _mobile;
  int _expires = 0;
  bool busy = false;
  String? error, notice;
  DateTime? resendAt;
  bool get authorized =>
      _token != null && DateTime.now().millisecondsSinceEpoch < _expires;
  String? get token => authorized ? _token : null;
  bool get codeSent => _challenge != null;
  Future<void> restore() async {
    try {
      final saved = await _read();
      if (saved == null) return;
      final data = jsonDecode(saved) as Map;
      if (data['accountId'] is String) _account = data['accountId'];
      if (data['token'] is String &&
          RegExp(r'^[a-f0-9]{64}$').hasMatch(data['token']) &&
          data['expiresAt'] is int) {
        _token = data['token'];
        _expires = data['expiresAt'];
      }
    } catch (_) {
      error = 'Unable to restore sign-in. Please verify your phone again.';
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? bearer,
  }) async {
    if (_base.scheme != 'https' ||
        _base.host.isEmpty ||
        _base.userInfo.isNotEmpty) {
      throw StateError('HTTPS required');
    }
    final response = await _client
        .post(
          _base.resolve('/api/auth/$path'),
          headers: {
            'Content-Type': 'application/json',
            'X-Jyotara-Tester-Code': testerCode() ?? '',
            if (bearer != null) 'Authorization': 'Bearer $bearer',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw _PhoneError(
        data['error'] is String ? data['error'] : 'Please try again later.',
      );
    }
    return data;
  }

  Future<void> send(String input) async {
    if (busy) return;
    final mobile = input.trim();
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
      error = 'Enter a valid 10-digit Indian mobile number.';
      notifyListeners();
      return;
    }
    if (resendAt != null && DateTime.now().isBefore(resendAt!)) return;
    busy = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      final data = await _post('send', {'mobile': mobile});
      if (data['challengeId'] is! String ||
          !RegExp(r'^[a-f0-9]{48}$').hasMatch(data['challengeId'])) {
        throw const FormatException();
      }
      _challenge = data['challengeId'];
      _mobile = mobile;
      resendAt = DateTime.now().add(const Duration(seconds: 60));
      notice = data['deliveryUnconfirmed'] == true
          ? 'Delivery is taking longer. If your SMS arrives, enter the code here.'
          : 'Code sent. It expires in 5 minutes.';
    } on _PhoneError catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Unable to confirm delivery. Please wait before trying again.';
      resendAt = DateTime.now().add(const Duration(seconds: 60));
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> verify(String input) async {
    if (busy || _challenge == null) return;
    if (!RegExp(r'^\d{6}$').hasMatch(input.trim())) {
      error = 'Enter the 6-digit code.';
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final data = await _post('verify', {
        'mobile': _mobile,
        'challengeId': _challenge,
        'otp': input.trim(),
      });
      if (data['token'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['token']) ||
          data['accountId'] is! String ||
          data['expiresAt'] is! int ||
          data['expiresAt'] <= DateTime.now().millisecondsSinceEpoch) {
        throw const FormatException();
      }
      if (_account != null && _account != data['accountId']) {
        await _post('logout', {}, bearer: data['token']);
        throw _PhoneError(
          'Use the phone number previously verified on this device to protect its saved profiles.',
        );
      }
      await _write(
        jsonEncode({
          'token': data['token'],
          'accountId': data['accountId'],
          'expiresAt': data['expiresAt'],
        }),
      );
      _token = data['token'];
      _account = data['accountId'];
      _expires = data['expiresAt'];
      _challenge = null;
    } on _PhoneError catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Unable to verify or save sign-in. Please request a new code and try again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void editNumber() {
    if (busy) return;
    _challenge = null;
    error = null;
    notice = null;
    notifyListeners();
  }
}

class _PhoneError implements Exception {
  _PhoneError(this.message);
  final String message;
}
