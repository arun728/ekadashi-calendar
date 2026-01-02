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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupSequence();
    });
  }

  Future<void> _runStartupSequence() async {
    await NotificationService().requestPermissions();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      await _handleLocation();
    }
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

      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        setState(() => _locationText = '${place.locality}, ${place.administrativeArea}');
      }
    } catch (e) {
      if (mounted) setState(() => _locationText = 'Chennai, TN');
    }
  }

  void _scrollToNextEkadashi({bool animate = true}) {
    if (_ekadashiList.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int indexToScroll = 0;

    // Find first future or today's Ekadashi
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
        // Tap Home again -> Scroll to upcoming with animation
        _scrollToNextEkadashi(animate: true);
      } else if (index == 1) {
        _calendarKey.currentState?.resetToToday();
      }
    } else {
      setState(() => _currentIndex = index);
      // Switching BACK to Home -> Jump instantly
      if (index == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToNextEkadashi(animate: false);
        });
      }
    }
  }

  Future<void> _loadData({String languageCode = 'en'}) async {
    setState(() => _isLoading = true);

    try {
      final dates = await _ekadashiService.getUpcomingEkadashis(languageCode: languageCode);

      try {
        final prefs = await SharedPreferences.getInstance();
        bool remind1 = prefs.getBool('remind_one_day_before') ?? true;
        bool remind2 = prefs.getBool('remind_two_days_before') ?? true;
        bool remindOnDay = prefs.getBool('remind_on_day') ?? true;

        if (prefs.getBool('notifications_enabled') ?? true) {
          final langService = Provider.of<LanguageService>(context, listen: false);
          await NotificationService().cancelAll();
          await NotificationService().scheduleAllNotifications(
              dates, remind1, remind2, remindOnDay, langService.localizedStrings);
        }
      } catch (e) {
        debugPrint("Notification schedule error: $e");
      }

      if (mounted) {
        setState(() {
          _ekadashiList = dates;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // First load -> Jump instantly
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

          if (_isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: tealColor)),
            );
          }
          if (_errorMessage.isNotEmpty) {
            return Scaffold(
              body: Center(child: Text(_errorMessage)),
            );
          }

          final pages = [
            _buildHomeTab(context),
            CalendarScreen(key: _calendarKey, ekadashiList: _ekadashiList),
            const SettingsScreen(),
          ];

          return Scaffold(
            appBar: AppBar(
              title: Text(languageService.translate('app_title')),
              centerTitle: true,
            ),
            body: pages[_currentIndex],
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onBottomNavTapped,
              selectedItemColor: const Color(0xFF00A19B),
              unselectedItemColor: Colors.grey,
              items: [
                BottomNavigationBarItem(icon: const Icon(Icons.home), label: languageService.translate('home')),
                BottomNavigationBarItem(icon: const Icon(Icons.calendar_month), label: languageService.translate('calendar')),
                BottomNavigationBarItem(icon: const Icon(Icons.settings), label: languageService.translate('settings')),
              ],
            ),
          );
        }
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    const tealColor = Color(0xFF00A19B);
    final lang = Provider.of<LanguageService>(context);

    String locText = _locationText == 'Locating...' ? lang.translate('locating') : _locationText;
    if (locText.contains(',')) {
      locText = locText.split(',').first.trim();
    }

    // Determine display text for the button based on current language
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
              // REPLACED DropdownButton with PopupMenuButton
              PopupMenuButton<String>(
                onSelected: (String newValue) {
                  lang.changeLanguage(newValue);
                },
                color: Theme.of(context).cardColor,
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(value: 'en', child: Text("English")),
                  // Reordered: Hindi first, then Tamil
                  const PopupMenuItem<String>(value: 'hi', child: Text("हिंदी", style: TextStyle(fontWeight: FontWeight.bold))),
                  const PopupMenuItem<String>(value: 'ta', child: Text("தமிழ்")),
                ],
                // Adjust offset if needed to push menu down slightly
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