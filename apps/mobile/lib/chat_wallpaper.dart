import 'package:flutter/material.dart';

import 'bronze_theme.dart';

class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: BronzePalette.background,
    child: BronzeBackground(child: child),
  );
}
