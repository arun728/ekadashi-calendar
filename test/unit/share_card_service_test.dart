import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gal/gal.dart';
import 'package:ekadashi_calendar/services/share_card_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ShareCardService Unit Tests', () {
    final service = ShareCardService();

    test('buildShareSummary presents app description without emojis and provides expandable download link to landing page', () {
      final summary = service.buildShareSummary(
        ekadashiName: 'Vaikuntha Ekadashi',
        dateFormatted: '2026-12-20',
        traditionName: 'Vaishnava',
        fastingStart: '05:30 AM',
        paranaWindow: '06:45 AM - 09:30 AM',
        locationName: 'Chennai, Tamil Nadu',
        spiritualMessage: 'Observing this fast bestows moksha and supreme spiritual bliss.',
      );

      // Must be EXACTLY the default share message
      expect(summary, equals(ShareCardService.defaultShareMessage));
      expect(
        summary,
        equals(
          'Ekadashi Calendar\n\n'
          'Check Ekadashi dates, fasting timings, Parana windows, and spiritual significance.\n\n'
          '[Download the app](https://sakthivel-rajendhran.github.io/ekadashi-calendar/download.html)',
        ),
      );

      // Exact normal text verification (without emojis)
      expect(summary.contains('Ekadashi Calendar'), isTrue);
      expect(
        summary.contains('Check Ekadashi dates, fasting timings, Parana windows, and spiritual significance.'),
        isTrue,
      );
      expect(summary.contains('Download the app'), isTrue);

      // Verify NO emojis are present
      expect(summary.contains('🙏'), isFalse);
      expect(summary.contains('📲'), isFalse);
      expect(summary.contains('🌸'), isFalse);
      expect(summary.contains('📅'), isFalse);

      // Raw Play Store URL is NOT displayed in the shared text
      expect(summary.contains('play.google.com'), isFalse);
      expect(summary.contains(ShareCardService.officialDownloadUrl), isFalse);

      // Link directs to the hosted landing page with the expandable interaction
      expect(summary.contains(ShareCardService.landingPageUrl), isTrue);

      // Must NOT contain per-event dates, timings, locations, or quotes
      expect(summary.contains('Vaikuntha Ekadashi'), isFalse);
      expect(summary.contains('2026-12-20'), isFalse);
      expect(summary.contains('Tradition'), isFalse);
      expect(summary.contains('Fasting Begins'), isFalse);
      expect(summary.contains('Parana Window'), isFalse);
      expect(summary.contains('Chennai'), isFalse);
      expect(summary.contains('Observing this fast'), isFalse);
    });

    test('buildShareSummary without parameters returns default share message', () {
      final summary = service.buildShareSummary();

      expect(summary, equals(ShareCardService.defaultShareMessage));
      expect(service.shareMessage, equals(ShareCardService.defaultShareMessage));
    });

    test('officialDownloadUrl matches expected Play Store URL and downloadUrl getter', () {
      expect(
        ShareCardService.officialDownloadUrl,
        equals('https://play.google.com/store/apps/details?id=com.applausestudios.ekadashi_calendar'),
      );
      expect(service.downloadUrl, equals(ShareCardService.officialDownloadUrl));
      expect(
        ShareCardService.landingPageUrl,
        equals('https://sakthivel-rajendhran.github.io/ekadashi-calendar/download.html'),
      );
      expect(service.landingUrl, equals(ShareCardService.landingPageUrl));
    });

    test('CardDesignTheme exclusively contains the divine teal / emerald green theme', () {
      expect(CardDesignTheme.values.length, equals(1));
      final theme = CardDesignTheme.values.first;
      expect(theme, equals(CardDesignTheme.divineTeal));
      expect(theme.id, equals('divine_teal'));
      expect(theme.translationKey, equals('design_divine_teal'));
      expect(theme.gradientColors.length, greaterThanOrEqualTo(2));
      expect(theme.accentColor.opacity, 1.0);
      expect(theme.cardBorderColor.opacity, greaterThan(0.0));
    });

    test('saveImageToGallery returns GallerySaveResult.success on successful save', () async {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);
      bool saverCalled = false;

      final result = await service.saveImageToGallery(
        dummyBytes,
        filename: 'test_card',
        customSaver: (bytes, {String? album, String name = 'image'}) async {
          saverCalled = true;
          expect(bytes, equals(dummyBytes));
          expect(album, equals('Ekadashi Calendar'));
          expect(name, equals('test_card'));
        },
      );

      expect(saverCalled, isTrue);
      expect(result.isSuccess, isTrue);
      expect(result.status, equals(GallerySaveStatus.success));
      expect(result.isPermissionDenied, isFalse);
    });

    test('saveImageToGallery handles GalException.accessDenied and returns permissionDenied', () async {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

      final result = await service.saveImageToGallery(
        dummyBytes,
        filename: 'test_denied',
        customSaver: (bytes, {String? album, String name = 'image'}) async {
          throw GalException(
            type: GalExceptionType.accessDenied,
            platformException: PlatformException(code: 'ACCESS_DENIED', message: 'Permission denied'),
            stackTrace: StackTrace.current,
          );
        },
      );

      expect(result.isSuccess, isFalse);
      expect(result.isPermissionDenied, isTrue);
      expect(result.status, equals(GallerySaveStatus.permissionDenied));
    });

    test('saveImageToGallery handles unexpected exceptions and returns failure', () async {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);

      final result = await service.saveImageToGallery(
        dummyBytes,
        filename: 'test_error',
        customSaver: (bytes, {String? album, String name = 'image'}) async {
          throw Exception('Disk full or I/O failure');
        },
      );

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.status, equals(GallerySaveStatus.failure));
      expect(result.errorMessage?.contains('Disk full'), isTrue);
    });

    test('Localization keys for Share Cards exist in all 4 supported languages', () async {
      final lang = LanguageService();
      final requiredKeys = [
        'share_card',
        'share_card_title',
        'choose_design',
        'design_sacred_gold',
        'design_divine_teal',
        'design_cosmic_blue',
        'save_to_device',
        'image_saved_success',
        'image_save_error',
        'sharing_card',
        'spiritual_quote_default',
        'ekadashi_observance',
        'parana_window_label',
        'fasting_begins',
        'card_branding',
        'gallery_save_success',
        'gallery_permission_denied',
        'gallery_save_error',
        'open_settings',
        'get_app_label',
      ];

      final supportedLangs = ['en', 'ta', 'hi', 'te'];

      for (final code in supportedLangs) {
        await lang.changeLanguage(code);
        for (final key in requiredKeys) {
          final translated = lang.translate(key);
          expect(
            translated.isNotEmpty,
            isTrue,
            reason: 'Missing or empty translation for key "$key" in language "$code"',
          );
          // Key should not just return itself
          expect(
            translated,
            isNot(equals(key)),
            reason: 'Translation returned raw key for "$key" in language "$code"',
          );
        }
      }
    });
  });
}
