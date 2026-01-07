import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'services/ekadashi_service.dart';
import 'services/notification_service.dart';
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
  String _currentLangCode = '';

  List<EkadashiDate> _ekadashiList = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _locationText = '';
  bool _locationDenied = false;
  bool _isRequestingLocation = false; // NEW: Track if we're requesting permission
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
      _loadData(languageCode: _currentLangCode);
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
    if (state == AppLifecycleState.resumed && !_isResuming && !_isRequestingLocation) {
      _isResuming = true;
      // Use post frame callback instead of delay for smoother experience
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _safeLocationCheck();
        }
        _isResuming = false;
      });
    }
  }

  /// Safe location check that won't crash during activity recreation
  Future<void> _safeLocationCheck() async {
    if (!mounted) return;

    try {
      final permission = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 3), onTimeout: () => LocationPermission.denied);

      if (!mounted) return;

      final hasPermission = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      if (hasPermission && _locationDenied) {
        // Permission was granted while away - fetch location
        _handleLocation();
      } else if (!hasPermission && !_locationDenied) {
        // Permission was revoked while away - update UI immediately
        setState(() {
          _locationDenied = true;
          _locationText = '';
        });
      }
    } catch (e) {
      debugPrint('Safe location check error: $e');
    }
  }

  Future<void> _initializeApp() async {
    final prefs = await SharedPreferences.getInstance();
    final hasLaunched = prefs.getBool('has_launched') ?? false;

    if (!hasLaunched) {
      await prefs.setBool('has_launched', true);
      await _requestPermissionsOnFirstLaunch();
    } else {
      _handleLocation();
    }
  }

  Future<void> _requestPermissionsOnFirstLaunch() async {
    // Show "Detecting location..." immediately during first launch
    if (mounted) {
      setState(() {
        _isRequestingLocation = true;
        _locationDenied = false;
        _locationText = '';
      });
    }

    final notifGranted = await NotificationService().requestNotificationPermission();

    if (notifGranted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', true);
      await prefs.setBool('remind_one_day_before', true);
      await prefs.setBool('remind_two_days_before', true);
      await prefs.setBool('remind_on_day', true);
      debugPrint('✅ Notification preferences saved: all enabled');

      // Check alarm permission status (don't open settings automatically!)
      // User can enable it later from Settings tab if needed
      if (Platform.isAndroid) {
        final hasAlarmPermission = await NotificationService().hasExactAlarmPermission();
        debugPrint('📢 Alarm permission on first launch: $hasAlarmPermission');
        // If not granted, user will see warning in Settings > Permissions
      }
    }

    // Now request location permission
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (mounted) {
        setState(() => _isRequestingLocation = false);
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        await _handleLocation();
      } else {
        _setLocationDenied();
      }
    } catch (e) {
      debugPrint('Location permission error: $e');
      if (mounted) {
        setState(() => _isRequestingLocation = false);
      }
      _setLocationDenied();
    }
  }

  Future<void> _handleLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      if (!serviceEnabled) {
        _setLocationDenied();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 2), onTimeout: () => LocationPermission.denied);
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setLocationDenied();
        return;
      }

      if (mounted) {
        setState(() {
          _locationText = '';
          _locationDenied = false;
        });
      }

      Position position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 10),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude
      ).timeout(const Duration(seconds: 5), onTimeout: () => []);

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        setState(() {
          _locationText = place.locality ?? place.subAdministrativeArea ?? '';
          _locationDenied = false;
        });
      }
    } catch (e) {
      debugPrint('Location error: $e');
      _setLocationDenied();
    }
  }

  void _setLocationDenied() {
    if (mounted) {
      setState(() {
        _locationText = '';
        _locationDenied = true;
        _isRequestingLocation = false;
      });
    }
  }

  Future<void> _requestLocationAgain() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      } else {
        // Show detecting state while requesting
        if (mounted) {
          setState(() {
            _isRequestingLocation = true;
            _locationDenied = false;
          });
        }

        permission = await Geolocator.requestPermission();

        if (mounted) {
          setState(() => _isRequestingLocation = false);
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          await _handleLocation();
        } else {
          _setLocationDenied();
        }
      }
    } catch (e) {
      debugPrint('Location request error: $e');
      if (mounted) {
        setState(() => _isRequestingLocation = false);
      }
    }
  }

  Future<void> _loadData({String languageCode = 'en'}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final dates = _ekadashiService.getEkadashis(languageCode);

      if (mounted) {
        setState(() {
          _ekadashiList = dates;
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToNextEkadashi(animate: false);
        });

        _scheduleNotificationsInBackground(dates);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load data';
        });
      }
    }
  }

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
          curve: Curves.easeOutCubic
      );
    } else {
      _pageController.jumpToPage(indexToScroll);
    }

    if (mounted) {
      setState(() => _currentPage = indexToScroll);
    }
  }

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

      // When switching TO Home tab, scroll to upcoming ekadashi
      if (index == 0) {
        // Use post-frame callback to ensure page controller is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToNextEkadashi(animate: false);
        });
      }
    }
  }

  void _scheduleNotificationsInBackground(List<EkadashiDate> dates) {
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool('notifications_enabled') ?? true)) return;

        final hasPermission = await NotificationService().hasNotificationPermission();
        if (!hasPermission) return;

        bool remind1 = prefs.getBool('remind_one_day_before') ?? true;
        bool remind2 = prefs.getBool('remind_two_days_before') ?? true;
        bool remindOnDay = prefs.getBool('remind_on_day') ?? true;

        if (!mounted) return;
        final langService = Provider.of<LanguageService>(context, listen: false);
        await NotificationService().scheduleAllNotifications(
            dates, remind1, remind2, remindOnDay, langService.localizedStrings);
      } catch (e) {
        debugPrint("Error scheduling notifications: $e");
      }
    });
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: tealColor))
          : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage))
          : IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeContent(),
          CalendarScreen(key: _calendarKey, ekadashiList: _ekadashiList),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTapped,
        selectedItemColor: tealColor,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home),
              label: lang.translate('home')
          ),
          BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_month),
              label: lang.translate('calendar')
          ),
          BottomNavigationBarItem(
              icon: const Icon(Icons.settings),
              label: lang.translate('settings')
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    const tealColor = Color(0xFF00A19B);
    final lang = Provider.of<LanguageService>(context);
    final bool isFirstPage = _currentPage == 0;
    final bool isLastPage = _currentPage >= _ekadashiList.length - 1;

    return Column(
      children: [
        // Header with more vertical space
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

        // Page indicator (shows current position in list)
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

        // Card with arrows - takes remaining space
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, top: 8, bottom: 8),
            child: Row(
              children: [
                // Left arrow
                SizedBox(
                  width: 44,
                  child: IconButton(
                    onPressed: isFirstPage ? null : () {
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

                // Card
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _ekadashiList.length,
                    onPageChanged: (index) {
                      // Update page indicator when user swipes
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
                    onPressed: isLastPage ? null : () {
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
    // Show "Detecting location..." while requesting permission
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, size: 18, color: tealColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _locationText,
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
      case 'ta': displayLanguage = 'தமிழ்'; break;
      case 'hi': displayLanguage = 'हिंदी'; break;
      default: displayLanguage = 'English';
    }

    return PopupMenuButton<String>(
      onSelected: (String newValue) => lang.changeLanguage(newValue),
      color: Theme.of(context).cardColor,
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'en', child: Text("English")),
        const PopupMenuItem(value: 'hi', child: Text("हिंदी", style: TextStyle(fontWeight: FontWeight.bold))),
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
            // Scrollable content area
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Days badge - top right
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: daysUntil < 0 ? Colors.grey : tealColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          daysText,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Date
                    Text(
                      DateFormat('MMM dd, yyyy').format(ekadashi.date),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w300),
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
                          fontWeight: FontWeight.bold
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    // Start Fasting section
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        lang.translate('start_fasting'),
                        style: const TextStyle(
                            color: tealColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16
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
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Break Fasting section
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        lang.translate('break_fasting'),
                        style: const TextStyle(
                            color: tealColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        DateFormat('MMM dd, yyyy').format(
                            ekadashi.date.add(const Duration(days: 1))
                        ),
                        style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        breakTime,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Divider
                    Divider(color: Colors.grey.shade400, height: 1),

                    const SizedBox(height: 16),

                    // Description
                    Text(
                      ekadashi.description,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 15,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // View Details button - ALWAYS VISIBLE at bottom
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailsScreen(ekadashi: ekadashi),
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