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
  @override
  Widget build(BuildContext context) {
    if (_completed || widget.session.facts != null) return widget.child;
    return BirthForm(
      session: widget.session,
      onCompleted: () {
        if (widget.session.facts != null) setState(() => _completed = true);
      },
    );
  }
}
