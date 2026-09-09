import 'conversation.dart';
import 'jyotara_api.dart';

/// Formats the returned content without adding an interpretation or claiming
/// that every supplied calculation proves the answer. Use the language captured
/// when the request was sent, not a selector changed while it was in flight.
ChatMessage guidanceMessage(GuidanceResponse result, String language) {
  String copy(String english, String tamil, String tanglish) =>
      language == 'tamil'
      ? tamil
      : language == 'tanglish'
      ? tanglish
      : english;
  final chartReading = result.answerMode == 'chart_guidance';
  final provider = result.answerMode == 'provider_reading';
  final traditional = result.answerMode == 'reviewed_traditional';
  final limited = result.answerMode != 'personalised' && !traditional;
  final indiaTime = result.answeredAt?.toUtc().add(
    const Duration(hours: 5, minutes: 30),
  );
  final timestamp = indiaTime
      ?.toIso8601String()
      .substring(0, 16)
      .replaceFirst('T', ' ');
  final heading = provider || chartReading
      ? copy('Reading source', 'பலனின் ஆதாரம்', 'Reading source')
      : limited
      ? copy(
          'Chart context — not a prediction',
          'ஜாதகப் பின்னணி — பலன் கணிப்பு அல்ல',
          'Jathaga context — prediction illai',
        )
      : copy(
          'Calculated chart facts',
          'கணக்கிடப்பட்ட ஜாதக விவரங்கள்',
          'Kanakkitta jathaga vivarangal',
        );
  return ChatMessage(
    fromUser: false,
    text: [
      if (result.replayed)
        copy(
          'Recovered earlier answer. No new reading was generated for this retry.',
          'முன்பு தயாரித்த பதில் மீட்கப்பட்டுள்ளது. இந்த மறுமுயற்சிக்காக புதிய பலன் தயாரிக்கப்படவில்லை.',
          'Munnaadi thayaaricha answer thirumba kidaichirukku. Indha retry-ku pudhu reading generate pannala.',
        ),
      if (timestamp != null)
        '${copy('Answer prepared', 'பதில் தயாரிக்கப்பட்ட நேரம்', 'Answer thayaaricha neram')}: $timestamp IST',
      result.answer,
      if (result.evidence.isNotEmpty) '$heading\n${result.evidence.join('\n')}',
      if (result.limitation?.trim().isNotEmpty == true)
        '${copy('Limitations', 'வரம்புகள்', 'Varambugal')}: ${result.limitation}',
    ].join('\n\n'),
    label: chartReading
        ? copy('CHART GUIDANCE', 'ஜாதக வழிகாட்டல்', 'JATHAGA GUIDANCE')
        : result.answerMode == 'model_guidance'
        ? copy('GUIDANCE', 'வழிகாட்டல்', 'GUIDANCE')
        : provider
        ? copy('CHART READING', 'ஜாதகப் பலன்', 'CHART READING')
        : result.answerMode == 'practical_guidance'
        ? copy(
            'PRACTICAL GUIDANCE',
            'நடைமுறை வழிகாட்டல்',
            'NADAIMURAI GUIDANCE',
          )
        : traditional
        ? copy(
            'TRADITIONAL GUIDANCE',
            'பாரம்பரிய வழிகாட்டல்',
            'PARAMBARIYA GUIDANCE',
          )
        : limited
        ? copy(
            'LIMITED GUIDANCE',
            'வரம்புகளுடன் வழிகாட்டல்',
            'VARAMBUGALUDAN GUIDANCE',
          )
        : copy(
            'PERSONALISED GUIDANCE',
            'தனிப்பட்ட வழிகாட்டல்',
            'THANIPPATTA GUIDANCE',
          ),
  );
}
