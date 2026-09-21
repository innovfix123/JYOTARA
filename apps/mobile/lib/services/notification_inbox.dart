import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppNotice {
  const AppNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
  });
  final String id, title, body;
  final DateTime time;
  final bool read;
  AppNotice seen() =>
      AppNotice(id: id, title: title, body: body, time: time, read: true);
  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'time': time.toIso8601String(),
    'read': read,
  };
}

final notificationInbox = NotificationInbox();

/// Device-wide product announcements, encrypted at rest; never chart/chat data.
class NotificationInbox extends ChangeNotifier {
  NotificationInbox({
    Future<String?> Function()? load,
    Future<void> Function(String)? save,
  }) : _load =
           load ??
           (() => const FlutterSecureStorage().read(
             key: 'jyotara.notificationInbox',
           )),
       _save =
           save ??
           ((v) => const FlutterSecureStorage().write(
             key: 'jyotara.notificationInbox',
             value: v,
           ));
  final Future<String?> Function() _load;
  final Future<void> Function(String) _save;
  final List<AppNotice> _items = [];
  Future<void>? _restoring;
  Future<void> _writes = Future.value();
  List<AppNotice> get items => List.unmodifiable(_items);
  int get unread => _items.where((n) => !n.read).length;
  Future<void> restore() => _restoring ??= _restore();
  Future<void> _restore() async {
    try {
      final raw = await _load();
      if (raw == null) return;
      for (final row in (jsonDecode(raw) as List).take(30)) {
        _items.add(
          AppNotice(
            id: row['id'] as String,
            title: row['title'] as String,
            body: row['body'] as String,
            time: DateTime.parse(row['time'] as String),
            read: row['read'] == true,
          ),
        );
      }
    } catch (_) {
      _items.clear();
    }
    notifyListeners();
  }

  Future<void> add(AppNotice notice) async {
    await restore();
    if (_items.any((n) => n.id == notice.id)) return;
    _items.insert(0, notice);
    if (_items.length > 30) _items.removeRange(30, _items.length);
    await _persist();
  }

  Future<void> markRead() async {
    await restore();
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].seen();
    }
    await _persist();
  }

  Future<void> clear() async {
    await restore();
    _items.clear();
    await _persist();
  }

  Future<void> _persist() {
    final value = jsonEncode(_items.map((n) => n.toJson()).toList());
    notifyListeners();
    _writes = _writes.then((_) => _save(value)).catchError((Object _) {});
    return _writes;
  }
}
