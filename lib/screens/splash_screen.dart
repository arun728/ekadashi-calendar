import 'package:flutter/material.dart';
import '../main.dart';

import '../services/ekadashi_service.dart';
import '../services/notification_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/time_zone_data.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final stopwatch = Stopwatch()..start();

    // Run initialization tasks
    // Priority 3: Keep EkadashiService blocking (needed for Home)
    await EkadashiService().initializeData();

    // Initialize locale data for DateFormat
    await initializeDateFormatting();

    // Initialize timezone database
    initializeTimeZoneData();

    debugPrint('Splash blocking init took: ${stopwatch.elapsedMilliseconds}ms');

    // Priority 3: Defer NotificationService init (fire-and-forget)
    NotificationService().init().then((_) {
      debugPrint(
        'NotificationService init completed (deferred) in ${stopwatch.elapsedMilliseconds}ms total',
      );
    });

    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
    }
  }

  @override
  /// Plain #121212 while the data loads, like the iOS launch screen (no
  /// artwork or text).
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: Color(0xFF121212));
}
