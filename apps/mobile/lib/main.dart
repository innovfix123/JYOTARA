import 'services/user_journey.dart';
import 'services/meta_measurement.dart';
import 'bronze_theme.dart';
import 'jyotara_typography.dart';
import 'ask_theme.dart';
import 'matching_art.dart';
import 'services/profile_avatar.dart';
import 'services/chat_delivery.dart';
import 'services/marketing_analytics.dart';
import 'services/remote_config.dart';
import 'chat_wallpaper.dart';
import 'route_nav.dart';
import 'premium_profile.dart';
export 'premium_profile.dart' show AccountScreen;
import 'coin_wallet.dart';
import 'explore_screen.dart';
import 'payment_support.dart';
import 'chat_availability.dart';
import 'notification_center.dart';
import 'services/notification_inbox.dart';
import 'services/firebase_services.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'services/account_storage.dart';
import 'services/account_profile_session.dart';
import 'services/profile_backup.dart';
import 'first_profile_setup.dart';
import 'services/phone_access.dart';
import 'phone_access_screen.dart';
import 'services/public_reading_text.dart';
import 'services/name_display.dart';
import 'brand_mark.dart';

import 'dart:async';

import 'package:flutter/services.dart';

import 'launch_intro.dart';
import 'celestial_welcome.dart';
import 'home_sage_art.dart';
import 'discovery_screens.dart';
import 'chat_profile_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/profile_session.dart';
import 'services/jyotara_api.dart';
import 'services/conversation.dart';
import 'services/chat_suggestions.dart';
import 'services/ui_language.dart';
import 'services/language_preferences.dart';
import 'services/reply_language.dart';
import 'services/chart_display.dart';
import 'services/local_profile_vault.dart';
import 'birth_form.dart';
import 'south_chart.dart';
import 'navamsa_section.dart';
import 'research_consent_dialog.dart';
import 'privacy_links.dart';
import 'services/tester_access.dart';
import 'tester_access_screen.dart';

part 'compact_home.dart';
part 'chat_bubbles.dart';

final firebaseMessenger = GlobalKey<ScaffoldMessengerState>();
final languagePreferences = LanguagePreferences();
final uiLanguagePreferences = UiLanguagePreferences();
final testerAccess = TesterAccess();
final accountStorage = AccountStorage();
final profileAvatarPreference = ProfileAvatarPreference(
  storage: accountStorage,
);
final phoneAccess = PhoneAccess(
  testerCode: () => testerAccess.code,
  prepareAccount: _prepareAccount,
  restoreVerifiedProfile: _restoreVerifiedProfile,
  eraseLocalAccount: (account) async {
    await profileSession.flushStorage();
    await accountStorage.erase(account);
    // Discard the old in-memory session after its writes have settled.
    profileSession = _newProfileSession();
  },
);
ProfileBackup? _activeBackup;
String? _backupAccount;
ProfileSession profileSession = _newProfileSession();
ProfileSession _newProfileSession() {
  final owner = accountStorage.account;
  final storageKey = accountStorage.key('nirayana.private-profile.v1');
  return ProfileSession(
    api: JyotaraApiClient(
      testerCode: () => testerAccess.code,
      phoneToken: () => phoneAccess.token,
    ),
    preferences: languagePreferences,
    onBirthProfileSaved: (record) async {
      if (owner != null &&
          _backupAccount == owner &&
          phoneAccess.accountId == owner &&
          phoneAccess.token != null &&
          _activeBackup != null) {
        await _activeBackup!.save(record);
      }
    },
    vault: LocalProfileVault(
      read: () => const FlutterSecureStorage().read(key: storageKey),
      write: (value) => accountStorage.writeKey(storageKey, value),
    ),
  );
}

Future<void> _prepareAccount(String account) async {
  _activeBackup = null;
  _backupAccount = null;
  profileSession = await restoreAccountProfile(
    account: account,
    storage: accountStorage,
    current: profileSession,
    create: _newProfileSession,
  );
  unawaited(profileAvatarPreference.load());
}

Future<void> _restoreVerifiedProfile(String account, String token) async {
  if (accountStorage.account != account) await _prepareAccount(account);
  final backup = ProfileBackup(
    token: () =>
        phoneAccess.accountId == account ? phoneAccess.token ?? '' : '',
    testerCode: () => testerAccess.code,
  );
  await restoreBirthProfile(backup: backup, session: profileSession);
  _backupAccount = account;
  _activeBackup = backup;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await userJourney.initialize(
    baseUrl: defaultApiBaseUrl,
    account: () => phoneAccess.accountId,
    token: () => phoneAccess.token,
    testerCode: () => testerAccess.code,
  );
  officeDemoAccount = () => phoneAccess.officeDemo;
  coinAccount = AccountService(
    token: () => phoneAccess.token,
    tester: () => testerAccess.code,
    account: () => phoneAccess.accountId,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: canvasColor,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: canvasColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(JyotaraApp(initialization: _restoreApp()));
  firebaseServices.incoming.stream.listen((message) {
    if (!firebaseServices.notifications) return;
    final title = message.notification?.title?.trim();
    final body = message.notification?.body?.trim();
    final text = [
      if (title != null && title.isNotEmpty) title,
      if (body != null && body.isNotEmpty) body,
    ].join('\n');
    if (text.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      firebaseMessenger.currentState?.showSnackBar(
        SnackBar(
          content: Text(text, maxLines: 5, overflow: TextOverflow.ellipsis),
          duration: const Duration(seconds: 8),
          showCloseIcon: true,
        ),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  });
  if (!const bool.fromEnvironment('JYOTARA_OFFLINE_QA')) {
    unawaited(firebaseServices.initialize());
    unawaited(marketingAnalytics.initialize());
    unawaited(metaMeasurement.initialize());
  }
}

Future<void> _restoreApp() async {
  unawaited(remoteConfig.start());
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
  if (const bool.fromEnvironment('JYOTARA_REQUIRE_TESTER_ACCESS')) {
    await testerAccess.restore();
  }
  await phoneAccess.restore();
  await accountStorage.migrateLegacy(phoneAccess.accountId);
  if (phoneAccess.accountId != null) {
    await _prepareAccount(phoneAccess.accountId!);
    if (phoneAccess.profileRestorePending && phoneAccess.token != null) {
      await phoneAccess.retryProfileRestore();
    }
  } else {
    await profileSession.restore();
  }
}

const appBuildLabel = String.fromEnvironment(
  'JYOTARA_BUILD_LABEL',
  defaultValue: 'Development',
);

const canvasColor = BronzePalette.background;
const panel = BronzePalette.card;
const line = BronzePalette.border;
const saffron = BronzePalette.accent;
const bodyInk = BronzePalette.ink;
const muted = BronzePalette.muted;
const gold = BronzePalette.gold;

class JyotaraApp extends StatelessWidget {
  const JyotaraApp({super.key, this.uiPreferences, this.initialization});
  final UiLanguagePreferences? uiPreferences;
  final Future<void>? initialization;

  @override
  Widget build(BuildContext context) {
    final preferences = uiPreferences ?? uiLanguagePreferences;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: saffron,
          brightness: Brightness.dark,
          surface: panel,
        ).copyWith(
          primary: gold,
          primaryContainer: BronzePalette.raised,
          onPrimary: BronzePalette.onAccent,
          onPrimaryContainer: BronzePalette.ink,
          secondary: gold,
          secondaryContainer: BronzePalette.raised,
          onSecondaryContainer: bodyInk,
          surfaceContainerHighest: BronzePalette.card,
          surfaceContainerHigh: BronzePalette.card,
          surfaceContainer: BronzePalette.card,
          surfaceContainerLow: BronzePalette.card,
          surfaceContainerLowest: BronzePalette.background,
          surfaceDim: BronzePalette.background,
          surfaceBright: BronzePalette.raised,
          onSurfaceVariant: BronzePalette.muted,
          outlineVariant: BronzePalette.border,
          onSurface: bodyInk,
          outline: line,
        );
    return AnimatedBuilder(
      animation: preferences,
      builder: (context, _) => MaterialApp(
        navigatorKey: coinNavigator,
        navigatorObservers: [userJourney.navigatorObserver],
        locale: Locale(preferences.value),
        supportedLocales: const [Locale('en'), Locale('ta')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: canvasColor,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: canvasColor,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: RemoteConfigScope(
            config: remoteConfig,
            child: UserJourneyBoundary(
              child: UiLanguageScope(preferences: preferences, child: child!),
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
        title: 'Jyotara',
        scaffoldMessengerKey: firebaseMessenger,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: scheme,
          scaffoldBackgroundColor: canvasColor,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {TargetPlatform.android: MidnightPageTransitions()},
          ),
          fontFamily: JyotaraFonts.app,
          fontFamilyFallback: JyotaraFonts.fallback,
          appBarTheme: const AppBarTheme(
            backgroundColor: canvasColor,
            surfaceTintColor: Colors.transparent,
            foregroundColor: bodyInk,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: canvasColor,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: canvasColor,
              systemNavigationBarIconBrightness: Brightness.light,
            ),
            titleTextStyle: TextStyle(
              fontFamily: JyotaraFonts.app,
              fontFamilyFallback: JyotaraFonts.fallback,
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: bodyInk,
            ),
            centerTitle: false,
            elevation: 0,
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: BronzePalette.raised,
            contentTextStyle: const TextStyle(color: bodyInk),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: saffron,
              foregroundColor: BronzePalette.onAccent,
              minimumSize: const Size(48, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: const BorderSide(color: line),
            ),
          ),
          dividerTheme: const DividerThemeData(color: line, thickness: .6),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: panel,
            surfaceTintColor: Colors.transparent,
          ),
          chipTheme: ChipThemeData(
            backgroundColor: panel,
            selectedColor: BronzePalette.raised,
            side: const BorderSide(color: line),
            labelStyle: const TextStyle(color: bodyInk),
          ),
          segmentedButtonTheme: SegmentedButtonThemeData(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected) ? canvasColor : muted,
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected) ? gold : panel,
              ),
              side: const WidgetStatePropertyAll(BorderSide(color: line)),
            ),
          ),
          textTheme: jyotaraAppTextTheme(tamil: preferences.value == 'ta'),
          cardTheme: CardThemeData(
            color: panel,
            surfaceTintColor: Colors.transparent,
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: line),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: BronzePalette.card,
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
              borderSide: const BorderSide(color: saffron, width: 1.4),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: canvasColor,
            indicatorColor: BronzePalette.raised,
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                color: states.contains(WidgetState.selected) ? gold : muted,
                size: 24,
              ),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                color: states.contains(WidgetState.selected) ? gold : muted,
                fontSize: 11,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ),
        ),
        home: CelestialWelcome(
          initialization: initialization,
          child:
              const bool.fromEnvironment('JYOTARA_REQUIRE_TESTER_ACCESS') &&
                  officeAccessCode.isEmpty
              ? TesterAccessScreen(access: testerAccess, child: _phoneGate())
              : _phoneGate(),
        ),
      ),
    );
  }
}

Widget _phoneGate() => const bool.fromEnvironment('JYOTARA_REQUIRE_PHONE_AUTH')
    ? PhoneAccessScreen(
        access: phoneAccess,
        child: AnimatedBuilder(
          animation: phoneAccess,
          builder: (context, _) => FirstProfileSetup(
            key: ValueKey(phoneAccess.accountId),
            session: profileSession,
            child: const IntroScreen(),
          ),
        ),
      )
    : const IntroScreen();

enum ChatLanguage { auto, english, tamil, tanglish }

class Guide {
  const Guide({
    required this.name,
    required this.speciality,
    this.category = 'Daily',
    this.portraitIndex,
    this.historyKey,
    required this.description,
    required this.asset,
    required this.icon,
    required this.colors,
    required this.prompts,
  });

  final int? portraitIndex;
  final String? historyKey;
  String get conversationKey => historyKey ?? name;
  String get group => switch (category) {
    'Love' || 'Relationships' || 'Marriage' => 'Love & Marriage',
    'Education' => 'Education & Hobbies',
    'Career' || 'Business' => 'Career & Business',
    _ => 'Family & Personal Life',
  };
  final String name;
  final String speciality;
  final String category;
  final String description;
  final String asset;
  final IconData icon;
  final List<Color> colors;
  final List<String> prompts;
}

const guides = <Guide>[
  Guide(
    name: "Meera",
    category: "Love",
    speciality: "Your Love Life",
    description: "Dating, new relationships and communication.",
    asset: "assets/images/guides_portraits97.png",
    portraitIndex: 0,
    icon: Icons.auto_awesome_outlined,
    colors: [BronzePalette.gold, Color(0xFF493021)],
    prompts: [],
  ),
  Guide(
    name: "Nila",
    category: "Relationships",
    speciality: "Love & Trust",
    description: "Mixed signals, trust concerns and healthy boundaries.",
    asset: "assets/images/guides_portraits97.png",
    portraitIndex: 1,
    historyKey: "NilaTrust",
    icon: Icons.auto_awesome_outlined,
    colors: [BronzePalette.gold, Color(0xFF493021)],
    prompts: [],
  ),
  Guide(
    name: "Janaki",
    category: "Marriage",
    speciality: "Your Marriage",
    description: "Marriage, compatibility and commitment.",
    asset: "assets/images/guides_portraits97.png",
    portraitIndex: 2,
    icon: Icons.auto_awesome_outlined,
    colors: [BronzePalette.gold, Color(0xFF493021)],
    prompts: [],
  ),
  Guide(
    name: "Harini",
    category: "Marriage",
    speciality: "Love to Marriage",
    description: "Commitment, family acceptance and married life.",
    asset: "assets/images/guides_portraits97.png",
    portraitIndex: 3,
    icon: Icons.auto_awesome_outlined,
    colors: [BronzePalette.gold, Color(0xFF493021)],
    prompts: [],
  ),
  Guide(
    name: "Aravind",
    category: "Education",
    speciality: "Your Future",
    description: "Learning, exams, college and higher studies.",
    asset: "assets/images/guides_portraits97.png",
    portraitIndex: 4,
    icon: Icons.auto_awesome_outlined,
    colors: [BronzePalette.gold, Color(0xFF493021)],
    prompts: [],
  ),
  Guide(
    name: "Kavya",
    category: "Education",
    speciality: "Your Passions",
    description: "Hobbies, creativity and personal interests.",
    asset: "assets/images/guides_portraits97.png",
    portraitIndex: 5,
    icon: Icons.auto_awesome_outlined,
    colors: [BronzePalette.gold, Color(0xFF493021)],
    prompts: [],
  ),
  Guide(
    name: "Adithya",
    category: "Career",
    speciality: "Your Career",
    description: "Jobs, promotions and career changes.",
    asset: "assets/images/guides_portraits97.png",
    portraitIndex: 6,
    icon: Icons.auto_awesome_outlined,
    colors: [BronzePalette.gold, Color(0xFF493021)],
    prompts: [],
  ),
  Guide(
    name: "Raghavan",
    category: "Business",
    speciality: "Your Business",
    description: "Business direction and partnerships.",
    asset: "assets/images/guides_portraits97.png",
    portraitIndex: 7,
    icon: Icons.auto_awesome_outlined,
    colors: [BronzePalette.gold, Color(0xFF493021)],
    prompts: [],
  ),
  Guide(
    name: "Revathi",
    category: "Family",
    speciality: "Your Family",
    description: "Family relationships, parenting and responsibilities.",
    asset: "assets/images/guides_portraits97.png",
    portraitIndex: 8,
    icon: Icons.auto_awesome_outlined,
    colors: [BronzePalette.gold, Color(0xFF493021)],
    prompts: [],
  ),
  Guide(
    name: "Karthik",
    category: "Spiritual",
    speciality: "Your Journey",
    description: "Personal growth, confidence and life direction.",
    asset: "assets/images/guides_portraits97.png",
    portraitIndex: 9,
    icon: Icons.auto_awesome_outlined,
    colors: [BronzePalette.gold, Color(0xFF493021)],
    prompts: [],
  ),
];

const legacyGuides = <Guide>[
  Guide(
    name: 'Aadhirai',
    category: 'Love',
    speciality: 'Love',
    description:
        'Questions about love, communication and relationship decisions.',
    asset: 'assets/images/aadhirai.png',
    icon: Icons.favorite_rounded,
    colors: [Color(0xFFA84B43), Color(0xFF51271E)],
    prompts: [
      'Will my relationship move forward?',
      'En love life ippo epdi iruku?',
      'இந்த உறவில் நான் எதில் கவனம் செலுத்த வேண்டும்?',
    ],
  ),
  Guide(
    name: 'Arivan',
    category: 'Career',
    speciality: 'Career',
    description: 'Career questions, job changes and practical preparation.',
    asset: 'assets/images/arivan.png',
    icon: Icons.work_rounded,
    colors: [Color(0xFF9A7040), Color(0xFF493021)],
    prompts: [
      'Is this a good period to change jobs?',
      'Enaku promotion chance iruka?',
      'எனக்கு ஏற்ற வேலைத் திசை என்ன?',
    ],
  ),
  Guide(
    name: 'Medha',
    category: 'Education',
    speciality: 'Education & Direction',
    description: 'Study choices, exam focus and higher-education decisions.',
    asset: 'assets/images/medha.png',
    icon: Icons.school_rounded,
    colors: [Color(0xFF60734A), Color(0xFF303D29)],
    prompts: [
      'Higher studies or job—which should I focus on?',
      'Exam clear panna nalla period ah?',
      'எந்த படிப்பு துறை எனக்கு ஏற்றது?',
    ],
  ),
  Guide(
    name: 'Tharagai',
    category: 'Marriage',
    speciality: 'Marriage',
    description:
        'Marriage questions, family relationships and thoughtful next steps.',
    asset: 'assets/images/tharagai.png',
    icon: Icons.people_alt_rounded,
    colors: [Color(0xFFAD6845), Color(0xFF593423)],
    prompts: [
      'What does my chart show about marriage?',
      'Marriage delay aaguma?',
      'திருமணத்திற்கான சாதகமான காலம் எது?',
    ],
  ),
  Guide(
    name: 'Kaalam',
    category: 'Daily',
    speciality: 'Daily Guidance & Panchangam',
    description: 'Daily questions, Dasa, transits and Panchangam.',
    asset: 'assets/images/kaalam.png',
    icon: Icons.wb_twilight_rounded,
    colors: [Color(0xFF9C723E), Color(0xFF4B3222)],
    prompts: [
      'What should I focus on today?',
      'Innaiku en focus enna?',
      'இன்றைய பஞ்சாங்க வழிகாட்டல் என்ன?',
    ],
  ),
  Guide(
    name: 'Iniya',
    category: 'Relationships',
    speciality: 'Relationships',
    description: 'Communication, trust and relationship questions.',
    asset: 'assets/images/iniya.png',
    icon: Icons.favorite_rounded,
    colors: [Color(0xFF9C723E), Color(0xFF4B3222)],
    prompts: ['What does my birth chart say about relationships?'],
  ),
  Guide(
    name: 'Nila',
    category: 'Family',
    speciality: 'Family',
    description: 'Family bonds and household questions.',
    asset: 'assets/images/nila.png',
    icon: Icons.people_alt_rounded,
    colors: [Color(0xFF9C723E), Color(0xFF4B3222)],
    prompts: ['What family themes appear in my chart?'],
  ),
  Guide(
    name: 'Vetri',
    category: 'Career',
    speciality: 'Jobs',
    description: 'Job search, interviews and employment questions.',
    asset: 'assets/images/vetri.png',
    icon: Icons.work_rounded,
    colors: [Color(0xFF9C723E), Color(0xFF4B3222)],
    prompts: ['What does my chart show about work?'],
  ),
  Guide(
    name: 'Valan',
    category: 'Business',
    speciality: 'Business',
    description: 'Business direction and partnership questions.',
    asset: 'assets/images/valan.png',
    icon: Icons.storefront_rounded,
    colors: [Color(0xFF9C723E), Color(0xFF4B3222)],
    prompts: ['What business themes appear in my birth chart?'],
  ),
  Guide(
    name: 'Oli',
    category: 'Education',
    speciality: 'Higher Education',
    description: 'Further study and learning direction.',
    asset: 'assets/images/oli.png',
    icon: Icons.school_rounded,
    colors: [Color(0xFF9C723E), Color(0xFF4B3222)],
    prompts: ['What study themes appear in my chart?'],
  ),
  Guide(
    name: 'Agam',
    category: 'Property',
    speciality: 'Property',
    description: 'Home and property questions.',
    asset: 'assets/images/agam.png',
    icon: Icons.home_rounded,
    colors: [Color(0xFF9C723E), Color(0xFF4B3222)],
    prompts: ['What does my chart show about home life?'],
  ),
  Guide(
    name: 'Arul',
    category: 'Spiritual',
    speciality: 'Spiritual',
    description: 'Traditional Yoga meanings and spiritual reflection.',
    asset: 'assets/images/arul.png',
    icon: Icons.auto_awesome_rounded,
    colors: [Color(0xFF9C723E), Color(0xFF4B3222)],
    prompts: ['Explain the Yogas in my birth chart.'],
  ),
];

String guideWelcome(Guide guide, String name, String language) {
  final custom = remoteConfig.welcome(language);
  if (custom.isNotEmpty) return custom.replaceAll('{guide}', guide.name);
  final topics = <String, List<String>>{
    'Love': ['love', 'காதல்', 'kaadhal'],
    'Relationships': ['your relationship', 'உங்கள் உறவு', 'unga relationship'],
    'Marriage': ['marriage', 'திருமணம்', 'thirumanam'],
    'Family': ['family', 'குடும்பம்', 'family'],
    'Career': [
      guide.name == 'Vetri' ? 'your job search' : 'your career',
      'வேலை',
      'unga velai',
    ],
    'Business': ['your business', 'வணிகம்', 'unga business'],
    'Education': ['your studies', 'படிப்பு', 'unga padippu'],
    'Property': [
      'home or property',
      'வீடு அல்லது சொத்து',
      'veedu allathu property',
    ],
    'Spiritual': [
      'what you are reflecting on',
      'உங்கள் மனதில் இருக்கும் எண்ணங்கள்',
      'unga manasula irukkira vishayam',
    ],
    'Daily': ['today', 'இன்றைய நாள்', 'innaiku'],
  };
  final topic = topics[guide.category] ?? topics['Daily']!;
  if (language == 'tamil') {
    return 'வணக்கம்! நான் ${guide.name}.\n\n${topic[1]} அல்லது உங்கள் மனதில் உள்ளதை என்னிடம் கேட்கலாம்.';
  }
  if (language == 'tanglish') {
    return 'Vanakkam! Naan ${guide.name}.\n\n${topic[2]} pathi illa unga manasula irukkuradha enkitta ketkalaam.';
  }
  return 'Welcome! I’m ${guide.name}.\n\nYou can ask about ${topic[0]} or anything on your mind.';
}

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  @override
  Widget build(BuildContext context) => const MainShell();
}

class MainTabScope extends InheritedWidget {
  const MainTabScope({super.key, required super.child});
  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainTabScope>() != null;
  @override
  bool updateShouldNotify(MainTabScope oldWidget) => false;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tabReveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );
  @override
  void initState() {
    super.initState();
    requestedMainTab.addListener(_routeTab);
  }

  void _routeTab() {
    final index = requestedMainTab.value;
    if (index == null) return;
    requestedMainTab.value = null;
    _selectTab(index);
  }

  @override
  void dispose() {
    requestedMainTab.removeListener(_routeTab);
    _tabReveal.dispose();
    super.dispose();
  }

  void _selectTab(int value) {
    unawaited(remoteConfig.refresh());
    if (value == _index) return;
    userJourney.event('navigation.tab', metadata: {'control': 'tab'});
    userJourney.screen(['home', 'daily', 'explore', 'ask', 'profile'][value]);
    setState(() {
      _index = value;
      _visitedTabs.add(value);
    });
    if (value == 0) coinWalletRevision.value++;
    if (MediaQuery.disableAnimationsOf(context)) {
      _tabReveal.value = 1;
    } else {
      _tabReveal.forward(from: 0);
    }
  }

  int _index = 0;
  final Set<int> _visitedTabs = {0};

  void _openChat(Guide guide) {
    if (!remoteConfig.enabled('chat') ||
        !remoteConfig.guideEnabled(guide.name)) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ChatProfilePicker(guide: guide)),
    );
  }

  @override
  Widget build(BuildContext context) {
    RemoteConfigScope.watch(context);
    final pages = [
      HomeScreen(onOpenChat: _openChat),
      _visitedTabs.contains(1)
          ? const FeatureGate(feature: 'daily', child: DailyHoroscopeScreen())
          : const SizedBox.shrink(),
      const FeatureGate(feature: 'explore', child: ExploreScreen()),
      QuickAskScreen(onOpenChat: _openChat),
      const AccountScreen(),
    ];
    return Theme(
      data: _index == 3 ? askTheme(Theme.of(context)) : Theme.of(context),
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 0,
          title: Text(
            'Jyotara',
            style: TextStyle(
              fontFamily: 'JyotaraEditorial',
              fontSize: 29,
              color: _index == 3 ? AskPalette.action : gold,
            ),
          ),
          leading: IconButton(
            tooltip: uiText(context, 'Account'),
            icon: const Icon(Icons.menu),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: AccountScreen()),
              ),
            ),
          ),
          actions: [
            if (coinWalletEnabled) const HomeCoinCard(compact: true),
            const SizedBox(width: 4),
            IconButton(
              tooltip: uiText(context, 'Notifications'),
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationCenter(),
                ),
              ),
            ),
          ],
          bottom: _index == 0
              ? null
              : const PreferredSize(
                  preferredSize: Size.fromHeight(34),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: CompactLanguageSwitch(),
                  ),
                ),
        ),
        body: MainTabScope(
          child: PremiumBackdrop(
            showPattern: _index != 0,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _tabReveal,
                curve: Curves.easeOutCubic,
              ),
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, .012),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _tabReveal,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: IndexedStack(index: _index, children: pages),
              ),
            ),
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: _index == 3 ? AskPalette.border : line,
                width: .6,
              ),
            ),
          ),
          child: NavigationBar(
            height: 68,
            selectedIndex: _index,
            onDestinationSelected: _selectTab,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: uiText(context, 'Home'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.wb_sunny_outlined),
                selectedIcon: const Icon(Icons.wb_sunny_rounded),
                label: ex(context, 'Daily', 'தினசரி'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.explore_outlined),
                selectedIcon: const Icon(Icons.explore),
                label: ex(context, 'Explore', 'அறியுங்கள்'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: const Icon(Icons.chat_bubble_rounded),
                label: uiText(context, 'Ask'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: ex(context, 'Profile', 'சுயவிவரம்'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.onOpenChat, super.key});
  final ValueChanged<Guide> onOpenChat;
  @override
  Widget build(BuildContext context) => CompactHome(onOpenChat: onOpenChat);
}

class GuidesScreen extends StatefulWidget {
  const GuidesScreen({
    required this.onOpenChat,
    super.key,
    this.initialFilter = 'All',
  });
  final String initialFilter;

  final ValueChanged<Guide> onOpenChat;

  @override
  State<GuidesScreen> createState() => _GuidesScreenState();
}

class _GuidesScreenState extends State<GuidesScreen> {
  late String _filter;
  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    userJourney.screen('ask');
  }

  @override
  Widget build(BuildContext context) {
    RemoteConfigScope.watch(context);
    final visibleGuides = guides
        .where((guide) => remoteConfig.guideEnabled(guide.name))
        .where((guide) => _filter == 'All' || guide.group == _filter)
        .toList();
    return Theme(
      data: askTheme(Theme.of(context)),
      child: ColoredBox(
        key: const Key('softBronzeAsk'),
        color: AskPalette.background,
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                sliver: SliverList.list(
                  children: [
                    const _TopBar(),
                    if (!MainTabScope.contains(context))
                      const AppLanguageSwitch(),
                    const SizedBox(height: 10),
                    UiText(
                      ex(
                        context,
                        'Choose a guide',
                        'வழிகாட்டியைத் தேர்ந்தெடுங்கள்',
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        color: AskPalette.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    UiText(
                      ex(context, 'AI guides', 'AI வழிகாட்டிகள்'),
                      style: const TextStyle(
                        color: AskPalette.muted,
                        fontSize: 12,
                      ),
                    ),
                    if (legacyGuides.any(
                      (g) => profileSession
                          .conversation(g.conversationKey)
                          .messages
                          .isNotEmpty,
                    ))
                      ExpansionTile(
                        title: const UiText('Previous guide chats'),
                        children: [
                          for (final old in legacyGuides.where(
                            (g) => profileSession
                                .conversation(g.conversationKey)
                                .messages
                                .isNotEmpty,
                          ))
                            ListTile(
                              title: Text(old.name),
                              subtitle: UiText(old.speciality),
                              onTap: () => widget.onOpenChat(old),
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final label in [
                            'All',
                            'Love & Marriage',
                            'Education & Hobbies',
                            'Career & Business',
                            'Family & Personal Life',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                visualDensity: VisualDensity.compact,
                                label: UiText(label),
                                selected: _filter == label,
                                onSelected: (_) {
                                  userJourney.event(
                                    'interaction.tap',
                                    metadata: {
                                      'control': 'category',
                                      'feature': 'chat',
                                    },
                                  );
                                  setState(() => _filter = label);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                sliver: SliverList.separated(
                  itemCount: visibleGuides.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) => _FullGuideCard(
                    guide: visibleGuides[index],
                    onTap: () => widget.onOpenChat(visibleGuides[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickAskScreen extends StatelessWidget {
  const QuickAskScreen({required this.onOpenChat, super.key});
  final ValueChanged<Guide> onOpenChat;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: requestedAskGroup,
    builder: (context, group, _) => GuidesScreen(
      key: ValueKey(group),
      onOpenChat: onOpenChat,
      initialFilter: group,
    ),
  );
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.guide,
    this.session,
    this.allowProfileSwitch = false,
    super.key,
  });

  final Guide guide;
  final ProfileSession? session;
  final bool allowProfileSwitch;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  ProfileSession get _session => widget.session ?? profileSession;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();
  late GuideConversation _conversation;
  List<ChatMessage> get _messages => _conversation.messages;
  int _boundRevision = -1;
  ChatLanguage _language = ChatLanguage.auto;
  String _depth = 'standard';
  bool _choosingDepth = false;
  bool _canExit = false;
  bool _ending = false;
  BuildContext? _chatUiContext;
  bool _controlsExpanded = false;
  CoinChatConsent? _coinConsent;
  final _knownMessages = <ChatMessage>{};
  ChatMessage? _deliveryMessage;
  bool get _thinking =>
      _ending || _conversation.pending || _deliveryMessage != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bindConversation();
    _session.addListener(_profileChanged);
    userJourney.screen('chat');
    userJourney.event(
      'chat.start',
      metadata: {'feature': 'chat', 'outcome': 'started'},
    );
    if (_messages.length > 1) _scrollToLatest();
  }

  void _bindConversation() {
    if (_boundRevision != -1) {
      _conversation.removeListener(_conversationChanged);
    }
    _boundRevision = _session.revision;
    _coinConsent = null;
    _conversation = _session.conversation(widget.guide.conversationKey);
    _conversation.addListener(_conversationChanged);
    _conversation.messages.removeWhere((m) => m.label == 'PROFILE OVERVIEW');
    if (_conversation.language == 'auto') {
      _conversation.language = _session.preferredChatLanguage == 'auto'
          ? 'english'
          : _session.preferredChatLanguage;
    }
    if (_conversation.ended) {
      _session.startNewConversation(widget.guide.conversationKey);
    }
    // One customer-facing conversation mode. Existing pending request receipts
    // retain their original depth in ProfileSession for recovery.
    _depth = 'standard';
    if (_conversation.depth == 'standard' &&
        _conversation.billingAcknowledged &&
        _conversation.acceptedGeneralCoins != null &&
        _conversation.acceptedRelationshipCoins != null) {
      _coinConsent = CoinChatConsent(
        coinAccount?.account(),
        'standard',
        _conversation.acceptedGeneralCoins! >
                _conversation.acceptedRelationshipCoins!
            ? _conversation.acceptedGeneralCoins!
            : _conversation.acceptedRelationshipCoins!,
        generalCoins: _conversation.acceptedGeneralCoins,
        relationshipCoins: _conversation.acceptedRelationshipCoins,
      );
    }
    _conversation.depth = 'standard';
    _controlsExpanded = false;
    _language = ChatLanguage.values.firstWhere(
      (value) => value.name == _conversation.language,
      orElse: () => ChatLanguage.auto,
    );
    // A cached welcome with no user question should follow the saved language.
    // Never rewrite an actual conversation when its language changes.
    if (_messages.length == 1 &&
        !_messages.single.fromUser &&
        ['english', 'tamil', 'tanglish'].any(
          (lang) =>
              _messages.single.text ==
              guideWelcome(widget.guide, _session.nickname, lang),
        )) {
      _messages.clear();
    }
    if (_messages.isEmpty) {
      _messages.add(
        ChatMessage(
          fromUser: false,
          text: guideWelcome(
            widget.guide,
            _session.nickname,
            _language == ChatLanguage.auto ? 'english' : _language.name,
          ),
        ),
      );
    }
    _restoreRetryDraft();
    _deliveryMessage = null;
    _knownMessages
      ..clear()
      ..addAll(_messages);
  }

  void _restoreRetryDraft() {
    if (_conversation.pending ||
        _conversation.ended ||
        _controller.text.isNotEmpty ||
        _messages.isEmpty) {
      return;
    }
    const retryLabels = {
      'ANSWER NOT CONFIRMED',
      'REQUEST NOT COMPLETED',
      'INTERRUPTED REQUEST',
      'SERVICE ERROR',
    };
    if (!retryLabels.contains(_messages.last.label) &&
        _messages.last.wallet?['status'] != 'failed') {
      return;
    }
    final question = _messages.where((message) => message.fromUser).lastOrNull;
    if (question != null) _controller.text = question.text;
  }

  void _conversationChanged() {
    if (mounted) {
      setState(() {
        final fresh = _messages
            .where((m) => !m.fromUser && !_knownMessages.contains(m))
            .toList();
        _knownMessages.addAll(_messages);
        if (fresh.isNotEmpty) {
          final message = fresh.last;
          // Errors and saved history stay immediately readable. Presentation
          // never changes the stored answer or the coin receipt.
          if (!const {
                'ANSWER NOT CONFIRMED',
                'REQUEST NOT COMPLETED',
                'INTERRUPTED REQUEST',
                'SERVICE ERROR',
              }.contains(message.label) &&
              message.wallet?['status'] != 'failed' &&
              chatReplyParts(message.text).isNotEmpty) {
            _deliveryMessage = message;
          }
        }
        _restoreRetryDraft();
        _language = ChatLanguage.values.firstWhere(
          (v) => v.name == _conversation.language,
          orElse: () => ChatLanguage.auto,
        );
      });
      _scrollToLatest();
      _session.conversationUpdated();
    }
  }

  @override
  void didChangeMetrics() => _scrollToLatest();

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        if (MediaQuery.disableAnimationsOf(context)) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  void _profileChanged() {
    if (!mounted || _boundRevision == _session.revision) return;
    setState(() {
      _controller.clear();
      _bindConversation();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputFocus.dispose();
    _session.removeListener(_profileChanged);
    _conversation.removeListener(_conversationChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _setReplyLanguage(ChatLanguage language) async {
    try {
      await _session.setChatLanguage(language.name);
      if (!_messages.any((m) => m.fromUser)) {
        _messages.clear();
        _messages.add(
          ChatMessage(
            fromUser: false,
            text: guideWelcome(widget.guide, _session.nickname, language.name),
          ),
        );
        _conversation.changed();
        await _session.flushStorage();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Language could not be saved. Please retry.'),
          ),
        );
      }
    }
  }

  ChatLanguage _detect(String text) {
    final detected = detectReplyLanguage(text, preference: _language.name);
    return ChatLanguage.values.byName(detected);
  }

  List<String> get _suggestions => chatSuggestions(
    widget.guide.category,
    detectReplyLanguage(
      _messages.where((m) => m.fromUser).lastOrNull?.text ?? '',
      preference: _language.name,
    ),
    _messages.where((m) => m.fromUser).map((m) => m.text).toList(),
    lastReply: _messages.where((m) => !m.fromUser).lastOrNull?.text,
  );

  Future<void> _send([
    String? suggestion,
    Map<String, dynamic>? upgrade,
  ]) async {
    if (!publicChatEnabled || !remoteConfig.enabled('chat')) return;
    if (upgrade != null) return;
    _depth = 'standard';
    if (!remoteConfig.languageEnabled(_language.name)) {
      _setReplyLanguage(
        ChatLanguage.values.byName(remoteConfig.list('languages').first),
      );
    }
    final text = (suggestion ?? _controller.text).trim();
    if (text.isEmpty || _thinking || _choosingDepth || _conversation.ended) {
      return;
    }
    final detected = upgrade?['style'] is String
        ? ChatLanguage.values.byName(upgrade!['style'])
        : _detect(text);
    final pendingRequest = _session.pendingGuidanceRequest(
      category: widget.guide.category,
      question: text,
      responseStyle: detected.name,
      guide: widget.guide.name,
    );
    if (pendingRequest == null &&
        coinWalletEnabled &&
        !RegExp(
          r'^(hi|hello|hey|vanakkam|வணக்கம்)[!.,\s]*$',
          caseSensitive: false,
        ).hasMatch(text) &&
        upgrade == null &&
        (_coinConsent == null ||
            _coinConsent!.account != coinAccount?.account())) {
      _choosingDepth = true;
      final account = coinAccount?.account();
      final generalCoins = remoteConfig.cost('generalStandard', 10);
      final relationshipCoins = remoteConfig.cost('relationshipStandard', 15);
      final selected = await showChatDepthPicker(
        _chatUiContext ?? context,
        generalCoins: generalCoins,
        relationshipCoins: relationshipCoins,
      );
      _choosingDepth = false;
      if (!mounted ||
          selected == null ||
          _conversation.ended ||
          account != coinAccount?.account()) {
        return;
      }
      setState(() {
        _controlsExpanded = false;
        _depth = selected;
        _conversation.depth = selected;
        _conversation.billingAcknowledged = true;
        _conversation.acceptedGeneralCoins = generalCoins;
        _conversation.acceptedRelationshipCoins = relationshipCoins;
        _conversation.changed();
        _coinConsent = CoinChatConsent(
          account,
          selected,
          generalCoins > relationshipCoins ? generalCoins : relationshipCoins,
          generalCoins: generalCoins,
          relationshipCoins: relationshipCoins,
        );
      });
    }
    userJourney.event(
      'chat.send',
      metadata: {
        'feature': 'chat',
        'control': 'send',
        'language': detected == ChatLanguage.tamil
            ? 'ta'
            : detected == ChatLanguage.tanglish
            ? 'tanglish'
            : 'en',
      },
    );
    final sentRevision = _session.revision;
    final sentConversation = _conversation;
    setState(() {
      _controlsExpanded = false;
      _inputFocus.requestFocus();
      _messages.add(ChatMessage(fromUser: true, text: text));
      _controller.clear();
      sentConversation.pending = true;
      sentConversation.updatedAt = DateTime.now();
    });
    sentConversation.changed();
    if (RegExp(
      r'^(hi|hello|hey|vanakkam|வணக்கம்)[!.,\s]*$',
      caseSensitive: false,
    ).hasMatch(text)) {
      _messages.add(
        ChatMessage(
          fromUser: false,
          text: detected == ChatLanguage.tamil
              ? 'வணக்கம்! எதைப் பற்றிப் பேச விரும்புகிறீர்கள்?'
              : detected == ChatLanguage.tanglish
              ? 'Vanakkam! Edha pathi pesa virumbureenga?'
              : 'Hi! What would you like to talk about?',
        ),
      );
      sentConversation.pending = false;
      sentConversation.changed();
      await _session.flushStorage();
      return;
    }
    try {
      final category = widget.guide.category;
      final consent = upgrade == null
          ? (pendingRequest == null ? _coinConsent : null)
          : CoinChatConsent(
              coinAccount!.account(),
              'detailed',
              (upgrade['upgradeCost'] as num).toInt(),
              upgrade: upgrade['id'] as String,
            );
      final result = await withCoinChatConsent(
        consent,
        () => _session.ask(
          category: category,
          question: text,
          responseStyle: detected.name,
          guide: widget.guide.name,
          conversationKey: widget.guide.conversationKey,
          depth: pendingRequest != null
              ? pendingRequest.depth
              : coinWalletEnabled
              ? _depth
              : null,
          upgradeFrom: pendingRequest?.upgrade,
        ),
      );
      userJourney.event(
        'chat.answer',
        metadata: {
          'feature': 'chat',
          'outcome': result.wallet?['status'] == 'failed'
              ? 'unavailable'
              : 'success',
        },
      );
      coinWalletRevision.value++;
      if (!result.replayed && result.wallet?['status'] == 'complete') {
        unawaited(marketingAnalytics.event('chat_completed'));
        unawaited(metaMeasurement.event('chat_completed'));
      }
      if (sentRevision != _session.revision) return;
      if (upgrade != null && result.wallet?['status'] == 'complete') {
        for (final m in sentConversation.messages) {
          if (m.wallet?['id'] == upgrade['id']) m.wallet!['canUpgrade'] = false;
        }
      }
      await _session.recordGuidanceResponse(
        result,
        sentConversation,
        detected.name,
      );
    } on JyotaraApiException catch (error) {
      userJourney.event(
        'chat.answer',
        metadata: {
          'feature': 'chat',
          'outcome': 'failed',
          'error': error.deliveryUncertain ? 'network' : 'provider',
        },
      );
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

  bool _reporting = false;
  Future<void> _reportAnswer(ChatMessage message) async {
    if (_reporting) return;
    final reason = await showDialog<String>(
      context: _chatUiContext ?? context,
      builder: (dialog) => SimpleDialog(
        title: const UiText('Report answer'),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: UiText(
              'Choose a reason to send this answer and the guide name to the Jyotara team for review. No other messages or separate birth-profile fields are attached.',
            ),
          ),
          for (final entry in const {
            'harmful': 'Harmful or unsafe',
            'sexual': 'Sexual content',
            'hateful': 'Hateful or abusive',
            'misleading': 'Misleading answer',
            'privacy': 'Privacy concern',
            'other': 'Other concern',
          }.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialog, entry.key),
              child: UiText(entry.value),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialog),
            child: const UiText('Cancel'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted || _reporting) return;
    setState(() => _reporting = true);
    try {
      await _session.reportAnswer(
        answer: message.text,
        guide: widget.guide.name,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: UiText('Report sent to the Jyotara team. Thank you.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: UiText('Report could not be confirmed. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  Future<void> _endChat() async {
    if (_thinking) return;
    setState(() => _ending = true);
    try {
      final confirmed = await showDialog<bool>(
        context: _chatUiContext ?? context,
        builder: (context) => AlertDialog(
          title: const Text('End chat?'),
          content: const Text(
            'Your conversation stays saved for this profile and guide. You can read or continue it later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep chatting'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('End chat'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      _conversation.ended = true;
      _conversation.changed();
      await _session.flushStorage();
      if (!mounted) return;
      if (_session.storageError != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_session.storageError!)));
        return;
      }
      userJourney.event(
        'chat.end',
        metadata: {
          'feature': 'chat',
          'control': 'end_chat',
          'outcome': 'success',
        },
      );
      unawaited(userJourney.flush());
      int selectedRating = 0;
      final rating = await showDialog<int>(
        context: _chatUiContext ?? context,
        builder: (dialog) => StatefulBuilder(
          builder: (dialog, update) => AlertDialog(
            title: Text('${uiText(dialog, 'Rate')} ${widget.guide.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const UiText(
                  'Optional feedback saved privately on this device.',
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(
                    5,
                    (i) => Expanded(
                      child: IconButton(
                        tooltip: '${i + 1} stars',
                        onPressed: () => update(() => selectedRating = i + 1),
                        icon: Icon(
                          i < selectedRating ? Icons.star : Icons.star_outline,
                          color: gold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const UiText('Skip'),
              ),
              FilledButton(
                onPressed: selectedRating == 0
                    ? null
                    : () => Navigator.pop(dialog, selectedRating),
                child: const UiText('Submit'),
              ),
            ],
          ),
        ),
      );
      if (rating != null) {
        _conversation.rating = rating;
        _conversation.changed();
        await _session.flushStorage();
      }
      if (!mounted) return;
      setState(() => _canExit = true);
      // Let PopScope observe the confirmed end before requesting navigation.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    RemoteConfigScope.watch(context);
    if (!publicChatEnabled ||
        !remoteConfig.enabled('chat') ||
        !remoteConfig.guideEnabled(widget.guide.name)) {
      return const ChatUnavailableScreen();
    }
    return Theme(
      data: askTheme(Theme.of(context), conversation: true),
      child: Builder(
        builder: (chatContext) {
          _chatUiContext = chatContext;
          return PopScope(
            canPop: _canExit,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && mounted) {
                userJourney.event(
                  'chat.back',
                  metadata: {
                    'feature': 'chat',
                    'control': 'back',
                    'outcome': 'blocked',
                  },
                );
                FocusManager.instance.primaryFocus?.unfocus();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: UiText(
                      'Use End chat to finish your conversation.',
                    ),
                  ),
                );
              }
            },
            child: Scaffold(
              appBar: AppBar(
                key: const Key('softBronzeChatHeader'),
                toolbarHeight: MediaQuery.textScalerOf(context).scale(14) > 20
                    ? 82
                    : 64,
                centerTitle: false,
                titleSpacing: 0,
                title: Row(
                  children: [
                    _GuideAvatar(guide: widget.guide, radius: 17),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UiText(
                            widget.guide.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            ex(context, 'AI guide', 'AI வழிகாட்டி'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AskPalette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                automaticallyImplyLeading: false,
                actions: [
                  TextButton(
                    key: const Key('end-chat'),
                    onPressed: _thinking ? null : _endChat,
                    child: Text(ex(context, 'End chat', 'முடி')),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Chat options',
                    onOpened: () =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    enabled: !_thinking,
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit-birth',
                        child: UiText('Edit birth details'),
                      ),
                      if (widget.allowProfileSwitch)
                        const PopupMenuItem(
                          value: 'profile',
                          child: UiText('Change Birth Chart'),
                        ),
                      if (_conversation.history.isNotEmpty)
                        const PopupMenuItem(
                          value: 'history',
                          child: UiText('View old chats'),
                        ),
                      PopupMenuItem(
                        value: 'end',
                        enabled: !_conversation.ended,
                        child: const Text('End chat'),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit-birth') {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                BirthForm(session: _session, onboarding: true),
                          ),
                        );
                      } else if (value == 'profile') {
                        _endChat();
                      } else if (value == 'history') {
                        showDialog<void>(
                          context: chatContext,
                          builder: (dialog) => AlertDialog(
                            title: const UiText('Chat history'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: ListView(
                                shrinkWrap: true,
                                children: [
                                  for (final chat
                                      in _conversation.history.reversed) ...[
                                    const Divider(),
                                    for (final m in chat)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: Text(
                                          '${m.fromUser ? _session.nickname : widget.guide.name}: ${m.text}',
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialog),
                                child: const UiText('Close'),
                              ),
                            ],
                          ),
                        );
                      } else {
                        _endChat();
                      }
                    },
                  ),
                ],
              ),
              body: ChatWallpaper(
                child: Column(
                  children: [
                    if (MediaQuery.viewInsetsOf(context).bottom == 0)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          key: const Key('chat-settings-toggle'),
                          onPressed: _thinking
                              ? null
                              : () => setState(
                                  () => _controlsExpanded = !_controlsExpanded,
                                ),
                          icon: Icon(
                            _controlsExpanded ? Icons.expand_less : Icons.tune,
                            size: 16,
                          ),
                          label: Text(
                            _language == ChatLanguage.tamil
                                ? 'தமிழ்'
                                : _language == ChatLanguage.tanglish
                                ? 'Tanglish'
                                : 'English',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    if (_controlsExpanded &&
                        MediaQuery.viewInsetsOf(context).bottom == 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 5, 16, 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ChatLanguage>(
                            expandedInsets: EdgeInsets.zero,
                            showSelectedIcon: false,
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                    ? AskPalette.action
                                    : AskPalette.reply,
                              ),
                              foregroundColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                    ? AskPalette.onAction
                                    : AskPalette.ink,
                              ),
                            ),
                            segments: [
                              for (final option
                                  in [
                                    (ChatLanguage.english, 'English'),
                                    (ChatLanguage.tamil, 'தமிழ்'),
                                    (ChatLanguage.tanglish, 'Tanglish'),
                                  ].where(
                                    (option) => remoteConfig.languageEnabled(
                                      option.$1.name,
                                    ),
                                  ))
                                ButtonSegment(
                                  value: option.$1,
                                  label: Text(
                                    option.$2,
                                    key: ValueKey('reply-${option.$1.name}'),
                                  ),
                                  enabled: !_thinking,
                                ),
                            ],
                            selected: {_language},
                            onSelectionChanged: _thinking
                                ? null
                                : (values) => _setReplyLanguage(values.first),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        key: const Key('chatHistoryList'),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount:
                            1 +
                            _messages.length +
                            (_conversation.pending && _deliveryMessage == null
                                ? 1
                                : 0),
                        itemBuilder: (_, index) {
                          if (index == 0) {
                            return _session.facts == null
                                ? ListTile(
                                    title: const UiText(
                                      'Create your chart to start',
                                    ),
                                    subtitle: const UiText(
                                      'Create the selected profile’s chart to ask a guide.',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => BirthForm(
                                          session: _session,
                                          onboarding: true,
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          }
                          index -= 1;
                          if (index == _messages.length) {
                            return const _TypingBubble();
                          }
                          final message = _messages[index];
                          return Column(
                            key: ObjectKey(message),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _MessageBubble(
                                message: message,
                                animate: identical(message, _deliveryMessage),
                                onPart: _scrollToLatest,
                                onDelivered: () {
                                  if (mounted &&
                                      identical(message, _deliveryMessage)) {
                                    setState(() => _deliveryMessage = null);
                                    _scrollToLatest();
                                  }
                                },
                                onReport: message.fromUser
                                    ? null
                                    : () => _reportAnswer(message),
                              ),
                              if (message.wallet?['status'] == 'failed' &&
                                  index == _messages.length - 1 &&
                                  !_thinking &&
                                  !_conversation.ended)
                                TextButton(
                                  onPressed: () {
                                    final question = _messages
                                        .take(index)
                                        .where((m) => m.fromUser)
                                        .lastOrNull;
                                    if (question != null) _send(question.text);
                                  },
                                  child: Text(
                                    _language == ChatLanguage.tamil
                                        ? 'மீண்டும் முயற்சி'
                                        : _language == ChatLanguage.tanglish
                                        ? 'Meendum muyarchi'
                                        : 'Retry',
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    if (!_conversation.ended &&
                        !_thinking &&
                        !_messages.any((message) => message.fromUser) &&
                        _suggestions.isNotEmpty)
                      SizedBox(
                        height: 46,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 3,
                          ),
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (_, index) => ActionChip(
                            label: Text(_suggestions[index]),
                            onPressed: _thinking
                                ? null
                                : () => _send(_suggestions[index]),
                          ),
                        ),
                      ),
                    if (_conversation.ended)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text(
                                'Chat ended · History saved for this profile',
                              ),
                              if (_conversation.rating != null)
                                Text(
                                  'Your private rating: ${_conversation.rating}/5',
                                ),
                              FilledButton(
                                onPressed: () async {
                                  _conversation.ended = false;
                                  _conversation.changed();
                                  await _session.flushStorage();
                                },
                                child: const Text('Continue this chat'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          13,
                          12,
                          13,
                          12 + MediaQuery.paddingOf(context).bottom,
                        ),
                        decoration: const BoxDecoration(
                          color: AskPalette.conversation,
                          border: Border(
                            top: BorderSide(color: AskPalette.border),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('chatInput'),
                                focusNode: _inputFocus,
                                controller: _controller,
                                maxLength: 240,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AskPalette.ink,
                                ),
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                decoration: InputDecoration(
                                  hintText: _language == ChatLanguage.tamil
                                      ? 'உங்கள் கேள்வி…'
                                      : _language == ChatLanguage.tanglish
                                      ? 'Unga kelvi…'
                                      : 'Your question…',
                                  hintMaxLines: 1,
                                  isDense: true,
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton.filled(
                              key: const Key('sendMessage'),
                              tooltip: uiText(context, 'Send question'),
                              onPressed: _thinking ? null : _send,
                              icon: const Icon(Icons.send_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: AskPalette.action,
                                foregroundColor: AskPalette.onAction,
                                minimumSize: const Size(44, 44),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
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
              if (active.backupError != null) UiText(active.backupError!),
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
                NavamsaSection(
                  facts: facts,
                  birthTimeKnown: active.birthTimeKnown,
                ),
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
                const UiText(
                  'These periods belong to the saved calculation date. New chat answers check the current period separately.',
                ),
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
                                    ? 'Delete this session’s server chart cache, research questions and answer copies, then clear this device’s profile and history. Minimal usage and revocation records remain. External astrology conversation deletion may still be pending. Internet is required; if deletion fails, keep this app installed and retry.'
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
                              await active.clear(
                                includeServer: active.canDeleteServer,
                              );
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
                        : active.canDeleteServer
                        ? 'Delete server and device data'
                        : 'Delete device profile and history',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.person_outline_rounded,
        'Birth profile',
        'View or change your details',
      ),
      if (!coinWalletEnabled)
        (
          Icons.workspace_premium_outlined,
          'Plans & question balance',
          'Payments not enabled',
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
      (Icons.help_outline_rounded, 'About this build', 'AI astrology guidance'),
    ];
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        children: [
          const _TopBar(showAccount: false),
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
                        colors: [saffron, Color(0xFF8F452C)],
                      ),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UiText(
                          phoneAccess.authorized
                              ? 'Phone verified'
                              : 'Local test session',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          phoneAccess.authorized
                              ? '${uiText(context, 'Signed in')}${phoneAccess.mobile == null ? '' : ' · ••••••${phoneAccess.mobile!.substring(6)}'}'
                              : uiText(context, 'Not signed in'),
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
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
                  'Plans & question balance' => 'Daily limits apply to chart calculations and place searches. A failed calculation may still count toward its daily limit. Payments are not enabled; no money is deducted.',
                  'Chat history' => 'Your profile and conversations are saved in encrypted device storage. Reopen a guide to see its history. Changing or deleting the profile removes the previous history. This is not cloud backup or cross-device account recovery. Check the Chart tab for storage errors.',
                  _ => 'Jyotara offers AI astrology guidance based on traditional interpretations. Guides are automated, not human astrologers. Predictions are not guarantees. Do not use them as medical, legal or investment advice.',
                };
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: UiText(item.$2),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UiText(detail),
                          if (item.$2 == 'About this build') ...[
                            const SizedBox(height: 12),
                            SelectableText('Jyotara $appBuildLabel'),
                          ],
                        ],
                      ),
                    ),
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
                  color: BronzePalette.raised,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.$1, color: bodyInk),
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
          const PrivacyLinks(),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const UiText('Notification settings'),
            subtitle: const UiText('Manage notifications and app improvements'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Help & Support'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SupportScreen(
                  api: AccountService(
                    token: () => phoneAccess.token,
                    tester: () => testerAccess.code,
                    account: () => phoneAccess.accountId,
                  ),
                ),
              ),
            ),
          ),
          if (coinWalletEnabled)
            ListTile(
              leading: const RupeeCoinIcon(),
              title: const Text('Coin wallet'),
              subtitle: const Text('Packs, prices and coin activity'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CoinWalletScreen(api: coinAccount!),
                ),
              ),
            ),
          if (paymentQaEnabled && !coinWalletEnabled)
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Test payments'),
              subtitle: const Text('Sandbox only — no real money'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => TestPaymentScreen(
                    api: AccountService(
                      token: () => phoneAccess.token,
                      tester: () => testerAccess.code,
                      account: () => phoneAccess.accountId,
                    ),
                  ),
                ),
              ),
            ),
          if (phoneAccess.authorized)
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: const UiText('Delete account'),
              subtitle: const UiText(
                'Delete phone account, saved profiles and chats',
              ),
              onTap: () async {
                if (profileSession.calculating ||
                    profileSession.answering ||
                    phoneAccess.busy) {
                  return;
                }
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const UiText('Delete account?'),
                    content: const UiText(
                      'This removes your phone account and its saved profiles and chats from this device and our server. Minimal security records and backups remain temporarily. External service deletion may still be pending.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const UiText('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const UiText('Delete account'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                final deleted = await phoneAccess.deleteAccount();
                if (!context.mounted) return;
                if (deleted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(phoneAccess.error ?? 'Please try again.'),
                    ),
                  );
                }
              },
            ),
          const SizedBox(height: 14),
          const _DisclosureCard(),
          if (phoneAccess.authorized)
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const UiText('Sign out'),
              subtitle: const UiText(
                'Your saved profiles stay with this account',
              ),
              onTap: () async {
                if (profileSession.calculating || profileSession.answering) {
                  return;
                }
                if (!await confirmSignOut(context) || !context.mounted) return;
                await profileSession.flushStorage();
                if (profileSession.storageError != null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(profileSession.storageError!)),
                    );
                  }
                  return;
                }
                await phoneAccess.signOut();
                if (!phoneAccess.authorized) {
                  await uiLanguagePreferences.set('en');
                }
                if (!context.mounted) return;
                if (!phoneAccess.authorized) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(phoneAccess.error ?? 'Please try again.'),
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}

class BirthProfileScreen extends StatelessWidget {
  const BirthProfileScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      BirthForm(session: profileSession, onboarding: true);
}

class _TopBar extends StatefulWidget {
  const _TopBar({this.showAccount = true});
  final bool showAccount;
  final bool editorial = false;
  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  bool _opening = false;
  Future<void> _openAccount() async {
    if (_opening) return;
    _opening = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: AccountScreen()),
        ),
      );
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MainTabScope.contains(context)) return const SizedBox.shrink();
    return Row(
      children: [
        if (widget.editorial && widget.showAccount)
          IconButton(
            tooltip: uiText(context, 'Account'),
            onPressed: _openAccount,
            icon: const Icon(Icons.menu_rounded, size: 20, color: gold),
          ),
        Expanded(
          child: widget.editorial
              ? const Center(child: _EditorialBrand())
              : const _BrandLockup(compact: true),
        ),
        AnimatedBuilder(
          animation: notificationInbox,
          builder: (context, _) => IconButton(
            tooltip: uiText(context, 'Notifications'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationCenter(),
              ),
            ),
            icon: Badge(
              isLabelVisible: notificationInbox.unread > 0,
              label: Text('${notificationInbox.unread}'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        ),
        if (widget.showAccount && !widget.editorial)
          IconButton(
            tooltip: uiText(context, 'Account'),
            onPressed: _openAccount,
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
            gradient: LinearGradient(colors: [saffron, Color(0xFF974D2C)]),
          ),
          child: BrandMark(size: compact ? 34 : 44),
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

class _EditorialBrand extends StatelessWidget {
  const _EditorialBrand();
  @override
  Widget build(BuildContext context) => const Text(
    'Jyotara',
    style: TextStyle(
      fontFamily: 'JyotaraEditorial',
      fontSize: 34,
      color: bodyInk,
      letterSpacing: .3,
    ),
  );
}

class _FullGuideCard extends StatelessWidget {
  const _FullGuideCard({required this.guide, required this.onTap});
  final Guide guide;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PressFeedback(
    child: Card(
      key: ValueKey('guide-card-${guide.name}'),
      color: AskPalette.card,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: const BorderSide(color: AskPalette.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          child: Row(
            children: [
              _GuideAvatar(guide: guide, radius: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UiText(
                      guide.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.3,
                        color: AskPalette.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (remoteConfig.languageEnabled('tamil')) 'தமிழ்',
                        if (remoteConfig.languageEnabled('english')) 'English',
                        if (!remoteConfig.languageEnabled('tamil') &&
                            !remoteConfig.languageEnabled('english') &&
                            remoteConfig.languageEnabled('tanglish'))
                          'Tanglish',
                      ].join(', '),
                      maxLines: MediaQuery.textScalerOf(context).scale(12) > 18
                          ? null
                          : 1,
                      overflow: MediaQuery.textScalerOf(context).scale(12) > 18
                          ? null
                          : TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AskPalette.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // End-of-chat feedback is private device data. The app has
                    // no public rating source, so no average is implied here.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.star_outline_rounded,
                          size: 14,
                          color: AskPalette.muted,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            ex(context, 'No ratings yet', 'மதிப்பீடுகள் இல்லை'),
                            maxLines:
                                MediaQuery.textScalerOf(context).scale(12) > 18
                                ? null
                                : 1,
                            overflow:
                                MediaQuery.textScalerOf(context).scale(12) > 18
                                ? null
                                : TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              height: 1.4,
                              color: AskPalette.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: ValueKey('guide-chat-${guide.name}'),
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AskPalette.action,
                  foregroundColor: AskPalette.onAction,
                  minimumSize: const Size(60, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'JyotaraSans',
                    fontFamilyFallback: ['JyotaraTamil'],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: Text(ex(context, 'Chat', 'பேசு')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
          colors: [Colors.white.withValues(alpha: .8), saffron, gold],
        ),
      ),
      child: ClipOval(
        child: guide.portraitIndex == null
            ? Image.asset(
                guide.asset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final i = guide.portraitIndex!;
                  // Source is a 5x2 sheet, each portrait 4:5. Crop its top square,
                  // keeping the built-in name strip outside the circular avatar.
                  return Stack(
                    children: [
                      Positioned(
                        left: -(i % 5) * width,
                        top: -(i ~/ 5) * width * 1.25,
                        width: width * 5,
                        height: width * 2.5,
                        child: Image.asset(
                          guide.asset,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _DisclosureCard extends StatelessWidget {
  const _DisclosureCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: BronzePalette.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: line),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: bodyInk, size: 20),
        SizedBox(width: 11),
        Expanded(
          child: UiText(
            'Your birth details, questions and recent chat context are processed by astrology and language services. External astrology conversation deletion may still be pending after local and server deletion. Manage your saved profile from the Chart tab. Research sharing is optional.',
            style: TextStyle(color: muted, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

Future<bool> confirmSignOut(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const UiText('Sign out?'),
        content: const UiText('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const UiText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const UiText('Sign out'),
          ),
        ],
      ),
    ) ==
    true;

Future<String?> showChatDepthPicker(
  BuildContext context, {
  int? generalCoins,
  int? relationshipCoins,
}) => showDialog<String>(
  context: context,
  builder: (dialog) => AlertDialog(
    title: const UiText('Start chat'),
    content: Text(
      uiText(dialog, 'Start chat') != 'Start chat'
          ? 'பொதுவான கேள்விகளுக்கு ஒரு பதிலுக்கு ${generalCoins ?? remoteConfig.cost('generalStandard', 10)} நாணயங்கள். '
                'உறவு தொடர்பான கேள்விகளுக்கு ஒரு பதிலுக்கு ${relationshipCoins ?? remoteConfig.cost('relationshipStandard', 15)} நாணயங்கள். '
                'முழுமையான பதில்களுக்கு மட்டுமே கட்டணம்.'
          : 'General questions: ${generalCoins ?? remoteConfig.cost('generalStandard', 10)} coins per answer. '
                'Relationship questions: ${relationshipCoins ?? remoteConfig.cost('relationshipStandard', 15)} coins per answer. '
                'Only completed answers are charged.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialog),
        child: const UiText('Cancel'),
      ),
      FilledButton(
        key: const Key('start-unified-chat'),
        onPressed: () => Navigator.pop(dialog, 'standard'),
        child: const UiText('Start chat'),
      ),
    ],
  ),
);
