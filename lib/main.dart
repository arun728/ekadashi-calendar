import 'dart:async';
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
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('Notification Init Failed: $e');
  }
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

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final EkadashiService _ekadashiService = EkadashiService();
  String _currentLangCode = '';

  List<EkadashiDate> _ekadashiList = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _locationText = 'Locating...';
  String _currentTime = '';
  Timer? _timer;

  final PageController _pageController = PageController(viewportFraction: 1.0);
  final GlobalKey<CalendarScreenState> _calendarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _startTimer();

    // FIXED: Start background tasks immediately, don't block UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runBackgroundTasks();
    });
  }

  // FIXED: All slow tasks run in background
  void _runBackgroundTasks() {
    // Request permissions in background
    Future.microtask(() async {
      try {
        await NotificationService().requestPermissions();
        // Small delay to avoid Android permission conflict
        await Future.delayed(const Duration(milliseconds: 100));
        await _handleLocation();
      } catch (e) {
        debugPrint('⚠️ Background task error: $e');
      }
    });
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
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('hh:mm a').format(DateTime.now());
      });
    }
  }

  Future<void> _handleLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted && _locationText == 'Locating...') {
          setState(() => _locationText = 'Chennai, TN');
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _locationText = 'Chennai, TN');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationText = 'Chennai, TN');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 5),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        setState(() => _locationText = '${place.locality}, ${place.administrativeArea}');
      }
    } catch (e) {
      debugPrint('⚠️ Location error: $e');
      if (mounted) setState(() => _locationText = 'Chennai, TN');
    }
  }

  void _scrollToNextEkadashi({bool animate = true}) {
    if (_ekadashiList.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int indexToScroll = 0;

    for (int i = 0; i < _ekadashiList.length; i++) {
      if (_ekadashiList[i].date.isAfter(today) || _ekadashiList[i].date.isAtSameMomentAs(today)) {
        indexToScroll = i;
        break;
      }
    }

    if (_pageController.hasClients) {
      if (animate) {
        _pageController.animateToPage(
            indexToScroll,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic
        );
      } else {
        _pageController.jumpToPage(indexToScroll);
      }
    }
  }

  void _onBottomNavTapped(int index) {
    if (index == _currentIndex) {
      if (index == 0) {
        _scrollToNextEkadashi(animate: true);
      } else if (index == 1) {
        _calendarKey.currentState?.resetToToday();
      }
    } else {
      setState(() => _currentIndex = index);
      if (index == 0) {
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

        if (!(prefs.getBool('notifications_enabled') ?? true)) {
          debugPrint('⚠️ Notifications disabled globally');
          return;
        }

        bool remind1 = prefs.getBool('remind_one_day_before') ?? true;
        bool remind2 = prefs.getBool('remind_two_days_before') ?? true;
        bool remindOnDay = prefs.getBool('remind_on_day') ?? true;

        final langService = Provider.of<LanguageService>(context, listen: false);
        await NotificationService().scheduleAllNotifications(
            dates, remind1, remind2, remindOnDay, langService.localizedStrings);

        debugPrint('✅ Background notification scheduling completed');
      } catch (e) {
        debugPrint("❌ Background notification error: $e");
      }
    });
  }

  Future<void> _loadData({String languageCode = 'en'}) async {
    // FIXED: Only show spinner on very first load
    final isInitialLoad = _ekadashiList.isEmpty;

    if (isInitialLoad) {
      setState(() => _isLoading = true);
    }

    try {
      final dates = await _ekadashiService.getUpcomingEkadashis(languageCode: languageCode);

      if (mounted) {
        // FIXED: Use AnimatedSwitcher for smooth transition
        setState(() {
          _ekadashiList = dates;
          _isLoading = false;
        });

        _scheduleNotificationsInBackground(dates);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToNextEkadashi(animate: false);
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) {
        final lang = Provider.of<LanguageService>(context, listen: false);
        setState(() {
          _errorMessage = lang.translate('failed_load');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageService>(
        builder: (context, languageService, child) {
          const tealColor = Color(0xFF00A19B);

          // FIXED: Use AnimatedSwitcher for smooth transition
          return Scaffold(
            appBar: _isLoading || _errorMessage.isNotEmpty
                ? null
                : AppBar(
              title: Text(languageService.translate('app_title')),
              centerTitle: true,
            ),
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isLoading
                  ? const Center(
                key: ValueKey('loading'),
                child: CircularProgressIndicator(color: tealColor),
              )
                  : _errorMessage.isNotEmpty
                  ? Center(
                key: ValueKey('error'),
                child: Text(_errorMessage),
              )
                  : _buildMainContent(languageService),
            ),
          );
        }
    );
  }

  Widget _buildMainContent(LanguageService languageService) {
    const tealColor = Color(0xFF00A19B);

    final pages = [
      _buildHomeTab(context),
      CalendarScreen(key: _calendarKey, ekadashiList: _ekadashiList),
      const SettingsScreen(),
    ];

    return Column(
      key: const ValueKey('content'),
      children: [
        Expanded(child: pages[_currentIndex]),
        BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onBottomNavTapped,
          selectedItemColor: tealColor,
          unselectedItemColor: Colors.grey,
          items: [
            BottomNavigationBarItem(
                icon: const Icon(Icons.home),
                label: languageService.translate('home')
            ),
            BottomNavigationBarItem(
                icon: const Icon(Icons.calendar_month),
                label: languageService.translate('calendar')
            ),
            BottomNavigationBarItem(
                icon: const Icon(Icons.settings),
                label: languageService.translate('settings')
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    const tealColor = Color(0xFF00A19B);
    final lang = Provider.of<LanguageService>(context);

    String locText = _locationText == 'Locating...' ? lang.translate('locating') : _locationText;
    if (locText.contains(',')) {
      locText = locText.split(',').first.trim();
    }

    String displayLanguage = "English";
    TextStyle langTextStyle = TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).textTheme.bodyMedium?.color
    );

    if (lang.currentLocale.languageCode == 'ta') {
      displayLanguage = "தமிழ்";
    } else if (lang.currentLocale.languageCode == 'hi') {
      displayLanguage = "हिंदी";
      langTextStyle = langTextStyle.copyWith(fontWeight: FontWeight.bold);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
          child: Row(
            children: [
              const Icon(Icons.location_on, size: 20, color: tealColor),
              const SizedBox(width: 8),
              Text(locText, style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyMedium?.color
              )),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (String newValue) {
                  lang.changeLanguage(newValue);
                },
                color: Theme.of(context).cardColor,
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(value: 'en', child: Text("English")),
                  const PopupMenuItem<String>(value: 'hi', child: Text("हिंदी", style: TextStyle(fontWeight: FontWeight.bold))),
                  const PopupMenuItem<String>(value: 'ta', child: Text("தமிழ்")),
                ],
                offset: const Offset(0, 40),
                child: Row(
                  children: [
                    Text(displayLanguage, style: langTextStyle),
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.language, color: tealColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  if (_pageController.page != null && _pageController.page! > 0) {
                    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  }
                },
                icon: const Icon(Icons.arrow_back_ios, size: 24),
                color: tealColor,
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _ekadashiList.length,
                  itemBuilder: (context, index) {
                    final ekadashi = _ekadashiList[index];
                    return _buildEkadashiCard(ekadashi);
                  },
                ),
              ),
              IconButton(
                onPressed: () {
                  if (_pageController.page != null && _pageController.page! < _ekadashiList.length -1) {
                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  }
                },
                icon: const Icon(Icons.arrow_forward_ios, size: 24),
                color: tealColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
      ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: daysUntil < 0 ? Colors.grey : tealColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    daysText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              Center(
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMM dd, yyyy').format(ekadashi.date),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w300),
                    ),
                    Text(
                      DateFormat('EEEE').format(ekadashi.date),
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      ekadashi.name,
                      style: const TextStyle(color: tealColor, fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              Text(lang.translate('start_fasting'), style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(DateFormat('MMM dd, yyyy').format(ekadashi.date), style: const TextStyle(fontSize: 14, color: Colors.grey)),
              Text(ekadashi.fastStartTime, style: const TextStyle(fontSize: 18)),

              const SizedBox(height: 20),

              Text(lang.translate('break_fasting'), style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(DateFormat('MMM dd, yyyy').format(ekadashi.date.add(const Duration(days: 1))), style: const TextStyle(fontSize: 14, color: Colors.grey)),
              Text(breakTime, style: const TextStyle(fontSize: 18)),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              Text(
                ekadashi.description,
                style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).textTheme.bodyMedium?.color
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 24),
              Center(
                child: SizedBox(
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
                    child: Text(lang.translate('view_details'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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