import 'package:flutter/material.dart';

import 'ask_theme.dart';

class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    key: const Key('softBronzeConversation'),
    color: AskPalette.conversation,
    child: child,
  );
}
