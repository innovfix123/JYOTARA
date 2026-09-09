import 'package:flutter/material.dart';

import 'services/profile_session.dart';

class ResearchConsentDialog extends StatefulWidget {
  const ResearchConsentDialog({super.key, required this.session});
  final ProfileSession session;
  @override
  State<ResearchConsentDialog> createState() => _ResearchConsentDialogState();
}

class _ResearchConsentDialogState extends State<ResearchConsentDialog> {
  bool tamil = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tamil ? 'விருப்ப ஆய்வு அனுமதி' : 'Optional research questions'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('English'),
                selected: !tamil,
                onSelected: (_) => setState(() => tamil = false),
              ),
              ChoiceChip(
                label: const Text('தமிழ்'),
                selected: tamil,
                onSelected: (_) => setState(() => tamil = true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            tamil
                ? 'அனுமதி அளிக்காமலும் கேள்வி கேட்கலாம். அனுமதித்தால், இனி நீங்கள் கேட்கும் கேள்விகளின் உரை, அமர்வு மற்றும் வகை விவரங்களுடன் செயலியை மேம்படுத்தும் ஆய்விற்காகச் சேமிக்கப்படலாம். வெளிப்படையான தொலைபேசி எண்களும் மின்னஞ்சல் முகவரிகளும் நீக்கப்படும்; மற்ற தனிப்பட்ட விவரங்கள் இருக்கலாம். முக்கியமான தனிப்பட்ட தகவல்களைச் சேர்க்க வேண்டாம். சேமிப்புக் கால இலக்கு 90 நாட்கள். சேவைக்கு கோரிக்கைகள் வரும்போதுதான் பழைய உரை நீக்கப்படுகிறது; தினசரி நீக்கம் உறுதி செய்யப்படவில்லை.'
                : 'Chat works with this turned off. If enabled, future question text may be stored for product research with session and category information. Obvious phone numbers and email addresses are removed, but other personal details may remain. Do not include sensitive details. The retention target is 90 days; deletion runs when the service handles requests, not on a guaranteed daily schedule.',
          ),
          const SizedBox(height: 12),
          Text(
            tamil
                ? 'ஆய்வுக்கு அனுமதிக்காவிட்டாலும், மீண்டும் முயற்சிக்கும்போது அதே பதிலைப் பெற சேவையகம் மறையாக்கப்பட்ட பதிலை இந்த ஜாதக அமர்வு முடியும் வரை (அதிகபட்சம் 24 மணி நேரம்) வைத்திருக்கும். காலாவதியான பிரதிகள் அடுத்த கோரிக்கைகள் வரும்போது நீக்கப்படும்; குறிப்பிட்ட நேரத்தில் நீக்கம் உறுதி செய்யப்படவில்லை. இரட்டைப் பயன்பாட்டைத் தடுக்க கோரிக்கைப் பதிவுகள் வைக்கப்படும்.'
                : 'Retry recovery is separate from research. An encrypted answer is retained until the chart session expires (up to 24 hours), even with research off. Expired copies are cleared when requests arrive, not on a guaranteed schedule. Request receipts remain to prevent duplicate usage.',
          ),
          const SizedBox(height: 12),
          Text(
            tamil
                ? 'அதே நாளில் மீண்டும் முயற்சிக்கும்போது ஜாதகத்தை மீட்க, அதன் பதில் சேவையகத்தில் அதிகபட்சம் 23 மணி நேரம் மறையாக்கம் செய்து வைக்கப்படும். இது ஆய்வுச் சம்மதத்திலிருந்து தனியானது. காலாவதியான பிரதிகள் அடுத்த ஜாதகக் கோரிக்கைகள் வரும்போது நீக்கப்படும்; குறிப்பிட்ட நேரத்தில் தானாக நீக்கும் வசதி இன்னும் இல்லை.'
                : 'For same-day retry recovery, the server also keeps an encrypted chart response for up to 23 hours, separately from research consent. Expired copies are removed when chart requests arrive; scheduled deletion is not yet available.',
          ),
          SwitchListTile(
            // Operational recovery storage is independent of this consent.
            contentPadding: EdgeInsets.zero,
            title: Text(
              tamil
                  ? 'இனி கேட்கும் கேள்விகளை ஆய்விற்குப் பகிர்கிறேன்'
                  : 'Share future questions for research',
            ),
            value: widget.session.researchConsent,
            onChanged: (value) =>
                setState(() => widget.session.setResearchConsent(value)),
          ),
          Text(
            tamil
                ? 'இது உங்கள் விருப்பம். இந்தச் சோதனைப் பதிப்பை மீண்டும் தொடங்கும்போதோ பிறப்பு விவரத்தை மாற்றும்போதோ அனுமதி அணைக்கப்படும். அணைத்தால் இனிவரும் கேள்விகள் பகிரப்படாது; ஏற்கெனவே பகிர்ந்தவை நீக்கப்படாது. சேவையகத் தரவை நீக்கும் வசதி இன்னும் இல்லை. அனுமதி அணைந்திருந்தாலும் ஜாதகக் கணக்கீடும் பதில் தயாரிப்பும் எங்கள் சேவை வழங்குநர்கள் மூலம் நடைபெறும்.'
                : 'Optional. This test-build choice resets when you restart or change your profile. Turning it off stops sharing future questions; it does not delete previously shared questions. Server deletion controls are not yet available. Chart calculation and answer processing still use our service providers when this is off.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tamil ? 'மூடு' : 'Close'),
      ),
    ],
  );
}
