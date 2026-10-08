import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'jyotara_api.dart';

final remoteConfig = RemoteConfig();
class RemoteConfig extends ChangeNotifier with WidgetsBindingObserver {
  Map<String,dynamic> _data = {};
  bool _started=false, _loading=false;
  DateTime? _last;
  static const _store=FlutterSecureStorage();
  static const _key='jyotara.remote-config.v1';
  bool enabled(String key) => !(_data['maintenance']==true) &&
      ((_data['features'] as Map?)?[key] as bool? ?? key!='detailed');
  String get message => _data['message'] as String? ?? 'This feature is temporarily unavailable. Please try again later.';
  int cost(String key,int fallback)=>(_data['costs'] as Map?)?[key] as int? ?? fallback;
  String welcome(String language)=>(_data['welcome'] as Map?)?[language] as String? ?? '';
  String get announcement => _data['announcement'] as String? ?? '';
  String get supportEmail => _data['supportEmail'] as String? ?? 'jyotara29@gmail.com';
  List<String> list(String key) => ((_data[key] as List?) ?? []).cast<String>();
  bool guideEnabled(String name) => !list('disabledGuides').contains(name);
  bool languageEnabled(String language) => !_data.containsKey('languages') || list('languages').contains(language);
  String guideDescription(String name,String fallback) => (_data['guideDescriptions'] as Map?)?[name] as String? ?? fallback;
  List<Map<String,dynamic>> get cards => ((_data['exploreCards'] as List?) ?? []).map((e)=>Map<String,dynamic>.from(e)).toList();
  static Map<String,dynamic> parse(String raw) {
    if(raw.length>32000)throw const FormatException();
    final d=jsonDecode(raw);
    if(d is! Map<String,dynamic> || d['schema']!=1 || d['revision'] is! int || d['revision']<1)throw const FormatException();
    if(d['features'] is! Map || (d['features'] as Map).values.any((v)=>v is! bool))throw const FormatException();
    if(d['maintenance'] is! bool)throw const FormatException();
    for(final k in ['message','announcement','supportEmail']) {if(d[k] is! String || (d[k] as String).length>300)throw const FormatException();}
    for(final k in ['disabledGuides','disabledPacks','languages']) {if(d[k] is! List || (d[k] as List).length>30 || (d[k] as List).any((v)=>v is! String))throw const FormatException();}
    if((d['languages'] as List).isEmpty || (d['languages'] as List).any((v)=>!['english','tamil','tanglish'].contains(v)))throw const FormatException();
    if(d['guideDescriptions'] is! Map || (d['guideDescriptions'] as Map).values.any((v)=>v is! String || v.length>250))throw const FormatException();
    if(d['exploreCards'] is! List || (d['exploreCards'] as List).length>20 || (d['exploreCards'] as List).any((v)=>v is! Map || v['title'] is! String || v['body'] is! String || v['title'].length>80 || v['body'].length>2000))throw const FormatException();
    if(d['costs']!=null && (d['costs'] is! Map || (d['costs'] as Map).values.any((v)=>v is! int || v<1 || v>500)))throw const FormatException();
    if(d['welcome']!=null && (d['welcome'] is! Map || (d['welcome'] as Map).values.any((v)=>v is! String || v.length>300)))throw const FormatException();
    return d;
  }
  Future<void> start() async {
    if(_started)return;_started=true;WidgetsBinding.instance.addObserver(this);
    try{final raw=await _store.read(key:_key);if(raw!=null){_data=parse(raw);notifyListeners();}}catch(_){}
    await refresh();
  }
  Future<void> refresh() async {
    if(_loading || (_last!=null && DateTime.now().difference(_last!)<const Duration(seconds:30)))return;
    _loading=true;_last=DateTime.now();
    try {
      final uri=Uri.parse(defaultApiBaseUrl).resolve('/api/app-config');
      if(uri.scheme!='https')return;
      final r=await http.get(uri).timeout(const Duration(seconds:5));
      if(r.statusCode!=200)return;
      final data=parse(r.body);_data=data;notifyListeners();
      await _store.write(key:_key,value:jsonEncode(data));
    }catch(_){/* Keep last known valid configuration. */}finally{_loading=false;}
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed)unawaited(refresh());}
}
class RemoteConfigScope extends InheritedNotifier<RemoteConfig> {
  const RemoteConfigScope({super.key,required RemoteConfig config,required super.child}):super(notifier:config);
  static RemoteConfig watch(BuildContext context)=>context.dependOnInheritedWidgetOfExactType<RemoteConfigScope>()?.notifier??remoteConfig;
}
class FeatureGate extends StatelessWidget {
  const FeatureGate({super.key,required this.feature,required this.child});
  final String feature;final Widget child;
  @override Widget build(BuildContext context)=>ListenableBuilder(listenable:remoteConfig,builder:(context,_)=>remoteConfig.enabled(feature)?child:Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(remoteConfig.message,textAlign:TextAlign.center))));
}
