import 'dart:io';
import 'services/premium_service.dart';
import 'services/play_billing_service.dart';
import 'widgets/glass_tube.dart';
import 'package:flutter/foundation.dart';
import 'widgets/glass_navigation_bar.dart';
import 'data/calendar_entry_repository.dart';
import 'widgets/app_background.dart';
import 'widgets/ios_style.dart';
import 'widgets/tab_shell.dart';
import 'data/sqflite_calendar_entry_repository.dart';
import 'models/calendar_entry.dart';
import 'services/notifications/event_reminder_service.dart';
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
          _ekadashiList.isNotEmpty) {
        _achievementTracker!
            .refreshAchievements(_ekadashiList)
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

  List<EkadashiDate> _ekadashiList = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _locationText = '';
  (double, double)? _locationCoords;

  /// Place names from the phone's geocoder, by "language|English name".
  final _nativeCityNames = <String, String?>{};
  String _currentTimezone = 'IST';
  bool _locationDenied = false;
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

  bool get _tabPushed => _currentTabNavigator?.canPop() ?? false;

  void _tabStackChanged() {
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
    NativeWidgetService().initializeDeepLinkListener(handleDeepLink);
    EventReminderService.instance.attach(_scheduleEventReminders);
    // City and country names in the app language.
    PlaceNames.load().then((_) {
      if (mounted) setState(() {});
    });
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

    // Load saved timezone
    _currentTimezone = await _locationService.getCurrentTimezone();

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
    if (mounted) {
      setState(() {
        _isRequestingLocation = true;
        _locationDenied = false;
        _locationText = '';
      });
    }

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

    if (mounted) {
      setState(() => _isRequestingLocation = false);
    }

    // Now handle location after permission is requested
    await _handleLocation();
  }

  /// Handle location detection using native service
  Future<void> _handleLocation() async {
    if (!mounted) return;

    setState(() {
      _locationText = '';
      _locationDenied = false;
      _isRequestingLocation = true; // Show spinner while getting location
    });

    try {
      // Try to get current location using native service
      final location = await _locationService.getCurrentLocation();

      if (location != null && mounted) {
        setState(() {
          _locationText = location.city;
          _locationCoords = (location.latitude, location.longitude);
          _currentTimezone = location.timezone;
          _locationDenied = false;
          _isRequestingLocation = false;
        });

        // Save timezone
        await _locationService.setTimezone(location.timezone);
      } else {
        // Location is null - could be timeout OR permission issue
        // Check permissions to distinguish between the two
        final hasPermission = await _locationService.hasLocationPermission();
        debugPrint('📍 Location null - hasPermission: $hasPermission');

        // Priority: Check permission FIRST before cache
        if (!hasPermission) {
          // Permission denied - show Location Denied immediately, ignore cache
          // BUT use smart timezone fallback based on device's system timezone
          debugPrint('📍 Permission denied - detecting device timezone');
          final deviceTimezone = await _ekadashiService.getDeviceAppTimezone();
          debugPrint('📍 Using device timezone: $deviceTimezone');
          if (mounted) {
            setState(() {
              _currentTimezone = deviceTimezone;
            });
          }
          _setLocationDenied();
        } else {
          // Permission granted but location is null (timeout/GPS issue)
          // Try cached location as fallback
          final cached = await _locationService.getCachedLocation();
          if (cached != null && mounted) {
            setState(() {
              _locationText = cached.city;
              _locationCoords = (cached.latitude, cached.longitude);
              _currentTimezone = cached.timezone;
              _locationDenied = false;
              _isRequestingLocation = false;
            });
          } else {
            // No cache available - use device timezone fallback
            debugPrint(
              '📍 Location unavailable (timeout) - using device timezone fallback',
            );
            final deviceTimezone = await _ekadashiService
                .getDeviceAppTimezone();

            if (mounted) {
              setState(() {
                _locationText = ''; // No city name, just timezone logic applies
                _currentTimezone = deviceTimezone;
                _locationDenied = false; // It's not denied, just timed out
                _isRequestingLocation = false;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Location error: $e');
      // On error, check if it's permission-related
      final hasPermission = await _locationService.hasLocationPermission();
      if (!hasPermission) {
        _setLocationDenied();
      } else {
        // Error but have permission - use device timezone fallback
        debugPrint(
          '📍 Location error with permission - using device timezone fallback',
        );
        final deviceTimezone = await _ekadashiService.getDeviceAppTimezone();

        if (mounted) {
          setState(() {
            _locationText = '';
            _currentTimezone = deviceTimezone;
            _locationDenied = false;
            _isRequestingLocation = false;
          });
        }
      }
    }

    // Load data regardless of location result
    // If we updated location successfully (or fallback), we should probably ensure we show the correct Ekadashi for that location
    await _loadData(shouldScrollToNext: true);
  }

  void _setLocationDenied() {
    if (mounted) {
      setState(() {
        _locationDenied = true;
        _locationText = '';
        _isRequestingLocation = false;
      });
    }
  }

  /// Request location permission again when user taps on "Location Denied"
  Future<void> _requestLocationAgain() async {
    if (_isRequestingLocation) return;

    // 1. Always try to request permission first
    setState(() {
      _isRequestingLocation = true;
      _locationDenied = false;
    });

    try {
      // This will either show the dialog (if allowed) or auto-deny (if permanently denied previously but we didn't track it yet)
      final granted = await _locationService.requestLocationPermission();

      if (granted) {
        // Success
        if (mounted) {
          setState(() {
            _isPermanentDenial = false;
            _isRequestingLocation = false;
          });
        }
        await _refreshLocationIfNeeded();
      } else {
        // Denied
        final shouldShowRationale = await _locationService
            .shouldShowRequestRationale();
        debugPrint(
          '📍 Permission denied. shouldShowRationale: $shouldShowRationale',
        );

        if (mounted) {
          setState(() {
            _isRequestingLocation = false;
            _locationDenied = true;
            _locationText = '';
          });

          // 2. Smart Redirect Logic:
          // If we failed to get permission AND the system refused to show a rationale (dialog blocked),
          // AND we have already flagged this state previously, THEN open settings.
          if (!shouldShowRationale) {
            if (_isPermanentDenial) {
              // User clicked AGAIN after we already knew it was blocked.
              // Now we open settings.
              final settings = NativeSettingsService();
              await settings.openAppSettings();
            } else {
              // First time discovering it's blocked. Just flag it. Do NOT redirect.
              setState(() => _isPermanentDenial = true);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Location request error: $e');
      if (mounted) {
        setState(() => _isRequestingLocation = false);
      }
      _setLocationDenied();
    }
  }

  /// Refresh location in background when app resumes
  Future<void> _refreshLocationIfNeeded() async {
    // Guard against concurrent calls
    if (_isRequestingLocation || _isLoading) {
      debugPrint('⏭️ Skipping location refresh - already in progress');
      return;
    }

    try {
      // STEP A: Immediately check current permission status
      final hasPermission = await _locationService.hasLocationPermission();

      // STEP B: If permission denied, instantly update UI synchronously
      if (!hasPermission) {
        debugPrint('⚠️ Permission denied - updating UI synchronously');
        if (mounted) {
          setState(() {
            _locationDenied = true;
            _locationText = '';
          });
        }
        return;
      }

      // Permission granted - if was previously denied, try to get location
      if (_locationDenied) {
        final location = await _locationService.getCurrentLocation();
        if (location != null && mounted) {
          setState(() {
            _locationText = location.city;
            _locationCoords = (location.latitude, location.longitude);
            _currentTimezone = location.timezone;
            _locationDenied = false;
          });
          await _loadData();
        }
        return;
      }

      // Have permission and not denied - try to get location
      final location = await _locationService.getCurrentLocation();
      if (location != null && mounted) {
        if (location.timezone != _currentTimezone) {
          // Timezone changed - reload data
          setState(() {
            _locationText = location.city;
            _locationCoords = (location.latitude, location.longitude);
            _currentTimezone = location.timezone;
          });
          await _loadData(shouldScrollToNext: true);
        } else if (location.city != _locationText) {
          // Just city name changed
          setState(() {
            _locationText = location.city;
            _locationCoords = (location.latitude, location.longitude);
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ _refreshLocationIfNeeded error: $e');
      // Don't crash - just skip the refresh
    }
  }

  /// Load Ekadashi data for current timezone and language
  /// [shouldScrollToNext] - if true, ignores previous scroll position and forces scroll to "Next/Active" Ekadashi.
  /// Useful when timezone/location changes significantly.
  Future<void> _loadData({bool shouldScrollToNext = false}) async {
    if (!mounted) return;

    // Save the ID of the currently viewing Ekadashi before reloading
    // ONLY if we are not forced to scroll away
    int? currentEkadashiId;
    if (!shouldScrollToNext &&
        _ekadashiList.isNotEmpty &&
        _currentPage < _ekadashiList.length) {
      currentEkadashiId = _ekadashiList[_currentPage].id;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final lang = _currentLangCode.isEmpty ? 'en' : _currentLangCode;
      final ekadashis = _ekadashiService.getEkadashis(
        timezone: _currentTimezone,
        languageCode: lang,
      );

      if (mounted) {
        setState(() {
          _ekadashiList = ekadashis;
          _isLoading = false;
        });

        // Initialize Vrat Tracker with loaded occurrences
        Provider.of<VratTrackerService>(
          context,
          listen: false,
        ).init(occurrences: ekadashis);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          bool restored = false;
          // Try to restore the view to the previously selected Ekadashi
          if (currentEkadashiId != null) {
            final index = _ekadashiList.indexWhere(
              (e) => e.id == currentEkadashiId,
            );
            if (index != -1) {
              _pageController.jumpToPage(index);
              setState(() => _currentPage = index);
              restored = true;
            }
          }

          // If restoration failed OR we forced a scroll, go to next upcoming
          if (!restored) {
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
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
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
          ekadashiList: _ekadashiList,
          ekadashisFor: (code) => _ekadashiService.getEkadashis(
            timezone: _currentTimezone,
            languageCode: code,
          ),
          currentTimezone: _currentTimezone,
          availableYears: _ekadashiService.availableYears,
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
    if (!mounted || _ekadashiList.isEmpty) return;
    final lang = context.read<LanguageService>();
    await WidgetSyncManager().syncWidgetData(
      ekadashiList: _ekadashiList,
      timezone: _currentTimezone,
      locationName: _cityLabel(lang.currentLocale.languageCode),
      languageService: lang,
    );
    final pending = _pendingDeepLink;
    _pendingDeepLink = null;
    if (pending != null && mounted) handleDeepLink(pending);
  }

  /// The detected place in [language]: the shared table first, then the
  /// phone's geocoder, then the English name.
  String _cityLabel(String language) {
    final table = AppStrings.placeName(_locationText, language);
    if (language == 'en' || table != _locationText) return table;
    final key = '$language|$_locationText';
    final known = _nativeCityNames[key];
    if (known != null) return known;
    final coords = _locationCoords;
    if (coords != null && !_nativeCityNames.containsKey(key)) {
      _nativeCityNames[key] = null;
      _locationService.localizedCityName(coords.$1, coords.$2, language).then((
        name,
      ) {
        // Only a name in the language's own script replaces English.
        if (mounted && name != null && !RegExp('[A-Za-z]').hasMatch(name)) {
          setState(() => _nativeCityNames[key] = name);
        }
      });
    }
    return _locationText;
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
    if (_ekadashiList.isEmpty) return;

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
      final ekadashiData = _ekadashiList
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
        _ekadashiList,
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
      // The iOS tab symbols: calendar, leaf and sparkles.
      BottomNavigationBarItem(
        icon: const Icon(Icons.calendar_today),
        label: lang.translate('calendar'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.eco),
        label: lang.translate('journey_tab'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.auto_awesome),
        label: lang.translate('search_screen_panchang'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.settings),
        label: lang.translate('settings'),
      ),
    ];
    // A search result opened this tab: the top bar's "Search" back button
    // and the system back reopen its results (docs/ROADMAP.md Phase 9).
    final searchBack = _searchReturn.showsBack(_currentIndex);
    // A page pushed inside the tab brings its own top bar, as on iOS.
    final tabPushed = !_isLoading && _errorMessage.isEmpty && _tabPushed;
    final slots = switch (_currentIndex) {
      1 => _calendarBar,
      3 => _panchangBar,
      _ => null,
    };
    // The iOS gradient behind every tab (docs/ROADMAP.md Phase 8).
    return PopScope(
      canPop: !searchBack && !tabPushed,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (tabPushed) {
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
                  preferredSize: const Size.fromHeight(kToolbarHeight),
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          label: Text(
            lang.translate('search'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: IosText.body),
          ),
        ),
      ?tabLeading,
    ];
    return AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: leading.isEmpty
          ? null
          : (searchBack && tabLeading != null ? 210 : 128),
      // Long words in other languages shrink rather than overflow.
      leading: leading.isEmpty
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(mainAxisSize: MainAxisSize.min, children: leading),
            ),
      title: Text(lang.translate('app_title')),
      actions: [
        ...?slots?.actions(context),
        IconButton(
          key: const Key('open_global_search'),
          tooltip: lang.translate('search'),
          icon: const Icon(Icons.search),
          onPressed: _openSearch,
        ),
        const SizedBox(width: 4),
      ],
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
        icon: Icons.error_outline,
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
        ekadashiList: _ekadashiList,
        currentTimezone: _currentTimezone,
        barSlots: _calendarBar,
      ),
      2 => SafeArea(
        top: false,
        child: VratTrackerScreen(
          ekadashiList: _ekadashiList,
          currentTimezone: _currentTimezone,
        ),
      ),
      // Built when first opened: the Panchang calculates a year of
      // festivals, which the other tabs never need.
      3 =>
        _currentIndex == 3 || _panchangOpened
            ? PanchangScreen(
                key: _panchangKey,
                ekadashiList: _ekadashiList,
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
  Widget _buildHomeHeader(LanguageService lang, Color tealColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: GlassTube(
        key: const Key('home_options_tube'),
        optionCount: 2,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final location = _buildLocationWidget(lang, tealColor);
            final language = _buildLanguageSelector(lang, tealColor);
            if (_headerFits(lang, constraints.maxWidth)) {
              return Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: location,
                    ),
                  ),
                  const SizedBox(width: 20),
                  language,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                location,
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: language,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Whether the location and the language fit on one line (the first
  /// layout of iOS ViewThatFits).
  bool _headerFits(LanguageService lang, double width) {
    final code = lang.currentLocale.languageCode;
    double measure(String text) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
              .copyWith(
                fontSize: IosText.subheadline,
                fontWeight: FontWeight.w500,
              ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    final zone = AppStrings.timeZoneName(_currentTimezone, code);
    final location = _locationDenied
        ? lang.translate('location_denied')
        : _isRequestingLocation
        ? lang.translate('detecting_location')
        : _locationText.isEmpty
        ? '${lang.translate('locating')} • $zone'
        : '${_cityLabel(code)} • $zone';
    final language = AppLanguage.named(code).nativeName;
    // Icons and gaps: location ~40, between 20, globe ~24.
    return measure(location) + 40 + 20 + measure(language) + 24 <= width;
  }

  Widget _buildHomeContent(LanguageService lang, Color tealColor) {
    if (_ekadashiList.isEmpty) {
      // iOS keeps the header above ContentUnavailableView.
      return Column(
        children: [
          _buildHomeHeader(lang, tealColor),
          Expanded(
            child: UnavailableView(
              key: const Key('home_empty'),
              icon: Icons.event_busy_outlined,
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

        // Card with navigation arrows
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
            child: Row(
              children: [
                _homeArrow(
                  key: const Key('home_previous'),
                  icon: Icons.arrow_back_ios_new_rounded,
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
                  icon: Icons.arrow_forward_ios_rounded,
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

  Widget _buildLocationWidget(LanguageService lang, Color tealColor) {
    final code = lang.currentLocale.languageCode;
    const subheadline = TextStyle(fontSize: IosText.subheadline);
    // Detecting: a small spinner and the secondary text.
    if (_isRequestingLocation) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: tealColor),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              lang.translate('detecting_location'),
              maxLines: 1,
              style: subheadline.copyWith(color: IosColors.secondary(context)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    // Denied: orange, underlined, tap to ask again.
    if (_locationDenied) {
      final orange = IosColors.orange(context);
      return GestureDetector(
        key: const Key('home_location_chip'),
        behavior: HitTestBehavior.opaque,
        onTap: _requestLocationAgain,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.near_me_disabled, size: 16, color: orange),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                lang.translate('location_denied'),
                maxLines: 1,
                style: subheadline.copyWith(
                  color: orange,
                  decoration: TextDecoration.underline,
                  decorationColor: orange,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    final zone = AppStrings.timeZoneName(_currentTimezone, code);
    // Locating: the zone in use; tap to ask for the location again.
    if (_locationText.isEmpty) {
      return GestureDetector(
        key: const Key('home_location_chip'),
        behavior: HitTestBehavior.opaque,
        onTap: _requestLocationAgain,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.near_me, size: 16, color: tealColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${lang.translate('locating')} • $zone',
                maxLines: 1,
                style: subheadline,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Located: the city and zone; tap to look the location up again.
    return GestureDetector(
      key: const Key('home_location_chip'),
      behavior: HitTestBehavior.opaque,
      onTap: _handleLocation,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.near_me, size: 16, color: tealColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${_cityLabel(code)} • $zone',
              maxLines: 1,
              style: subheadline.copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.refresh,
            size: IosText.caption2,
            color: IosColors.secondary(context),
          ),
        ],
      ),
    );
  }

  /// The app's only language menu (docs/ROADMAP.md Phase 2), in the
  /// registry's order: English, Hindi, Tamil, Telugu, Gujarati, Bengali.
  /// As in the iOS Menu, the current language has a leading checkmark.
  Widget _buildLanguageSelector(LanguageService lang, Color tealColor) {
    final current = AppLanguage.named(lang.currentLocale.languageCode);
    return PopupMenuButton<String>(
      key: const Key('language_menu'),
      onSelected: (String newValue) => lang.changeLanguage(newValue),
      color: IosColors.sheet(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) => [
        for (final language in AppLanguage.all)
          PopupMenuItem(
            value: language.code,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: language.code == current.code
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color: IosColors.primary(context),
                        )
                      : null,
                ),
                Expanded(
                  child: Text(
                    language.nativeName,
                    style: const TextStyle(fontSize: IosText.body),
                  ),
                ),
              ],
            ),
          ),
      ],
      offset: const Offset(0, 40),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A SwiftUI Menu label takes the tint: teal.
          Text(
            current.nativeName,
            style: TextStyle(
              fontSize: IosText.subheadline,
              fontWeight: FontWeight.w500,
              color: tealColor,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.language, color: tealColor, size: 18),
        ],
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
                  // Days badge
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
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
    final record = tracker.getRecord(ekadashi.id);
    final open = VratRecording.isOpen(
      ekadashi,
      now: DateTime.now(),
      timezone: _currentTimezone,
    );
    final color = open ? IosColors.teal : IosColors.tertiary(context);
    final Widget icon = switch (record?.status) {
      ObservanceStatus.observed => Icon(Icons.check_circle, color: color),
      ObservanceStatus.partial => Icon(Icons.adjust, color: color),
      ObservanceStatus.missed => Icon(Icons.highlight_off, color: color),
      // calendar.badge.plus: a calendar with a plus badge.
      _ => SizedBox(
        width: 24,
        height: 24,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.calendar_month_outlined, size: 22, color: color),
            Positioned(
              right: -1,
              bottom: -1,
              child: Icon(Icons.add_circle, size: 11, color: color),
            ),
          ],
        ),
      ),
    };
    return OutlinedButton(
      key: const Key('home_record_vrat'),
      onPressed: open
          ? () async {
              final unlocks = await RecordVratDialog.show(
                context,
                ekadashi: ekadashi,
                allOccurrences: _ekadashiList,
                currentTimezone: _currentTimezone,
              );
              if (unlocks != null && unlocks.isNotEmpty && mounted) {
                for (final u in unlocks) {
                  await AchievementUnlockDialog.show(context, u);
                }
              }
            }
          : null,
      // A round glass button, neutral grey while recording is closed.
      style: IosButtons.glass(context).copyWith(
        shape: const WidgetStatePropertyAll(CircleBorder()),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        fixedSize: const WidgetStatePropertyAll(Size.square(48)),
        minimumSize: const WidgetStatePropertyAll(Size.square(48)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? IosColors.gray(context).withValues(alpha: .18)
              : IosColors.teal.withValues(alpha: .10),
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color:
                (states.contains(WidgetState.disabled)
                        ? IosColors.gray(context)
                        : IosColors.teal)
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
