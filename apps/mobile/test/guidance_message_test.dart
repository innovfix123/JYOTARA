import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/guidance_message.dart';
import 'package:jyotara/services/jyotara_api.dart';

void main() {
  test('normal chat keeps the answer concise without report metadata', () {
    for (final mode in [
      'chart_guidance',
      'provider_reading',
      'reviewed_traditional',
      'model_guidance',
      'practical_guidance',
    ]) {
      final message = guidanceMessage(
        GuidanceResponse(
          answer: 'Short answer.',
          evidence: ['Long calculation details'],
          support: 'partially_supported',
          answerMode: mode,
          answeredAt: DateTime.utc(2026, 9, 13),
        ),
        'english',
      );
      expect(message.text, 'Short answer.');
    }
  });

  GuidanceResponse response(String mode) => GuidanceResponse(
    answer: 'Original answer',
    evidence: ['Moon: Meena'],
    support: 'partially_supported',
    answerMode: mode,
    limitation: 'Original limitation',
  );
  test('fallback context is never described as proof or facts used', () {
    for (final mode in ['grounded_fallback', 'unknown', '']) {
      final message = guidanceMessage(response(mode), 'english');
      expect(message.text, contains('Chart context — not a prediction'));
      expect(message.text, isNot(contains('Chart facts used')));
      expect(message.label, 'LIMITED GUIDANCE');
      expect(message.text, contains('Original answer'));
      expect(message.text, contains('Moon: Meena'));
    }
  });
  test('response labels follow the captured request language', () {
    final tamil = guidanceMessage(response('grounded_fallback'), 'tamil');
    expect(tamil.label, 'வரம்புகளுடன் வழிகாட்டல்');
    expect(tamil.text, contains('வரம்புகள்: Original limitation'));
    final tanglish = guidanceMessage(response('grounded_fallback'), 'tanglish');
    expect(tanglish.text, contains('Jathaga context'));
    expect(RegExp(r'[\u0B80-\u0BFF]').hasMatch(tanglish.text), false);
    expect(
      guidanceMessage(response('personalised'), 'english').text,
      contains('Calculated chart facts'),
    );
  });
  test('empty facts and limitations do not create empty sections', () {
    final message = guidanceMessage(
      const GuidanceResponse(
        answer: 'Answer',
        evidence: [],
        support: 'unsupported',
        answerMode: 'grounded_fallback',
        limitation: ' ',
      ),
      'english',
    );
    expect(message.text, 'Answer');
  });
  test(
    'recovered answers retain original server time and are not labelled fresh',
    () {
      final response = GuidanceResponse.fromJson({
        'answer': 'Saved answer',
        'evidence': [],
        'answerMode': 'grounded_fallback',
        'replayed': true,
        'answeredAt': '2026-09-07T18:45:00Z',
      });
      final message = guidanceMessage(response, 'english');
      expect(message.text, contains('Recovered earlier answer'));
      expect(message.text, contains('No new reading was generated'));
      expect(message.text, contains('2026-09-08 00:15 IST'));
      expect(
        guidanceMessage(response, 'tamil').text,
        contains('முன்பு தயாரித்த பதில்'),
      );
      expect(
        RegExp(r'[\u0B80-\u0BFF]')
            .hasMatch(guidanceMessage(response, 'tanglish').text),
        false,
      );
      final legacy = GuidanceResponse.fromJson({
        'answer': 'Legacy saved answer',
        'evidence': [],
        'replayed': true,
      });
      expect(
        guidanceMessage(legacy, 'english').text,
        isNot(contains('Answer prepared')),
      );
      for (final change in [
        {'replayed': 'true'},
        {'answeredAt': '2026-02-30T12:00:00Z'},
        {'answeredAt': '2026-09-07T10:00:00'},
        {'answeredAt': 123},
      ]) {
        expect(
          () => GuidanceResponse.fromJson({
            'answer': 'Answer',
            'evidence': [],
            ...change,
          }),
          throwsA(isA<JyotaraApiException>()),
        );
      }
    },
  );
  test('reviewed traditional mode retains the distinction from guaranteed predictions', () {
    for (final language in ['english', 'tamil', 'tanglish']) {
      final message = guidanceMessage(
        response('reviewed_traditional'),
        language,
      );
      expect(message.text, contains('Original answer'));
      expect(message.text, contains('Original limitation'));
      expect(message.label, isNot('PERSONALISED GUIDANCE'));
    }
    expect(
      guidanceMessage(response('reviewed_traditional'), 'english').label,
      'TRADITIONAL GUIDANCE',
    );
  });
}
