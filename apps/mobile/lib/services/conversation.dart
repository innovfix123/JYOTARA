import 'package:flutter/foundation.dart';

/// In-memory conversation scoped to a single profile revision and guide.
/// Not durable storage and never used as calculation evidence.
class GuideConversation extends ChangeNotifier {
  final messages = <ChatMessage>[];
  String language = 'auto';
  bool pending = false;
  bool ended = false;
  int? rating;
  void changed() => notifyListeners();
}

class ChatMessage {
  const ChatMessage({required this.fromUser, required this.text, this.label});
  final bool fromUser;
  final String text;
  final String? label;
}
