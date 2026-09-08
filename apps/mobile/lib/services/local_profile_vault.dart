import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-local encrypted storage, not a cloud account or research database.
/// A single record keeps profile, bearer session and history in one generation.
class LocalProfileVault {
  LocalProfileVault({
    Future<String?> Function()? read,
    Future<void> Function(String?)? write,
  }) : _read = read ?? (() => const FlutterSecureStorage().read(key: _key)),
       _write =
           write ??
           ((value) => value == null
               ? const FlutterSecureStorage().delete(key: _key)
               : const FlutterSecureStorage().write(key: _key, value: value));
  static const _key = 'nirayana.private-profile.v1';
  final Future<String?> Function() _read;
  final Future<void> Function(String?) _write;
  Future<void> _tail = Future.value();

  Future<Map<String, dynamic>?> load() async {
    await _tail;
    final text = await _read();
    if (text == null) return null;
    if (text.length > 1000000) {
      throw const FormatException('Saved profile is too large');
    }
    final value = jsonDecode(text);
    if (value is! Map<String, dynamic> || value['version'] != 1) {
      throw const FormatException('Saved profile version is unsupported');
    }
    return value;
  }

  Future<void> _enqueue(String? text) {
    final next = _tail.then((_) => _write(text));
    _tail = next.catchError((Object _) {});
    return next;
  }

  Future<void> save(Map<String, dynamic> value) => Future<void>.sync(() {
    // Serialize before enqueue: later in-memory edits cannot change this write.
    final text = jsonEncode(value);
    if (text.length > 1000000) {
      throw const FormatException('Saved profile is too large');
    }
    return _enqueue(text);
  });

  Future<void> delete() => _enqueue(null);
}
