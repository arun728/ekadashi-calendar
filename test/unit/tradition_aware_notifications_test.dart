import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:ekadashi_calendar/services/tradition_service.dart';
import 'package:ekadashi_calendar/services/language_service.dart';
import 'package:ekadashi_calendar/services/ekadashi_service.dart';
import 'package:ekadashi_calendar/services/notification_service.dart';
import 'package:ekadashi_calendar/services/tradition_notification_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

  group('Module 11 Area 6: TraditionNotificationHelper Content & Localization Tests', () {
    test('Tradition tags for General, Smarta, and Vaishnava in EN, TA, and HI', () {
      // General has no prefix (clean notification title)
      expect(TraditionNotificationHelper.getTraditionTag(AppTradition.general, 'en'), '');
      expect(TraditionNotificationHelper.getTraditionTag(AppTradition.general, 'ta'), '');
      expect(TraditionNotificationHelper.getTraditionTag(AppTradition.general, 'hi'), '');

      // Smarta
      expect(TraditionNotificationHelper.getTraditionTag(AppTradition.smarta, 'en'), '[Smarta]');
      expect(TraditionNotificationHelper.getTraditionTag(AppTradition.smarta, 'ta'), '[ஸ்மார்த்தா]');
      expect(TraditionNotificationHelper.getTraditionTag(AppTradition.smarta, 'hi'), '[स्मार्त]');

      // Vaishnava
      expect(TraditionNotificationHelper.getTraditionTag(AppTradition.vaishnava, 'en'), '[Vaishnava]');
      expect(TraditionNotificationHelper.getTraditionTag(AppTradition.vaishnava, 'ta'), '[வைணவம்]');
      expect(TraditionNotificationHelper.getTraditionTag(AppTradition.vaishnava, 'hi'), '[वैष्णव]');
    });

    test('English notification content for all 4 reminder types across traditions', () {
      const ekadashi = 'Vijaya Ekadashi';
      const fastTime = '06:40 AM';
      const paranaWin = '07:05 AM - 09:15 AM';

      // 1. General (clean title, no bracket)
      final gen2Day = TraditionNotificationHelper.buildContent(
        type: NotificationReminderType.twoDaysBefore,
        ekadashiName: ekadashi,
        tradition: AppTradition.general,
        languageCode: 'en',
      );
      expect(gen2Day.title, 'Upcoming Ekadashi');
      expect(gen2Day.body, contains('Vijaya Ekadashi is in 2 days'));

      // 2. Smarta 1-Day Before
      final smarta1Day = TraditionNotificationHelper.buildContent(
        type: NotificationReminderType.oneDayBefore,
        ekadashiName: ekadashi,
        tradition: AppTradition.smarta,
        languageCode: 'en',
        fastStartTime: fastTime,
      );
      expect(smarta1Day.title, '[Smarta] Ekadashi Tomorrow!');
      expect(smarta1Day.body, contains('Fasting starts at 06:40 AM'));

      // 3. Vaishnava Fasting Day Start
      final vaishnavaStart = TraditionNotificationHelper.buildContent(
        type: NotificationReminderType.fastingDay,
        ekadashiName: ekadashi,
        tradition: AppTradition.vaishnava,
        languageCode: 'en',
      );
      expect(vaishnavaStart.title, '[Vaishnava] Ekadashi Starts Now');
      expect(vaishnavaStart.body, 'Today is Vijaya Ekadashi. Fasting begins now.');

      // 4. Vaishnava Parana Day (fast break window)
      final vaishnavaParana = TraditionNotificationHelper.buildContent(
        type: NotificationReminderType.paranaDay,
        ekadashiName: ekadashi,
        tradition: AppTradition.vaishnava,
        languageCode: 'en',
        paranaWindow: paranaWin,
      );
      expect(vaishnavaParana.title, '[Vaishnava] Parana Time');
      expect(vaishnavaParana.body, contains('You can break your fast now'));
      expect(vaishnavaParana.body, contains(paranaWin));

      // 5. Upcoming Parana Window
      final upcomingParana = TraditionNotificationHelper.buildContent(
        type: NotificationReminderType.upcomingParana,
        ekadashiName: ekadashi,
        tradition: AppTradition.smarta,
        languageCode: 'en',
        paranaWindow: paranaWin,
      );
      expect(upcomingParana.title, '[Smarta] Upcoming Parana Window');
      expect(upcomingParana.body, contains(paranaWin));
    });

    test('Tamil notification content for all reminder types across traditions', () {
      const ekadashi = 'விஜய ஏகாதசி';
      const fastTime = '06:40 AM';
      const paranaWin = '07:05 AM - 09:15 AM';

      // General 2-Day
      final gen2Day = TraditionNotificationHelper.buildContent(
        type: NotificationReminderType.twoDaysBefore,
        ekadashiName: ekadashi,
        tradition: AppTradition.general,
        languageCode: 'ta',
      );
      expect(gen2Day.title, 'வரவிருக்கும் ஏகாதசி');
      expect(gen2Day.body, contains('2 நாட்களில் வருகிறது'));

      // Smarta 1-Day
      final smarta1Day = TraditionNotificationHelper.buildContent(
        type: NotificationReminderType.oneDayBefore,
        ekadashiName: ekadashi,
        tradition: AppTradition.smarta,
        languageCode: 'ta',
        fastStartTime: fastTime,
      );
      expect(smarta1Day.title, '[ஸ்மார்த்தா] நாளை ஏகாதசி!');
      expect(smarta1Day.body, contains('06:40 AM'));

      // Vaishnava Fasting Day Start
      final vaishnavaStart = TraditionNotificationHelper.buildContent(
        type: NotificationReminderType.fastingDay,
        ekadashiName: ekadashi,
        tradition: AppTradition.vaishnava,
        languageCode: 'ta',
      );
      expect(vaishnavaStart.title, '[வைணவம்] ஏகாதசி தொடங்குகிறது');
      expect(vaishnavaStart.body, contains('இன்று விஜய ஏகாதசி'));

      // Vaishnava Parana Day
      final vaishnavaParana = TraditionNotificationHelper.buildContent(
        type: NotificationReminderType.paranaDay,
        ekadashiName: ekadashi,
        tradition: AppTradition.vaishnava,
        languageCode: 'ta',
        paranaWindow: paranaWin,
      );
      expect(vaishnavaParana.title, '[வைணவம்] பாரணை நேரம்');
      expect(vaishnavaParana.body, contains('இப்போது விரதத்தை முடிக்கலாம்'));
    });

    test('Hindi notification content for all reminder types across traditions', () {
      const ekadashi = 'विजया एकादशी';
      const fastTime = '06:40 AM';
      const paranaWin = '07:05 AM - 09:15 AM';

      // General 2-Day
      final gen2Day = TraditionNotificationHelper.buildContent(
        type: NotificationReminderType.twoDaysBefore,
        ekadashiName: ekadashi,
        tradition: AppTradition.general,
        languageCode: 'hi',
      );
      expect(gen2Day.title, 'आगामी एकादशी');
      expect(gen2Day.body, contains('2 दिनों में है'));

      // Smarta 1-Day
      final smarta1Day = TraditionNotificationHelper.buildContent(
        type: NotificationReminderType.oneDayBefore,
        ekadashiName: ekadashi,
        tradition: AppTradition.smarta,
        languageCode: 'hi',
        fastStartTime: fastTime,
      );
      expect(smarta1Day.title, '[स्मार्त] कल एकादशी!');
      expect(smarta1Day.body, contains('06:40 AM'));

      // Vaishnava Fasting Day Start
      final vaishnavaStart = TraditionNotificationHelper.buildContent(
        type: NotificationReminderType.fastingDay,
        ekadashiName: ekadashi,
        tradition: AppTradition.vaishnava,
        languageCode: 'hi',
      );
      expect(vaishnavaStart.title, '[वैष्णव] एकादशी अब शुरू');
      expect(vaishnavaStart.body, contains('आज है विजया एकादशी'));

      // Vaishnava Parana Day
      final vaishnavaParana = TraditionNotificationHelper.buildContent(
        type: NotificationReminderType.paranaDay,
        ekadashiName: ekadashi,
        tradition: AppTradition.vaishnava,
        languageCode: 'hi',
        paranaWindow: paranaWin,
      );
      expect(vaishnavaParana.title, '[वैष्णव] पारण का समय');
      expect(vaishnavaParana.body, contains('अब व्रत तोड़ सकते हैं'));
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });
  });

  group('Module 11 Area 6: Tradition-Specific Notification Scheduling & Timestamps', () {
    late NotificationService notificationService;

    // Use a date securely in the future relative to current time (e.g., +15 days)
    // with Smarta on Day 15 and Vaishnava on Day 16 to test tradition shift
    late DateTime futureDateSmarta;
    late DateTime futureDateVaishnava;
    late EkadashiDate mockFutureEkadashi;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      notificationService = NotificationService();
      await notificationService.cancelAll();

      final baseFuture = DateTime.now().add(const Duration(days: 15));
      futureDateSmarta = DateTime(baseFuture.year, baseFuture.month, baseFuture.day, 6, 40);
      futureDateVaishnava = futureDateSmarta.add(const Duration(days: 1));

      final smartaVariant = TraditionVariant(
        tradition: AppTradition.smarta,
        date: DateTime(futureDateSmarta.year, futureDateSmarta.month, futureDateSmarta.day),
        fastStartTime: '06:40 AM',
        fastBreakTime: '07:05 AM - 09:15 AM',
        fastingStartIso: futureDateSmarta.toIso8601String(),
        paranaStartIso: futureDateSmarta.add(const Duration(days: 1, hours: 1)).toIso8601String(),
        paranaEndIso: futureDateSmarta.add(const Duration(days: 1, hours: 3)).toIso8601String(),
      );

      final vaishnavaVariant = TraditionVariant(
        tradition: AppTradition.vaishnava,
        date: DateTime(futureDateVaishnava.year, futureDateVaishnava.month, futureDateVaishnava.day),
        fastStartTime: '06:40 AM',
        fastBreakTime: '07:04 AM - 09:14 AM',
        fastingStartIso: futureDateVaishnava.toIso8601String(),
        paranaStartIso: futureDateVaishnava.add(const Duration(days: 1, hours: 1)).toIso8601String(),
        paranaEndIso: futureDateVaishnava.add(const Duration(days: 1, hours: 3)).toIso8601String(),
      );

      mockFutureEkadashi = EkadashiDate(
        id: 25,
        name: 'Devutthana Ekadashi',
        date: DateTime(futureDateSmarta.year, futureDateSmarta.month, futureDateSmarta.day),
        fastStartTime: '06:40 AM',
        fastBreakTime: '07:05 AM - 09:15 AM',
        description: 'Awakening of Lord Vishnu',
        fastingStartIso: futureDateSmarta.toIso8601String(),
        paranaStartIso: futureDateSmarta.add(const Duration(days: 1, hours: 1)).toIso8601String(),
        paranaEndIso: futureDateSmarta.add(const Duration(days: 1, hours: 3)).toIso8601String(),
        hasTraditionVariation: true,
        traditionVariants: {
          AppTradition.smarta: smartaVariant,
          AppTradition.vaishnava: vaishnavaVariant,
        },
      );
    });

    test('Schedules notifications for Smarta preference with future fasting and Parana', () async {
      final resolved = EkadashiService().resolveEkadashiObservance(
        event: mockFutureEkadashi,
        userTradition: AppTradition.smarta,
      );

      final texts = LanguageService().localizedStrings;

      final count = await notificationService.scheduleAllNotifications(
        [resolved.primary],
        true, // remind1Day
        true, // remind2Days
        true, // remindOnDay
        texts,
        remindOnParana: true,
        tradition: AppTradition.smarta,
        languageCode: 'en',
      );

      expect(notificationService.scheduledCount, count);
      expect(count, greaterThan(0));

      for (var record in notificationService.scheduledNotifications) {
        expect(record.tradition, AppTradition.smarta);
        expect(record.title, startsWith('[Smarta]'));
        expect(record.ekadashiId, 25);
      }
    });

    test('Schedules notifications for Vaishnava preference with tradition shift', () async {
      final resolved = EkadashiService().resolveEkadashiObservance(
        event: mockFutureEkadashi,
        userTradition: AppTradition.vaishnava,
      );

      expect(resolved.primary.date, DateTime(futureDateVaishnava.year, futureDateVaishnava.month, futureDateVaishnava.day));

      final texts = LanguageService().localizedStrings;

      await notificationService.scheduleAllNotifications(
        [resolved.primary],
        true,
        true,
        true,
        texts,
        remindOnParana: true,
        tradition: AppTradition.vaishnava,
        languageCode: 'en',
      );

      expect(notificationService.scheduledCount, greaterThan(0));
      for (var record in notificationService.scheduledNotifications) {
        expect(record.tradition, AppTradition.vaishnava);
        expect(record.title, startsWith('[Vaishnava]'));
      }
    });

    test('Automatic cancellation and rescheduling when tradition changes', () async {
      final texts = LanguageService().localizedStrings;

      // 1. Initial schedule with Smarta
      final smartaResolved = EkadashiService().resolveEkadashiObservance(
        event: mockFutureEkadashi,
        userTradition: AppTradition.smarta,
      );
      await notificationService.scheduleAllNotifications(
        [smartaResolved.primary],
        true, true, true, texts,
        remindOnParana: true,
        tradition: AppTradition.smarta,
        languageCode: 'en',
      );

      final initialSmartaCount = notificationService.scheduledCount;
      expect(initialSmartaCount, greaterThan(0));
      for (var record in notificationService.scheduledNotifications) {
        expect(record.tradition, AppTradition.smarta);
      }

      // 2. User switches tradition to Vaishnava -> Reschedule triggers
      final vaishnavaResolved = EkadashiService().resolveEkadashiObservance(
        event: mockFutureEkadashi,
        userTradition: AppTradition.vaishnava,
      );
      await notificationService.scheduleAllNotifications(
        [vaishnavaResolved.primary],
        true, true, true, texts,
        remindOnParana: true,
        tradition: AppTradition.vaishnava,
        languageCode: 'en',
      );

      // Verify that all scheduled notifications are now Vaishnava, not Smarta
      expect(notificationService.scheduledCount, greaterThan(0));
      for (var record in notificationService.scheduledNotifications) {
        expect(record.tradition, AppTradition.vaishnava);
        expect(record.title, startsWith('[Vaishnava]'));
      }
      expect(
        notificationService.scheduledNotifications.any((n) => n.tradition == AppTradition.smarta),
        isFalse,
        reason: 'Outdated Smarta notifications must be completely cancelled and replaced',
      );
    });

    test('Duplicate prevention: Scheduling multiple times does not produce duplicate notifications', () async {
      final texts = LanguageService().localizedStrings;
      final resolved = EkadashiService().resolveEkadashiObservance(
        event: mockFutureEkadashi,
        userTradition: AppTradition.general,
      );

      // First run
      final firstCount = await notificationService.scheduleAllNotifications(
        [resolved.primary],
        true, true, true, texts,
        remindOnParana: true,
        tradition: AppTradition.general,
        languageCode: 'en',
      );

      // Second run with same parameters
      final secondCount = await notificationService.scheduleAllNotifications(
        [resolved.primary],
        true, true, true, texts,
        remindOnParana: true,
        tradition: AppTradition.general,
        languageCode: 'en',
      );

      expect(firstCount, secondCount);
      expect(notificationService.scheduledCount, firstCount);

      // Verify deterministic IDs are unique
      final ids = notificationService.scheduledNotifications.map((n) => n.id).toList();
      final uniqueIds = ids.toSet().toList();
      expect(ids.length, uniqueIds.length, reason: 'Deterministic IDs prevent duplicate collisions');
    });

    test('Disabled reminders return 0 and cancel all existing notifications', () async {
      final texts = LanguageService().localizedStrings;
      final resolved = EkadashiService().resolveEkadashiObservance(
        event: mockFutureEkadashi,
        userTradition: AppTradition.smarta,
      );

      // Schedule first
      await notificationService.scheduleAllNotifications(
        [resolved.primary],
        true, true, true, texts,
        remindOnParana: true,
        tradition: AppTradition.smarta,
      );
      expect(notificationService.scheduledCount, greaterThan(0));

      // Now disable all toggles
      final count = await notificationService.scheduleAllNotifications(
        [resolved.primary],
        false, false, false, texts,
        remindOnParana: false,
        remindUpcomingParana: false,
        tradition: AppTradition.smarta,
      );

      expect(count, 0);
      expect(notificationService.scheduledCount, 0);
    });

    test('Preserves unrelated notification preferences across tradition changes', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': true,
        'remind_one_day_before': true,
        'remind_two_days_before': false, // User disabled 2-day reminder
        'remind_on_day': true,
        'remind_on_parana': true,
        'user_tradition': 'smarta',
      });

      final prefs = await SharedPreferences.getInstance();
      final traditionService = TraditionService();
      await traditionService.loadTradition();

      expect(traditionService.currentTradition, AppTradition.smarta);
      expect(prefs.getBool('remind_two_days_before'), false);

      // Change tradition to Vaishnava
      await traditionService.setTradition(AppTradition.vaishnava);

      // Verify tradition changed
      expect(traditionService.currentTradition, AppTradition.vaishnava);

      // Verify unrelated notification preferences were preserved!
      expect(prefs.getBool('notifications_enabled'), true);
      expect(prefs.getBool('remind_one_day_before'), true);
      expect(prefs.getBool('remind_two_days_before'), false);
      expect(prefs.getBool('remind_on_day'), true);
      expect(prefs.getBool('remind_on_parana'), true);
    });

    test('Cancel specific Ekadashi by ID cleanly removes only that event', () async {
      final texts = LanguageService().localizedStrings;
      final futureDate1 = DateTime.now().add(const Duration(days: 10));
      final futureDate2 = DateTime.now().add(const Duration(days: 25));

      final e1 = EkadashiDate(
        id: 10,
        name: 'Event 1',
        date: futureDate1,
        fastStartTime: '06:00 AM',
        fastBreakTime: '06:30 AM - 09:30 AM',
        description: 'First event',
        fastingStartIso: futureDate1.toIso8601String(),
        paranaStartIso: futureDate1.add(const Duration(days: 1)).toIso8601String(),
      );

      final e2 = EkadashiDate(
        id: 20,
        name: 'Event 2',
        date: futureDate2,
        fastStartTime: '06:00 AM',
        fastBreakTime: '06:30 AM - 09:30 AM',
        description: 'Second event',
        fastingStartIso: futureDate2.toIso8601String(),
        paranaStartIso: futureDate2.add(const Duration(days: 1)).toIso8601String(),
      );

      await notificationService.scheduleAllNotifications(
        [e1, e2],
        true, true, true, texts,
        remindOnParana: true,
      );

      expect(notificationService.scheduledNotifications.any((n) => n.ekadashiId == 10), isTrue);
      expect(notificationService.scheduledNotifications.any((n) => n.ekadashiId == 20), isTrue);

      // Cancel only event 10
      await notificationService.cancelEkadashi(10);

      expect(notificationService.scheduledNotifications.any((n) => n.ekadashiId == 10), isFalse);
      expect(notificationService.scheduledNotifications.any((n) => n.ekadashiId == 20), isTrue);
    });

    test('Timezone handling: respects non-IST local timezones without hardcoded offsets', () async {
      final nyLocation = tz.getLocation('America/New_York');
      tz.setLocalLocation(nyLocation);

      final texts = LanguageService().localizedStrings;
      final futureDate = tz.TZDateTime.now(nyLocation).add(const Duration(days: 10));

      final testEvent = EkadashiDate(
        id: 77,
        name: 'Kamada Ekadashi',
        date: DateTime(futureDate.year, futureDate.month, futureDate.day),
        fastStartTime: '06:15 AM',
        fastBreakTime: '06:20 AM - 09:10 AM',
        description: 'Grants desires',
      );

      final count = await notificationService.scheduleAllNotifications(
        [testEvent],
        true, true, false, texts,
        remindOnParana: false,
        tradition: AppTradition.general,
      );

      expect(count, greaterThan(0));
      for (var record in notificationService.scheduledNotifications) {
        // Scheduled hour should be 8:00 AM in America/New_York local time
        expect(record.scheduledDate.hour, 8);
        expect(record.scheduledDate.location.name, 'America/New_York');
      }

      // Restore to Asia/Kolkata
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    });

    test('Handles missing and malformed event data gracefully without crashing', () async {
      final texts = LanguageService().localizedStrings;

      // Event with missing/empty fields
      final incompleteEvent = EkadashiDate(
        id: 99,
        name: 'Incomplete Ekadashi',
        date: DateTime.now().add(const Duration(days: 12)),
        fastStartTime: '', // Empty
        fastBreakTime: '', // Empty
        description: 'Test event',
        fastingStartIso: '', // Empty
        paranaStartIso: '', // Empty
        paranaEndIso: '', // Empty
      );

      // Should not throw or crash and should safely schedule date-based alerts
      final count = await notificationService.scheduleAllNotifications(
        [incompleteEvent],
        true, true, true, texts,
        remindOnParana: true,
        tradition: AppTradition.smarta,
      );

      // Only the valid date-based notifications (2-day and 1-day) are scheduled
      expect(count, greaterThan(0));
      expect(notificationService.scheduledCount, count);
    });

    test('App restart simulation: Restores tradition preference and schedules accordingly', () async {
      SharedPreferences.setMockInitialValues({
        'user_tradition': 'vaishnava',
        'tradition_onboarding_completed': true,
        'notifications_enabled': true,
      });

      // Initialize TraditionService like app launch
      final traditionService = TraditionService();
      await traditionService.loadTradition();

      expect(traditionService.isInitialized, isTrue);
      expect(traditionService.currentTradition, AppTradition.vaishnava);

      // Verify notification texts reflect restored tradition
      final langService = LanguageService();
      final texts = NotificationService.getTraditionNotificationTexts(
        baseTexts: langService.localizedStrings,
        tradition: traditionService.currentTradition,
        languageCode: 'en',
      );

      expect(texts['notif_start_title'], '[Vaishnava] Ekadashi Starts Now');
      expect(texts['notif_parana_title'], '[Vaishnava] Parana Time');
    });

    test('All notification keys exist in en, ta, and hi dictionaries', () {
      final lang = LanguageService();

      const requiredKeys = [
        'notif_2day_title',
        'notif_2day_body',
        'notif_1day_title',
        'notif_1day_body',
        'notif_start_title',
        'notif_start_body',
        'notif_start_suffix',
        'notif_parana_title',
        'notif_parana_body',
        'notif_upcoming_parana_title',
        'notif_upcoming_parana_body',
        'notif_parana_day_title',
        'notif_parana_day_body',
      ];

      for (var code in ['en', 'ta', 'hi']) {
        lang.changeLanguage(code);
        for (var key in requiredKeys) {
          final translated = lang.translate(key);
          expect(translated, isNotEmpty, reason: '$key should exist in $code');
          expect(translated, isNot(equals(key)), reason: '$key translation should not return raw key in $code');
        }
      }
    });

    test('TraditionNotificationCoordinator: automatic rescheduling on TraditionService.setTradition', () async {
      SharedPreferences.setMockInitialValues({
        'user_tradition': 'smarta',
        'notifications_enabled': true,
        'remind_one_day_before': true,
        'remind_two_days_before': true,
        'remind_on_day': true,
        'remind_on_parana': true,
      });

      // Clear any prior notifications
      await notificationService.cancelAll();
      expect(notificationService.scheduledCount, 0);

      // Initialize coordinator
      TraditionNotificationCoordinator.initialize();

      // Setup tradition service
      final traditionService = TraditionService();
      await traditionService.loadTradition();
      expect(traditionService.currentTradition, AppTradition.smarta);

      // Trigger initial schedule for Smarta using mock event
      await TraditionNotificationCoordinator.rescheduleForTradition(
        tradition: AppTradition.smarta,
        dates: [mockFutureEkadashi],
      );
      final smartaCount = notificationService.scheduledCount;
      expect(smartaCount, greaterThan(0));
      for (var n in notificationService.scheduledNotifications) {
        expect(n.tradition, AppTradition.smarta);
        expect(n.title, startsWith('[Smarta]'));
      }

      // Now switch tradition via TraditionService.setTradition -> onTraditionChanged fires
      // We pass the mock event to rescheduleForTradition to test callback flow
      TraditionService.onTraditionChanged = (tradition) async {
        await TraditionNotificationCoordinator.rescheduleForTradition(
          tradition: tradition,
          dates: [mockFutureEkadashi],
        );
      };

      await traditionService.setTradition(AppTradition.vaishnava);

      // Verify that all notifications are now Vaishnava
      expect(traditionService.currentTradition, AppTradition.vaishnava);
      expect(notificationService.scheduledCount, greaterThan(0));
      for (var n in notificationService.scheduledNotifications) {
        expect(n.tradition, AppTradition.vaishnava);
        expect(n.title, startsWith('[Vaishnava]'));
      }
      expect(notificationService.scheduledNotifications.any((n) => n.tradition == AppTradition.smarta), isFalse);
    });

    test('TraditionNotificationCoordinator: handles disabled notifications and cancels all', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': false, // Disabled
      });

      // Pretend notifications were already scheduled
      await notificationService.scheduleAllNotifications(
        [mockFutureEkadashi],
        true, true, true,
        LanguageService().localizedStrings,
      );
      expect(notificationService.scheduledCount, greaterThan(0));

      final count = await TraditionNotificationCoordinator.rescheduleForTradition(
        tradition: AppTradition.smarta,
        dates: [mockFutureEkadashi],
      );

      expect(count, 0);
      expect(notificationService.scheduledCount, 0);
    });

    test('TraditionNotificationHelper: 1-day before notification without fastStartTime formats cleanly', () {
      const name = 'Mokshada Ekadashi';

      // English without fastStartTime
      final en = TraditionNotificationHelper.buildContent(
        type: NotificationReminderType.oneDayBefore,
        ekadashiName: name,
        tradition: AppTradition.general,
        languageCode: 'en',
        fastStartTime: '',
      );
      expect(en.body, 'Mokshada Ekadashi is tomorrow. Prepare for fasting.');
      expect(en.body.endsWith('starts at'), isFalse);

      // Tamil without fastStartTime
      final ta = TraditionNotificationHelper.buildContent(
        type: NotificationReminderType.oneDayBefore,
        ekadashiName: 'மோக்ஷதா ஏகாதசி',
        tradition: AppTradition.smarta,
        languageCode: 'ta',
        fastStartTime: '',
      );
      expect(ta.body, 'மோக்ஷதா ஏகாதசி நாளை. விரதத்திற்கு தயாராகுங்கள்.');

      // Hindi without fastStartTime
      final hi = TraditionNotificationHelper.buildContent(
        type: NotificationReminderType.oneDayBefore,
        ekadashiName: 'मोक्षदा एकादशी',
        tradition: AppTradition.vaishnava,
        languageCode: 'hi',
        fastStartTime: '',
      );
      expect(hi.body, 'मोक्षदा एकादशी कल है। व्रत की तैयारी करें।');
    });

    test('TraditionNotificationHelper: includeGeneral flag produces localized General tag when requested', () {
      expect(TraditionNotificationHelper.getTraditionTag(AppTradition.general, 'en', includeGeneral: true), '[General]');
      expect(TraditionNotificationHelper.getTraditionTag(AppTradition.general, 'ta', includeGeneral: true), '[பொதுவானது]');
      expect(TraditionNotificationHelper.getTraditionTag(AppTradition.general, 'hi', includeGeneral: true), '[सामान्य]');
      expect(TraditionNotificationHelper.getTraditionTag(AppTradition.general, 'en', includeGeneral: false), '');
    });
  });
}
