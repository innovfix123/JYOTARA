import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Account namespaces never fall back to another account's private records.
/// Legacy records are copied only for the account known before the upgrade.
class AccountStorage {
  AccountStorage({
    Future<String?> Function(String)? read,
    Future<void> Function(String, String)? write,
    Future<Map<String, String>> Function()? readAll,
    Future<void> Function(String)? delete,
  }) : _readAll = readAll ?? (() => const FlutterSecureStorage().readAll()),
       _delete =
           delete ?? ((key) => const FlutterSecureStorage().delete(key: key)),
       _read = read ?? ((key) => const FlutterSecureStorage().read(key: key)),
       _write =
           write ??
           ((key, value) =>
               const FlutterSecureStorage().write(key: key, value: value));
  final Future<String?> Function(String) _read;
  final Future<void> Function(String, String) _write;
  final Future<Map<String, String>> Function() _readAll;
  final Future<void> Function(String) _delete;
  String? account;

  /// Erase this account namespace and only its owned pre-migration copies.
  Future<void> erase(String owner) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(owner)) {
      throw const FormatException('Invalid account');
    }
    final records = await _readAll();
    final legacyOwned = records['jyotara.legacy-owner.v1'] == owner;
    for (final key in records.keys) {
      final namespaced = key.startsWith('jyotara.account.$owner.');
      final legacy =
          legacyOwned &&
          (key == 'nirayana.private-profile.v1' ||
              key == 'jyotara.kundli.index.v1' ||
              RegExp(r'^jyotara\.kundli\.[a-f0-9]{32}$').hasMatch(key));
      if (namespaced || legacy) await _delete(key);
    }
    // Preserve ownership marker to prevent legacy data being claimed elsewhere.
  }

  String key(String base) =>
      account == null ? base : 'jyotara.account.$account.$base';

  Future<void> migrateLegacy(String? owner) async {
    const ownerKey = 'jyotara.legacy-owner.v1';
    final existingOwner = await _read(ownerKey);
    if (existingOwner == null) await _write(ownerKey, owner ?? 'unassigned');
    if (owner == null || (existingOwner != null && existingOwner != owner)) {
      return;
    }
    final marker = 'jyotara.account.$owner.migrated.v1';
    if (await _read(marker) != null) return;
    const keys = ['nirayana.private-profile.v1', 'jyotara.kundli.index.v1'];
    for (final base in keys) {
      final target = 'jyotara.account.$owner.$base';
      if (await _read(target) == null) {
        final old = await _read(base);
        if (old != null) await _write(target, old);
      }
    }
    final index = await _read('jyotara.account.$owner.jyotara.kundli.index.v1');
    if (index != null) {
      for (final id in (jsonDecode(index) as List).cast<String>()) {
        if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
          throw const FormatException('Invalid Kundli index');
        }
        final target = 'jyotara.account.$owner.jyotara.kundli.$id';
        if (await _read(target) == null) {
          final old = await _read('jyotara.kundli.$id');
          if (old != null) await _write(target, old);
        }
      }
    }
    await _write(marker, '1');
  }
}
