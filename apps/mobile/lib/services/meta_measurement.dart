import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

final metaMeasurement = MetaMeasurement();

class MetaMeasurement extends ChangeNotifier {
  MetaMeasurement({bool? supported})
    : supported =
          supported ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
  static const channel = MethodChannel('jyotara/meta-measurement');
  final bool supported;
  bool configured = false;
  bool enabled = false;
  Future<void> _queue = Future.value();
  SharedPreferences? _prefs;

  Future<void> _serialize(Future<void> Function() action) {
    _queue = _queue.then((_) => action()).catchError((Object _) {
      enabled = false;
      notifyListeners();
    });
    return _queue;
  }

  Future<void> initialize() => _serialize(() async {
    if (!supported) return;
    configured = await channel.invokeMethod<bool>('configured') == true;
    if (!configured) return;
    _prefs ??= await SharedPreferences.getInstance();
    await _apply(_prefs!.getBool('meta.measurement') == true);
    if (enabled) {
      await channel.invokeMethod<void>('event', 'fb_mobile_activate_app');
    }
    notifyListeners();
  });

  Future<void> setConsent(bool value) => _serialize(() async {
    if (!configured) return;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('meta.measurement', value);
    final starting = value && !enabled;
    await _apply(value);
    if (starting && enabled) {
      await channel.invokeMethod<void>('event', 'fb_mobile_activate_app');
    }
    notifyListeners();
  });

  Future<void> _apply(bool value) async {
    enabled = await channel.invokeMethod<bool>('consent', value) == true;
  }

  Future<void> event(String name) => _serialize(() async {
    if (!configured ||
        !enabled ||
        !{'login_success', 'chat_completed'}.contains(name)) {
      return;
    }
    await channel.invokeMethod<void>('event', name);
  });
}
