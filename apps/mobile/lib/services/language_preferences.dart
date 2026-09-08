import 'package:shared_preferences/shared_preferences.dart';

/// Device-local, non-sensitive preference only. Never stores charts, tokens,
/// consent, payments or conversations in this key-value store.
class LanguagePreferences {
  LanguagePreferences({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
  }) : _read = read ?? (() => SharedPreferencesAsync().getString(_key)),
       _write =
           write ??
           ((value) => SharedPreferencesAsync().setString(_key, value));
  static const _key = 'nirayana.chat_language.v1';
  static const allowed = {'auto', 'english', 'tamil', 'tanglish'};
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  String value = 'auto';
  Future<void> _writes = Future.value();

  Future<void> load() async {
    final stored = await _read();
    value = allowed.contains(stored) ? stored! : 'auto';
  }

  Future<void> set(String language) {
    if (!allowed.contains(language)) {
      return Future.error(ArgumentError('Invalid chat language'));
    }
    final operation = _writes.then((_) async {
      await _write(language);
      value = language;
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }
}
