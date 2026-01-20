import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'services/ekadashi_service.dart';
import 'services/notification_service.dart';
import 'services/native_location_service.dart';
import 'services/native_notification_service.dart';
import 'services/native_settings_service.dart';
import 'services/theme_service.dart';
import 'services/language_service.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/details_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    NotificationService().init(),
    EkadashiService().initializeData(),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()..loadTheme()),
        ChangeNotifierProvider(create: (_) => LanguageService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'Ekadashi Calendar',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode,
          home: const MainScreen(),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final EkadashiService _ekadashiService = EkadashiService();
  final NativeLocationService _locationService = NativeLocationService();
  String _currentLangCode = '';

  List<EkadashiDate> _ekadashiList = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _locationText = '';
  String _currentTimezone = 'IST';
  bool _locationDenied = false;
  bool _isRequestingLocation = false;
  int _currentPage = 0;
  bool _isResuming = false;

  final PageController _pageController = PageController(viewportFraction: 1.0);
  final GlobalKey<CalendarScreenState> _calendarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final langService = Provider.of<LanguageService>(context);
    if (_currentLangCode != langService.currentLocale.languageCode) {
      _currentLangCode = langService.currentLocale.languageCode;
      _loadData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Wait for the first frame to render (ensure engine is attached)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Add a small safety buffer for low-end devices/heavy restoration
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isResuming && !_isRequestingLocation && !_isLoading) {
            _isResuming = true;
            _refreshLocationIfNeeded().catchError((e) {
              debugPrint('⚠️ Resume refresh error: $e');
            }).whenComplete(() {
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

    if (!hasLaunched) {
      // First launch - request permissions
      await prefs.setBool('has_launched', true);
      await prefs.setString('app_version', '2.0');
      await _requestPermissionsOnFirstLaunch();
    } else {
      // Existing user - check for upgrade migration
      if (appVersion != '2.0') {
        debugPrint('📦 Migrating from v$appVersion to v2.0...');
        await prefs.setString('app_version', '2.0');

        // Enable Break Fasting Reminder by default in v2.0
        // Only set if not explicitly set before (check for key existence by checking both Flutter and native prefs)
        if (!prefs.containsKey('remind_on_parana')) {
          await prefs.setBool('remind_on_parana', true);
          debugPrint('  ✅ Enabled Break Fasting Reminder by default');
        }
      }
      _handleLocation();
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
    final notifGranted = await NotificationService().requestNotificationPermission();
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
    });

    try {
      // Try to get current location using native service
      final location = await _locationService.getCurrentLocation();

      if (location != null && mounted) {
        setState(() {
          _locationText = location.city;
          _currentTimezone = location.timezone;
          _locationDenied = false;
        });

        // Save timezone
        await _locationService.setTimezone(location.timezone);
      } else {
        // Try cached location
        final cached = await _locationService.getCachedLocation();
        if (cached != null && mounted) {
          setState(() {
            _locationText = cached.city;
            _currentTimezone = cached.timezone;
            _locationDenied = false;
          });
        } else {
          _setLocationDenied();
        }
      }
    } catch (e) {
      debugPrint('Location error: $e');
      _setLocationDenied();
    }

    // Load data regardless of location result
    await _loadData();
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

    setState(() {
      _isRequestingLocation = true;
      _locationDenied = false;
    });

    try {
      // First check if we already have permission
      final hasPermission = await _locationService.hasLocationPermission();

      if (!hasPermission) {
        // Request permission - this attempts to show system dialog
        debugPrint('📍 Re-requesting location permission...');
        final granted = await _locationService.requestLocationPermission();
        debugPrint('📍 Permission re-request result: $granted');

        if (!granted) {
          // Permission denied - check if it's permanent denial
          final shouldShowRationale = await _locationService.shouldShowRequestRationale();
          debugPrint('📍 shouldShowRequestRationale: $shouldShowRationale');

          if (!shouldShowRationale) {
            // Permanent denial - OS blocked the dialog, open App Settings
            debugPrint('📍 Permanent denial detected - opening App Settings');
            final settings = NativeSettingsService();
            await settings.openAppSettings();
          }
          // If shouldShowRationale is true, user just denied again - do nothing

          if (mounted) {
            setState(() => _isRequestingLocation = false);
          }
          _setLocationDenied();
          return;
        }
      }

      // Permission granted - try to get location
      final location = await _locationService.getCurrentLocation();

      if (mounted) {
        setState(() => _isRequestingLocation = false);
      }

      if (location != null && mounted) {
        setState(() {
          _locationText = location.city;
          _currentTimezone = location.timezone;
          _locationDenied = false;
        });
        await _locationService.setTimezone(location.timezone);
        await _loadData();
      } else {
        _setLocationDenied();
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
          await _loadData();
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
  Future<void> _loadData() async {
    if (!mounted) return;

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

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToNextEkadashi(animate: false);
        });

        // Schedule notifications
        _scheduleNotifications();
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
  void _scrollToNextEkadashi({bool animate = true}) {
    if (_ekadashiList.isEmpty || !_pageController.hasClients) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int indexToScroll = 0;

    for (int i = 0; i < _ekadashiList.length; i++) {
      if (_ekadashiList[i].date.isAfter(today) ||
          _ekadashiList[i].date.isAtSameMomentAs(today)) {
        indexToScroll = i;
        break;
      }
    }

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

  /// Handle bottom navigation taps
  void _onBottomNavTapped(int index) {
    if (index == _currentIndex) {
      // Already on this tab - special actions
      if (index == 0) {
        _scrollToNextEkadashi(animate: true);
      } else if (index == 1) {
        _calendarKey.currentState?.resetToToday();
      }
    } else {
      // Switching tabs
      setState(() => _currentIndex = index);

      // When switching TO Home tab, scroll to upcoming Ekadashi
      if (index == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToNextEkadashi(animate: false);
        });
      }
    }
  }

  /// Schedule notifications for all Ekadashis
  Future<void> _scheduleNotifications() async {
    if (_ekadashiList.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    if (!notificationsEnabled) return;

    final lang = Provider.of<LanguageService>(context, listen: false);
    final texts = lang.localizedStrings;

    // Use native notification service
    try {
      final nativeNotifService = NativeNotificationService();
      final ekadashiData = _ekadashiList.map((e) => EkadashiNotificationData(
        id: e.id,
        name: e.name,
        fastingStartTime: e.fastingStartIso,
        paranaStartTime: e.paranaStartIso,
      )).toList();

      await nativeNotifService.scheduleAllNotifications(
        ekadashis: ekadashiData,
        texts: texts,
      );
    } catch (e) {
      // Fallback to old notification service
      debugPrint('Native notifications failed, using fallback: $e');
      final remind1Day = prefs.getBool('remind_one_day_before') ?? true;
      final remind2Days = prefs.getBool('remind_two_days_before') ?? true;
      final remindOnDay = prefs.getBool('remind_on_day') ?? true;

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

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('app_title')),
        centerTitle: true,
      ),
      body: _buildBody(lang, tealColor),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTapped,
        selectedItemColor: tealColor,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: lang.translate('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_month),
            label: lang.translate('calendar'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: lang.translate('settings'),
          ),
        ],
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
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return IndexedStack(
      index: _currentIndex,
      children: [
        _buildHomeContent(lang, tealColor),
        CalendarScreen(
          key: _calendarKey,
          ekadashiList: _ekadashiList,
          currentTimezone: _currentTimezone,
        ),
        const SettingsScreen(),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildLocationWidget(lang, tealColor),
              ),
              const SizedBox(width: 20),
              _buildLanguageSelector(lang, tealColor),
            ],
          ),
        ),

        // Page indicator
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${_currentPage + 1} / ${_ekadashiList.length}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ),

        // Card with navigation arrows
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, top: 8, bottom: 8),
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
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tealColor,
            ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, size: 18, color: tealColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$_locationText • $_currentTimezone',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector(LanguageService lang, Color tealColor) {
    String displayLanguage;
    switch (lang.currentLocale.languageCode) {
      case 'ta':
        displayLanguage = 'தமிழ்';
        break;
      case 'hi':
        displayLanguage = 'हिंदी';
        break;
      default:
        displayLanguage = 'English';
    }

    return PopupMenuButton<String>(
      onSelected: (String newValue) => lang.changeLanguage(newValue),
      color: Theme.of(context).cardColor,
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'en', child: Text("English")),
        const PopupMenuItem(
          value: 'hi',
          child: Text("हिंदी", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const PopupMenuItem(value: 'ta', child: Text("தமிழ்")),
      ],
      offset: const Offset(0, 40),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayLanguage,
            style: TextStyle(
              fontSize: 14,
              fontWeight: lang.currentLocale.languageCode == 'hi'
                  ? FontWeight.bold
                  : FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.language, color: tealColor, size: 20),
        ],
      ),
    );
  }

  Widget _buildEkadashiCard(EkadashiDate ekadashi) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int daysUntil = ekadashi.date.difference(today).inDays;
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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          )
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
                      DateFormat('MMM dd, yyyy').format(ekadashi.date),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE').format(ekadashi.date),
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
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
                        DateFormat('MMM dd, yyyy').format(ekadashi.date),
                        style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
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
                        DateFormat('MMM dd, yyyy').format(
                          ekadashi.date.add(const Duration(days: 1)),
                        ),
                        style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
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
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(0.8),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // View Details button
            SizedBox(
              width: double.infinity,
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
                  backgroundColor: tealColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  lang.translate('view_details'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
