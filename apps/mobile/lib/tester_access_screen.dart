import 'package:flutter/material.dart';
import 'services/tester_access.dart';
import 'services/ui_language.dart';

class TesterAccessScreen extends StatefulWidget {
  const TesterAccessScreen({super.key, required this.access, required this.child});
  final TesterAccess access;
  final Widget child;
  @override
  State<TesterAccessScreen> createState() => _TesterAccessScreenState();
}
class _TesterAccessScreenState extends State<TesterAccessScreen> {
  final _code = TextEditingController();
  @override
  void dispose() { _code.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.access,
    builder: (context, _) {
      if (widget.access.authorized) return widget.child;
      return Scaffold(
        appBar: AppBar(title: const Text('Jyotara')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const UiText('Welcome, tester', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const UiText('This build is available to invited testers. Enter the access code shared with you.'),
          const SizedBox(height: 24),
          TextField(controller: _code, enabled: !widget.access.busy, obscureText: true,
            autocorrect: false, enableSuggestions: false,
            decoration: InputDecoration(labelText: uiText(context, 'Tester access code'))),
          const SizedBox(height: 16),
          if (widget.access.error != null) Padding(padding: const EdgeInsets.only(bottom: 16),
            child: UiText(widget.access.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          FilledButton(onPressed: widget.access.busy ? null : () => widget.access.verify(_code.text),
            child: UiText(widget.access.busy ? 'Checking access…' : 'Continue')),
        ]),
      );
    },
  );
}
