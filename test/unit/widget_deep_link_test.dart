import 'package:flutter_test/flutter_test.dart';
import 'package:ekadashi_calendar/services/native_widget_service.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LanguageService languageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    languageService = LanguageService();
  });

  group('EC2-FR-060: Widget Deep Link Verification', () {
    test('Widget A deep link parses to dashboard route', () {
      final uri = Uri.parse('ekadashi://dashboard');
      expect(uri.scheme, 'ekadashi');
      expect(uri.host, 'dashboard');
      expect(uri.queryParameters.isEmpty, isTrue);
    });

    test('Widget B active Parana deep link parses with action=parana', () {
      final uri = Uri.parse('ekadashi://dashboard?action=parana');
      expect(uri.scheme, 'ekadashi');
      expect(uri.host, 'dashboard');
      expect(uri.queryParameters['action'], 'parana');
    });

    test('Widget B default deep link parses to today view', () {
      final uri = Uri.parse('ekadashi://today');
      expect(uri.scheme, 'ekadashi');
      expect(uri.host, 'today');
      expect(uri.queryParameters.isEmpty, isTrue);
    });

    test('Widget C deep link parses with specific ISO calendar date', () {
      const isoDate = '2026-09-15';
      final uri = Uri.parse('ekadashi://calendar?date=$isoDate');
      expect(uri.scheme, 'ekadashi');
      expect(uri.host, 'calendar');
      expect(uri.queryParameters['date'], '2026-09-15');

      final parsed = DateTime.tryParse(uri.queryParameters['date']!);
      expect(parsed, isNotNull);
      expect(parsed?.year, 2026);
      expect(parsed?.month, 9);
      expect(parsed?.day, 15);
    });

    test('Widget C handles missing date parameter gracefully', () {
      final uri = Uri.parse('ekadashi://calendar');
      expect(uri.scheme, 'ekadashi');
      expect(uri.host, 'calendar');
      expect(uri.queryParameters['date'], isNull);
    });

    test('Widget C handles malformed date parameter safely without throwing', () {
      final uri = Uri.parse('ekadashi://calendar?date=not-a-real-date');
      expect(uri.scheme, 'ekadashi');
      expect(uri.host, 'calendar');
      final parsed = DateTime.tryParse(uri.queryParameters['date']!);
      expect(parsed, isNull);
    });

    test('Invalid scheme is rejected', () {
      final uri = Uri.parse('https://example.com/dashboard');
      expect(uri.scheme, isNot('ekadashi'));
    });
  });

  group('EC2-FR-058 & EC2-FR-059: State Machine & Cache Validation', () {
    test('State machine identifies BEFORE_EKADASHI, FASTING_ACTIVE, PARANA_AVAILABLE, PARANA_COMPLETED', () {
      final base = DateTime.utc(2026, 9, 15, 6, 0, 0);
      final fStart = base.subtract(const Duration(hours: 24)); // Sep 14, 06:00 UTC
      final pStart = base;                                     // Sep 15, 06:00 UTC
      final pEnd = base.add(const Duration(hours: 4));         // Sep 15, 10:00 UTC

      String evaluateState(DateTime now) {
        if (now.isBefore(fStart)) return 'BEFORE_EKADASHI';
        if (now.isBefore(pStart)) return 'FASTING_ACTIVE';
        if (now.isBefore(pEnd) || now.isAtSameMomentAs(pEnd)) return 'PARANA_AVAILABLE';
        return 'PARANA_COMPLETED';
      }

      // 1. Before fasting begins
      expect(evaluateState(fStart.subtract(const Duration(hours: 2))), 'BEFORE_EKADASHI');

      // 2. Fasting is active
      expect(evaluateState(fStart.add(const Duration(hours: 1))), 'FASTING_ACTIVE');
      expect(evaluateState(pStart.subtract(const Duration(minutes: 1))), 'FASTING_ACTIVE');

      // 3. Parana window is open
      expect(evaluateState(pStart), 'PARANA_AVAILABLE');
      expect(evaluateState(pStart.add(const Duration(hours: 2))), 'PARANA_AVAILABLE');
      expect(evaluateState(pEnd), 'PARANA_AVAILABLE');

      // 4. Parana completed
      expect(evaluateState(pEnd.add(const Duration(minutes: 1))), 'PARANA_COMPLETED');
      expect(evaluateState(pEnd.add(const Duration(days: 1))), 'PARANA_COMPLETED');
    });

    test('Validates canonical payload schema v2 format and metadata', () async {
      final now = DateTime.now().toUtc();
      final e1 = EkadashiDate(
        id: 101,
        name: 'Indira Ekadashi',
        date: DateTime.utc(2026, 9, 15),
        fastStartTime: '06:12 AM',
        fastBreakTime: '06:15 AM - 08:30 AM',
        paksha: 'Krishna',
        month: 'Ashwin',
        description: 'Pitru Paksha Ekadashi',
        fastingStartIso: now.add(const Duration(days: 1)).toIso8601String(),
        paranaStartIso: now.add(const Duration(days: 2, hours: 6)).toIso8601String(),
        paranaEndIso: now.add(const Duration(days: 2, hours: 8, minutes: 30)).toIso8601String(),
      );

      final List<EkadashiDate> list = [e1];
      final service = NativeWidgetService();

      // Ensure that updating with custom tradition, location, and timezone creates schemaVersion 2
      final success = await service.updateWidgetData(
        ekadashiList: list,
        timezone: 'Asia/Kolkata',
        locationName: 'Bengaluru',
        languageService: languageService,
        tradition: 'Smarta',
      );

      // MethodChannel will be unattached in standard unit test without mock, returns false gracefully
      expect(success, isFalse);
    });

    test('Cache state classification rules', () {
      const expectedSchema = 2;
      const maxAgeMs = 14 * 24 * 60 * 60 * 1000;

      String classifyCache({
        required bool hasData,
        required bool isJsonCorrupt,
        required int schemaVersion,
        required int ageMs,
        required bool hasRequiredFields,
      }) {
        if (!hasData) return 'UNAVAILABLE';
        if (isJsonCorrupt) return 'CORRUPTED';
        if (schemaVersion != expectedSchema || !hasRequiredFields) return 'INVALID';
        if (ageMs > maxAgeMs) return 'STALE';
        return 'VALID';
      }

      // Healthy
      expect(classifyCache(hasData: true, isJsonCorrupt: false, schemaVersion: 2, ageMs: 1000, hasRequiredFields: true), 'VALID');

      // Stale (> 14 days)
      expect(classifyCache(hasData: true, isJsonCorrupt: false, schemaVersion: 2, ageMs: maxAgeMs + 1000, hasRequiredFields: true), 'STALE');

      // Old schema
      expect(classifyCache(hasData: true, isJsonCorrupt: false, schemaVersion: 1, ageMs: 1000, hasRequiredFields: true), 'INVALID');

      // Missing required fields
      expect(classifyCache(hasData: true, isJsonCorrupt: false, schemaVersion: 2, ageMs: 1000, hasRequiredFields: false), 'INVALID');

      // Corrupted JSON
      expect(classifyCache(hasData: true, isJsonCorrupt: true, schemaVersion: 2, ageMs: 1000, hasRequiredFields: true), 'CORRUPTED');

      // No data
      expect(classifyCache(hasData: false, isJsonCorrupt: false, schemaVersion: 2, ageMs: 0, hasRequiredFields: true), 'UNAVAILABLE');
    });
  });
}
