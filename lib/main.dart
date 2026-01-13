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
import 'services/theme_service.dart';
import 'services/language_service.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/details_screen.dart';
import 'screens/city_selection_screen.dart';

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
  bool _isAutoDetectEnabled = true;
  int _currentPage = 0;

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
      // Refresh location when app resumes (non-blocking)
      _refreshLocationIfNeeded();
    }
  }

  /// Initialize app - check settings and load data
  Future<void> _initializeApp() async {
    final prefs = await SharedPreferences.getInstance();
    final hasLaunched = prefs.getBool('has_launched') ?? false;

    // Load saved settings
    _isAutoDetectEnabled = await _locationService.isAutoDetectEnabled();
    _currentTimezone = await _locationService.getCurrentTimezone();

    if (!hasLaunched) {
      await prefs.setBool('has_launched', true);
      await _requestPermissionsOnFirstLaunch();
    } else {
      _handleLocation();
    }
  }

  Future<void> _requestPermissionsOnFirstLaunch() async {
    // Request notification permission
    final notifGranted = await NotificationService().requestNotificationPermission();
    if (notifGranted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', true);
      await prefs.setBool('remind_one_day_before', true);
      await prefs.setBool('remind_two_days_before', true);
      await prefs.setBool('remind_on_day', true);
      debugPrint('✅ Notification preferences saved');
    }

    // Handle location (native service will request permission if needed)
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
      if (_isAutoDetectEnabled) {
        // Try to get current location
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
      } else {
        // Manual city selection - load from preferences
        final cityId = await _locationService.getSelectedCityId();
        if (cityId != null) {
          final city = _ekadashiService.getCityById(cityId);
          if (city != null && mounted) {
            setState(() {
              _locationText = city.name;
              _currentTimezone = city.timezone;
              _locationDenied = false;
            });
          }
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
      });
    }
  }

  /// Refresh location in background when app resumes
  Future<void> _refreshLocationIfNeeded() async {
    if (!_isAutoDetectEnabled) return;

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
  }

  /// Load Ekadashi data for current timezone and language
  Future<void> _loadData({String? languageCode}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final lang = languageCode ?? _currentLangCode;
      final ekadashis = _ekadashiService.getEkadashis(
        timezone: _currentTimezone,
        languageCode: lang.isEmpty ? 'en' : lang,
      );

      // Filter to upcoming Ekadashis (from today onwards, plus a few past ones for context)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final cutoffDate = today.subtract(const Duration(days: 7)); // Show last week too

      final filtered = ekadashis.where((e) => e.date.isAfter(cutoffDate)).toList();

      // Find index of next upcoming Ekadashi
      int startIndex = 0;
      for (int i = 0; i < filtered.length; i++) {
        if (!filtered[i].date.isBefore(today)) {
          startIndex = i;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _ekadashiList = filtered;
          _currentPage = startIndex;
          _isLoading = false;
        });

        // Jump to current Ekadashi
        if (_pageController.hasClients && filtered.isNotEmpty) {
          _pageController.jumpToPage(startIndex);
        }

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

  /// Schedule notifications for all Ekadashis
  Future<void> _scheduleNotifications() async {
    if (_ekadashiList.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    if (!notificationsEnabled) return;

    final lang = Provider.of<LanguageService>(context, listen: false);
    final texts = lang.localizedStrings;

    // Use native notification service if available, fallback to old service
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

  /// Handle city selection
  void _onCitySelected(String cityId, String timezone, bool autoDetect) async {
    await _locationService.setAutoDetectEnabled(autoDetect);
    await _locationService.setTimezone(timezone);

    if (!autoDetect && cityId != 'auto') {
      await _locationService.setSelectedCityId(cityId);
      final city = _ekadashiService.getCityById(cityId);
      if (city != null) {
        setState(() {
          _locationText = city.name;
          _isAutoDetectEnabled = false;
        });
      }
    } else {
      await _locationService.setSelectedCityId(null);
      setState(() => _isAutoDetectEnabled = true);
    }

    setState(() => _currentTimezone = timezone);
    _loadData();
  }

  /// Open city selection screen
  void _openCitySelection() async {
    final cityId = await _locationService.getSelectedCityId();

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CitySelectionScreen(
          currentCityId: cityId,
          isAutoDetectEnabled: _isAutoDetectEnabled,
          onCitySelected: _onCitySelected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF00A19B);
    final lang = Provider.of<LanguageService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('app_title')),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildLanguageDropdown(lang),
          ),
        ],
      ),
      body: Column(
        children: [
          // Location header
          _buildLocationHeader(lang, tealColor),

          // Main content
          Expanded(
            child: _buildBody(lang, tealColor),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: tealColor,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.spa),
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
        onTap: (index) {
          if (index == 1 && _currentIndex == 1) {
            _calendarKey.currentState?.resetToToday();
          }
          setState(() => _currentIndex = index);
        },
      ),
    );
  }

  Widget _buildLocationHeader(LanguageService lang, Color tealColor) {
    return InkWell(
      onTap: _openCitySelection,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withOpacity(0.2),
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isAutoDetectEnabled ? Icons.my_location : Icons.location_on,
              size: 18,
              color: _locationDenied ? Colors.orange : tealColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _locationText.isNotEmpty
                  ? Text(
                '$_locationText • $_currentTimezone',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              )
                  : Text(
                _locationDenied
                    ? lang.translate('location_denied')
                    : lang.translate('detecting_location'),
                style: TextStyle(
                  fontSize: 14,
                  color: _locationDenied ? Colors.orange : Colors.grey,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey.shade400,
            ),
          ],
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
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    switch (_currentIndex) {
      case 0:
        return _buildHomeTab(lang, tealColor);
      case 1:
        return CalendarScreen(
          key: _calendarKey,
          ekadashiList: _ekadashiList,
          currentTimezone: _currentTimezone,
        );
      case 2:
        return const SettingsScreen();
      default:
        return _buildHomeTab(lang, tealColor);
    }
  }

  Widget _buildHomeTab(LanguageService lang, Color tealColor) {
    if (_ekadashiList.isEmpty) {
      return Center(
        child: Text(
          lang.translate('no_ekadashi'),
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _ekadashiList.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildEkadashiCard(_ekadashiList[index]),
              );
            },
          ),
        ),
        // Page indicator
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_currentPage + 1} / ${_ekadashiList.length}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageDropdown(LanguageService lang) {
    const tealColor = Color(0xFF00A19B);
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
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Days badge
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
                            fontSize: 13,
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
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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

            // View Details button
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