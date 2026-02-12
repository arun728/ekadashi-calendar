import 'package:flutter/material.dart';
import '../main.dart';

import '../services/ekadashi_service.dart';
import '../services/notification_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;

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
    tz.initializeTimeZones();

    debugPrint('Splash blocking init took: ${stopwatch.elapsedMilliseconds}ms');

    // Priority 3: Defer NotificationService init (fire-and-forget)
    NotificationService().init().then((_) {
      debugPrint('NotificationService init completed (deferred) in ${stopwatch.elapsedMilliseconds}ms total');
    });

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 100,
              width: 100,
              child: Stack(
                alignment: Alignment.center,
                children: const [
                   Positioned(
                    top: 0,
                    child: Icon(Icons.wb_sunny_outlined, size: 40, color: Colors.orangeAccent),
                  ),
                  Positioned(
                    bottom: 0,
                    child: Icon(Icons.spa, size: 80, color: Color(0xFF00A19B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ekadashi Calendar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Om Namo Narayana!',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Color(0xFF00A19B)),
          ],
        ),
      ),
    );
  }
}
