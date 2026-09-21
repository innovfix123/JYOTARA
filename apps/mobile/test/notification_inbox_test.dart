import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/notification_inbox.dart';

void main() {
  test(
    'deduplicates delivery, restores seen state and clears persisted updates',
    () async {
      String? saved;
      final inbox = NotificationInbox(
        load: () async => saved,
        save: (v) async {
          saved = v;
        },
      );
      final notice = AppNotice(
        id: 'one',
        title: 'Update',
        body: 'Free features remain available.',
        time: DateTime(2026, 9, 21),
      );
      await inbox.add(notice);
      await inbox.add(notice);
      expect(inbox.unread, 1);
      await inbox.markRead();
      final restored = NotificationInbox(
        load: () async => saved,
        save: (v) async {
          saved = v;
        },
      );
      await restored.restore();
      expect(restored.items.length, 1);
      expect(restored.unread, 0);
      await restored.clear();
      expect(jsonDecode(saved!), isEmpty);
    },
  );
  test(
    'retains only the latest thirty messages and tolerates malformed storage',
    () async {
      final inbox = NotificationInbox(
        load: () async => 'bad data',
        save: (_) async {},
      );
      for (var i = 0; i < 35; i++) {
        await inbox.add(
          AppNotice(
            id: '$i',
            title: 'Title',
            body: 'Body',
            time: DateTime(2026),
          ),
        );
      }
      expect(inbox.items.length, 30);
      expect(inbox.items.first.id, '34');
      expect(inbox.items.last.id, '5');
    },
  );
}
