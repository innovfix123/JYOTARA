import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:jyotara/services/conversation.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/profile_session.dart';

import 'profile_replacement_test.dart' show chartReply;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'reply choice and archived chat survive restart without mixing guides',
    () async {
      String? disk;
      final vault = LocalProfileVault(
        read: () async => disk,
        write: (v) async => disk = v,
      );
      ProfileSession make() => ProfileSession(
        vault: vault,
        api: JyotaraApiClient(
          baseUrl: 'https://example.test',
          client: MockClient((_) async => chartReply('persist')),
        ),
      );
      final session = make();
      await session.calculate(
        dateTime: '1995-01-10T08:30:00+05:30',
        latitude: 11,
        longitude: 77,
        exactTime: true,
      );
      final chat = session.conversation('Meera');
      chat.depth = 'detailed';
      chat.language = 'tamil';
      chat.messages.add(
        const ChatMessage(fromUser: true, text: 'Previous private question'),
      );
      chat.ended = true;
      chat.changed();
      session.startNewConversation('Meera');
      expect(chat.ended, false);
      expect(chat.messages, isEmpty);
      expect(chat.history.single.single.text, 'Previous private question');
      expect(chat.depth, 'detailed');
      chat.messages.add(
        const ChatMessage(fromUser: true, text: 'New conversation'),
      );
      chat.changed();
      await session.flushStorage();
      final restored = make();
      await restored.restore();
      expect(restored.conversation('Meera').depth, 'detailed');
      expect(restored.conversation('Meera').language, 'tamil');
      expect(
        restored.conversation('Meera').messages.single.text,
        'New conversation',
      );
      expect(
        restored.conversation('Meera').history.single.single.text,
        'Previous private question',
      );
      expect(restored.conversation('Aravind').depth, isNull);
      expect(restored.conversation('Aravind').history, isEmpty);
    },
  );
}
