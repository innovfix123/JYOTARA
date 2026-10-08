import 'bronze_theme.dart';
import 'package:flutter/material.dart';

import 'launch_intro.dart';

class AstrologyLesson {
  const AstrologyLesson(
    this.title,
    this.subtitle,
    this.category,
    this.art,
    this.sections,
  );
  final String title, subtitle, category;
  final int art;
  final List<(String, String)> sections;
}

const astrologyLessons = [
  AstrologyLesson(
    'Understanding the 12 Rasis',
    'Traits, strengths and more',
    'Rasis',
    0,
    [
      (
        'What is a Rasi?',
        'A Rasi is a zodiac sign. In a birth chart, different planets occupy different signs. Your Moon sign is only one part of the whole chart.',
      ),
      (
        'Mesha · Aries',
        'Fire · Mars. Traditionally associated with initiative, directness and courage.',
      ),
      (
        'Vrishabha · Taurus',
        'Earth · Venus. Associated with steadiness, comfort and persistence.',
      ),
      (
        'Mithuna · Gemini',
        'Air · Mercury. Associated with curiosity, communication and adaptability.',
      ),
      (
        'Karkata · Cancer',
        'Water · Moon. Associated with care, belonging and emotional sensitivity.',
      ),
      (
        'Simha · Leo',
        'Fire · Sun. Associated with expression, confidence and leadership.',
      ),
      (
        'Kanya · Virgo',
        'Earth · Mercury. Associated with detail, practical service and discernment.',
      ),
      (
        'Tula · Libra',
        'Air · Venus. Associated with balance, relationships and cooperation.',
      ),
      (
        'Vrischika · Scorpio',
        'Water · Mars. Associated with depth, determination and transformation.',
      ),
      (
        'Dhanu · Sagittarius',
        'Fire · Jupiter. Associated with learning, exploration and meaning.',
      ),
      (
        'Makara · Capricorn',
        'Earth · Saturn. Associated with responsibility, structure and patient effort.',
      ),
      (
        'Kumbha · Aquarius',
        'Air · Saturn. Associated with communities, ideas and wider perspectives.',
      ),
      (
        'Meena · Pisces',
        'Water · Jupiter. Associated with imagination, compassion and reflection.',
      ),
      (
        'Read the whole chart',
        'These are traditional themes, not a fixed personality test. The Ascendant, planets, houses and periods add context.',
      ),
    ],
  ),
  AstrologyLesson(
    'The Nine Planets',
    'Their meanings in your chart',
    'Planets',
    1,
    [
      (
        'The Navagraha',
        'Vedic astrology uses nine grahas. Rahu and Ketu are lunar nodes, not physical planets. Each symbol carries a traditional interpretive meaning.',
      ),
      ('Sun · Surya', 'Identity, vitality, purpose and authority.'),
      ('Moon · Chandra', 'Mind, feelings, habits and a sense of belonging.'),
      (
        'Mars · Mangala',
        'Energy, initiative, courage and how effort is directed.',
      ),
      ('Mercury · Budha', 'Communication, learning, reasoning and exchange.'),
      ('Jupiter · Guru', 'Learning, wisdom, growth and guiding principles.'),
      ('Venus · Shukra', 'Affection, beauty, enjoyment and relationships.'),
      ('Saturn · Shani', 'Discipline, responsibility, time and perseverance.'),
      ('Rahu', 'Desire, unfamiliar experiences and unconventional pursuits.'),
      ('Ketu', 'Detachment, introspection and the search for meaning.'),
      (
        'Position matters',
        'Interpretations depend on sign, house and other chart factors. A planet alone does not determine an outcome.',
      ),
    ],
  ),
  AstrologyLesson(
    'Houses in Astrology',
    'Areas of life and what they reveal',
    'Houses',
    2,
    [
      (
        'A map of life topics',
        'The twelve houses organise a chart into life areas. An accurate birth time is important when interpreting the Ascendant and houses.',
      ),
      ('1 · Self', 'Identity, appearance and your approach to life.'),
      ('2 · Resources', 'Family, speech, values and accumulated resources.'),
      ('3 · Effort', 'Communication, skills, siblings and initiative.'),
      ('4 · Home', 'Home, roots, care and inner comfort.'),
      ('5 · Creativity', 'Creative expression, learning and children.'),
      (
        '6 · Daily responsibilities',
        'Service, routines, challenges and obligations.',
      ),
      (
        '7 · Partnership',
        'Marriage, partnerships and one-to-one relationships.',
      ),
      ('8 · Change', 'Shared resources, uncertainty and transformation.'),
      (
        '9 · Meaning',
        'Higher learning, teachers, beliefs and longer journeys.',
      ),
      ('10 · Work', 'Career, public responsibilities and contribution.'),
      ('11 · Networks', 'Friends, communities, aspirations and gains.'),
      ('12 · Reflection', 'Retreat, rest, expenses and letting go.'),
    ],
  ),
  AstrologyLesson(
    'Dasha Periods Explained',
    'Cycles that shape your journey',
    'Life',
    3,
    [
      (
        'What is a Dasha?',
        'A Dasha is a planetary period in a traditional timing system. Vimshottari is one commonly used system.',
      ),
      (
        'Dasha and Bhukti',
        'The main period is divided into smaller subperiods, often called Bhukti or Antardasha. These describe time periods; they do not mean the two planets sit together in a chart.',
      ),
      (
        'Your timeline',
        'Open My Current Dasha in Explore to view the periods calculated for your saved birth details. Check those details before relying on the dates.',
      ),
      (
        'What a period means',
        'Read a period together with the whole chart and real-life circumstances. It is not a promise that a particular event must happen.',
      ),
    ],
  ),
  AstrologyLesson(
    'Remedies and Simple Practices',
    'Small steps, meaningful change',
    'Life',
    4,
    [
      (
        'A moment of quiet',
        'Choose a few minutes for calm breathing, prayer or reflection, according to your own preferences.',
      ),
      (
        'A small act of kindness',
        'Offer time or practical help when you can. Keep giving voluntary and within your means.',
      ),
      (
        'A steady daily habit',
        'Use a reading as a prompt to reflect, then choose one practical step: finish a task, reconnect kindly or make time to rest.',
      ),
      (
        'Keep it personal',
        'These optional practices are for reflection and wellbeing. No purchases, costly rituals or gemstones are required, and outcomes are not guaranteed.',
      ),
    ],
  ),
  AstrologyLesson(
    'Understanding Nakshatras',
    'Discover the meaning of birth stars',
    'Rasis',
    0,
    [
      (
        'Your birth star',
        'A Nakshatra is one of 27 divisions used along the Moon’s path in Vedic astrology. Your birth star refers to the division occupied by the Moon at birth.',
      ),
      (
        'Rasi and Nakshatra',
        'Rasi divides the zodiac into twelve signs. Nakshatra uses a different, finer division; the two describe different layers of a chart.',
      ),
      (
        'Find your own',
        'Open My Astrology · Birth chart to see the star calculated from your saved birth details. A reading combines it with the rest of your chart.',
      ),
    ],
  ),
];

class ExploreArtwork extends StatelessWidget {
  const ExploreArtwork({super.key, required this.index, this.size = 64});
  final int index;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(9),
    child: SizedBox.square(
      dimension: size,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxWidth: size * 5,
        maxHeight: size * 2,
        child: Transform.translate(
          offset: Offset(-size * index, -size * .465),
          child: Image.asset(
            'assets/images/explore_library_hd.png',
            width: size * 5,
            height: size * 2,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    ),
  );
}

class AstrologyLessonPage extends StatelessWidget {
  const AstrologyLessonPage({super.key, required this.lesson});
  final AstrologyLesson lesson;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      centerTitle: true,
      title: const Text('Jyotara', style: TextStyle(fontFamily: 'JyotaraEditorial')),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Hero(
            tag: 'lesson-${lesson.title}',
            child: ExploreArtwork(index: lesson.art, size: 148),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          lesson.title,
          style: const TextStyle(fontFamily: 'JyotaraEditorial', fontSize: 29),
        ),
        const SizedBox(height: 6),
        Text(lesson.subtitle, style: const TextStyle(color: BronzePalette.muted)),
        const SizedBox(height: 20),
        for (final section in lesson.sections)
          EntranceReveal(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.$1,
                      style: const TextStyle(
                        color: BronzePalette.gold,
                        fontSize: 18,
                        fontFamily: 'JyotaraEditorial',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(section.$2, style: const TextStyle(height: 1.5)),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
