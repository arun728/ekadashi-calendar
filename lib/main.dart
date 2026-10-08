import 'dart:io';
import 'services/premium_service.dart';
import 'services/play_billing_service.dart';
import 'widgets/glass_tube.dart';
import 'package:flutter/foundation.dart';
import 'widgets/glass_navigation_bar.dart';
import 'data/calendar_entry_repository.dart';
import 'data/sqflite_calendar_entry_repository.dart';
import 'models/calendar_entry.dart';
import 'services/notifications/event_reminder_service.dart';
import 'services/panchang/panchang_city.dart';
import 'services/panchang/panchang_location_store.dart';
import 'services/native_widget_service.dart';
import 'services/widget_sync_manager.dart';
import 'screens/global_search_screen.dart';
import 'screens/panchang_screen.dart';
import 'l10n/generated/app_localizations.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
  String _currentTimezone = 'IST';
  bool _locationDenied = false;
  bool _isRequestingLocation = false;
  int _currentPage = 0;
  bool _isResuming = false;
  bool _isPermanentDenial = false;
  bool _searchOpen = false;

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
            _currentTimezone = location.timezone;
          });
          await _loadData(shouldScrollToNext: true);
        } else if (location.city != _locationText) {
          // Just city name changed
          setState(() => _locationText = location.city);
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
          _errorMessage = 'Failed to load data';
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

  Future<void> _openSearch() async {
    if (!mounted || _searchOpen) return;
    _searchOpen = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => GlobalSearchScreen(
            ekadashiList: _ekadashiList,
            ekadashisFor: (code) => _ekadashiService.getEkadashis(
              timezone: _currentTimezone,
              languageCode: code,
            ),
            currentTimezone: _currentTimezone,
            availableYears: _ekadashiService.availableYears,
            onOpenTab: (tab) {
              if (!mounted) return;
              setState(() => _currentIndex = tab);
            },
            onOpenCalendar: (day) {
              if (!mounted) return;
              setState(() => _currentIndex = 1);
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
    if (!mounted || _ekadashiList.isEmpty) return;
    final lang = context.read<LanguageService>();
    await WidgetSyncManager().syncWidgetData(
      ekadashiList: _ekadashiList,
      timezone: _currentTimezone,
      locationName: _locationText,
      languageService: lang,
    );
    final pending = _pendingDeepLink;
    _pendingDeepLink = null;
    if (pending != null && mounted) handleDeepLink(pending);
  }

  /// Handle bottom navigation taps
  void _onBottomNavTapped(int index) {
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
      BottomNavigationBarItem(
        icon: const Icon(Icons.calendar_month),
        label: lang.translate('calendar'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.spa_outlined),
        activeIcon: const Icon(Icons.spa),
        label: lang.translate('journey_tab'),
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.auto_awesome_outlined),
        activeIcon: Icon(Icons.auto_awesome),
        label: 'Panchang',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.settings),
        label: lang.translate('settings'),
      ),
    ];
    return Scaffold(
      extendBody: glass,
      appBar: AppBar(
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
          ekadashiList: _ekadashiList,
          currentTimezone: _currentTimezone,
        ),
        SafeArea(
          top: false,
          child: VratTrackerScreen(
            ekadashiList: _ekadashiList,
            currentTimezone: _currentTimezone,
          ),
        ),
        // Built when first opened: the Panchang calculates a year of
        // festivals, which the other tabs never need.
        if (_currentIndex == 3 || _panchangOpened)
          PanchangScreen(key: _panchangKey, ekadashiList: _ekadashiList)
        else
          const SizedBox.shrink(),
        SettingsScreen(currentTimezone: _currentTimezone),
      ],
    );
  }

  Widget _buildHomeContent(LanguageService lang, Color tealColor) {
    if (_ekadashiList.isEmpty) {
      return Center(
        child: Text(
          lang.translate('no_ekadashi'),
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    final bool isFirstPage = _currentPage == 0;
    final bool isLastPage = _currentPage >= _ekadashiList.length - 1;

    return Column(
      children: [
        // Header with location and language inline (v1.0 style)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: GlassTube(
            key: const Key('home_options_tube'),
            optionCount: 2,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 400 &&
                    MediaQuery.textScalerOf(context).scale(14) > 20) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLocationWidget(lang, tealColor),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildLanguageSelector(lang, tealColor),
                      ),
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _buildLocationWidget(lang, tealColor)),
                    const SizedBox(width: 20),
                    _buildLanguageSelector(lang, tealColor),
                  ],
                );
              },
            ),
          ),
        ),

        // Page indicator
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${_currentPage + 1} / ${_ekadashiList.length}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ),

        // Card with navigation arrows
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 4,
              right: 4,
              top: 8,
              bottom: 8,
            ),
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
        ),
      ],
    );
  }

  Widget _buildLocationWidget(LanguageService lang, Color tealColor) {
    // Show spinner while detecting location
    if (_isRequestingLocation) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: tealColor),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              lang.translate('detecting_location'),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    // Show "Location Denied" with tap to retry
    if (_locationDenied) {
      return GestureDetector(
        onTap: _requestLocationAgain,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 18, color: Colors.orange.shade400),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                lang.translate('location_denied'),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange.shade400,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Show "Locating..." while loading
    if (_locationText.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 18, color: tealColor),
          const SizedBox(width: 6),
          Text(
            lang.translate('locating'),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      );
    }

    // Show city name and timezone
    // Show city name and timezone (Clickable to retry)
    return InkWell(
      onTap: _handleLocation,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 18, color: tealColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$_locationText • $_currentTimezone',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.refresh, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  /// The app's only language menu (docs/ROADMAP.md Phase 2), in the
  /// registry's order: English, Hindi, Tamil, Telugu, then new languages.
  Widget _buildLanguageSelector(LanguageService lang, Color tealColor) {
    final current = AppLanguage.named(lang.currentLocale.languageCode);
    return PopupMenuButton<String>(
      key: const Key('language_menu'),
      onSelected: (String newValue) => lang.changeLanguage(newValue),
      color: Theme.of(context).cardColor,
      itemBuilder: (context) => [
        for (final language in AppLanguage.all)
          PopupMenuItem(
            value: language.code,
            child: Row(
              children: [
                Expanded(child: Text(language.nativeName)),
                if (language.code == current.code)
                  Icon(Icons.check, size: 18, color: tealColor),
              ],
            ),
          ),
      ],
      offset: const Offset(0, 40),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            current.nativeName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 6),
          Icon(Icons.language, color: tealColor, size: 20),
        ],
      ),
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
    breakTime = breakTime.replaceAll(RegExp(r'^[a-zA-Z]{3} \d{1,2}, '), '');

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

                    // Date
                    Text(
                      DateFormat(
                        'MMM dd, yyyy',
                        lang.currentLocale.languageCode,
                      ).format(ekadashi.date),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat(
                        'EEEE',
                        lang.currentLocale.languageCode,
                      ).format(ekadashi.date),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade500,
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
                        DateFormat(
                          'MMM dd, yyyy',
                          lang.currentLocale.languageCode,
                        ).format(ekadashi.date),
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        ekadashi.fastStartTime,
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
                        DateFormat(
                          'MMM dd, yyyy',
                          lang.currentLocale.languageCode,
                        ).format(ekadashi.date.add(const Duration(days: 1))),
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

            // Action buttons: View Details and Record Vrat
            GlassOptionGroup(
              key: const Key('home_card_actions_tube'),
              optionCount: context.watch<VratTrackerService>().trackerEnabled
                  ? 2
                  : 1,
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
                        backgroundColor:
                            context.watch<VratTrackerService>().trackerEnabled
                            ? Colors.transparent
                            : tealColor,
                        foregroundColor:
                            context.watch<VratTrackerService>().trackerEnabled
                            ? GlassTubeColors.teal
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        lang.translate('view_details'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  Consumer<VratTrackerService>(
                    builder: (ctx, trackerService, _) {
                      if (!trackerService.trackerEnabled) {
                        return const SizedBox.shrink();
                      }
                      final record = trackerService.getRecord(ekadashi.id);
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
                                      allOccurrences: _ekadashiList,
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
