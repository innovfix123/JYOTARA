import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/remote_config.dart';
void main(){
 final good={'schema':1,'revision':1,'features':{'detailed':false},'maintenance':false,'message':'Try later','announcement':'','supportEmail':'jyotara29@gmail.com','languages':['english','tamil','tanglish'],'disabledGuides':[],'disabledPacks':[],'guideDescriptions':{},'exploreCards':[]};
 test('valid data-only remote config parses; unsupported schema and malformed fields fail',(){
 expect(RemoteConfig.parse(jsonEncode(good))['features']['detailed'],false);
 for(final bad in [{...good,'schema':2},{...good,'features':{'detailed':'false'}},{...good,'languages':[]},{...good,'costs':{'matching':-1}},{...good,'exploreCards':[{'title':'x','body':4}]}]){
 expect(()=>RemoteConfig.parse(jsonEncode(bad)),throwsFormatException);
 }
 });
 test('offline defaults keep Standard and existing services available',(){final c=RemoteConfig();expect(c.enabled('detailed'),false);expect(c.enabled('chat'),true);expect(c.cost('matching',20),20);});
}
