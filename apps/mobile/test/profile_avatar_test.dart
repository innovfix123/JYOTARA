import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/account_storage.dart';
import 'package:jyotara/services/profile_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'avatar persists per account without sharing another account choice',
    () async {
      final records = <String, String>{};
      final storage = AccountStorage(
        read: (k) async => records[k],
        write: (k, v) async => records[k] = v,
      );
      storage.account = 'a';
      final pref = ProfileAvatarPreference(
        storage: storage,
        read: (k) async => records[k],
      );
      await pref.load();
      await pref.select(ProfileAvatar.orbit);
      final restored = ProfileAvatarPreference(
        storage: storage,
        read: (k) async => records[k],
      );
      await restored.load();
      expect(restored.value, ProfileAvatar.orbit);
      storage.account = 'b';
      expect(restored.value, ProfileAvatar.zodiac);
      await restored.load();
      await restored.select(ProfileAvatar.star);
      storage.account = 'a';
      await restored.load();
      expect(restored.value, ProfileAvatar.orbit);
    },
  );
  test(
    'late avatar read from a previous account cannot replace current choice',
    () async {
      final old = Completer<String?>();
      final storage = AccountStorage()..account = 'a';
      final pref = ProfileAvatarPreference(
        storage: storage,
        read: (k) => k.contains('.a.') ? old.future : Future.value('star'),
      );
      final first = pref.load();
      storage.account = 'b';
      await pref.load();
      old.complete('orbit');
      await first;
      expect(pref.value, ProfileAvatar.star);
    },
  );
  test(
    'failed write preserves the selected avatar and reports the failure',
    () async {
      final storage = AccountStorage(
        write: (k, v) async => throw StateError('storage failed'),
      )..account = 'a';
      final pref = ProfileAvatarPreference(
        storage: storage,
        read: (k) async => 'constellation',
      );
      await pref.load();
      await expectLater(pref.select(ProfileAvatar.star), throwsStateError);
      expect(pref.value, ProfileAvatar.constellation);
    },
  );
}
