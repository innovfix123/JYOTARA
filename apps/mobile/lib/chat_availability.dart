import 'package:flutter/material.dart';

import 'services/ui_language.dart';

// Public releases remain closed until billing is implemented and approved.
const publicChatEnabled = bool.fromEnvironment('JYOTARA_PUBLIC_CHAT_ENABLED');

class ChatUnavailableScreen extends StatelessWidget {
  const ChatUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const UiText('AI chat')),
    body: Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 56,
                color: Color(0xFFE6B85C),
              ),
              const SizedBox(height: 24),
              const UiText(
                'Something thoughtful is on its way',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const UiText(
                'AI chat is temporarily unavailable while we prepare paid access. Your saved conversations remain on this device.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const UiText(
                'Daily horoscopes, Free Kundli and Kundli Matching are still available.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const UiText(
                'Support: jyotara29@gmail.com',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
