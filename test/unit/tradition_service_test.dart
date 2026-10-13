import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ekadashi_calendar/services/tradition_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TraditionService Unit Tests', () {
    test('Default preference is General when SharedPreferences is empty', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TraditionService();
      await service.loadTradition();

      expect(service.currentTradition, AppTradition.general);
      expect(service.traditionId, 'general');
    });

    test('Selecting Smarta updates currentTradition and persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TraditionService();
      await service.loadTradition();

      bool listenerNotified = false;
      service.addListener(() {
        listenerNotified = true;
      });

      await service.setTradition(AppTradition.smarta);

      expect(service.currentTradition, AppTradition.smarta);
      expect(service.traditionId, 'smarta');
      expect(listenerNotified, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_tradition'), 'smarta');
      expect(prefs.getBool('tradition_onboarding_completed'), isTrue);
    });

    test('Selecting Vaishnava updates currentTradition and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TraditionService();
      await service.loadTradition();

      await service.setTradition(AppTradition.vaishnava);

      expect(service.currentTradition, AppTradition.vaishnava);
      expect(service.traditionId, 'vaishnava');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_tradition'), 'vaishnava');
    });

    test('Loads pre-saved tradition from SharedPreferences correctly', () async {
      SharedPreferences.setMockInitialValues({'user_tradition': 'vaishnava'});
      final service = TraditionService();
      await service.loadTradition();

      expect(service.currentTradition, AppTradition.vaishnava);
    });

    test('Invalid or unknown stored tradition falls back safely to General', () async {
      SharedPreferences.setMockInitialValues({'user_tradition': 'unknown_tradition_xyz'});
      final service = TraditionService();
      await service.loadTradition();

      expect(service.currentTradition, AppTradition.general);
    });

    test('Onboarding completion marks tradition_onboarding_completed', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TraditionService();
      await service.loadTradition();

      expect(await service.hasCompletedOnboarding(), isFalse);

      await service.completeOnboarding(AppTradition.smarta);

      expect(await service.hasCompletedOnboarding(), isTrue);
      expect(service.currentTradition, AppTradition.smarta);
    });
  });
}
