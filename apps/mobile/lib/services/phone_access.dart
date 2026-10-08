import 'meta_measurement.dart';
import 'marketing_analytics.dart';
import 'user_journey.dart';

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'jyotara_api.dart';

class PhoneAccess extends ChangeNotifier {
  PhoneAccess({
    required this.testerCode,
    this.requireRealSms = const bool.fromEnvironment('JYOTARA_REAL_SMS_ONLY'),
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
    DateTime Function()? now,
    this.prepareAccount,
    this.restoreVerifiedProfile,
    this.eraseLocalAccount,
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
  final bool requireRealSms;
  final Future<void> Function(String account)? prepareAccount;
  final Future<void> Function(String account, String token)?
  restoreVerifiedProfile;
  bool _profileRestorePending = false;
  bool get profileRestorePending => _profileRestorePending;
  final Future<void> Function(String account)? eraseLocalAccount;
  String? get accountId => _account;
  final DateTime Function() _now;
  final http.Client _client;
  final Uri _base;
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  String? _token, _account, _challenge, _mobile;
  int _expires = 0, _challengeExpires = 0;
  String? _sendRequestId, _sendRequestMobile;
  bool _serverDeleted = false, _deletionPending = false;
  bool _deletionOtp = false;
  bool _reviewAccount = false;
  bool _officeDemoChallenge = false;
  bool get officeDemo => _account?.startsWith('office_demo_') ?? false;
  bool get canVerifyReviewDeletion =>
      _deletionPending && !_serverDeleted && _reviewAccount;
  bool get deletionPending => _deletionPending;
  bool get deletionCodeSent => _deletionPending && _deletionOtp && codeSent;
  bool get canVerifyDeletion =>
      _deletionPending && !_serverDeleted && _mobile != null;
  bool busy = false;
  String? error, notice;
  DateTime? resendAt;
  int get resendSecondsRemaining => resendAt == null
      ? 0
      : ((resendAt!.millisecondsSinceEpoch - _now().millisecondsSinceEpoch) /
                1000)
            .ceil()
            .clamp(0, 86400);
  bool get authorized =>
      !_deletionPending &&
      !_profileRestorePending &&
      _token != null &&
      _now().millisecondsSinceEpoch < _expires;
  String? get token =>
      !_deletionPending && _now().millisecondsSinceEpoch < _expires
      ? _token
      : null;
  int _verificationRevision = 0;
  int get verificationRevision => _verificationRevision;
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
      'serverDeleted': _serverDeleted,
      'deletionPending': _deletionPending,
      'profileRestorePending': _profileRestorePending,
      'deletionOtp': _deletionOtp,
      'reviewAccount': _reviewAccount,
      'officeDemoChallenge': _officeDemoChallenge,
      'token': _token,
      'accountId': _account,
      'expiresAt': _expires,
      'mobile': _mobile,
      'challengeId': _challenge,
      'challengeExpiresAt': _challengeExpires,
      'resendAt': resendAt?.millisecondsSinceEpoch,
      'sendRequestId': _sendRequestId,
      'sendRequestMobile': _sendRequestMobile,
    }),
  );
  Future<void> restore() async {
    try {
      final saved = await _read();
      if (saved == null) return;
      final data = jsonDecode(saved) as Map;
      if (requireRealSms &&
          (data['officeDemoChallenge'] == true ||
              data['reviewAccount'] == true ||
              (data['accountId'] is String &&
                  (data['accountId'] as String).startsWith('office_demo_')))) {
        // Forget demo authentication only; retain separately stored profiles.
        await _write('{}');
        return;
      }
      if (data['sendRequestId'] is String &&
          RegExp(r'^[a-f0-9]{32}$').hasMatch(data['sendRequestId']) &&
          data['sendRequestMobile'] is String &&
          RegExp(r'^[6-9][0-9]{9}$').hasMatch(data['sendRequestMobile'])) {
        _sendRequestId = data['sendRequestId'];
        _sendRequestMobile = data['sendRequestMobile'];
      }
      _officeDemoChallenge = data['officeDemoChallenge'] == true;
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
        _verificationRevision++;
        _challengeExpires = data['challengeExpiresAt'];
        notice = _officeDemoChallenge ? 'Enter your office review OTP.' : 'Use the latest SMS code. Reopening the app does not send another SMS.';
      }
      if (data['accountId'] is String) _account = data['accountId'];
      _serverDeleted = data['serverDeleted'] == true;
      _reviewAccount = data['reviewAccount'] == true;
      _deletionPending = data['deletionPending'] == true || _serverDeleted;
      _profileRestorePending =
          restoreVerifiedProfile != null && !_deletionPending;
      _deletionOtp = _deletionPending && data['deletionOtp'] == true;
      if (data['token'] is String &&
          RegExp(r'^[a-f0-9]{64}$').hasMatch(data['token']) &&
          data['expiresAt'] is int) {
        _token = data['token'];
        _expires = data['expiresAt'];
      }
      if (token == null) _profileRestorePending = false;
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
    final event = switch (path) {
      'send' => 'auth.send',
      'verify' || 'reviewer' => 'auth.verify',
      'session' => 'auth.restore',
      'logout' => 'auth.logout',
      'delete-account' ||
      'verify-deletion' ||
      'reviewer-delete' => 'auth.delete',
      _ => 'api.request',
    };
    final watch = Stopwatch()..start();
    userJourney.event(
      event,
      metadata: {'feature': 'auth', 'outcome': 'started'},
    );
    late http.Response response;
    try {
      response = await _client
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
    } catch (_) {
      userJourney.event(
        event,
        metadata: {
          'feature': 'auth',
          'outcome': 'failed',
          'error': 'network',
          'durationMs': watch.elapsedMilliseconds,
        },
      );
      rethrow;
    }
    userJourney.event(
      event,
      metadata: {
        'feature': 'auth',
        'outcome': response.statusCode == 200 ? 'success' : 'failed',
        'status': response.statusCode,
        'durationMs': watch.elapsedMilliseconds,
      },
    );
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

  Future<void> send(String input, {bool deletionOnly = false}) async {
    if (busy ||
        (_deletionPending && !deletionOnly) ||
        (deletionOnly && !canVerifyDeletion)) {
      return;
    }
    if (deletionOnly && input != _mobile) return;
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
      if (_sendRequestId == null || _sendRequestMobile != mobile) {
        final random = Random.secure();
        _sendRequestId = List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        _sendRequestMobile = mobile;
      }
      // Persist the retry identity before sending; never send automatically.
      await _save();
      final data = await _post('send', {
        'requestId': _sendRequestId,
        'mobile': mobile,
        'officeDemo':
            !requireRealSms &&
            const bool.fromEnvironment('JYOTARA_OFFICE_DEMO_LOGIN'),
      });
      if ((requireRealSms && data['officeDemo'] == true) ||
          data['challengeId'] is! String ||
          !RegExp(r'^[a-f0-9]{48}$').hasMatch(data['challengeId'])) {
        throw const FormatException();
      }
      _challenge = data['challengeId'];
      _verificationRevision++;
      _deletionOtp = deletionOnly;
      _mobile = mobile;
      final expiresIn = data['expiresIn'] is int
          ? (data['expiresIn'] as int).clamp(1, 300)
          : 300;
      _challengeExpires = requestedAt
          .add(Duration(seconds: expiresIn))
          .millisecondsSinceEpoch;
      final retryAfter = data['retryAfterSeconds'] is int
          ? (data['retryAfterSeconds'] as int).clamp(0, 86400)
          : 60;
      resendAt = _now().add(Duration(seconds: retryAfter));
      _sendRequestId = null;
      _sendRequestMobile = null;
      _officeDemoChallenge = data['officeDemo'] == true;
      notice = _officeDemoChallenge
          ? 'Enter your office review OTP.'
          : data['deliveryUnconfirmed'] == true
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
    if (busy || _deletionPending || _challenge == null) return;
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
        'officeDemo': _officeDemoChallenge,
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
          'profileRestorePending': restoreVerifiedProfile != null,
          'token': data['token'],
          'accountId': data['accountId'],
          'expiresAt': data['expiresAt'],
        }),
      );
      _serverDeleted = false;
      _reviewAccount = false;
      _token = data['token'];
      _account = data['accountId'];
      _expires = data['expiresAt'];
      _challenge = null;
      userJourney.event(
        'auth.verify',
        metadata: {'feature': 'auth', 'outcome': 'success'},
      );
      _profileRestorePending = restoreVerifiedProfile != null;
      notifyListeners();
      await _restoreVerifiedProfile();
      if (!_officeDemoChallenge) {
        await marketingAnalytics.event('login_success');
        await metaMeasurement.event('login_success');
      }
    } on _PhoneError catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Unable to verify or save sign-in. Please request a new code and try again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _restoreVerifiedProfile() async {
    if (!_profileRestorePending || _account == null || _token == null) return;
    try {
      await restoreVerifiedProfile?.call(_account!, _token!);
      userJourney.event(
        'profile.restore',
        metadata: {'feature': 'profile', 'outcome': 'success'},
      );
      _profileRestorePending = false;
      error = null;
      await _save();
    } catch (_) {
      _profileRestorePending = true;
      userJourney.event(
        'profile.restore',
        metadata: {
          'feature': 'profile',
          'outcome': 'failed',
          'error': 'unavailable',
        },
      );
      error = 'Your saved profile could not be restored. Retry without entering your details again.';
    }
  }

  Future<void> retryProfileRestore() async {
    if (busy || !_profileRestorePending) return;
    if (token == null) {
      _profileRestorePending = false;
      _token = null;
      _expires = 0;
      error = 'Please verify your phone again.';
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _restoreVerifiedProfile();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> requestDeletionCode() async {
    if (!canVerifyDeletion) return;
    await send(_mobile!, deletionOnly: true);
  }

  Future<void> reviewerLogin(String username, String password) async {
    final deletionOnly = canVerifyReviewDeletion;
    if (busy || (_deletionPending && !deletionOnly) || authorized) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final data = await _post(deletionOnly ? 'reviewer-delete' : 'reviewer', {
        'username': username.trim(),
        'password': password,
      });
      if (deletionOnly) {
        if (data['deleted'] != true) throw const FormatException();
        _serverDeleted = true;
        await _save();
        return;
      }
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
        throw _PhoneError('Unable to switch accounts safely on this device.');
      }
      await prepareAccount?.call(data['accountId'] as String);
      await _write(
        jsonEncode({
          'reviewAccount': true,
          'token': data['token'],
          'accountId': data['accountId'],
          'expiresAt': data['expiresAt'],
        }),
      );
      _token = data['token'];
      _reviewAccount = true;
      _account = data['accountId'];
      _expires = data['expiresAt'];
      _mobile = null;
      userJourney.event(
        'auth.verify',
        metadata: {'feature': 'auth', 'outcome': 'success'},
      );
      _challenge = null;
      _serverDeleted = false;
      resendAt = null;
      notice = null;
    } on _PhoneError catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Unable to sign in to the review account. Please try again.';
    } finally {
      busy = false;
      notifyListeners();
      if (deletionOnly && _serverDeleted) await deleteAccount();
    }
  }

  Future<bool> verifyDeletionCode(String input) async {
    if (busy ||
        !deletionCodeSent ||
        codeExpired ||
        !RegExp(r'^\d{6}$').hasMatch(input.trim())) {
      error =
          'Enter a current 6-digit code. Request a new one if it has expired.';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await _post('verify-deletion', {
        'mobile': _mobile,
        'challengeId': _challenge,
        'otp': input.trim(),
        'officeDemo': _officeDemoChallenge,
      });
      if (result['deleted'] != true) throw const FormatException();
      _serverDeleted = true;
      await _save();
    } catch (_) {
      error = 'Deletion was not confirmed. Check the code or request a new code and retry.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
    return deleteAccount();
  }

  Future<bool> deleteAccount() async {
    if (busy || _account == null || (_token == null && !_serverDeleted)) {
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      _deletionPending = true;
      await _save();
      if (!_serverDeleted) {
        final result = await _post('delete-account', {
          'confirm': true,
        }, bearer: _token);
        if (result['deleted'] != true) throw const FormatException();
        _serverDeleted = true;
        await _save();
      }
      // Keep the token until cleanup completes, allowing the server's opaque
      // deletion receipt to acknowledge a retry after a lost response.
      if (eraseLocalAccount == null) {
        throw StateError('Local erasure unavailable');
      }
      await eraseLocalAccount!(_account!);
      await _write('{}');
      _serverDeleted = false;
      _deletionPending = false;
      _profileRestorePending = false;
      _deletionOtp = false;
      _reviewAccount = false;
      _account = null;
      _token = null;
      await userJourney.discardAccount();
      _mobile = null;
      _challenge = null;
      _expires = 0;
      _challengeExpires = 0;
      resendAt = null;
      notice =
          'Account deleted. External service deletion may still be pending.';
      return true;
    } catch (_) {
      error = 'Deletion could not be completed. Keep this app installed and try again. Contact support if it continues.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (busy || _deletionPending) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await userJourney.beforeLogout();
      if (token != null) await _post('logout', {}, bearer: token);
      await _write(jsonEncode({'accountId': _account}));
      _token = null;
      await userJourney.discardAccount();
      _profileRestorePending = false;
      _expires = 0;
      _mobile = null;
      _challenge = null;
      _verificationRevision++;
      _sendRequestId = null;
      _sendRequestMobile = null;
      _officeDemoChallenge = false;
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

  void clearError() {
    error = null;
    notice = null;
    notifyListeners();
  }

  Future<void> editNumber() async {
    if (busy || _deletionPending) return;
    _challenge = null;
    _verificationRevision++;
    _sendRequestId = null;
    _sendRequestMobile = null;
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
