import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/phone_access.dart';

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
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _phone.text = widget.access.mobile ?? '';
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.access,
    builder: (context, _) {
      final access = widget.access;
      if (access.authorized) return widget.child;
      if (access.codeSent && _phone.text != access.mobile) {
        _phone.text = access.mobile ?? '';
      }
      final remaining = access.codeSecondsRemaining;
      final seconds = access.resendAt == null
          ? 0
          : access.resendAt!.difference(DateTime.now()).inSeconds + 1;
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(28),
                children: [
                  Icon(
                    Icons.phone_android_rounded,
                    size: 52,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to Jyotara',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Verify your phone to continue. Your saved profiles and chats stay on this device.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _phone,
                    enabled: !access.busy && !access.codeSent,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [
                      AutofillHints.telephoneNumberNational,
                    ],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      prefixText: '+91 ',
                    ),
                  ),
                  if (access.codeSent) ...[
                    const SizedBox(height: 20),
                    TextField(
                      controller: _otp,
                      enabled: !access.busy && !access.codeExpired,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        labelText: '6-digit OTP',
                      ),
                      onSubmitted: (_) => access.verify(_otp.text),
                    ),
                    TextButton(
                      onPressed: access.busy
                          ? null
                          : () {
                              _otp.clear();
                              access.editNumber();
                            },
                      child: const Text('Change number'),
                    ),
                  ],
                  if (access.codeSent)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        access.codeExpired
                            ? 'This code has expired. Request a new OTP below.'
                            : 'Code expires in ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                      ),
                    ),
                  if (access.notice != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(access.notice!),
                    ),
                  if (access.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        access.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: access.busy
                        ? null
                        : access.codeSent
                        ? access.codeExpired
                              ? null
                              : () => access.verify(_otp.text)
                        : seconds > 0
                        ? null
                        : () => access.send(_phone.text),
                    child: Text(
                      access.busy
                          ? 'Please wait…'
                          : access.codeSent
                          ? 'Verify & continue'
                          : seconds > 0
                          ? 'Wait ${seconds}s'
                          : 'Send OTP',
                    ),
                  ),
                  if (access.codeSent)
                    TextButton(
                      onPressed: access.busy || seconds > 0
                          ? null
                          : () {
                              _otp.clear();
                              access.send(_phone.text);
                            },
                      child: Text(
                        seconds > 0 ? 'Resend in ${seconds}s' : 'Resend OTP',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
