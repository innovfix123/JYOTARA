import 'bronze_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/jyotara_api.dart';
import 'services/ui_language.dart';

class PrivacyLinks extends StatelessWidget {
  const PrivacyLinks({super.key});
  static Future<void> open(BuildContext context, String path) async {
    final url = Uri.parse(defaultApiBaseUrl).resolve(path);
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      /* Show a copyable address if no browser is available. */
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const UiText('Open in your browser'),
        content: SelectableText(url.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const UiText('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 4,
    children: [
      TextButton(
        onPressed: () => open(context, '/privacy'),
        child: const UiText('Privacy policy'),
      ),
      TextButton(
        onPressed: () => open(context, '/delete-account'),
        child: const UiText('Account deletion help'),
      ),
    ],
  );
}

/// Login consent follows the wording requested in JYOT-6.
class LoginConsent extends StatefulWidget {
  const LoginConsent({
    super.key,
    required this.value,
    required this.onChanged,
    this.openPage,
    this.compact = false,
  });
  final bool compact;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final void Function(String)? openPage;
  @override
  State<LoginConsent> createState() => _LoginConsentState();
}

class _LoginConsentState extends State<LoginConsent> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => _open('/terms');
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => _open('/privacy');
  void _open(String path) {
    if (widget.openPage != null) {
      widget.openPage!(path);
    } else {
      PrivacyLinks.open(context, path);
    }
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: widget.compact ? 8 : 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Checkbox(
            value: widget.value,
            onChanged: widget.onChanged == null
                ? null
                : (value) => widget.onChanged!(value ?? false),
            semanticLabel: 'Agree to Terms & Conditions and Privacy Policy',
            activeColor: BronzePalette.gold,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: widget.compact ? 'I agree to the ' : "By continuing, I confirm that I have read and agree to Jyotara's ",
                  ),
                  TextSpan(
                    text: 'Terms & Conditions',
                    recognizer: _terms,
                    style: const TextStyle(
                      color: BronzePalette.gold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    recognizer: _privacy,
                    style: const TextStyle(
                      color: BronzePalette.gold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
              style: TextStyle(
                fontFamily: widget.compact ? 'JyotaraSans' : null,
                fontSize: widget.compact ? 10 : 13,
                height: 1.5,
                color: BronzePalette.muted,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
