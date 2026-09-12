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
    DateTime Function()? now,
    this.prepareAccount,
  }) : _now = now ?? DateTime.now,
       _client = client ?? http.Client(),
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
  final Future<void> Function(String account)? prepareAccount;
  String? get accountId => _account;
  final DateTime Function() _now;
  final http.Client _client;
  final Uri _base;
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  String? _token, _account, _challenge, _mobile;
  int _expires = 0, _challengeExpires = 0;
  bool busy = false;
  String? error, notice;
  DateTime? resendAt;
  bool get authorized =>
      _token != null && _now().millisecondsSinceEpoch < _expires;
  String? get token => authorized ? _token : null;
  bool get codeSent => _challenge != null;
  String? get mobile => _mobile;
  bool get codeExpired =>
      codeSent && _now().millisecondsSinceEpoch >= _challengeExpires;
  int get codeSecondsRemaining =>
      ((_challengeExpires - _now().millisecondsSinceEpoch) / 1000).ceil().clamp(
        0,
        300,
      );
  Future<void> _save() => _write(
    jsonEncode({
      'token': _token,
      'accountId': _account,
      'expiresAt': _expires,
      'mobile': _mobile,
      'challengeId': _challenge,
      'challengeExpiresAt': _challengeExpires,
      'resendAt': resendAt?.millisecondsSinceEpoch,
    }),
  );
  Future<void> restore() async {
    try {
      final saved = await _read();
      if (saved == null) return;
      final data = jsonDecode(saved) as Map;
      if (data['mobile'] is String &&
          RegExp(r'^[6-9]\d{9}$').hasMatch(data['mobile'])) {
        _mobile = data['mobile'];
      }
      if (data['resendAt'] is int) {
        resendAt = DateTime.fromMillisecondsSinceEpoch(data['resendAt']);
      }
      if (_mobile != null &&
          data['challengeId'] is String &&
          RegExp(r'^[a-f0-9]{48}$').hasMatch(data['challengeId']) &&
          data['challengeExpiresAt'] is int) {
        _challenge = data['challengeId'];
        _challengeExpires = data['challengeExpiresAt'];
        notice = 'Use the latest SMS code. Reopening the app does not send another SMS.';
      }
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
        retryAfter: data['retryAfterSeconds'] is int
            ? data['retryAfterSeconds']
            : null,
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
    if (resendAt != null && _now().isBefore(resendAt!)) return;
    busy = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      final requestedAt = _now();
      final data = await _post('send', {'mobile': mobile});
      if (data['challengeId'] is! String ||
          !RegExp(r'^[a-f0-9]{48}$').hasMatch(data['challengeId'])) {
        throw const FormatException();
      }
      _challenge = data['challengeId'];
      _mobile = mobile;
      _challengeExpires = requestedAt
          .add(const Duration(minutes: 5))
          .millisecondsSinceEpoch;
      resendAt = _now().add(const Duration(seconds: 60));
      notice = data['deliveryUnconfirmed'] == true
          ? 'Delivery is taking longer. If your SMS arrives, enter the code here.'
          : 'SMS requested. Enter the newest code when it arrives.';
      await _save();
    } on _PhoneError catch (e) {
      error = e.message;
      if (e.retryAfter != null && e.retryAfter! > 0) {
        resendAt = _now().add(Duration(seconds: e.retryAfter!));
        _mobile ??= mobile;
        try {
          await _save();
        } catch (_) {
          error = '${e.message} Unable to save the waiting time.';
        }
      }
    } catch (_) {
      error = 'Unable to confirm delivery. Please wait before trying again.';
      resendAt = _now().add(const Duration(seconds: 60));
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> verify(String input) async {
    if (busy || _challenge == null) return;
    if (codeExpired) {
      error = 'This code has expired. Request a new OTP when the resend timer ends.';
      notifyListeners();
      return;
    }
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
          data['expiresAt'] <= _now().millisecondsSinceEpoch) {
        throw const FormatException();
      }
      if (_account != null &&
          _account != data['accountId'] &&
          prepareAccount == null) {
        await _post('logout', {}, bearer: data['token']);
        throw _PhoneError(
          'Use the phone number previously verified on this device to protect its saved profiles.',
        );
      }
      await prepareAccount?.call(data['accountId'] as String);
      await _write(
        jsonEncode({
          'mobile': _mobile,
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

  Future<void> signOut() async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (token != null) await _post('logout', {}, bearer: token);
      await _write(jsonEncode({'accountId': _account}));
      _token = null;
      _expires = 0;
      _mobile = null;
      _challenge = null;
      _challengeExpires = 0;
      resendAt = null;
      notice = null;
    } catch (_) {
      error = 'Unable to sign out. Check your connection and try again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> editNumber() async {
    if (busy) return;
    _challenge = null;
    _challengeExpires = 0;
    try {
      await _save();
    } catch (_) {
      error = 'Unable to save this change.';
      notifyListeners();
      return;
    }
    error = null;
    notice = null;
    notifyListeners();
  }
}

class _PhoneError implements Exception {
  _PhoneError(this.message, {this.retryAfter});
  final int? retryAfter;
  final String message;
}
