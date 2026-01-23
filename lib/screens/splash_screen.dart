import 'package:flutter/material.dart';
import '../main.dart';

import '../services/ekadashi_service.dart';
import '../services/notification_service.dart';

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
    // Run initialization tasks
    await Future.wait([
      NotificationService().init(),
      EkadashiService().initializeData(),
      // Ensure splash is visible for at least 2 seconds
      Future.delayed(const Duration(seconds: 2)), 
    ]);

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
