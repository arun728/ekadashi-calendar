import 'dart:io';
import 'package:clock/clock.dart';
import 'widgets/home_fasting_progress.dart';
import 'services/premium_service.dart';
import 'services/play_billing_service.dart';
import 'package:flutter/foundation.dart';
import 'widgets/glass_navigation_bar.dart';
import 'data/calendar_entry_repository.dart';
import 'widgets/app_background.dart';
import 'widgets/ios_style.dart';
import 'widgets/tab_shell.dart';
import 'data/sqflite_calendar_entry_repository.dart';
import 'models/calendar_entry.dart';
import 'services/notifications/event_reminder_service.dart';
import 'services/panchang/calculated_ekadashi.dart';
import 'services/panchang/panchang_city.dart';
import 'services/panchang/panchang_location_store.dart';
import 'services/native_widget_service.dart';
import 'services/widget_sync_manager.dart';
import 'screens/global_search_screen.dart';
import 'services/search/search_return.dart';
import 'screens/panchang_screen.dart';
import 'l10n/generated/app_localizations.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'services/ekadashi_service.dart';
import 'services/ekadashi_settings.dart';
import 'services/place_name_resolver.dart';
import 'screens/share_card_screen.dart';
import 'screens/widgets/city_picker_sheet.dart';
import 'screens/widgets/home_controls.dart';
import 'services/notification_service.dart';
import 'services/native_location_service.dart';
import 'services/native_notification_service.dart';
import 'services/native_settings_service.dart';
import 'services/theme_service.dart';
import 'l10n/app_language.dart';
import 'l10n/place_names.dart';
import 'services/language_service.dart';
import 'services/vrat_recording.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/details_screen.dart';
import 'screens/splash_screen.dart';
import 'services/vrat_tracker_service.dart';
import 'screens/vrat_tracker/vrat_tracker_screen.dart';
import 'screens/vrat_tracker/record_vrat_dialog.dart';
import 'screens/vrat_tracker/achievement_unlock_dialog.dart';
import 'models/vrat_tracker_models.dart';
import 'package:timezone/timezone.dart' as tz;
import 'widgets/app_icons.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialization moved to SplashScreen to prevent cold start freeze

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.calendarRepository});
  final CalendarEntryRepository? calendarRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<CalendarEntryRepository?>(create: (_) => calendarRepository),
        ChangeNotifierProvider(create: (_) => ThemeService()..loadTheme()),
        ChangeNotifierProvider(create: (_) => LanguageService()),
        // Home's city, tradition and year for every Ekadashi in the app.
        ChangeNotifierProvider(create: (_) => EkadashiSettings()),
        ChangeNotifierProvider(
          create: (_) => PremiumService(entitlements: PlayStoreEntitlements()),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (ctx) {
            final billing = PlayBillingService(ctx.read<PremiumService>());
            if (Platform.isAndroid) Future.microtask(billing.initialize);
            return billing;
          },
        ),
        ChangeNotifierProvider(
          create: (ctx) => VratTrackerService(
            premiumAchievements: () => ctx.read<PremiumService>().isPremium,
          ),
        ),
      ],
      child: Consumer2<ThemeService, LanguageService>(
        builder: (context, themeService, lang, child) {
          return MaterialApp(
            title: 'Ekadashi Calendar',
            locale: lang.currentLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeService.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

/// Helper to convert App Timezone codes to IANA IDs for timezone package
String _getIANATimezone(String appTimezone) {
  switch (appTimezone) {
    case 'IST':
      return 'Asia/Kolkata';
    case 'EST':
      return 'America/New_York';
    case 'PST':
      return 'America/Los_Angeles';
    case 'CST':
      return 'America/Chicago';
    case 'MST':
      return 'America/Denver';
    default:
      return appTimezone; // Hope it's already IANA or fallback
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  Uri? _pendingDeepLink;
  String? _widgetOccurrenceUid;
  int _currentIndex = 0;
  final EkadashiService _ekadashiService = EkadashiService();
  final NativeLocationService _locationService = NativeLocationService();
  String _currentLangCode = '';
  PremiumService? _premium;
  VratTrackerService? _achievementTracker;
  bool _lastPremium = false;
  void _refreshPremiumFeatures() {
    if (!mounted) return;
    final premium = _premium;
    if (premium == null) return;
    if (premium.isPremium != _lastPremium) {
      _lastPremium = premium.isPremium;
      // Festival and Panchang reminders start or stop with Premium.
      EventReminderService.instance.changed();
      if (_achievementTracker?.isInitialized == true &&
          _allEkadashis.isNotEmpty) {
        _achievementTracker!
            .refreshAchievements(_allEkadashis)
            .then((unlocked) async {
              for (final achievement in unlocked) {
                if (!mounted) return;
                await AchievementUnlockDialog.show(context, achievement);
              }
            })
            .catchError((_) {});
      }
    }
  }

  /// Every enabled year's Ekadashis at Home's city for its tradition
  /// (Calendar, Journey, Panchang, reminders, widgets and search).
  List<EkadashiDate> _allEkadashis = [];

  /// Home's cards: the year chosen on Home.
  List<EkadashiDate> _ekadashiList = [];
  bool _isLoading = true;

  /// True while a city or tradition is being calculated.
  bool _isCalculating = false;
  int _loadGeneration = 0;
  String _errorMessage = '';
  EkadashiSettings? _settings;
  Future<void>? _settingsLoad;

  /// What the latest load calculates, so a settings change reloads only
  /// when the place or tradition really changed.
  String? _requestedPlace;
  EkadashiTradition? _requestedTradition;

  /// The Ekadashi city's IANA zone: dates, countdowns and Parana.
  String _currentTimezone = EkadashiSettings.defaultCity.timeZoneId;
  bool _isRequestingLocation = false;
  int _currentPage = 0;
  bool _isResuming = false;
  bool _isPermanentDenial = false;
  bool _searchOpen = false;

  /// The way back to a search whose result opened a tab or calendar day.
  final _searchReturn = SearchReturn();

  /// Re-checks Google Play while the app stays open, so an ended
  /// subscription is noticed without leaving the app.
  Timer? _premiumRecheck;
  Timer? _homeClockTimer;
  static const premiumRecheckInterval = Duration(minutes: 5);
  bool _premiumSessionStarted = false;

  final PageController _pageController = PageController(viewportFraction: 1.0);
  final GlobalKey<CalendarScreenState> _calendarKey = GlobalKey();
  final GlobalKey<PanchangScreenState> _panchangKey = GlobalKey();
  bool _panchangOpened = false;

  /// One navigation stack per tab (iOS NavigationStack per tab): pages a
  /// tab pushes keep the tab bar; the shell's top bar gives way to theirs.
  final _tabNavigators = List.generate(5, (_) => GlobalKey<NavigatorState>());
  late final _tabObservers = List.generate(
    5,
    (_) => TabNavigatorObserver(_tabStackChanged),
  );

  /// Toolbar items of the Calendar and Panchang tabs.
  final _calendarBar = TabBarSlots();
  final _panchangBar = TabBarSlots();

  NavigatorState? get _currentTabNavigator =>
      _tabNavigators[_currentIndex].currentState;

  bool get _tabPushed => _tabObservers[_currentIndex].hasPushedPage;

  /// Rebuilds the shell in the same frame as the tab's new menu, sheet or
  /// page, so its Back handling is never a frame behind: Android 13+ closed
  /// the app on a Back in that frame. A push while building waits a frame.
  void _tabStackChanged() {
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      if (mounted) setState(() {});
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  /// Back to a tab's first page (re-tapping the tab, or a deep link).
  void _popTabToRoot(int index) =>
      _tabNavigators[index].currentState?.popUntil((route) => route.isFirst);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startHomeClock();
    NativeWidgetService().initializeDeepLinkListener(handleDeepLink);
    EventReminderService.instance.attach(_scheduleEventReminders);
    // City and country names in the app language.
    PlaceNames.load().then((_) {
      if (mounted) setState(() {});
    });
    PlaceNameResolver.instance.addListener(_namesChanged);
    PlaceNameResolver.instance.load();
    // Defer initialization to prevent freeze on process restoration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
      NativeWidgetService().getInitialDeepLink().then((uri) {
        if (uri != null && mounted) handleDeepLink(uri);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _premium ??= context.read<PremiumService?>()
      ?..addListener(_refreshPremiumFeatures);
    if (!_premiumSessionStarted && _premium != null) {
      _premiumSessionStarted = true;
      // Premium is read from Google Play's owned purchases (Android only).
      if (Platform.isAndroid) {
        Future.microtask(() => _premium?.refresh());
        _startPremiumRecheck();
      }
    }
    _achievementTracker ??= context.read<VratTrackerService?>();
    if (_settings == null) {
      final settings = context.read<EkadashiSettings?>() ?? EkadashiSettings();
      _settings = settings..addListener(_settingsChanged);
      _settingsLoad = settings.loaded ? Future.value() : settings.load();
    }
    final langService = Provider.of<LanguageService>(context);
    if (_currentLangCode != langService.currentLocale.languageCode) {
      _currentLangCode = langService.currentLocale.languageCode;
      _loadData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NativeWidgetService().clearDeepLinkListener();
    _premium?.removeListener(_refreshPremiumFeatures);
    _settings?.removeListener(_settingsChanged);
    PlaceNameResolver.instance.removeListener(_namesChanged);
    _premiumRecheck?.cancel();
    _homeClockTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startHomeClock() {
    _homeClockTimer?.cancel();
    _homeClockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _currentIndex == 0) setState(() {});
    });
  }

  void _startPremiumRecheck() {
    _premiumRecheck?.cancel();
    _premiumRecheck = Timer.periodic(
      premiumRecheckInterval,
      (_) => _premium?.refresh(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _premiumRecheck?.cancel();
      _homeClockTimer?.cancel();
    }
    if (state == AppLifecycleState.resumed) {
      _startHomeClock();
      setState(() {});
      // Pick up renewals, cancellations and refunds made in Google Play.
      if (Platform.isAndroid) {
        _premium?.refresh();
        _startPremiumRecheck();
      }
      // Wait for the first frame to render (ensure engine is attached)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Add a small safety buffer for low-end devices/heavy restoration
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted &&
              !_isResuming &&
              !_isRequestingLocation &&
              !_isLoading) {
            _isResuming = true;
            _refreshLocationIfNeeded()
                .catchError((e) {
                  debugPrint('⚠️ Resume refresh error: $e');
                })
                .whenComplete(() {
                  _isResuming = false;
                });
          }
        });
      });
    }
  }

  /// Initialize app - check settings and load data
  Future<void> _initializeApp() async {
    // The city search for the app language is built in the background, so
    // the city sheet answers the first keystroke at once (also after a
    // language change).
    final language = context.read<LanguageService>();
    void prepareCitySearch() => PanchangLocationStore.searchIndex(
      language.currentLocale.languageCode,
    ).ignore();
    prepareCitySearch();
    language.addListener(prepareCitySearch);
    final prefs = await SharedPreferences.getInstance();
    final hasLaunched = prefs.getBool('has_launched') ?? false;
    final appVersion = prefs.getString('app_version') ?? '1.0';

    // Initialize date formatting for all locales
    await initializeDateFormatting();

    if (!hasLaunched) {
      // First launch - request permissions
      await prefs.setBool('has_launched', true);
      await prefs.setString('app_version', '1.0');
      await _requestPermissionsOnFirstLaunch();
    } else {
      // Existing user - check for upgrade migration
      // Updated to target 1.0 for first release
      if (appVersion != '1.0') {
        debugPrint('📦 Migrating from v$appVersion to v1.0...');
        await prefs.setString('app_version', '1.0');

        // Enable Break Fasting Reminder by default
        if (!prefs.containsKey('remind_on_parana')) {
          await prefs.setBool('remind_on_parana', true);
          debugPrint('  ✅ Enabled Break Fasting Reminder by default');
        }
      }
      _handleLocation(atLaunch: true);
      // Ensure permissions are requested if missing (handles reinstall case)
      _ensurePermissionsOnResume();
    }
  }

  /// Check and request permissions if missing, but safely (avoid pestering)
  Future<void> _ensurePermissionsOnResume() async {
    // 1. Check current status
    final settings = NativeSettingsService();
    final status = await settings.checkAllPermissions();

    // 2. Notification Permission
    // Simple check - let the OS handle the policy (Android 13+ only asks once/twice)
    if (!status.hasNotificationPermission) {
      debugPrint('🔔 Re-requesting notification permission on resume...');
      await NotificationService().requestNotificationPermission();
    }

    // 3. Location Permission
    if (!status.hasLocationPermission) {
      // Vital check: shouldShowRequestRationale
      // If TRUE: User denied once. Do NOT ask again (don't pester).
      // If FALSE: Either "First Time" (Reinstall) OR "Permanent Denial".
      // We ask. If it's "First Time", dialog shows. If "Permanent", it auto-denies silently.
      final shouldShowRationale = await _locationService
          .shouldShowRequestRationale();

      if (!shouldShowRationale) {
        debugPrint(
          '📍 Re-requesting location permission (Reinstall or Permanent check)...',
        );
        await _requestLocationAgain();
      } else {
        debugPrint(
          '📍 Location permission denied previously (Rationale needed). Not asking automatically.',
        );
      }
    }
  }

  Future<void> _requestPermissionsOnFirstLaunch() async {
    // Show "Detecting location..." immediately
    if (mounted) setState(() => _isRequestingLocation = true);

    // Request notification permission first
    final notifGranted = await NotificationService()
        .requestNotificationPermission();
    if (notifGranted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', true);
      await prefs.setBool('remind_one_day_before', true);
      await prefs.setBool('remind_two_days_before', true);
      await prefs.setBool('remind_on_day', true);
      await prefs.setBool('remind_on_parana', true);
      debugPrint('✅ Notification preferences saved');
    }

    // Request location permission
    debugPrint('📍 Requesting location permission...');
    final locationGranted = await _locationService.requestLocationPermission();
    debugPrint('📍 Location permission result: $locationGranted');

    // Now handle location after permission is requested
    await _handleLocation(atLaunch: true);
  }

  /// A detected place becomes the Ekadashi city unless the user chose one
  /// since the app opened ([atLaunch]: the place found at launch wins, as in
  /// v1); without a fix the last known (or chosen) city stays, else Chennai
  /// (AppModel.handleLocation). The settings listener recalculates when the
  /// city changes.
  Future<void> _handleLocation({bool atLaunch = false}) async {
    if (!mounted) return;
    setState(() => _isRequestingLocation = true);
    LocationData? fix;
    try {
      fix = await _locationService.getCurrentLocation();
      if (fix == null) {
        if (await _locationService.hasLocationPermission()) {
          // A timeout or GPS issue: the last fix, if any.
          fix = await _locationService.getCachedLocation();
        }
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
    await _settingsLoad;
    if (fix != null) await _settings?.useDetected(fix, atLaunch: atLaunch);
    if (mounted) setState(() => _isRequestingLocation = false);
  }

  /// Requests the location permission again (a reinstall); a grant detects
  /// the place.
  Future<void> _requestLocationAgain() async {
    if (_isRequestingLocation) return;
    try {
      if (await _locationService.requestLocationPermission()) {
        _isPermanentDenial = false;
        await _handleLocation();
      }
    } catch (e) {
      debugPrint('Location request error: $e');
    }
  }

  /// "Use current location" in Home's city picker: detection decides again
  /// and the Panchang tab moves to the detected place too. Null when done,
  /// else the message key to show. A second refusal after Android stopped
  /// asking opens the app's settings.
  Future<String?> _useCurrentLocation() async {
    final settings = _settings!;
    var granted = await _locationService.hasLocationPermission();
    if (!granted) granted = await _locationService.requestLocationPermission();
    if (!granted) {
      if (!await _locationService.shouldShowRequestRationale()) {
        if (_isPermanentDenial) {
          await NativeSettingsService().openAppSettings();
        } else {
          _isPermanentDenial = true;
        }
      }
      return 'panchang_location_denied';
    }
    if (mounted) setState(() => _isRequestingLocation = true);
    LocationData? fix;
    try {
      fix =
          await _locationService.getCurrentLocation() ??
          await _locationService.getCachedLocation();
    } catch (_) {}
    if (mounted) setState(() => _isRequestingLocation = false);
    final city = fix == null ? null : await EkadashiSettings.cityFromFix(fix);
    if (fix == null || city == null) return 'panchang_location_unavailable';
    await settings.clearManual();
    await settings.useDetected(fix);
    await settings.savePanchangCity(settings.city);
    return null;
  }

  /// Home's location: the city search, current location, recent and popular
  /// cities (EkadashiLocationSheet on iOS).
  void _openLocationPicker() {
    final settings = _settings!;
    final language = context.read<LanguageService>().currentLocale.languageCode;
    showCityPicker(
      context,
      title: AppStrings.translate('home_location_title', language),
      footer: AppStrings.translate('home_location_footer', language),
      current: settings.city,
      icon: settings.isManual
          ? AppIcons.locationPicked
          : AppIcons.locationDetected,
      onPick: settings.chooseCity,
      onLocate: _useCurrentLocation,
    );
  }

  /// Back in the app: a new place detected while away moves the Ekadashis.
  Future<void> _refreshLocationIfNeeded() async {
    // Guard against concurrent calls
    if (_isRequestingLocation || _isLoading) {
      debugPrint('⏭️ Skipping location refresh - already in progress');
      return;
    }
    try {
      if (!await _locationService.hasLocationPermission()) return;
      final fix = await _locationService.getCurrentLocation();
      if (fix != null && mounted) await _settings?.useDetected(fix);
    } catch (e) {
      debugPrint('⚠️ _refreshLocationIfNeeded error: $e');
    }
  }

  static String _placeKey(PanchangCity city) =>
      '${city.latitude}|${city.longitude}|${city.timeZoneId}';

  /// Home's menus changed: another place or tradition is calculated (a
  /// tradition switch stays on the Ekadashi on screen); another year shows
  /// that year's cards from its next Ekadashi.
  void _settingsChanged() {
    final settings = _settings;
    if (settings == null || !settings.loaded || !mounted) return;
    final place = _placeKey(settings.city);
    if (_requestedPlace != null &&
        (place != _requestedPlace ||
            settings.tradition != _requestedTradition)) {
      _loadData(
        shouldScrollToNext:
            place != _requestedPlace && _widgetOccurrenceUid == null,
      );
      return;
    }
    final year = _homeYearList();
    if (!_sameIds(year, _ekadashiList)) {
      setState(() {
        _ekadashiList = year;
        _currentPage = 0;
      });
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      if (!_selectWidgetOccurrence()) {
        _widgetOccurrenceUid = null;
        _scrollToNextEkadashi(animate: false, includeParana: true);
      }
    } else {
      setState(() {});
    }
  }

  void _namesChanged() {
    if (mounted) setState(() {});
  }

  List<EkadashiDate> _homeYearList() {
    final year = _settings?.year;
    return year == null
        ? _allEkadashis
        : _allEkadashis.where((e) => e.date.year == year).toList();
  }

  static bool _sameIds(List<EkadashiDate> a, List<EkadashiDate> b) =>
      a.length == b.length &&
      Iterable<int>.generate(
        a.length,
      ).every((i) => a[i].occurrenceUid == b[i].occurrenceUid);

  /// Loads the Ekadashis of every enabled year at Home's city for its
  /// tradition in the app language, keeping the card on screen unless
  /// [shouldScrollToNext]. A place or tradition not calculated yet is
  /// calculated off the UI thread (then cached on the phone) while the
  /// cards dim (AppModel.reload).
  Future<void> _loadData({bool shouldScrollToNext = false}) async {
    if (!mounted) return;
    await _settingsLoad;
    final settings = _settings;
    if (!mounted || settings == null) return;
    final generation = ++_loadGeneration;
    final city = settings.city, tradition = settings.tradition;
    final years = settings.years;
    _requestedPlace = _placeKey(city);
    _requestedTradition = tradition;

    setState(() {
      _isCalculating = !_ekadashiService.isScheduleCached(
        city,
        tradition,
        years,
      );
      _errorMessage = '';
    });

    try {
      final lang = _currentLangCode.isEmpty ? 'en' : _currentLangCode;
      final ekadashis = await _ekadashiService.engineEkadashis(
        city: city,
        tradition: tradition,
        languageCode: lang,
        years: years,
      );
      if (!mounted || generation != _loadGeneration) return;

      // The Ekadashi on screen, to stay on it.
      final shown = _ekadashiList;
      final currentUid = !shouldScrollToNext && _currentPage < shown.length
          ? shown[_currentPage].occurrenceUid
          : null;

      setState(() {
        _allEkadashis = ekadashis;
        _ekadashiList = _homeYearList();
        _currentTimezone = city.timeZoneId;
        _isLoading = false;
        _isCalculating = false;
      });

      // Initialize Vrat Tracker with loaded occurrences
      Provider.of<VratTrackerService>(
        context,
        listen: false,
      ).init(occurrences: ekadashis);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_selectWidgetOccurrence()) return;
        final index = currentUid == null
            ? -1
            : _ekadashiList.indexWhere((e) => e.occurrenceUid == currentUid);
        if (index != -1) {
          if (_pageController.hasClients) _pageController.jumpToPage(index);
          setState(() => _currentPage = index);
        } else {
          // Use a slight delay to ensure PageView is built with new data
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && !_selectWidgetOccurrence()) {
              _scrollToNextEkadashi(animate: false, includeParana: true);
            }
          });
        }
      });

      // Schedule notifications
      _scheduleNotifications();
      _syncSearchAndWidgets();
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _isLoading = false;
          _isCalculating = false;
          _errorMessage = context.read<LanguageService>().translate(
            'failed_load',
          );
        });
      }
    }
  }

  /// Scroll to next upcoming Ekadashi
  /// [includeParana] - if true, will scroll to a "Passed" Ekadashi if the Parana time is still active.
  /// If false (e.g. user manually taps Home), it skips to the strictly next upcoming one.
  void _scrollToNextEkadashi({
    bool animate = true,
    int retryCount = 0,
    bool includeParana = true,
  }) {
    if (_ekadashiList.isEmpty) return;

    if (!_pageController.hasClients) {
      if (retryCount < 50) {
        // Increased to 5s for slow emulators
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _scrollToNextEkadashi(
              animate: animate,
              retryCount: retryCount + 1,
              includeParana: includeParana,
            );
          }
        });
      }
      return;
    }

    // Use timezone-aware "today" calculation - MUST MATCH _buildEkadashiCard LOGIC EXACTLY
    DateTime today;
    tz.TZDateTime? nowTz;

    try {
      final location = tz.getLocation(_getIANATimezone(_currentTimezone));
      nowTz = tz.TZDateTime.from(clock.now(), location);
      today = DateTime(nowTz.year, nowTz.month, nowTz.day);
    } catch (e) {
      debugPrint('Error parsing timezone $_currentTimezone: $e');
      final now = clock.now();
      today = DateTime(now.year, now.month, now.day);
    }

    int indexToScroll = 0;
    bool found = false;

    for (int i = 0; i < _ekadashiList.length; i++) {
      final ekadashi = _ekadashiList[i];

      // Calculate difference based on dates only (ignoring time)
      // This MUST match the logic in _buildEkadashiCard to ensure consistency
      final ekadashiDate = DateTime(
        ekadashi.date.year,
        ekadashi.date.month,
        ekadashi.date.day,
      );
      final daysUntil = ekadashiDate.difference(today).inDays;

      bool isParanaActive = false;

      // Check Parana logic if requested and we have current time (nowTz)
      if (includeParana &&
          daysUntil < 0 &&
          nowTz != null &&
          ekadashi.paranaEndIso.isNotEmpty) {
        try {
          // Parse paranaEndIso (e.g. "2026-02-14T08:52:00+05:30")
          // We need to parse it carefully to compare with nowTz
          final paranaEnd = tz.TZDateTime.parse(
            tz.getLocation(_getIANATimezone(_currentTimezone)),
            ekadashi.paranaEndIso,
          );

          if (nowTz.isBefore(paranaEnd)) {
            // Parana is still active
            isParanaActive = true;
          }
        } catch (e) {
          debugPrint('Error checking parana active: $e');
        }
      }

      // If daysUntil >= 0, it means Today (0) or Future (>0) - show it!
      // OR if Parana is still active for a passed Ekadashi
      if (daysUntil >= 0 || isParanaActive) {
        indexToScroll = i;
        found = true;
        break;
      }
    }

    // Safety check: If list is not empty but nothing found (rare end-of-year edge case)
    // stay at last index.
    if (!found && _ekadashiList.isNotEmpty) {
      indexToScroll = _ekadashiList.length - 1;
    }

    // Fix for Race Condition: Give the PageView a moment to verify layout before jumping
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && _pageController.hasClients) {
        if (animate) {
          _pageController.animateToPage(
            indexToScroll,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        } else {
          _pageController.jumpToPage(indexToScroll);
        }

        if (mounted) {
          setState(() => _currentPage = indexToScroll);
        }
      }
    });
  }

  void handleDeepLink(Uri uri) {
    if (!mounted || uri.scheme != 'ekadashi') return;
    if (_isLoading || _isCalculating) {
      _pendingDeepLink = uri;
      return;
    }
    if (uri.host == 'ekadashi') {
      final uid = uri.queryParameters['uid'];
      final occurrence = _allEkadashis
          .where((e) => e.occurrenceUid == uid)
          .firstOrNull;
      if (occurrence == null) return;
      _widgetOccurrenceUid = uid;
      _searchReturn.clear();
      Navigator.of(context).popUntil((route) => route.isFirst);
      _popTabToRoot(_currentIndex);
      _popTabToRoot(0);
      _settings?.setYear(occurrence.date.year);
      setState(() {
        _currentIndex = 0;
        _ekadashiList = _homeYearList();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectWidgetOccurrence();
      });
      return;
    }
    if (uri.host == 'search') {
      _openSearch();
      return;
    }
    final tab = {
      'dashboard': 0,
      'today': 0,
      'parana': 0,
      'calendar': 1,
      'vrat': 2,
      'panchang': 3,
      // PR #12's More tab now lives inside Panchang.
      'more': 3,
      'settings': 4,
    }[uri.host];
    if (tab == null) return;
    // A deep link is not a search result.
    _searchReturn.clear();
    // Sheets, the paywall and the search close first, and the target tab
    // shows its first page, so the link never lands under another page.
    Navigator.of(context).popUntil((route) => route.isFirst);
    _popTabToRoot(tab);
    _popTabToRoot(_currentIndex);
    setState(() => _currentIndex = tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (tab == 0) _scrollToNextEkadashi(animate: false, includeParana: true);
      final date = DateTime.tryParse(uri.queryParameters['date'] ?? '');
      if (tab == 1 && date != null) _calendarKey.currentState?.selectDate(date);
      // Event reminders open their day in Panchang.
      if (tab == 3 && date != null) _panchangKey.currentState?.showDate(date);
    });
  }

  bool _selectWidgetOccurrence() {
    final uid = _widgetOccurrenceUid;
    if (uid == null) return false;
    final index = _ekadashiList.indexWhere((e) => e.occurrenceUid == uid);
    if (index < 0) return false;
    if (_pageController.hasClients) _pageController.jumpToPage(index);
    setState(() => _currentPage = index);
    return true;
  }

  /// Opens the search; [restore] reopens the one a result left.
  Future<void> _openSearch({SearchSession? restore}) async {
    if (!mounted || _searchOpen) return;
    if (restore == null) setState(_searchReturn.clear);
    _searchOpen = true;
    try {
      // A sheet with its own navigation, as on iOS: results open inside it.
      await showAppSheet<void>(
        context,
        nested: true,
        builder: (_) => GlobalSearchScreen(
          ekadashiList: _allEkadashis,
          ekadashisFor: (code) => _settings!.cachedEkadashis(code),
          currentTimezone: _currentTimezone,
          availableYears: _settings!.years,
          initialSession: restore,
          onOpenTab: (tab, session) {
            if (!mounted) return;
            setState(() {
              _currentIndex = tab;
              _searchReturn.opened(tab, session);
            });
          },
          onOpenCalendar: (day, session) {
            if (!mounted) return;
            setState(() {
              _currentIndex = 1;
              _searchReturn.opened(1, session);
            });
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _calendarKey.currentState?.selectDate(day),
            );
          },
        ),
      );
    } finally {
      _searchOpen = false;
    }
  }

  Future<void> _syncSearchAndWidgets() async {
    if (!mounted || _allEkadashis.isEmpty) return;
    final lang = context.read<LanguageService>();
    final settings = _settings!;
    await WidgetSyncManager().syncWidgetData(
      ekadashiList: _allEkadashis,
      timezone: _currentTimezone,
      locationName: PlaceNameResolver.instance.city(
        settings.city,
        lang.currentLocale.languageCode,
      ),
      languageService: lang,
      tradition: settings.tradition.name,
    );
    final pending = _pendingDeepLink;
    _pendingDeepLink = null;
    if (pending != null && mounted) handleDeepLink(pending);
  }

  /// Back from a screen a search result opened: the same search again.
  void _returnToSearch() {
    final session = _searchReturn.goBack();
    setState(() {});
    if (session != null) _openSearch(restore: session);
  }

  /// Handle bottom navigation taps
  void _onBottomNavTapped(int index) {
    if (index == 0) _widgetOccurrenceUid = null;
    // Another tab forgets the way back to a search.
    _searchReturn.selected(index);
    if (index == _currentIndex) {
      // Re-tapping a tab first returns to its first page, as on iOS.
      if (_tabPushed) {
        _popTabToRoot(index);
        return;
      }
      // Already on this tab - special actions
      if (index == 0) {
        // User explicitly tapped Home - strictly go to next upcoming (skip Parana)
        _scrollToNextEkadashi(animate: false, includeParana: false);
      } else if (index == 1) {
        _calendarKey.currentState?.resetToToday();
      }
    } else {
      // Switching tabs keeps each tab where it was (Home keeps its card),
      // as on iOS.
      setState(() => _currentIndex = index);
    }
  }

  /// Plans the festival, Panchang and calendar reminders (docs/ROADMAP.md
  /// Phase 7) with the current Premium, language, Panchang location and
  /// entries; clears them while notifications are off.
  Future<void> _scheduleEventReminders() async {
    final service = EventReminderService.instance;
    final settings = await service.load();
    var enabled = false;
    try {
      final native = NativeSettingsService();
      enabled =
          (await native.getNotificationSettings()).enabled &&
          (await native.checkAllPermissions()).hasNotificationPermission;
    } catch (e) {
      debugPrint('Event reminders: notification state unavailable: $e');
    }
    if (!mounted) return;
    final language = context.read<LanguageService>().currentLocale.languageCode;
    final repository = context.read<CalendarEntryRepository?>();
    final city = await PanchangLocationStore().load() ?? PanchangCity.newDelhi;
    var entries = const <CalendarEntry>[];
    if (enabled && settings.reminders.any((r) => r.target.source != null)) {
      try {
        final repo = repository ?? SqfliteCalendarEntryRepository();
        await repo.init();
        entries = await repo.getAll();
      } catch (e) {
        debugPrint('Event reminders: entries unavailable: $e');
      }
    }
    await service.schedule(
      enabled: enabled,
      premium: _premium?.isPremium ?? false,
      language: language,
      city: city,
      entries: entries,
    );
  }

  /// Schedule notifications for all Ekadashis
  Future<void> _scheduleNotifications() async {
    _scheduleEventReminders();
    // The channel follows the app language, even while reminders are off.
    NativeNotificationService().localizeChannel(
      context.read<LanguageService>().localizedStrings,
    );
    if (_allEkadashis.isEmpty) return;

    final settingsService = NativeSettingsService();
    final notificationSettings = await settingsService
        .getNotificationSettings();
    if (!notificationSettings.enabled) {
      await NativeNotificationService().cancelAllNotifications();
      await NotificationService().cancelAll();
      return;
    }

    // Check system notification permission before scheduling
    try {
      final status = await NativeSettingsService().checkAllPermissions();
      if (!status.hasNotificationPermission) {
        debugPrint('⏭️ Skipping scheduling - System notifications disabled');
        await NativeNotificationService().cancelAllNotifications();
        await NotificationService().cancelAll();
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to check system notification permission: $e');
      // Continue with scheduling attempt on error
    }

    if (!mounted) return;
    final lang = Provider.of<LanguageService>(context, listen: false);
    final texts = lang.localizedStrings;

    // Use native notification service
    try {
      final nativeNotifService = NativeNotificationService();
      final ekadashiData = _allEkadashis
          .map(
            (e) => EkadashiNotificationData(
              id: e.id,
              occurrenceUid: e.occurrenceUid,
              calendarYear: e.date.year,
              name: e.name,
              fastingStartTime: e.fastingStartIso,
              paranaStartTime: e.paranaStartIso,
            ),
          )
          .toList();

      await nativeNotifService.scheduleAllNotifications(
        ekadashis: ekadashiData,
        texts: texts,
      );
    } catch (e) {
      // Fallback to old notification service
      debugPrint('Native notifications failed, using fallback: $e');
      final remind1Day = notificationSettings.remind1Day;
      final remind2Days = notificationSettings.remind2Days;
      final remindOnDay = notificationSettings.remindOnStart;

      await NotificationService().scheduleAllNotifications(
        _allEkadashis,
        remind1Day,
        remind2Days,
        remindOnDay,
        texts,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    const tealColor = Color(0xFF00A19B);

    final glass = defaultTargetPlatform == TargetPlatform.android;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final items = [
      BottomNavigationBarItem(
        icon: const Icon(AppIcons.tabHome),
        label: lang.translate('home'),
      ),
      // The iOS tab symbols (AppIcons): calendar, rosette and sparkles.
      BottomNavigationBarItem(
        icon: const Icon(AppIcons.tabCalendar),
        label: lang.translate('calendar'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(AppIcons.tabJourney),
        label: lang.translate('journey_tab'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(AppIcons.tabPanchang),
        label: lang.translate('search_screen_panchang'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(AppIcons.tabSettings),
        label: lang.translate('settings'),
      ),
    ];
    // A search result opened this tab: the top bar's "Search" back button
    // and the system back reopen its results (docs/ROADMAP.md Phase 9).
    final searchBack = _searchReturn.showsBack(_currentIndex);
    // A page pushed inside the tab brings its own top bar, as on iOS.
    final tabPushed = !_isLoading && _errorMessage.isEmpty && _tabPushed;
    // System Back also closes popup overlays in the active tab navigator.
    final tabCanPop = _currentTabNavigator?.canPop() ?? false;
    final slots = switch (_currentIndex) {
      1 => _calendarBar,
      3 => _panchangBar,
      _ => null,
    };
    // The iOS gradient behind every tab (docs/ROADMAP.md Phase 8).
    return PopScope(
      canPop: !searchBack && !tabCanPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (tabCanPop) {
          _currentTabNavigator?.maybePop();
        } else if (searchBack) {
          _returnToSearch();
        }
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: glass,
          appBar: tabPushed
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(
                    kToolbarHeight + ShellTopBar.topGap,
                  ),
                  child: ListenableBuilder(
                    listenable: slots ?? const AlwaysStoppedAnimation(0),
                    builder: (context, _) =>
                        _topBar(context, lang, searchBack, slots),
                  ),
                ),
          body: _buildBody(lang, tealColor),
          bottomNavigationBar: glass
              ? (keyboardOpen
                    ? null
                    : GlassNavigationBar(
                        items: items,
                        currentIndex: _currentIndex,
                        onTap: _onBottomNavTapped,
                      ))
              : BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _currentIndex,
                  onTap: _onBottomNavTapped,
                  selectedItemColor: tealColor,
                  items: items,
                ),
        ),
      ),
    );
  }

  /// The iOS inline navigation bar: "‹ Search" when a search result opened
  /// the tab, the tab's leading items (Today), the centred title, the
  /// tab's actions and the search button.
  PreferredSizeWidget _topBar(
    BuildContext context,
    LanguageService lang,
    bool searchBack,
    TabBarSlots? slots,
  ) {
    final tabLeading = slots?.leading(context);
    final leading = [
      if (searchBack)
        TextButton.icon(
          key: const Key('search_return'),
          onPressed: _returnToSearch,
          style: TextButton.styleFrom(
            foregroundColor: IosColors.teal,
            padding: const EdgeInsets.only(left: 4, right: 8),
            minimumSize: const Size(44, 44),
          ),
          icon: const Icon(AppIcons.back, size: 20),
          label: Text(
            lang.translate('search'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: IosText.body),
          ),
        ),
      ?tabLeading,
    ];
    // The iPhone top bar: Today and "‹ Search" in a glass capsule on the
    // left, search and the tab's actions in one on the right.
    return ShellTopBar(
      title: lang.translate('app_title'),
      searchTooltip: lang.translate('search'),
      onSearch: _openSearch,
      leading: leading,
      actions: slots?.actions(context) ?? const [],
    );
  }

  Widget _buildBody(LanguageService lang, Color tealColor) {
    // Loading and error states as iOS RootView: a spinner with
    // "Locating...", or the unavailable view with a prominent Try again.
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: tealColor),
            const SizedBox(height: 16),
            Text(
              lang.translate('locating'),
              style: TextStyle(
                fontSize: IosText.body,
                color: IosColors.secondary(context),
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return UnavailableView(
        icon: AppIcons.error,
        title: _errorMessage,
        action: FilledButton(
          onPressed: () => _loadData(),
          style: IosButtons.prominent(),
          child: Text(lang.translate('retry'), style: IosButtons.label),
        ),
      );
    }

    if (_currentIndex == 3) _panchangOpened = true;
    // Each tab is a navigation stack whose first page is built here.
    Widget tabRoot(int index) => switch (index) {
      0 => SafeArea(top: false, child: _buildHomeContent(lang, tealColor)),
      1 => CalendarScreen(
        key: _calendarKey,
        repository: context.read<CalendarEntryRepository?>(),
        ekadashiList: _allEkadashis,
        currentTimezone: _currentTimezone,
        barSlots: _calendarBar,
      ),
      2 => SafeArea(
        top: false,
        child: VratTrackerScreen(
          ekadashiList: _allEkadashis,
          currentTimezone: _currentTimezone,
        ),
      ),
      // Built when first opened: the Panchang calculates a year of
      // festivals, which the other tabs never need.
      3 =>
        _currentIndex == 3 || _panchangOpened
            ? PanchangScreen(
                key: _panchangKey,
                ekadashiList: _allEkadashis,
                barSlots: _panchangBar,
              )
            : const SizedBox.shrink(),
      _ => SettingsScreen(currentTimezone: _currentTimezone),
    };
    return TabContentScope(
      build: tabRoot,
      child: IndexedStack(
        index: _currentIndex,
        children: [
          for (var i = 0; i < 5; i++)
            TabNavigator(
              index: i,
              navigatorKey: _tabNavigators[i],
              observer: _tabObservers[i],
            ),
        ],
      ),
    );
  }

  /// The Home header as iOS HomeHeader: location and language in one glass
  /// tube, side by side when they fit, stacked otherwise (ViewThatFits).
  /// Home's four menus in a 2×2 grid (HomeControls in TodayView.swift).
  Widget _buildHomeHeader(LanguageService lang, Color tealColor) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
    child: HomeControls(
      locating: _isRequestingLocation,
      onLocation: _openLocationPicker,
    ),
  );

  Widget _buildHomeContent(LanguageService lang, Color tealColor) {
    if (_ekadashiList.isEmpty) {
      // iOS keeps the header above ContentUnavailableView, or the progress
      // view while another city or tradition is calculated.
      return Column(
        children: [
          _buildHomeHeader(lang, tealColor),
          Expanded(
            child: _isCalculating
                ? Center(
                    child: Column(
                      key: const Key('home_calculating'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: IosColors.teal),
                        const SizedBox(height: 12),
                        Text(
                          lang.translate('calculating_ekadashis'),
                          style: TextStyle(
                            fontSize: IosText.subheadline,
                            color: IosColors.secondary(context),
                          ),
                        ),
                      ],
                    ),
                  )
                : UnavailableView(
                    key: const Key('home_empty'),
                    icon: AppIcons.noEkadashi,
                    title: lang.translate('no_ekadashi'),
                  ),
          ),
        ],
      );
    }

    final bool isFirstPage = _currentPage == 0;
    final bool isLastPage = _currentPage >= _ekadashiList.length - 1;

    return Column(
      children: [
        _buildHomeHeader(lang, tealColor),

        // Page indicator
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${_currentPage + 1} / ${_ekadashiList.length}',
            key: const Key('home_page_indicator'),
            style: TextStyle(
              fontSize: IosText.footnote,
              color: IosColors.secondary(context),
            ),
          ),
        ),

        // Card with navigation arrows; dimmed while another city or
        // tradition is calculated.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: _isCalculating ? 0.5 : 1,
                  child: Row(
                    children: [
                      _homeArrow(
                        key: const Key('home_previous'),
                        icon: AppIcons.previous,
                        target: _currentPage - 1,
                        enabled: !isFirstPage,
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _ekadashiList.length,
                          onPageChanged: (index) {
                            if (mounted) {
                              if (_widgetOccurrenceUid != null &&
                                  _ekadashiList[index].occurrenceUid !=
                                      _widgetOccurrenceUid) {
                                _widgetOccurrenceUid = null;
                              }
                              setState(() => _currentPage = index);
                            }
                          },
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.all(4),
                            child: _buildEkadashiCard(_ekadashiList[index]),
                          ),
                        ),
                      ),
                      _homeArrow(
                        key: const Key('home_next'),
                        icon: AppIcons.next,
                        target: _currentPage + 1,
                        enabled: !isLastPage,
                        onPressed: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isCalculating)
                  const CircularProgressIndicator(
                    key: Key('home_recalculating'),
                    color: IosColors.teal,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// An arrow to the card at [target] (iOS: 28 pt semibold chevron in a
  /// 40 x 60 frame), read out as that Ekadashi's name.
  Widget _homeArrow({
    required Key key,
    required IconData icon,
    required int target,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    final name = enabled ? _ekadashiList[target].name : '';
    return SizedBox(
      width: 40,
      height: 60,
      child: IconButton(
        key: key,
        onPressed: enabled ? onPressed : null,
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          size: 26,
          weight: 600,
          semanticLabel: name,
          color: enabled ? IosColors.teal : IosColors.gray(context),
        ),
      ),
    );
  }

  /// One Ekadashi as the iOS EkadashiCard: a glass panel (radius 24) with
  /// the countdown, dates, fast and Parana times, the description, View
  /// Details (prominent) and the Vrat record button (glass).
  Widget _buildEkadashiCard(EkadashiDate ekadashi) {
    // Use timezone-aware "today" calculation
    DateTime today;
    try {
      final location = tz.getLocation(_getIANATimezone(_currentTimezone));
      final nowTz = tz.TZDateTime.from(clock.now(), location);
      today = DateTime(nowTz.year, nowTz.month, nowTz.day);
    } catch (e) {
      // Fallback to local time if timezone is invalid
      final now = clock.now();
      today = DateTime(now.year, now.month, now.day);
    }

    // Calculate difference based on dates only (ignoring time)
    final ekadashiDate = DateTime(
      ekadashi.date.year,
      ekadashi.date.month,
      ekadashi.date.day,
    );
    final daysUntil = ekadashiDate.difference(today).inDays;
    final remaining = HomeFastingProgress.remaining(
      ekadashi,
      clock.now(),
      _getIANATimezone(_currentTimezone),
    );

    const tealColor = IosColors.teal;
    final lang = Provider.of<LanguageService>(context);
    final code = lang.currentLocale.languageCode;

    final breakTime = AppStrings.localizeClock(
      ekadashi.fastBreakTime.replaceAll(RegExp(r'^[a-zA-Z]{3} \d{1,2}, '), ''),
      code,
    );

    String daysText;
    if (daysUntil == 0) {
      daysText = lang.translate('today');
    } else if (daysUntil == 1) {
      daysText = lang.translate('tomorrow');
    } else if (daysUntil < 0) {
      daysText = lang.translate('passed');
    } else {
      daysText = lang.translateWithArgs('in_days', [daysUntil.toString()]);
    }

    Widget timing(String title, DateTime date, String time) => SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: tealColor,
              fontWeight: FontWeight.bold,
              fontSize: IosText.callout,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppStrings.fullDate(date, code),
            style: TextStyle(
              fontSize: IosText.subheadline,
              color: IosColors.secondary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: TextStyle(
              fontSize: IosText.title3,
              fontWeight: FontWeight.w600,
              color: IosColors.primary(context),
            ),
          ),
        ],
      ),
    );

    final tracker = context.watch<VratTrackerService>();
    return GlassPanel(
      key: const Key('home_ekadashi_card'),
      radius: 24,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Reserve a separate header lane for the ring and badge.
                  Row(
                    children: [
                      if (remaining != null)
                        HomeFastingProgress(
                          key: const Key('home_fasting_progress'),
                          fraction: remaining,
                          language: code,
                        ),
                      const Spacer(),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: ShapeDecoration(
                            color: daysUntil < 0
                                ? IosColors.gray(context)
                                : tealColor,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            daysText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: IosText.footnote,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Date: weekday, date, month and year, as on every tab.
                  Text(
                    AppStrings.fullDate(ekadashi.date, code),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: IosText.title2,
                      fontWeight: FontWeight.w300,
                      color: IosColors.primary(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ekadashi.name,
                    style: const TextStyle(
                      color: tealColor,
                      fontSize: IosText.title,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  timing(
                    lang.translate('start_fasting'),
                    ekadashi.date,
                    AppStrings.localizeClock(ekadashi.fastStartTime, code),
                  ),
                  const SizedBox(height: 16),
                  timing(
                    lang.translate('break_fasting'),
                    ekadashi.date.add(const Duration(days: 1)),
                    breakTime,
                  ),
                  Divider(height: 33, color: IosColors.separator(context)),
                  Text(
                    ekadashi.description,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: IosText.callout,
                      color: IosColors.primary(context).withValues(alpha: 0.8),
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // View Details (prominent teal capsule) and the Vrat record button
          // (glass capsule), as the iOS GlassGroup.
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('view_details'),
                  onPressed: () => _openDetails(ekadashi),
                  style: IosButtons.prominent(vertical: 12).copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                    fixedSize: const WidgetStatePropertyAll(
                      Size.fromHeight(48),
                    ),
                  ),
                  child: Text(
                    lang.translate('view_details'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: IosText.callout,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _homeShareButton(ekadashi, lang),
              if (tracker.trackerEnabled) ...[
                const SizedBox(width: 8),
                _homeRecordButton(ekadashi, tracker, lang),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// The free share card (no paywall), a round glass button like Record.
  Widget _homeShareButton(EkadashiDate ekadashi, LanguageService lang) =>
      Tooltip(
        message: lang.translate('share_card'),
        child: OutlinedButton(
          key: const Key('home_share_card'),
          onPressed: () => openShareCard(context, ekadashi),
          style: IosButtons.glass(context).copyWith(
            shape: const WidgetStatePropertyAll(CircleBorder()),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            fixedSize: const WidgetStatePropertyAll(Size.square(48)),
            minimumSize: const WidgetStatePropertyAll(Size.square(48)),
            backgroundColor: WidgetStatePropertyAll(
              IosColors.teal.withValues(alpha: .10),
            ),
            side: const WidgetStatePropertyAll(BorderSide.none),
          ),
          child: const Icon(AppIcons.share, color: IosColors.teal),
        ),
      );

  /// Ekadashi details are pushed inside the Home tab, so the tab bar stays.
  void _openDetails(EkadashiDate ekadashi) {
    _tabNavigators[0].currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DetailsScreen(ekadashi: ekadashi, timezone: _currentTimezone),
      ),
    );
  }

  /// The card's Vrat button (iOS VratStatusStyle.cardSymbol), dimmed until
  /// Parana begins.
  Widget _homeRecordButton(
    EkadashiDate ekadashi,
    VratTrackerService tracker,
    LanguageService lang,
  ) {
    final record = tracker.getRecordByUid(ekadashi.occurrenceUid);
    final open =
        record != null ||
        VratRecording.isOpen(
          ekadashi,
          now: clock.now(),
          timezone: _currentTimezone,
        );
    final color = open ? IosColors.teal : IosColors.tertiary(context);
    final Widget icon = switch (record?.status) {
      ObservanceStatus.observed => Icon(AppIcons.cardObserved, color: color),
      ObservanceStatus.partial => Icon(AppIcons.statusPartial, color: color),
      ObservanceStatus.missed => Icon(AppIcons.statusMissed, color: color),
      _ => Icon(AppIcons.cardUnrecorded, color: color),
    };
    return OutlinedButton(
      key: const Key('home_record_vrat'),
      onPressed: () async {
        if (!open) {
          showToast(context, lang.translate('journey_record_after_parana'));
          return;
        }
        final unlocks = await RecordVratDialog.show(
          context,
          ekadashi: ekadashi,
          allOccurrences: _allEkadashis,
          currentTimezone: _currentTimezone,
        );
        if (unlocks != null && unlocks.isNotEmpty && mounted) {
          for (final u in unlocks) {
            await AchievementUnlockDialog.show(context, u);
          }
        }
      },
      // A round glass button, neutral grey while recording is closed.
      style: IosButtons.glass(context).copyWith(
        shape: const WidgetStatePropertyAll(CircleBorder()),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        fixedSize: const WidgetStatePropertyAll(Size.square(48)),
        minimumSize: const WidgetStatePropertyAll(Size.square(48)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => !open
              ? IosColors.gray(context).withValues(alpha: .18)
              : IosColors.teal.withValues(alpha: .10),
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: (!open ? IosColors.gray(context) : IosColors.teal)
                .withValues(alpha: .28),
            width: .7,
          ),
        ),
      ),
      child: Semantics(
        label: lang.translate(record == null ? 'record_vrat' : 'edit_record'),
        hint: open ? null : lang.translate('journey_record_after_parana'),
        child: SizedBox(height: 24, child: Center(child: icon)),
      ),
    );
  }
}
