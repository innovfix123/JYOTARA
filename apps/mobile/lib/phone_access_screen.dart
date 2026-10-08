import 'bronze_theme.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/phone_access.dart';
import 'services/sms_otp_autofill.dart';
import 'privacy_links.dart';
import 'premium_onboarding.dart';

class PhoneAccessScreen extends StatefulWidget {
  const PhoneAccessScreen({
    super.key,
    required this.access,
    required this.child,
  });
  final PhoneAccess access;
  final Widget child;
  @override
  State<PhoneAccessScreen> createState() => _PhoneAccessScreenState();
}

class _PhoneAccessScreenState extends State<PhoneAccessScreen> {
  final _phone = TextEditingController(), _otp = TextEditingController();
  final _reviewUser = TextEditingController(),
      _reviewPassword = TextEditingController();
  final _phoneFocus = FocusNode(), _otpFocus = FocusNode();
  String? _autoSendMobile, _autoVerifyKey;
  late bool _wasCodeSent;
  bool _wasInteractive = false;

  void _focusLoginField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final access = widget.access;
      if (!mounted || access.authorized || access.deletionPending) return;
      final focus = access.codeSent ? _otpFocus : _phoneFocus;
      if (focus.context != null) _showKeyboard(focus);
    });
  }

  void _showKeyboard(FocusNode focus) {
    final access = widget.access;
    if (!mounted ||
        access.authorized ||
        access.deletionPending ||
        access.profileRestorePending ||
        access.busy ||
        _startingSms ||
        focus.context == null) {
      return;
    }
    focus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !focus.hasFocus || widget.access.busy) return;
      // Reopen the IME even when a dismissed field still owns focus.
      unawaited(
        SystemChannels.textInput
            .invokeMethod<void>('TextInput.show')
            .catchError((_) {}),
      );
    });
  }

  void _maybeRequestCode() {
    final access = widget.access;
    final mobile = _phone.text.trim();
    if (!_termsAccepted ||
        access.authorized ||
        access.profileRestorePending ||
        access.deletionPending ||
        access.codeSent ||
        access.busy ||
        _startingSms ||
        access.resendSecondsRemaining > 0 ||
        _autoSendMobile == mobile ||
        !RegExp(r'^[6-9][0-9]{9}$').hasMatch(mobile)) {
      return;
    }
    _autoSendMobile = mobile;
    unawaited(_requestCode());
  }

  void _maybeVerifyCode() {
    final access = widget.access;
    final code = _otp.text.trim();
    if (access.authorized ||
        access.profileRestorePending ||
        access.deletionPending ||
        !access.codeSent ||
        access.codeExpired ||
        access.busy ||
        _startingSms ||
        !RegExp(r'^\d{6}$').hasMatch(code)) {
      return;
    }
    final key = '${access.verificationRevision}:$code';
    if (_autoVerifyKey == key) return;
    _autoVerifyKey = key;
    unawaited(access.verify(code));
  }

  bool _termsAccepted = false;
  Timer? _timer;
  final _smsAutofill = SmsOtpAutofill();
  String? _receivedCode;
  int _smsAttempt = 0;
  bool _startingSms = false;

  void _cancelSms() {
    _smsAttempt++;
    _receivedCode = null;
    unawaited(_smsAutofill.stop());
  }

  void _applyReceivedCode() {
    final access = widget.access;
    if (mounted &&
        !access.authorized &&
        access.codeSent &&
        !access.busy &&
        !access.codeExpired &&
        _receivedCode != null) {
      _otp.value = TextEditingValue(
        text: _receivedCode!,
        selection: TextSelection.collapsed(offset: _receivedCode!.length),
      );
      _receivedCode = null;
    }
  }

  Future<void> _requestCode() async {
    final access = widget.access;
    if (_startingSms || access.busy || access.resendSecondsRemaining > 0) {
      return;
    }
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(_phone.text.trim())) {
      await access.send(_phone.text);
      return;
    }
    setState(() => _startingSms = true);
    final attempt = ++_smsAttempt;
    _receivedCode = null;
    _otp.clear();
    final mobile = _phone.text;
    await _smsAutofill.start((code) {
      if (!mounted || attempt != _smsAttempt) return;
      _receivedCode = code;
      _applyReceivedCode();
    });
    if (mounted) setState(() => _startingSms = false);
    if (!mounted ||
        attempt != _smsAttempt ||
        _phone.text != mobile ||
        !_termsAccepted) {
      if (mounted) _maybeRequestCode();
      return;
    }
    await access.send(mobile);
    if (!mounted || attempt != _smsAttempt) return;
    if (!access.codeSent) _cancelSms();
    _applyReceivedCode();
  }

  late bool _wasAuthorized, _wasDeletionPending;
  late int _verificationRevision;

  void _syncLoginFields() {
    final access = widget.access;
    final deleted = _wasDeletionPending && !access.deletionPending;
    final signedOut = (_wasAuthorized && !access.authorized) || deleted;
    if (signedOut ||
        access.verificationRevision != _verificationRevision ||
        access.authorized) {
      _otp.clear();
      TextInput.finishAutofillContext(shouldSave: false);
    }
    if (signedOut) {
      _phone.clear();
      _reviewUser.clear();
      _reviewPassword.clear();
      _termsAccepted = false;
      _autoSendMobile = null;
      _autoVerifyKey = null;
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (signedOut || access.authorized) _cancelSms();
    final interactive =
        !access.authorized &&
        !access.deletionPending &&
        !access.profileRestorePending &&
        !access.busy;
    if (signedOut ||
        access.codeSent != _wasCodeSent ||
        (interactive && !_wasInteractive)) {
      _focusLoginField();
    }
    _wasInteractive = interactive;
    _wasCodeSent = access.codeSent;
    _wasAuthorized = access.authorized;
    _wasDeletionPending = access.deletionPending;
    _verificationRevision = access.verificationRevision;
    _applyReceivedCode();
    _maybeVerifyCode();
  }

  @override
  void initState() {
    super.initState();
    _phone.text = widget.access.mobile ?? '';
    _wasCodeSent = widget.access.codeSent;
    _otp.addListener(_maybeVerifyCode);
    _focusLoginField();
    _wasAuthorized = widget.access.authorized;
    _wasDeletionPending = widget.access.deletionPending;
    _verificationRevision = widget.access.verificationRevision;
    widget.access.addListener(_syncLoginFields);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          (widget.access.codeSent ||
              widget.access.resendSecondsRemaining > 0)) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _cancelSms();
    widget.access.removeListener(_syncLoginFields);
    _timer?.cancel();
    _phoneFocus.dispose();
    _otpFocus.dispose();
    _phone.dispose();
    _otp.dispose();
    _reviewUser.dispose();
    _reviewPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.access,
    builder: (context, _) {
      final access = widget.access;
      if (access.deletionPending) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const Text('Finish account deletion'),
                    const SizedBox(height: 16),
                    const Text(
                      'Your account is locked while deletion completes. Retry to finish removing the saved data. If this continues, contact jyotara29@gmail.com.',
                    ),
                    if (access.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(access.error!),
                      ),
                    FilledButton(
                      onPressed: access.busy
                          ? null
                          : () => access.deleteAccount(),
                      child: Text(access.busy ? 'Deleting…' : 'Retry deletion'),
                    ),
                    if (access.canVerifyDeletion) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'If your login expired, verify the same phone number to finish deletion. This will not open or recreate your account.',
                      ),
                      TextButton(
                        onPressed:
                            access.busy ||
                                (access.resendAt?.isAfter(DateTime.now()) ??
                                    false)
                            ? null
                            : () => access.requestDeletionCode(),
                        child: Text(
                          (access.resendAt?.isAfter(DateTime.now()) ?? false)
                              ? 'Please wait before requesting another code'
                              : 'Send deletion verification code',
                        ),
                      ),
                      if (access.notice != null) Text(access.notice!),
                      if (access.deletionCodeSent) ...[
                        TextField(
                          controller: _otp,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Deletion verification code',
                          ),
                        ),
                        FilledButton(
                          onPressed: access.busy
                              ? null
                              : () => access.verifyDeletionCode(_otp.text),
                          child: const Text('Verify and delete account'),
                        ),
                      ],
                    ],
                    if (access.canVerifyReviewDeletion) ...[
                      const Text(
                        'Verify review credentials to finish deletion.',
                      ),
                      TextField(
                        controller: _reviewUser,
                        enabled: !access.busy,
                        decoration: const InputDecoration(
                          labelText: 'Review username',
                        ),
                      ),
                      TextField(
                        controller: _reviewPassword,
                        enabled: !access.busy,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Review password',
                        ),
                      ),
                      FilledButton(
                        onPressed: access.busy
                            ? null
                            : () async {
                                await access.reviewerLogin(
                                  _reviewUser.text,
                                  _reviewPassword.text,
                                );
                                _reviewPassword.clear();
                              },
                        child: const Text('Verify and delete review account'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }
      if (access.profileRestorePending) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      access.busy
                          ? 'Restoring your profile…'
                          : 'Restore your saved profile',
                    ),
                    const SizedBox(height: 16),
                    if (access.busy)
                      const CircularProgressIndicator()
                    else ...[
                      Text(
                        access.error ??
                            'Your birth details are saved. Please retry.',
                      ),
                      TextButton(
                        onPressed: access.retryProfileRestore,
                        child: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }
      if (access.authorized) return widget.child;
      if (access.codeSent && _phone.text != access.mobile) {
        _phone.text = access.mobile ?? '';
      }
      final remaining = access.codeSecondsRemaining;
      final seconds = access.resendSecondsRemaining;
      final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
      final action = access.busy || _startingSms
          ? null
          : access.codeSent
          ? (access.codeExpired ? null : () => access.verify(_otp.text))
          : (seconds > 0 || !_termsAccepted ? null : _requestCode);
      final button = OnboardingButton(
        text: access.busy || _startingSms
            ? 'Please wait…'
            : access.codeSent
            ? 'Verify & continue'
            : seconds > 0
            ? 'Wait ${seconds}s'
            : 'Continue',
        onPressed: action,
        busy: access.busy || _startingSms,
      );
      return OnboardingTheme(
        child: Scaffold(
          backgroundColor: onboardingGreen,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(child: OnboardingBackdrop(orbit: false)),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact =
                            keyboardOpen || constraints.maxHeight < 640;
                        final logoSize = access.codeSent
                            ? 0.0
                            : compact
                            ? 48.0
                            : (constraints.maxHeight * .265).clamp(
                                150.0,
                                240.0,
                              );
                        return Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding: EdgeInsets.fromLTRB(
                                  24,
                                  compact ? 8 : 14,
                                  24,
                                  12,
                                ),
                                children: [
                                  Text(
                                    'Jyotara',
                                    textAlign: TextAlign.center,
                                    style: onboardingHeading(compact ? 30 : 32),
                                  ),
                                  if (!access.codeSent) ...[
                                    SizedBox(height: compact ? 6 : 14),
                                    Center(
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        width: compact
                                            ? logoSize
                                            : constraints.maxWidth - 48,
                                        height: compact
                                            ? logoSize
                                            : logoSize + 36,
                                        child: compact
                                            ? OnboardingLogo(size: logoSize)
                                            : OnboardingHero(size: logoSize),
                                      ),
                                    ),
                                    SizedBox(height: compact ? 8 : 6),
                                  ] else
                                    const SizedBox(height: 12),
                                  Text(
                                    access.codeSent
                                        ? 'You’re almost in.'
                                        : 'A little clarity.\nA new beginning.',
                                    textAlign: TextAlign.center,
                                    style: onboardingHeading(compact ? 30 : 36),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    access.codeSent
                                        ? 'Enter the OTP for +91 ${access.mobile}.'
                                        : 'Personal astrology, at your pace.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'JyotaraSans',
                                      fontSize: 13,
                                      letterSpacing: .4,
                                      color: onboardingMuted,
                                    ),
                                  ),
                                  SizedBox(height: compact ? 16 : 24),
                                  if (!compact && !access.codeSent) ...[
                                    const Row(
                                      children: [
                                        Text(
                                          'GET STARTED',
                                          style: TextStyle(
                                            fontFamily: 'JyotaraSans',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 3,
                                            color: onboardingGold,
                                          ),
                                        ),
                                        SizedBox(width: 18),
                                        Expanded(
                                          child: Divider(
                                            color: Color(0x55514330),
                                            height: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                  ],
                                  const Text(
                                    'Mobile number',
                                    style: TextStyle(
                                      fontFamily: 'JyotaraSans',
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OnboardingGlass(
                                    key: const ValueKey('login-phone-input'),
                                    child: TextField(
                                      controller: _phone,
                                      focusNode: _phoneFocus,
                                      onTapAlwaysCalled: true,
                                      onTap: () => _showKeyboard(_phoneFocus),
                                      enabled: !access.busy && !_startingSms,
                                      onChanged: (_) async {
                                        if (access.codeSent) {
                                          await access.editNumber();
                                          _otp.clear();
                                        }
                                        if (mounted) _maybeRequestCode();
                                      },
                                      keyboardType: TextInputType.phone,
                                      autofillHints: const [
                                        AutofillHints.telephoneNumberNational,
                                      ],
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(10),
                                      ],
                                      style: const TextStyle(
                                        fontFamily: 'JyotaraSans',
                                        fontSize: 15,
                                        color: onboardingInk,
                                      ),
                                      decoration: onboardingInput(
                                        hint: 'Enter your number',
                                        prefix: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '+91',
                                                style: TextStyle(
                                                  color: onboardingInk,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              SizedBox(width: 14),
                                              SizedBox(
                                                height: 22,
                                                child: VerticalDivider(
                                                  width: 1,
                                                  color: BronzePalette.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (access.codeSent) ...[
                                    const SizedBox(height: 14),
                                    const Text(
                                      '6-digit OTP',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 8),
                                    OnboardingGlass(
                                      key: const ValueKey('login-otp-input'),
                                      child: TextField(
                                        key: ValueKey(
                                          access.verificationRevision,
                                        ),
                                        controller: _otp,
                                        focusNode: _otpFocus,
                                        onTapAlwaysCalled: true,
                                        onTap: () => _showKeyboard(_otpFocus),
                                        enabled:
                                            !access.busy && !access.codeExpired,
                                        keyboardType: TextInputType.number,
                                        autofillHints: const [
                                          AutofillHints.oneTimeCode,
                                        ],
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(6),
                                        ],
                                        style: const TextStyle(
                                          fontFamily: 'JyotaraSans',
                                          fontSize: 20,
                                          letterSpacing: 6,
                                          color: onboardingInk,
                                        ),
                                        decoration: onboardingInput(
                                          hint: '— — — — — —',
                                        ),
                                        onSubmitted: (_) =>
                                            access.verify(_otp.text),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            access.codeExpired
                                                ? 'This code has expired.'
                                                : 'Code expires in ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: onboardingMuted,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: access.busy
                                              ? null
                                              : () {
                                                  _cancelSms();
                                                  _otp.clear();
                                                  access.editNumber();
                                                },
                                          child: const Text('Change number'),
                                        ),
                                      ],
                                    ),
                                  ] else
                                    LoginConsent(
                                      compact: true,
                                      value: _termsAccepted,
                                      onChanged: access.busy
                                          ? null
                                          : (value) {
                                              setState(
                                                () => _termsAccepted = value,
                                              );
                                              _maybeRequestCode();
                                            },
                                    ),
                                  if (access.notice != null && !access.codeSent)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        access.notice!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: onboardingMuted,
                                        ),
                                      ),
                                    ),
                                  if (access.error != null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        access.error!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFFFFB4AB),
                                        ),
                                      ),
                                    ),
                                  if (!keyboardOpen) ...[
                                    const SizedBox(height: 18),
                                    button,
                                    if (!access.codeSent)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 16),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.lock_outline,
                                              size: 13,
                                              color: onboardingMuted,
                                            ),
                                            SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                'Secure sign-in with an SMS code',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: onboardingMuted,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                  if (access.codeSent && access.codeExpired)
                                    TextButton(
                                      onPressed: access.busy || seconds > 0
                                          ? null
                                          : _requestCode,
                                      child: const Text('Resend OTP'),
                                    ),
                                ],
                              ),
                            ),
                            if (keyboardOpen)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  6,
                                  24,
                                  12,
                                ),
                                child: button,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
