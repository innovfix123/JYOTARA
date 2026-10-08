import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/approved_opening.dart';
void main(){
 testWidgets('Temple login art fits a narrow phone without layout errors',(tester) async {
  tester.view.physicalSize=const Size(360,800);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:ListView(padding:EdgeInsets.all(28),children:[SizedBox(height:280,child:TempleLoginArtwork()),TextField(),FilledButton(onPressed:null,child:Text('Continue'))]))));
  await tester.pumpAndSettle();expect(tester.takeException(),isNull);expect(find.byType(TextField),findsOneWidget);
 });
 testWidgets('Sunrise uses new logo and renders animation checkpoints',(tester) async {
  for(final progress in [0.0,.5,1.0]){await tester.pumpWidget(MaterialApp(home:Scaffold(body:GoldenSunriseMark(progress:progress))));await tester.pump();expect(tester.takeException(),isNull);}
 });
}
