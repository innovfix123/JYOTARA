import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/phone_access_screen.dart';
import 'package:jyotara/services/phone_access.dart';

void main(){
 testWidgets('complete OTP verifies once and an invalid code never loops', (tester)async{
  final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(const MethodChannel('jyotara/otp-autofill'),(call)async=>call.method=='start'?1:null);
  addTearDown(()=>messenger.setMockMethodCallHandler(const MethodChannel('jyotara/otp-autofill'),null));
  var sends=0,verifies=0;
  final access=PhoneAccess(testerCode:()=>null,read:()async=>null,write:(_)async{},client:MockClient((r)async{
   if(r.url.path.endsWith('/send')){sends++;return http.Response(jsonEncode({'challengeId':'b'*48}),200);}
   verifies++;
   if(jsonDecode(r.body)['otp']=='123456')return http.Response('{"error":"Invalid code"}',400);
   return http.Response(jsonEncode({'token':'a'*64,'accountId':'account','expiresAt':DateTime.now().add(const Duration(days:1)).millisecondsSinceEpoch}),200);
  }));
  await tester.pumpWidget(MaterialApp(home:PhoneAccessScreen(access:access,child:const Text('Welcome back'))));
  await tester.pump();expect(tester.testTextInput.isVisible,true);
  await tester.enterText(find.byType(TextField).first,'9000000000');
  expect(sends,0);tester.testTextInput.hide();await tester.pump();
  await tester.ensureVisible(find.byType(Checkbox));await tester.tap(find.byType(Checkbox));
  await tester.pump(const Duration(milliseconds:100));await tester.pumpAndSettle();expect(sends,1);
  await tester.enterText(find.byType(TextField).last,'123456');await tester.pumpAndSettle();expect(verifies,1);
  await tester.pump(const Duration(seconds:3));expect(verifies,1);expect(sends,1);
  await tester.enterText(find.byType(TextField).last,'654321');await tester.pumpAndSettle();expect(verifies,2);expect(find.text('Welcome back'),findsOneWidget);
  await tester.pumpWidget(const SizedBox());access.dispose();
 });
}
