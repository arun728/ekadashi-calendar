import 'dart:io';
import 'services/premium_service.dart';
import 'services/play_billing_service.dart';
import 'widgets/glass_tube.dart';
import 'package:flutter/foundation.dart';
import 'widgets/glass_navigation_bar.dart';
import 'data/calendar_entry_repository.dart';
import 'widgets/app_background.dart';
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
  static const premiumRecheckInterval = Duration(minutes: 5);
  bool _premiumSessionStarted = false;

  final PageController _pageController = PageController(viewportFraction: 1.0);
  final GlobalKey<CalendarScreenState> _calendarKey = GlobalKey();
  final GlobalKey<PanchangScreenState> _panchangKey = GlobalKey();
  bool _panchangOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    _pageController.dispose();
    super.dispose();
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
    if (state == AppLifecycleState.paused) _premiumRecheck?.cancel();
    if (state == AppLifecycleState.resumed) {
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
      _handleLocation();
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
    await _handleLocation();
  }

  /// A detected place becomes the Ekadashi city unless the user chose one;
  /// without a fix the last known (or chosen) city stays, else Chennai
  /// (AppModel.handleLocation). The settings listener recalculates when the
  /// city changes.
  Future<void> _handleLocation() async {
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
    if (fix != null) await _settings?.useDetected(fix);
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
      icon: settings.isManual ? Icons.place : Icons.my_location,
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
      _loadData(shouldScrollToNext: place != _requestedPlace);
      return;
    }
    final year = _homeYearList();
    if (!_sameIds(year, _ekadashiList)) {
      setState(() {
        _ekadashiList = year;
        _currentPage = 0;
      });
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      _scrollToNextEkadashi(animate: false, includeParana: true);
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
        final index = currentUid == null
            ? -1
            : _ekadashiList.indexWhere((e) => e.occurrenceUid == currentUid);
        if (index != -1) {
          if (_pageController.hasClients) _pageController.jumpToPage(index);
          setState(() => _currentPage = index);
        } else {
          // Use a slight delay to ensure PageView is built with new data
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
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
      nowTz = tz.TZDateTime.now(location);
      today = DateTime(nowTz.year, nowTz.month, nowTz.day);
    } catch (e) {
      debugPrint('Error parsing timezone $_currentTimezone: $e');
      final now = DateTime.now();
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
    if (_isLoading) {
      _pendingDeepLink = uri;
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
    if (_searchOpen && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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

  /// Opens the search; [restore] reopens the one a result left.
  Future<void> _openSearch({SearchSession? restore}) async {
    if (!mounted || _searchOpen) return;
    if (restore == null) setState(_searchReturn.clear);
    _searchOpen = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
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
    // Another tab forgets the way back to a search.
    _searchReturn.selected(index);
    if (index == _currentIndex) {
      // Already on this tab - special actions
      if (index == 0) {
        // User explicitly tapped Home - strictly go to next upcoming (skip Parana)
        _scrollToNextEkadashi(animate: false, includeParana: false);
      } else if (index == 1) {
        _calendarKey.currentState?.resetToToday();
      }
    } else {
      // Switching tabs
      setState(() => _currentIndex = index);

      // When switching TO Home tab, scroll to upcoming Ekadashi
      if (index == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToNextEkadashi(animate: false, includeParana: true);
        });
      }
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
        icon: const Icon(Icons.home),
        label: lang.translate('home'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.calendar_month),
        label: lang.translate('calendar'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.spa_outlined),
        activeIcon: const Icon(Icons.spa),
        label: lang.translate('journey_tab'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.auto_awesome_outlined),
        activeIcon: const Icon(Icons.auto_awesome),
        label: lang.translate('search_screen_panchang'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.settings),
        label: lang.translate('settings'),
      ),
    ];
    // A search result opened this tab: the top bar's back arrow and the
    // system back reopen its results (docs/ROADMAP.md Phase 9).
    final searchBack = _searchReturn.showsBack(_currentIndex);
    // The iOS gradient behind every tab (docs/ROADMAP.md Phase 8).
    return PopScope(
      canPop: !searchBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && searchBack) _returnToSearch();
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: glass,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            leading: searchBack
                ? IconButton(
                    key: const Key('search_return'),
                    tooltip: lang.translate('search'),
                    icon: const BackButtonIcon(),
                    onPressed: _returnToSearch,
                  )
                : null,
            title: Text(lang.translate('app_title')),
            centerTitle: true,
            actions: [
              IconButton(
                key: const Key('open_global_search'),
                tooltip: lang.translate('search'),
                icon: const Icon(Icons.search),
                onPressed: _openSearch,
              ),
              const SizedBox(width: 4),
            ],
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

  Widget _buildBody(LanguageService lang, Color tealColor) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: tealColor),
            const SizedBox(height: 16),
            Text(
              lang.translate('locating'),
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(_errorMessage, style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadData(),
              style: ElevatedButton.styleFrom(backgroundColor: tealColor),
              child: Text(lang.translate('retry')),
            ),
          ],
        ),
      );
    }

    if (_currentIndex == 3) _panchangOpened = true;
    return IndexedStack(
      index: _currentIndex,
      children: [
        SafeArea(top: false, child: _buildHomeContent(lang, tealColor)),
        CalendarScreen(
          key: _calendarKey,
          repository: context.read<CalendarEntryRepository?>(),
          ekadashiList: _allEkadashis,
          currentTimezone: _currentTimezone,
        ),
        SafeArea(
          top: false,
          child: VratTrackerScreen(
            ekadashiList: _allEkadashis,
            currentTimezone: _currentTimezone,
          ),
        ),
        // Built when first opened: the Panchang calculates a year of
        // festivals, which the other tabs never need.
        if (_currentIndex == 3 || _panchangOpened)
          PanchangScreen(key: _panchangKey, ekadashiList: _allEkadashis)
        else
          const SizedBox.shrink(),
        SettingsScreen(currentTimezone: _currentTimezone),
      ],
    );
  }

  /// Home (TodayView.swift): the four menus, then one card per Ekadashi of
  /// the chosen year with arrows, opening on the current or next Ekadashi.
  Widget _buildHomeContent(LanguageService lang, Color tealColor) {
    final controls = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: HomeControls(
        locating: _isRequestingLocation,
        onLocation: _openLocationPicker,
      ),
    );
    if (_ekadashiList.isEmpty) {
      return Column(
        children: [
          controls,
          Expanded(
            child: Center(
              child: _isCalculating
                  ? Column(
                      key: const Key('home_calculating'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: tealColor),
                        const SizedBox(height: 12),
                        Text(
                          lang.translate('calculating_ekadashis'),
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    )
                  : Text(
                      lang.translate('no_ekadashi'),
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
            ),
          ),
        ],
      );
    }

    final bool isFirstPage = _currentPage == 0;
    final bool isLastPage = _currentPage >= _ekadashiList.length - 1;

    return Column(
      children: [
        controls,

        // Page indicator
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${_currentPage + 1} / ${_ekadashiList.length}',
            key: const Key('home_page_indicator'),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ),

        // Card with navigation arrows; dimmed while another city or
        // tradition is calculated.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 4,
              right: 4,
              top: 8,
              bottom: 8,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: _isCalculating ? 0.5 : 1,
                  child: Row(
                    children: [
                      // Left arrow
                      SizedBox(
                        width: 44,
                        child: IconButton(
                          onPressed: isFirstPage
                              ? null
                              : () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                          icon: const Icon(Icons.chevron_left, size: 36),
                          color: isFirstPage ? Colors.grey.shade600 : tealColor,
                          padding: EdgeInsets.zero,
                        ),
                      ),

                      // Card with PageView
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _ekadashiList.length,
                          onPageChanged: (index) {
                            if (mounted) {
                              setState(() => _currentPage = index);
                            }
                          },
                          itemBuilder: (context, index) {
                            return _buildEkadashiCard(_ekadashiList[index]);
                          },
                        ),
                      ),

                      // Right arrow
                      SizedBox(
                        width: 44,
                        child: IconButton(
                          onPressed: isLastPage
                              ? null
                              : () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                          icon: const Icon(Icons.chevron_right, size: 36),
                          color: isLastPage ? Colors.grey.shade600 : tealColor,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isCalculating)
                  CircularProgressIndicator(
                    key: const Key('home_recalculating'),
                    color: tealColor,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEkadashiCard(EkadashiDate ekadashi) {
    // Use timezone-aware "today" calculation
    DateTime today;
    try {
      final location = tz.getLocation(_getIANATimezone(_currentTimezone));
      final nowTz = tz.TZDateTime.now(location);
      today = DateTime(nowTz.year, nowTz.month, nowTz.day);
    } catch (e) {
      // Fallback to local time if timezone is invalid
      final now = DateTime.now();
      today = DateTime(now.year, now.month, now.day);
    }

    // Calculate difference based on dates only (ignoring time)
    final ekadashiDate = DateTime(
      ekadashi.date.year,
      ekadashi.date.month,
      ekadashi.date.day,
    );
    final daysUntil = ekadashiDate.difference(today).inDays;

    const tealColor = Color(0xFF00A19B);
    final lang = Provider.of<LanguageService>(context);

    String breakTime = ekadashi.fastBreakTime;
    breakTime = AppStrings.localizeClock(
      breakTime.replaceAll(RegExp(r'^[a-zA-Z]{3} \d{1,2}, '), ''),
      lang.currentLocale.languageCode,
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Days badge
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: daysUntil < 0 ? Colors.grey : tealColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          daysText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date: weekday, date, month and year, as on every tab.
                    Text(
                      AppStrings.fullDate(
                        ekadashi.date,
                        lang.currentLocale.languageCode,
                      ),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ekadashi name
                    Text(
                      ekadashi.name,
                      style: const TextStyle(
                        color: tealColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Start Fasting
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        lang.translate('start_fasting'),
                        style: const TextStyle(
                          color: tealColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppStrings.fullDate(
                          ekadashi.date,
                          lang.currentLocale.languageCode,
                        ),
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppStrings.localizeClock(
                          ekadashi.fastStartTime,
                          lang.currentLocale.languageCode,
                        ),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Break Fasting
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        lang.translate('break_fasting'),
                        style: const TextStyle(
                          color: tealColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppStrings.fullDate(
                          ekadashi.date.add(const Duration(days: 1)),
                          lang.currentLocale.languageCode,
                        ),
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        breakTime,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Divider(color: Colors.grey.shade400, height: 1),
                    const SizedBox(height: 16),

                    // Description
                    Text(
                      ekadashi.description,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 15,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons: View Details, Share and Record Vrat
            GlassOptionGroup(
              key: const Key('home_card_actions_tube'),
              optionCount: context.watch<VratTrackerService>().trackerEnabled
                  ? 3
                  : 2,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailsScreen(
                              ekadashi: ekadashi,
                              timezone: _currentTimezone,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: GlassTubeColors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      // One line beside Share and Record, scaled down on
                      // narrow screens with large text.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          lang.translate('view_details'),
                          maxLines: 1,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The free share card (no paywall).
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Tooltip(
                      message: lang.translate('share_card'),
                      child: OutlinedButton(
                        key: const Key('home_share_card'),
                        onPressed: () => openShareCard(context, ekadashi),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                        child: const Icon(
                          Icons.share,
                          color: GlassTubeColors.teal,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  Consumer<VratTrackerService>(
                    builder: (ctx, trackerService, _) {
                      if (!trackerService.trackerEnabled) {
                        return const SizedBox.shrink();
                      }
                      final record = trackerService.getRecordByUid(
                        ekadashi.occurrenceUid,
                      );
                      final isObserved =
                          record?.status == ObservanceStatus.observed;
                      final isPartial =
                          record?.status == ObservanceStatus.partial;
                      final isMissed =
                          record?.status == ObservanceStatus.missed;
                      const iconColor = GlassTubeColors.teal;

                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Tooltip(
                          message: lang.translate(
                            record == null ? 'record_vrat' : 'edit_record',
                          ),
                          child: OutlinedButton(
                            key: const Key('home_record_vrat'),
                            // Open once the fast is over: after Parana begins.
                            onPressed:
                                !VratRecording.isOpen(
                                  ekadashi,
                                  now: DateTime.now(),
                                  timezone: _currentTimezone,
                                )
                                ? null
                                : () async {
                                    final unlocks = await RecordVratDialog.show(
                                      context,
                                      ekadashi: ekadashi,
                                      allOccurrences: _allEkadashis,
                                      currentTimezone: _currentTimezone,
                                    );
                                    if (unlocks != null &&
                                        unlocks.isNotEmpty &&
                                        mounted) {
                                      for (final u in unlocks) {
                                        await AchievementUnlockDialog.show(
                                          context,
                                          u,
                                        );
                                      }
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                            child: Icon(
                              isObserved
                                  ? Icons.check_circle
                                  : (isPartial
                                        ? Icons.adjust
                                        : (isMissed
                                              ? Icons.highlight_off
                                              : Icons.edit_calendar_outlined)),
                              color: iconColor,
                              size: 20,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
