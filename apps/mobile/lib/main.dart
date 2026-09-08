import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/profile_session.dart';
import 'services/jyotara_api.dart';
import 'services/conversation.dart';
import 'services/ui_language.dart';
import 'services/language_preferences.dart';
import 'services/reply_language.dart';
import 'services/chart_display.dart';
import 'services/local_profile_vault.dart';
import 'birth_form.dart';
import 'south_chart.dart';
import 'navamsa_section.dart';
import 'research_consent_dialog.dart';
import 'services/tester_access.dart';
import 'tester_access_screen.dart';

final languagePreferences = LanguagePreferences();
final uiLanguagePreferences = UiLanguagePreferences();
final testerAccess = TesterAccess();
final profileSession = ProfileSession(
  api: JyotaraApiClient(testerCode: () => testerAccess.code),
  preferences: languagePreferences,
  vault: LocalProfileVault(),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await languagePreferences.load();
  } catch (_) {
    /* Safe default if storage is unavailable. */
  }
  try {
    await uiLanguagePreferences.load();
  } catch (_) {
    /* UI preference failure must not erase the independent chat preference. */
  }
  if (const bool.fromEnvironment('JYOTARA_REQUIRE_TESTER_ACCESS')) await testerAccess.restore();
  await profileSession.restore();
  runApp(const JyotaraApp());
}

const ink = Color(0xFF090612);
const panel = Color(0xFF171022);
const line = Color(0xFF322643);
const violet = Color(0xFF9B79FF);
const lavender = Color(0xFFD8CBFF);
const muted = Color(0xFFA89FB8);
const gold = Color(0xFFF2C778);

class JyotaraApp extends StatelessWidget {
  const JyotaraApp({super.key, this.uiPreferences});
  final UiLanguagePreferences? uiPreferences;

  @override
  Widget build(BuildContext context) {
    final preferences = uiPreferences ?? uiLanguagePreferences;
    final scheme = ColorScheme.fromSeed(
      seedColor: violet,
      brightness: Brightness.dark,
      surface: panel,
    );
    return AnimatedBuilder(
      animation: preferences,
      builder: (context, _) => MaterialApp(
        locale: Locale(preferences.value),
        supportedLocales: const [Locale('en'), Locale('ta')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) =>
            UiLanguageScope(preferences: preferences, child: child!),
        debugShowCheckedModeBanner: false,
        title: 'Jyotara',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: scheme,
          scaffoldBackgroundColor: ink,
          fontFamily: 'sans-serif',
          textTheme: const TextTheme(
            displaySmall: TextStyle(
              fontSize: 40,
              height: 1.02,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.4,
            ),
            headlineMedium: TextStyle(
              fontSize: 28,
              height: 1.08,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
            headlineSmall: TextStyle(
              fontSize: 22,
              height: 1.12,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.35,
            ),
            titleLarge: TextStyle(fontWeight: FontWeight.w700),
            titleMedium: TextStyle(fontWeight: FontWeight.w700),
            bodyLarge: TextStyle(height: 1.48),
            bodyMedium: TextStyle(height: 1.42),
          ),
          cardTheme: CardThemeData(
            color: panel,
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: line),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF120D1D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: violet, width: 1.4),
            ),
          ),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: Color(0xFF100B19),
            indicatorColor: Color(0xFF332650),
            labelTextStyle: WidgetStatePropertyAll(
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        home: const bool.fromEnvironment('JYOTARA_REQUIRE_TESTER_ACCESS')
            ? TesterAccessScreen(access: testerAccess, child: const IntroScreen())
            : const IntroScreen(),
      ),
    );
  }
}

enum ChatLanguage { auto, english, tamil, tanglish }

class Guide {
  const Guide({
    required this.name,
    required this.speciality,
    required this.description,
    required this.asset,
    required this.icon,
    required this.colors,
    required this.prompts,
  });

  final String name;
  final String speciality;
  final String description;
  final String asset;
  final IconData icon;
  final List<Color> colors;
  final List<String> prompts;
}

const guides = <Guide>[
  Guide(
    name: 'Aadhirai',
    speciality: 'Love & Relationships',
    description:
        'Questions about love, communication and relationship decisions.',
    asset: 'assets/images/aadhirai.png',
    icon: Icons.favorite_rounded,
    colors: [Color(0xFFB04D8A), Color(0xFF4E255E)],
    prompts: [
      'Will my relationship move forward?',
      'En love life ippo epdi iruku?',
      'இந்த உறவில் நான் எதில் கவனம் செலுத்த வேண்டும்?',
    ],
  ),
  Guide(
    name: 'Arivan',
    speciality: 'Career, Job & Business',
    description: 'Career questions, job changes and practical preparation.',
    asset: 'assets/images/arivan.png',
    icon: Icons.work_rounded,
    colors: [Color(0xFF5D62C9), Color(0xFF243056)],
    prompts: [
      'Is this a good period to change jobs?',
      'Enaku promotion chance iruka?',
      'எனக்கு ஏற்ற வேலைத் திசை என்ன?',
    ],
  ),
  Guide(
    name: 'Medha',
    speciality: 'Education & Direction',
    description: 'Study choices, exam focus and higher-education decisions.',
    asset: 'assets/images/medha.png',
    icon: Icons.school_rounded,
    colors: [Color(0xFF298A91), Color(0xFF25425A)],
    prompts: [
      'Higher studies or job—which should I focus on?',
      'Exam clear panna nalla period ah?',
      'எந்த படிப்பு துறை எனக்கு ஏற்றது?',
    ],
  ),
  Guide(
    name: 'Tharagai',
    speciality: 'Marriage & Family',
    description:
        'Marriage questions, family relationships and thoughtful next steps.',
    asset: 'assets/images/tharagai.png',
    icon: Icons.people_alt_rounded,
    colors: [Color(0xFFA05668), Color(0xFF543045)],
    prompts: [
      'What does my chart show about marriage?',
      'Marriage delay aaguma?',
      'திருமணத்திற்கான சாதகமான காலம் எது?',
    ],
  ),
  Guide(
    name: 'Kaalam',
    speciality: 'Daily Guidance & Panchangam',
    description: 'Daily questions, Dasa, transits and Panchangam.',
    asset: 'assets/images/kaalam.png',
    icon: Icons.wb_twilight_rounded,
    colors: [Color(0xFF5A54A8), Color(0xFF263255)],
    prompts: [
      'What should I focus on today?',
      'Innaiku en focus enna?',
      'இன்றைய பஞ்சாங்க வழிகாட்டல் என்ன?',
    ],
  ),
];

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _rise;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _rise = Tween<double>(
      begin: 24,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _enter() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, secondaryAnimation) => const MainShell(),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            ),
        transitionDuration: const Duration(milliseconds: 550),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/cosmic-onboarding.png', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x2A090612),
                  Color(0x44090612),
                  Color(0xF2090612),
                ],
                stops: [0, 0.48, 0.84],
              ),
            ),
          ),
          const Positioned.fill(child: IgnorePointer(child: _StarField())),
          SafeArea(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Opacity(
                opacity: _fade.value,
                child: Transform.translate(
                  offset: Offset(0, _rise.value),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _BrandLockup(compact: true),
                        _StatusPill(label: 'PRIVATE PREVIEW'),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .18),
                        ),
                      ),
                      child: const Icon(Icons.nightlight_round, size: 28),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Your chart.\nYour time.',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Personal Vedic guidance, explained clearly for the decisions that matter to you.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFFD2CBDD),
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _LanguageBadge(label: 'English UI'),
                        _LanguageBadge(label: 'Tamil chat'),
                        _LanguageBadge(label: 'Tanglish chat'),
                      ],
                    ),
                    const SizedBox(height: 30),
                    FilledButton(
                      key: const Key('enterApp'),
                      onPressed: _enter,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                        backgroundColor: const Color(0xFFE0D5FF),
                        foregroundColor: const Color(0xFF24153E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Explore Jyotara',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Automated AI Vedic guidance · Not a human consultation or guaranteed prediction',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _openChat(Guide guide) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ChatScreen(guide: guide)));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onOpenChat: _openChat),
      GuidesScreen(onOpenChat: _openChat),
      QuickAskScreen(onOpenChat: _openChat),
      const ChartScreen(),
      const AccountScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: uiText(context, 'Home'),
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome_rounded),
            label: uiText(context, 'Guides'),
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: uiText(context, 'Ask'),
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: uiText(context, 'Chart'),
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: uiText(context, 'Account'),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.onOpenChat, super.key});

  final ValueChanged<Guide> onOpenChat;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const Key('homeScroll'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverList.list(
              children: [
                const _TopBar(),
                const SizedBox(height: 28),
                Text(
                  uiText(context, 'Welcome'),
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: muted),
                ),
                const SizedBox(height: 4),
                Text(
                  uiText(context, 'What would you like\nguidance about?'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 22),
                _ChartHero(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => profileSession.facts == null
                          ? const BirthProfileScreen()
                          : Scaffold(
                              appBar: AppBar(
                                title: Text(uiText(context, 'Your chart')),
                              ),
                              body: const ChartScreen(),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                _SectionHeader(
                  title: 'Your AI Vedic Guides',
                  action: 'View all',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: Text(uiText(context, 'Your AI Vedic Guides')),
                        ),
                        body: GuidesScreen(onOpenChat: onOpenChat),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 130 + MediaQuery.textScalerOf(context).scale(180),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: guides.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, index) => _CompactGuideCard(
                  guide: guides[index],
                  onTap: () => onOpenChat(guides[index]),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
            sliver: SliverList.list(
              children: [
                const _SectionHeader(title: 'Daily tools'),
                const SizedBox(height: 14),
                const _PanchangCard(),
                const SizedBox(height: 14),
                const _MultilingualCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GuidesScreen extends StatefulWidget {
  const GuidesScreen({required this.onOpenChat, super.key});

  final ValueChanged<Guide> onOpenChat;

  @override
  State<GuidesScreen> createState() => _GuidesScreenState();
}

class _GuidesScreenState extends State<GuidesScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final visibleGuides = guides
        .where(
          (guide) => _filter == 'All' || guide.speciality.contains(_filter),
        )
        .toList();
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            sliver: SliverList.list(
              children: [
                const _TopBar(),
                const SizedBox(height: 30),
                UiText(
                  'Specialist guides',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const UiText(
                  'One shared chart. Five focused guides for your questions.',
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 18),
                Wrap(
                  runSpacing: 8,
                  children: [
                    for (final label in [
                      'All',
                      'Love',
                      'Career',
                      'Education',
                      'Marriage',
                      'Daily',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: UiText(label),
                          selected: _filter == label,
                          onSelected: (_) => setState(() => _filter = label),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
            sliver: SliverList.separated(
              itemCount: visibleGuides.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (_, index) => _FullGuideCard(
                guide: visibleGuides[index],
                onTap: () => widget.onOpenChat(visibleGuides[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QuickAskScreen extends StatelessWidget {
  const QuickAskScreen({required this.onOpenChat, super.key});

  final ValueChanged<Guide> onOpenChat;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
        children: [
          const _TopBar(),
          const SizedBox(height: 30),
          UiText(
            'Ask naturally.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const UiText(
            'Choose a guide, then type in English, Tamil or Tanglish. The reply follows your language.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 24),
          ...guides.map(
            (guide) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () => onOpenChat(guide),
                tileColor: panel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: line),
                ),
                leading: _GuideAvatar(guide: guide, radius: 25),
                title: UiText(
                  guide.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: UiText(
                  guide.speciality,
                  style: const TextStyle(color: muted),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_rounded,
                  color: lavender,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.guide, this.session, super.key});

  final Guide guide;
  final ProfileSession? session;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  ProfileSession get _session => widget.session ?? profileSession;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late GuideConversation _conversation;
  List<ChatMessage> get _messages => _conversation.messages;
  int _boundRevision = -1;
  ChatLanguage _language = ChatLanguage.auto;
  bool get _thinking => _conversation.pending;

  @override
  void initState() {
    super.initState();
    _bindConversation();
    _session.addListener(_profileChanged);
  }

  void _bindConversation() {
    if (_boundRevision != -1) {
      _conversation.removeListener(_conversationChanged);
    }
    _boundRevision = _session.revision;
    _conversation = _session.conversation(widget.guide.name);
    _conversation.addListener(_conversationChanged);
    _language = ChatLanguage.values.firstWhere(
      (value) => value.name == _conversation.language,
      orElse: () => ChatLanguage.auto,
    );
    if (_messages.isEmpty) {
      _messages.add(
        ChatMessage(
          fromUser: false,
          text: 'Ask in English, Tamil or Tanglish and choose your preferred reply language above. Guidance depends on the chart information and reviewed interpretation available; future events are not guaranteed.',
          label: 'AI VEDIC GUIDE',
        ),
      );
    }
  }

  void _conversationChanged() {
    if (mounted) {
      setState(() {
        _language = ChatLanguage.values.firstWhere(
          (v) => v.name == _conversation.language,
          orElse: () => ChatLanguage.auto,
        );
      });
    }
  }

  void _profileChanged() {
    if (!mounted || _boundRevision == _session.revision) return;
    setState(() {
      _bindConversation();
      _controller.clear();
    });
  }

  @override
  void dispose() {
    _session.removeListener(_profileChanged);
    _conversation.removeListener(_conversationChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  ChatLanguage _detect(String text) {
    final detected = detectReplyLanguage(text, preference: _language.name);
    return ChatLanguage.values.byName(detected);
  }

  Future<void> _send([String? suggestion]) async {
    final text = (suggestion ?? _controller.text).trim();
    if (text.isEmpty || _thinking) return;
    final detected = _detect(text);
    final sentRevision = _session.revision;
    final sentConversation = _conversation;
    setState(() {
      _messages.add(ChatMessage(fromUser: true, text: text));
      _controller.clear();
      sentConversation.pending = true;
    });
    sentConversation.changed();
    try {
      final category = switch (widget.guide.name) {
        'Aadhirai' => 'Love',
        'Arivan' => 'Career',
        'Medha' => 'Education',
        'Tharagai' => 'Marriage',
        _ => 'Daily',
      };
      final result = await _session.ask(
        category: category,
        question: text,
        responseStyle: detected.name,
        guide: widget.guide.name,
      );
      if (sentRevision != _session.revision) return;
      await _session.recordGuidanceResponse(result, sentConversation, detected.name);
    } on JyotaraApiException catch (error) {
      if (sentRevision != _session.revision) return;
      if (!mounted) {
        sentConversation.messages.add(
          ChatMessage(
            fromUser: false,
            text: error.chatMessage,
            label: error.chatLabel,
          ),
        );
        sentConversation.changed();
        return;
      }
      setState(() {
        _controller.text = text;
        _messages.add(
          ChatMessage(
            fromUser: false,
            text: error.chatMessage,
            label: error.chatLabel,
          ),
        );
      });
    } catch (_) {
      if (sentRevision != _session.revision) return;
      if (!mounted) {
        sentConversation.messages.add(
          const ChatMessage(
            fromUser: false,
            text: 'Guidance could not be loaded. Your question is preserved; please try again.',
            label: 'SERVICE ERROR',
          ),
        );
        sentConversation.changed();
        return;
      }
      setState(() {
        _controller.text = text;
        _messages.add(
          const ChatMessage(
            fromUser: false,
            text: 'Guidance could not be loaded. Your question is preserved; please try again.',
            label: 'SERVICE ERROR',
          ),
        );
      });
    } finally {
      sentConversation.pending = false;
      sentConversation.changed();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 28 + MediaQuery.textScalerOf(context).scale(44),
        titleSpacing: 0,
        title: Row(
          children: [
            _GuideAvatar(guide: widget.guide, radius: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText(
                    widget.guide.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const UiText(
                    'AI Vedic Guide',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Icon(Icons.shield_outlined, color: lavender),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 24 + MediaQuery.textScalerOf(context).scale(24),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              children: ChatLanguage.values.map((language) {
                final labels = {
                  ChatLanguage.auto: 'Auto',
                  ChatLanguage.english: 'English',
                  ChatLanguage.tamil: 'Tamil',
                  ChatLanguage.tanglish: 'Tanglish',
                };
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: UiText(labels[language]!),
                    selected: _language == language,
                    onSelected: (_) async {
                      try {
                        await _session.setChatLanguage(language.name);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: UiText(
                                'Language could not be saved. Please try again.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              key: const Key('chatHistoryList'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              itemCount: 1 + _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (_, index) {
                if (index == 0) {
                  return _session.facts == null
                      ? ListTile(
                          title: const UiText('Create your chart to start'),
                          subtitle: const UiText(
                            'Your details are shared across all guides.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const BirthProfileScreen(),
                            ),
                          ),
                        )
                      : const SizedBox.shrink();
                }
                index -= 1;
                if (_thinking && index == _messages.length) {
                  return const _TypingBubble();
                }
                return _MessageBubble(message: _messages[index]);
              },
            ),
          ),
          if (_messages.length == 1)
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 3,
                ),
                itemCount: widget.guide.prompts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => ActionChip(
                  label: Text(widget.guide.prompts[index]),
                  onPressed: () => _send(widget.guide.prompts[index]),
                ),
              ),
            ),
          Container(
            padding: EdgeInsets.fromLTRB(
              14,
              10,
              14,
              10 + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF100B19),
              border: Border(top: BorderSide(color: line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('chatInput'),
                    controller: _controller,
                    maxLength: 240,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: uiText(
                        context,
                        'Ask in English, Tamil or Tanglish…',
                      ),
                      hintMaxLines: 1,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  key: const Key('sendMessage'),
                  tooltip: uiText(context, 'Send question'),
                  onPressed: _thinking ? null : _send,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: violet,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(50, 50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChartScreen extends StatelessWidget {
  const ChartScreen({super.key, this.session});
  final ProfileSession? session;
  @override
  Widget build(BuildContext context) {
    final active = session ?? profileSession;
    return ListenableBuilder(
      listenable: active,
      builder: (context, _) {
        final facts = active.facts;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              UiText(
                'Your Vedic chart',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              if (active.storageError != null) UiText(active.storageError!),
              if (active.profileRecovered)
                const UiText(
                  'Recovered the earlier chart without a new calculation. The calculation time below is the original time.',
                ),
              if (active.profileRequestUnconfirmed)
                const UiText(
                  'A chart request may already have reached the server. Its session is saved on this device; it has not been resent automatically. A retry may be blocked to avoid duplicate calculation charges.',
                ),
              if (facts == null)
                const UiText(
                  'Add your birth details to calculate your personal chart.',
                ),
              if (facts != null) ...[
                SouthIndianChart(facts: facts),
                NavamsaSection(facts: facts, birthTimeKnown: active.birthTimeKnown),
                if (!active.birthTimeKnown)
                  const UiText(
                    'Approximate noon chart: Rasi and Nakshatra are provisional. Lagnam and Dasa are withheld.',
                  ),
                for (final field in const {
                  'rashi': 'Rasi',
                  'nakshatra': 'Nakshatra',
                  'pada': 'Pada',
                  'lagna': 'Lagnam',
                  'rashiLord': 'Rasi lord',
                  'nakshatraLord': 'Nakshatra lord',
                }.entries)
                  ListTile(
                    title: UiText(field.value),
                    trailing: UiText(
                      facts[field.key]?.toString() ?? 'Unavailable',
                    ),
                  ),
                const Divider(),
                const UiText(
                  'Planetary positions',
                  style: TextStyle(fontSize: 20),
                ),
                for (final planet in (facts['planets'] as List? ?? []))
                  ListTile(
                    title: UiText(planet['name'].toString()),
                    subtitle: UiText(
                      '${planet['rasi']} · ${displayPlanetDegree(planet['degree'])}',
                    ),
                  ),
                const UiText(
                  'Dasa–Bhukti at calculation',
                  style: TextStyle(fontSize: 20),
                ),
                const UiText('These periods belong to the saved calculation date. New chat answers check the current period separately.'),
                UiText(
                  '${uiText(context, 'Mahadasha')}: ${uiText(context, facts['currentDasha']?['name'] ?? 'Unavailable')}',
                ),
                UiText(
                  '${uiText(context, 'Antardasha')}: ${uiText(context, facts['currentAntardasha']?['name'] ?? 'Unavailable')}',
                ),
                if (facts['currentAntardasha']?['end'] != null)
                  UiText(
                    '${uiText(context, 'Period ends')}: ${displayIndiaTimestamp(facts['currentAntardasha']['end'])}',
                  ),
                const SizedBox(height: 12),
                UiText(
                  '${uiText(context, 'Calculated')}: ${displayIndiaTimestamp(active.calculatedAt)}',
                ),
                const UiText(
                  'This is a saved calculation for this session, not a continuously updated chart.',
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: active.deleting
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BirthProfileScreen(),
                        ),
                      ),
                icon: const Icon(Icons.edit_calendar),
                label: UiText(
                  facts == null ? 'Add birth details' : 'Change birth details',
                ),
              ),
              if (facts != null ||
                  active.storageError != null ||
                  active.deleting ||
                  active.profileRequestUnconfirmed)
                TextButton(
                  onPressed: active.deleting
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const UiText('Clear this chart?'),
                              scrollable: true,
                              content: UiText(
                                active.canDeleteServer
                                  ? 'Delete this session’s server chart cache, research questions and answer copies, then clear this device’s profile and history. Minimal usage and revocation records remain. Internet is required; if deletion fails, keep this app installed and retry.'
                                  : 'This deletes the saved chart and chat history from this device. It does not delete server usage records.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const UiText('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const UiText('Clear'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            try {
                              await active.clear(includeServer: active.canDeleteServer);
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: UiText(
                                      'Deletion did not finish. Check the status above and retry.',
                                    ),
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: UiText(
                    active.deleting
                        ? 'Deleting data…'
                        : active.canDeleteServer ? 'Delete server and device data' : 'Delete device profile and history',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.person_outline_rounded,
        'Birth profile',
        'View or change your details',
      ),
      (
        Icons.workspace_premium_outlined,
        'Plans & question balance',
        'Pilot limits · Payments not enabled',
      ),
      (Icons.history_rounded, 'Chat history', 'Saved privately on this device'),
      (Icons.translate_rounded, 'App language', 'English or Tamil menus'),
      (
        Icons.language_rounded,
        'Chat language',
        'Choose a saved reply preference',
      ),
      (
        Icons.lock_outline_rounded,
        'Privacy & consent',
        'Research storage is off',
      ),
      (
        Icons.help_outline_rounded,
        'About this build',
        'Internal integration test',
      ),
    ];
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        children: [
          const _TopBar(),
          const SizedBox(height: 30),
          Text(
            uiText(context, 'Your account'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [violet, Color(0xFF5835A0)],
                      ),
                    ),
                    child: const Icon(Icons.person_rounded),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Local test session',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Not signed in · OTP not configured',
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          ...items.map(
            (item) => ListTile(
              onTap: () async {
                if (item.$2 == 'App language') {
                  final preferences =
                      context
                          .dependOnInheritedWidgetOfExactType<UiLanguageScope>()
                          ?.notifier ??
                      uiLanguagePreferences;
                  final selected = await showDialog<String>(
                    context: context,
                    builder: (dialogContext) => SimpleDialog(
                      title: Text(uiText(dialogContext, 'App language')),
                      children: [
                        for (final entry in {
                          'en': 'English',
                          'ta': 'தமிழ்',
                        }.entries)
                          SimpleDialogOption(
                            onPressed: () =>
                                Navigator.pop(dialogContext, entry.key),
                            child: Text(
                              '${preferences.value == entry.key ? '✓ ' : ''}${entry.value}',
                            ),
                          ),
                      ],
                    ),
                  );
                  if (selected != null) {
                    try {
                      await preferences.set(selected);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              uiText(
                                context,
                                'Language could not be saved. Please try again.',
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  }
                  return;
                }
                if (item.$2 == 'Privacy & consent') {
                  await showDialog<void>(
                    context: context,
                    builder: (_) =>
                        ResearchConsentDialog(session: profileSession),
                  );
                  return;
                }
                if (item.$2 == 'Chat language') {
                  final selected = await showDialog<String>(
                    context: context,
                    builder: (dialogContext) => SimpleDialog(
                      title: const UiText('Reply language'),
                      children: ['auto', 'english', 'tamil', 'tanglish']
                          .map(
                            (value) => SimpleDialogOption(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, value),
                              child: Text(
                                '${value == languagePreferences.value ? '✓ ' : ''}${uiText(dialogContext, '${value[0].toUpperCase()}${value.substring(1)}')}',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  );
                  if (selected != null) {
                    try {
                      await profileSession.setChatLanguage(selected);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: UiText(
                              'Language could not be saved. Please try again.',
                            ),
                          ),
                        );
                      }
                    }
                  }
                  return;
                }
                if (item.$2 == 'Birth profile') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BirthProfileScreen(),
                    ),
                  );
                  return;
                }
                final detail = switch (item.$2) {
                  'Plans & question balance' => 'Usage limits are enforced by the test service. Failed or uncertain requests may still count. Ask the test coordinator for your assigned limits. Payments are not enabled in this build.',
                  'Chat history' => 'Your profile and conversations are saved in encrypted device storage. Reopen a guide to see its history. Changing or deleting the profile removes the previous history. This is not cloud backup or cross-device account recovery. Check the Chart tab for storage errors.',
                  _ => 'Jyotara is an internal test build, not a public release. Guides are automated, not human astrologers. Traditional interpretations are not guarantees. Do not use them as medical, legal or investment advice.',
                };
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: UiText(item.$2),
                    content: SingleChildScrollView(child: UiText(detail)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const UiText('Close'),
                      ),
                    ],
                  ),
                );
              },
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 3,
              ),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF21172F),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.$1, color: lavender),
              ),
              title: Text(
                uiText(context, item.$2),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: item.$2 == 'Privacy & consent'
                  ? AnimatedBuilder(
                      animation: profileSession,
                      builder: (_, _) => Text(
                        uiText(
                          context,
                          profileSession.researchConsent
                              ? 'Research sharing is on for this session'
                              : 'Research sharing is off',
                        ),
                        style: const TextStyle(color: muted),
                      ),
                    )
                  : Text(
                      uiText(context, item.$3),
                      style: const TextStyle(color: muted),
                    ),
              trailing: const Icon(Icons.chevron_right_rounded, color: muted),
            ),
          ),
          const SizedBox(height: 14),
          const _DisclosureCard(),
        ],
      ),
    );
  }
}

class BirthProfileScreen extends StatelessWidget {
  const BirthProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => BirthForm(session: profileSession);
}

class _TopBar extends StatelessWidget {
  const _TopBar();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _BrandLockup(compact: true)),
        IconButton(
          tooltip: uiText(context, 'Account'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(uiText(context, 'Account'))),
                body: const AccountScreen(),
              ),
            ),
          ),
          icon: const Icon(Icons.person_outline_rounded),
        ),
      ],
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 34 : 44,
          height: compact ? 34 : 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [violet, Color(0xFF5A37A2)]),
          ),
          child: Icon(Icons.nightlight_round, size: compact ? 18 : 24),
        ),
        const SizedBox(width: 10),
        const Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Jyotara',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              UiText(
                'TRADITIONAL VEDIC GUIDANCE',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartHero extends StatelessWidget {
  const _ChartHero({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: profileSession,
      builder: (context, _) {
        final facts = profileSession.facts;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF513581), Color(0xFF21142F)],
            ),
            border: Border.all(color: const Color(0xFF7459A7)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x303A1F72),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: gold, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: UiText(
                      'YOUR PERSONAL CONTEXT',
                      style: TextStyle(
                        color: gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                facts == null
                    ? uiText(context, 'Start with your\nVedic birth chart.')
                    : '${facts['rashi']} ${uiText(context, 'Rasi')}',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 10),
              Text(
                facts == null
                    ? uiText(
                        context,
                        'Add your date, time and birthplace. Every guide uses this profile.',
                      )
                    : '${facts['nakshatra']} · ${uiText(context, 'Your chart is available. Open it to check details, freshness and storage status.')}',
                style: const TextStyle(color: Color(0xFFD5CCE2), height: 1.45),
              ),
              const SizedBox(height: 18),
              FilledButton.tonalIcon(
                onPressed: onPressed,
                icon: Icon(
                  facts == null ? Icons.add_rounded : Icons.grid_view_rounded,
                ),
                label: Text(
                  uiText(
                    context,
                    facts == null ? 'Create birth profile' : 'View my chart',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactGuideCard extends StatelessWidget {
  const _CompactGuideCard({required this.guide, required this.onTap});
  final Guide guide;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: guide.colors,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GuideAvatar(guide: guide, radius: 35),
                const Spacer(),
                const _AiBadge(),
                const SizedBox(height: 8),
                UiText(
                  guide.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                UiText(
                  guide.speciality,
                  style: const TextStyle(
                    color: Color(0xFFE6DFF0),
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FullGuideCard extends StatelessWidget {
  const _FullGuideCard({required this.guide, required this.onTap});
  final Guide guide;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GuideAvatar(guide: guide, radius: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        UiText(
                          guide.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const _AiBadge(),
                      ],
                    ),
                    const SizedBox(height: 3),
                    UiText(
                      guide.speciality,
                      style: const TextStyle(
                        color: lavender,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    UiText(
                      guide.description,
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.translate_rounded, color: gold, size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: UiText(
                            'English · Tamil · Tanglish',
                            style: TextStyle(
                              color: gold,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideAvatar extends StatelessWidget {
  const _GuideAvatar({required this.guide, required this.radius});
  final Guide guide;
  final double radius;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.white.withValues(alpha: .8), violet, gold],
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          guide.asset,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
    );
  }
}

class _PanchangCard extends StatelessWidget {
  const _PanchangCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.wb_twilight_rounded, color: gold),
                SizedBox(width: 10),
                Expanded(
                  child: UiText(
                    'Daily Panchangam',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const UiText(
              'Daily timings are not connected on this screen yet. Your birth chart is not today’s Panchangam. No daily timings are being shown.',
              style: TextStyle(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultilingualCard extends StatelessWidget {
  const _MultilingualCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF121D27),
        border: Border.all(color: const Color(0xFF29404F)),
      ),
      child: const Row(
        children: [
          Icon(Icons.translate_rounded, color: Color(0xFF80D7E0), size: 30),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(
                  'Ask in your natural language',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                UiText(
                  'Choose English or Tamil menus in Account. Chat in English, Tamil or Tanglish; set your reply language separately.',
                  style: TextStyle(color: Color(0xFFAFC7CF), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.fromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .82,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: message.fromUser ? const Color(0xFF7E5BDC) : panel,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.fromUser ? 20 : 5),
            bottomRight: Radius.circular(message.fromUser ? 5 : 20),
          ),
          border: message.fromUser ? null : Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.label != null) ...[
              Text(
                message.label!,
                style: const TextStyle(
                  color: gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 7),
            ],
            SelectionArea(
              child: Text(message.text, style: const TextStyle(fontSize: 16, height: 1.45)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: _StatusPill(label: 'READING YOUR LANGUAGE…'),
    ),
  );
}

class _DisclosureCard extends StatelessWidget {
  const _DisclosureCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF15101E),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: line),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: lavender, size: 20),
        SizedBox(width: 11),
        Expanded(
          child: Text(
            'Birth data is sensitive. Production storage, consent and deletion controls will be connected before testing with real users.',
            style: TextStyle(color: muted, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      UiText(title, style: Theme.of(context).textTheme.titleLarge),
      if (action != null)
        TextButton(
          onPressed: onAction,
          child: UiText(
            action!,
            style: const TextStyle(
              color: lavender,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
    ],
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF21172F),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFF4A3860)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: lavender,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: .65,
      ),
    ),
  );
}

class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: .16)),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class _AiBadge extends StatelessWidget {
  const _AiBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .2),
      borderRadius: BorderRadius.circular(999),
    ),
    child: const UiText(
      'AI GUIDE',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: .7,
        color: Color(0xFFE9E1FF),
      ),
    ),
  );
}

class _StarField extends StatefulWidget {
  const _StarField();
  @override
  State<_StarField> createState() => _StarFieldState();
}

class _StarFieldState extends State<_StarField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, _) => CustomPaint(painter: _StarPainter(_controller.value)),
  );
}

class _StarPainter extends CustomPainter {
  const _StarPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    const points = [
      Offset(.11, .18),
      Offset(.82, .12),
      Offset(.91, .33),
      Offset(.18, .42),
      Offset(.74, .55),
      Offset(.35, .67),
      Offset(.88, .76),
      Offset(.08, .82),
    ];
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .18 + progress * .22);
    for (var i = 0; i < points.length; i++) {
      final point = Offset(
        points[i].dx * size.width,
        points[i].dy * size.height,
      );
      canvas.drawCircle(point, i.isEven ? 1.4 : .8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
