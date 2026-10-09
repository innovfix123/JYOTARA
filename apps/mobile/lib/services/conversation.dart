import 'package:flutter/foundation.dart';

/// Submitted messages belonging to one priced answer. IDs survive a restart;
/// uncertain transport is retried only when the user explicitly chooses Retry.
class ChatTurn {
  ChatTurn({
    required this.id,
    required this.language,
    this.state = 'collecting',
    this.ack = 'queued',
    this.legacy = false,
  });
  final String id;
  final String language;
  String state, ack;
  final bool legacy;
  final messageIds = <String>[];
  final userMessages = <String>[];
  String get question => userMessages.join('\n');
  bool get waiting => state == 'collecting' || state == 'queued';
  Map<String, dynamic> toJson() => {
    'id': id,
    'language': language,
    'state': state,
    'ack': ack,
    'messageIds': messageIds,
    'userMessages': userMessages,
    if (legacy) 'legacy': true,
  };
  static ChatTurn fromJson(dynamic value) {
    if (value is! Map ||
        value['id'] is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(value['id']) ||
        !['english', 'tamil', 'tanglish'].contains(value['language']) ||
        ![
          'collecting',
          'queued',
          'sending',
          'uncertain',
          'complete',
          'failed',
          'cancelled',
        ].contains(value['state']) ||
        ![
          'queued',
          'sent',
          'received',
          'processing',
          'complete',
        ].contains(value['ack']) ||
        value['messageIds'] is! List ||
        value['userMessages'] is! List ||
        (value['messageIds'] as List).length !=
            (value['userMessages'] as List).length ||
        (value['userMessages'] as List).isEmpty ||
        (value['userMessages'] as List).length > 4 ||
        (value['messageIds'] as List).any(
          (id) => id is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(id),
        ) ||
        (value['userMessages'] as List).any(
          (text) =>
              text is! String || text.trim().isEmpty || text.runes.length > 240,
        )) {
      throw const FormatException('Invalid saved chat turn');
    }
    return ChatTurn(
        id: value['id'],
        language: value['language'],
        state: value['state'] == 'sending' ? 'uncertain' : value['state'],
        ack: value['ack'],
        legacy: value['legacy'] == true,
      )
      ..messageIds.addAll(List<String>.from(value['messageIds']))
      ..userMessages.addAll(List<String>.from(value['userMessages']));
  }
}

/// In-memory conversation scoped to a single profile revision and guide.
/// Not durable storage and never used as calculation evidence.
class GuideConversation extends ChangeNotifier {
  final messages = <ChatMessage>[];
  final turns = <ChatTurn>[];
  String language = 'auto';
  bool pending = false;
  bool ended = false;
  int? rating;
  String? depth;
  bool billingAcknowledged = false;
  int? acceptedGeneralCoins;
  int? acceptedRelationshipCoins;
  DateTime? updatedAt;
  final history = <List<ChatMessage>>[];
  void changed() => notifyListeners();
}

class ChatMessage {
  const ChatMessage({
    required this.fromUser,
    required this.text,
    this.label,
    this.wallet,
    this.clientId,
  });
  final bool fromUser;
  final String text;
  final String? label;
  final Map<String, dynamic>? wallet;
  final String? clientId;
}
