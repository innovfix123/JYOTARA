import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/coin_wallet.dart';
import 'package:jyotara/payment_support.dart';
import 'package:jyotara/services/jyotara_api.dart';

class _QuotedWallet extends AccountService {
  _QuotedWallet()
    : super(
        token: () => 'fixture',
        tester: () => null,
        account: () => 'fixture-account',
      );
  final quote = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      quote.future;
}

void main() {
  for (final outcome in ['accepted', 'failed', 'cancelled']) {
    testWidgets('guidance sent receipt waits until coin quote is $outcome', (
      tester,
    ) async {
      final wallet = _QuotedWallet();
      coinAccount = wallet;
      await tester.pumpWidget(
        MaterialApp(navigatorKey: coinNavigator, home: const Scaffold()),
      );
      final states = <String>[];
      var guidancePosts = 0;
      List<String>? statesAtHttp;
      final response = Completer<http.Response>();
      final api = JyotaraApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/status')) {
            final body = jsonDecode(request.body);
            return http.Response(
              jsonEncode({
                'requestId': body['requestId'],
                'profileId': 'fixture-profile',
                'state': 'absent',
              }),
              200,
            );
          }
          statesAtHttp = List<String>.of(states);
          guidancePosts++;
          return response.future;
        }),
      );
      final pending = withCoinChatConsent(
        const CoinChatConsent('fixture-account', 'standard', 15),
        () => api.askGuidance(
          category: 'Career',
          question: 'A fixture question.',
          responseStyle: 'english',
          birthTimeKnown: true,
          chart: const {},
          chartTicket: 'fixture-ticket',
          profileId: 'fixture-profile',
          requestId: 'a' * 32,
          depth: 'standard',
          onDeliveryState: states.add,
        ),
      );
      final checked = outcome == 'accepted'
          ? pending
          : expectLater(pending, throwsA(isA<JyotaraApiException>()));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(
        states,
        isEmpty,
        reason: 'A pending quote is not a sent question or server receipt',
      );
      expect(guidancePosts, 0);
      if (outcome == 'failed') {
        wallet.quote.completeError(
          const AccountServiceError('Fixture quote unavailable'),
        );
      } else {
        wallet.quote.complete({
          'quote': 'fixture',
          'category': 'Career',
          'depth': 'standard',
          'cost': outcome == 'cancelled' ? 50 : 10,
          'balance': 100,
          'canProceed': true,
        });
        await tester.pump();
        await tester.pump();
        if (outcome == 'cancelled') {
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
          await tester.pumpAndSettle();
        } else {
          expect(guidancePosts, 1);
          expect(statesAtHttp, ['sent']);
          response.complete(
            http.Response(
              jsonEncode({
                'profileId': 'fixture-profile',
                'answer': 'Fixture response.',
                'evidence': [],
              }),
              200,
            ),
          );
        }
      }
      await checked;
      if (outcome != 'accepted') {
        expect(states, isEmpty);
        expect(guidancePosts, 0);
      }
      await tester.pumpWidget(const SizedBox());
      coinAccount = null;
      api.close();
    }, skip: !coinWalletEnabled);
  }
}
