import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'account_storage.dart';

enum ProfileAvatar { zodiac, star, orbit, constellation }

/// Cosmetic choice belongs to this signed-in account and is erased with it.
class ProfileAvatarPreference extends ChangeNotifier {
  ProfileAvatarPreference({
    required this.storage,
    Future<String?> Function(String)? read,
  }) : _read = read ?? ((key) => const FlutterSecureStorage().read(key: key));
  final AccountStorage storage;
  final Future<String?> Function(String) _read;
  String? _owner;
  int _revision = 0;
  ProfileAvatar _value = ProfileAvatar.zodiac;
  ProfileAvatar get value =>
      _owner == storage.account ? _value : ProfileAvatar.zodiac;

  Future<void> load() async {
    final owner = storage.account;
    final revision = ++_revision;
    _owner = owner;
    _value = ProfileAvatar.zodiac;
    notifyListeners();
    try {
      final saved = await _read(storage.key('jyotara.avatar.v1'));
      if (revision != _revision || owner != storage.account) return;
      _value =
          ProfileAvatar.values.where((v) => v.name == saved).firstOrNull ??
          ProfileAvatar.zodiac;
      notifyListeners();
    } catch (_) {
      // An optional image preference must not interrupt sign-in.
    }
  }

  Future<void> select(ProfileAvatar avatar) async {
    final owner = storage.account;
    final revision = ++_revision;
    await storage.writeKey(storage.key('jyotara.avatar.v1'), avatar.name);
    if (revision != _revision || owner != storage.account) return;
    _owner = owner;
    _value = avatar;
    notifyListeners();
  }
}
