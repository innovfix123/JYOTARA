import 'package:flutter/material.dart';

import 'birth_form.dart';
import 'services/profile_session.dart';

/// A verified phone is not a completed birth profile. Keep new users in setup
/// until calculation succeeds; existing saved profiles retain their journey.
class FirstProfileSetup extends StatefulWidget {
  const FirstProfileSetup({
    super.key,
    required this.session,
    required this.child,
  });
  final ProfileSession session;
  final Widget child;
  @override
  State<FirstProfileSetup> createState() => _FirstProfileSetupState();
}

class _FirstProfileSetupState extends State<FirstProfileSetup> {
  bool _completed = false;
  bool _continueWithoutSavedProfiles = false;
  bool _retrying = false;
  void _continue() => setState(() => _continueWithoutSavedProfiles = true);
  @override
  Widget build(BuildContext context) {
    if (_continueWithoutSavedProfiles) return widget.child;
    if (widget.session.storageError != null &&
        (widget.session.savedReadFailed || widget.session.facts == null)) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _continue();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to Home',
              onPressed: _continue,
            ),
            title: const Text('Saved profiles'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.session.storageError!),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _retrying
                      ? null
                      : () async {
                          setState(() => _retrying = true);
                          await widget.session.restore();
                          if (mounted) setState(() => _retrying = false);
                        },
                  child: const Text('Retry opening saved profiles'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _continue,
                  child: const Text('Back to Home'),
                ),
                const Text(
                  'Your saved profiles are kept. You can retry after reopening the app.',
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_completed || widget.session.facts != null) return widget.child;
    return BirthForm(
      onboarding: true,
      session: widget.session,
      onCompleted: () {
        if (widget.session.facts != null) setState(() => _completed = true);
      },
    );
  }
}
