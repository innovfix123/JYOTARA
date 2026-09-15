import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/jyotara_api.dart';
import 'services/ui_language.dart';

class PrivacyLinks extends StatelessWidget {
  const PrivacyLinks({super.key});
  Future<void> _open(BuildContext context, String path) async {
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
    children: [
      TextButton(
        onPressed: () => _open(context, '/privacy'),
        child: const UiText('Privacy policy'),
      ),
      TextButton(
        onPressed: () => _open(context, '/delete-account'),
        child: const UiText('Account deletion help'),
      ),
    ],
  );
}
