import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tradition_service.dart';
import 'notification_service.dart';
import 'native_notification_service.dart';
import 'ekadashi_service.dart';
import 'language_service.dart';
import 'native_location_service.dart';

/// Notification reminder type categories for Ekadashi and Parana observances
enum NotificationReminderType {
  /// 2 days before Ekadashi fasting (upcoming alert)
  twoDaysBefore,

  /// 1 day before Ekadashi fasting (tomorrow alert with fast start time)
  oneDayBefore,

  /// Fasting day start (sunrise/fast begin)
  fastingDay,

  /// Upcoming Parana window (evening before Dwadashi or alert of upcoming window)
  upcomingParana,

  /// Parana day (fast breaking window active)
  paranaDay,
}

/// Structured tradition-aware notification payload
class TraditionNotificationContent {
  final String title;
  final String body;
  final NotificationReminderType type;
  final AppTradition tradition;
  final String languageCode;

  const TraditionNotificationContent({
    required this.title,
    required this.body,
    required this.type,
    required this.tradition,
    required this.languageCode,
  });

  @override
  String toString() => 'TraditionNotificationContent($title: $body)';
}

/// Helper service for generating localized, tradition-aware notification content
class TraditionNotificationHelper {
  /// Get tradition tag/badge for notification titles.
  /// General: empty string by default (clean title without tag)
  /// Smarta: '[Smarta]', '[ஸ்மார்த்தா]', '[स्मार्त]'
  /// Vaishnava: '[Vaishnava]', '[வைணவம்]', '[वैष्णव]'
  static String getTraditionTag(
    AppTradition tradition,
    String languageCode, {
    bool includeGeneral = false,
  }) {
    if (tradition == AppTradition.general) {
      if (!includeGeneral) return '';
      switch (languageCode) {
        case 'ta':
          return '[பொதுவானது]';
        case 'te':
          return '[సాధారణం]';
        case 'hi':
          return '[सामान्य]';
        case 'en':
        default:
          return '[General]';
      }
    }
    switch (languageCode) {
      case 'ta':
        return tradition == AppTradition.smarta ? '[ஸ்மார்த்தா]' : '[வைணவம்]';
      case 'te':
        return tradition == AppTradition.smarta ? '[స్మార్త]' : '[వైష్ణవ]';
      case 'hi':
        return tradition == AppTradition.smarta ? '[स्मार्त]' : '[वैष्णव]';
      case 'en':
      default:
        return tradition == AppTradition.smarta ? '[Smarta]' : '[Vaishnava]';
    }
  }

  /// Construct localized, tradition-aware title and body for mobile notifications.
  /// Keeps length concise for push notification displays.
  static TraditionNotificationContent buildContent({
    required NotificationReminderType type,
    required String ekadashiName,
    required AppTradition tradition,
    required String languageCode,
    String fastStartTime = '',
    String paranaWindow = '',
    Map<String, String>? texts,
  }) {
    final tag = getTraditionTag(tradition, languageCode);
    final prefix = tag.isNotEmpty ? '$tag ' : '';

    String rawTitle = '';
    String body = '';

    switch (type) {
      case NotificationReminderType.twoDaysBefore:
        rawTitle = texts?['notif_2day_title'] ?? _default2DayTitle(languageCode);
        final defaultBody = _default2DayBody(languageCode);
        final bodyText = texts?['notif_2day_body'] ?? defaultBody;
        body = '$ekadashiName $bodyText';
        break;

      case NotificationReminderType.oneDayBefore:
        rawTitle = texts?['notif_1day_title'] ?? _default1DayTitle(languageCode);
        if (fastStartTime.isNotEmpty) {
          final defaultBody = _default1DayBody(languageCode);
          final bodyText = texts?['notif_1day_body'] ?? defaultBody;
          body = '$ekadashiName $bodyText $fastStartTime'.trim();
        } else {
          final bodyText = _default1DayBodyNoTime(languageCode);
          body = '$ekadashiName $bodyText'.trim();
        }
        break;

      case NotificationReminderType.fastingDay:
        rawTitle = texts?['notif_start_title'] ?? _defaultStartTitle(languageCode);
        final bodyPrefix = texts?['notif_start_body'] ?? _defaultStartPrefix(languageCode);
        final bodySuffix = texts?['notif_start_suffix'] ?? _defaultStartSuffix(languageCode);
        body = '$bodyPrefix $ekadashiName. $bodySuffix';
        break;

      case NotificationReminderType.upcomingParana:
        rawTitle = texts?['notif_upcoming_parana_title'] ?? _defaultUpcomingParanaTitle(languageCode);
        final window = paranaWindow.isNotEmpty ? paranaWindow : '';
        body = _buildUpcomingParanaBody(languageCode, ekadashiName, window, texts);
        break;

      case NotificationReminderType.paranaDay:
        rawTitle = texts?['notif_parana_title'] ?? _defaultParanaTitle(languageCode);
        final bodySuffix = texts?['notif_parana_body'] ?? _defaultParanaBody(languageCode);
        final windowInfo = paranaWindow.isNotEmpty ? ' ($paranaWindow)' : '';
        body = '$ekadashiName $bodySuffix$windowInfo';
        break;
    }

    final finalTitle = rawTitle.startsWith('[') ? rawTitle : '$prefix$rawTitle';

    return TraditionNotificationContent(
      title: finalTitle.trim(),
      body: body.trim(),
      type: type,
      tradition: tradition,
      languageCode: languageCode,
    );
  }

  /// Adapt base texts map with tradition prefix on notification title keys
  static Map<String, String> getTraditionAwareTexts({
    required Map<String, String> baseTexts,
    required AppTradition tradition,
    required String languageCode,
  }) {
    final Map<String, String> result = Map<String, String>.from(baseTexts);
    final tag = getTraditionTag(tradition, languageCode);
    if (tag.isEmpty) return result;

    const titleKeys = [
      'notif_2day_title',
      'notif_1day_title',
      'notif_start_title',
      'notif_parana_title',
      'notif_upcoming_parana_title',
      'notif_parana_day_title',
      'notif_test_title',
    ];

    for (final key in titleKeys) {
      final base = baseTexts[key];
      if (base != null && !base.startsWith('[')) {
        result[key] = '$tag $base';
      }
    }

    return result;
  }

  // --- Internal Default Strings by Language ---

  static String _default2DayTitle(String lang) {
    switch (lang) {
      case 'ta': return 'வரவிருக்கும் ஏகாதசி';
      case 'te': return 'రాబోయే ఏకాదశి';
      case 'hi': return 'आगामी एकादशी';
      case 'en':
      default: return 'Upcoming Ekadashi';
    }
  }

  static String _default2DayBody(String lang) {
    switch (lang) {
      case 'ta': return '2 நாட்களில் வருகிறது. தயாராகுங்கள்.';
      case 'te': return '2 రోజుల్లో రాబోతోంది. సిద్ధం కండి.';
      case 'hi': return '2 दिनों में है। तैयारी करें।';
      case 'en':
      default: return 'is in 2 days. Prepare for your fast.';
    }
  }

  static String _default1DayTitle(String lang) {
    switch (lang) {
      case 'ta': return 'நாளை ஏகாதசி!';
      case 'te': return 'రేపే ఏకాదశి!';
      case 'hi': return 'कल एकादशी!';
      case 'en':
      default: return 'Ekadashi Tomorrow!';
    }
  }

  static String _default1DayBody(String lang) {
    switch (lang) {
      case 'ta': return 'நாளை. விரதம் தொடங்கும் நேரம்:';
      case 'te': return 'రేపు ఏకాదశి. ఉపవాస ప్రారంభం:';
      case 'hi': return 'कल है। व्रत शुरू:';
      case 'en':
      default: return 'is tomorrow. Fasting starts at';
    }
  }

  static String _default1DayBodyNoTime(String lang) {
    switch (lang) {
      case 'ta': return 'நாளை. விரதத்திற்கு தயாராகுங்கள்.';
      case 'te': return 'రేపు ఏకాదశి. ఉపవాసానికి సిద్ధం కండి.';
      case 'hi': return 'कल है। व्रत की तैयारी करें।';
      case 'en':
      default: return 'is tomorrow. Prepare for fasting.';
    }
  }

  static String _defaultStartTitle(String lang) {
    switch (lang) {
      case 'ta': return 'ஏகாதசி தொடங்குகிறது';
      case 'te': return 'ఏకాదశి ప్రారంభమైంది';
      case 'hi': return 'एकादशी अब शुरू';
      case 'en':
      default: return 'Ekadashi Starts Now';
    }
  }

  static String _defaultStartPrefix(String lang) {
    switch (lang) {
      case 'ta': return 'இன்று';
      case 'te': return 'ఈ రోజు';
      case 'hi': return 'आज है';
      case 'en':
      default: return 'Today is';
    }
  }

  static String _defaultStartSuffix(String lang) {
    switch (lang) {
      case 'ta': return 'விரதம் இப்போது தொடங்குகிறது.';
      case 'te': return 'ఉపవాసం ఇప్పుడే ప్రారంభమవుతుంది.';
      case 'hi': return 'व्रत अब शुरू।';
      case 'en':
      default: return 'Fasting begins now.';
    }
  }

  static String _defaultParanaTitle(String lang) {
    switch (lang) {
      case 'ta': return 'பாரணை நேரம்';
      case 'te': return 'పారణ సమయం';
      case 'hi': return 'पारण का समय';
      case 'en':
      default: return 'Parana Time';
    }
  }

  static String _defaultParanaBody(String lang) {
    switch (lang) {
      case 'ta': return '- இப்போது விரதத்தை முடிக்கலாம்.';
      case 'te': return '- ఇప్పుడు ఉపవాసం విరమించవచ్చు.';
      case 'hi': return '- अब व्रत तोड़ सकते हैं।';
      case 'en':
      default: return '- You can break your fast now.';
    }
  }

  static String _defaultUpcomingParanaTitle(String lang) {
    switch (lang) {
      case 'ta': return 'வரவிருக்கும் பாரணை நேரம்';
      case 'te': return 'రాబోయే పారణ సమయం';
      case 'hi': return 'आगामी पारण समय';
      case 'en':
      default: return 'Upcoming Parana Window';
    }
  }

  static String _buildUpcomingParanaBody(
      String lang, String name, String window, Map<String, String>? texts) {
    final customTemplate = texts?['notif_upcoming_parana_body'];
    if (customTemplate != null && customTemplate.contains('{}')) {
      return customTemplate.replaceFirst('{}', name).replaceFirst('{}', window);
    }

    switch (lang) {
      case 'ta':
        return 'நாளைய $name பாரணை காலம்: $window.';
      case 'te':
        return 'రేపటి $name పారణ సమయం: $window.';
      case 'hi':
        return 'कल $name का पारण समय: $window है।';
      case 'en':
      default:
        return 'Tomorrow\'s Parana window for $name is $window.';
    }
  }
}

/// Central coordinator for tradition-aware notification rescheduling.
/// Handles:
/// 1. Preference change detection and callback registration
/// 2. Purging outdated tradition-specific reminders
/// 3. Rescheduling with newly selected tradition dates and timestamps
/// 4. Deduplication via deterministic IDs and cancelAll
/// 5. Preservation of unrelated notification settings (toggles, timezones)
/// 6. Permission denial handling and offline safety
class TraditionNotificationCoordinator {
  static bool _isInitialized = false;

  /// Wire up automatic rescheduling on tradition change
  static void initialize() {
    if (_isInitialized) return;
    TraditionService.onTraditionChanged = (tradition) async {
      await rescheduleForTradition(tradition: tradition);
    };
    _isInitialized = true;
  }

  /// Reschedule all notifications for the given tradition preference.
  /// Returns the number of notifications successfully scheduled.
  static Future<int> rescheduleForTradition({
    required AppTradition tradition,
    List<EkadashiDate>? dates,
    String? languageCode,
    String? timezone,
    Map<String, String>? baseTexts,
    bool? remind1Day,
    bool? remind2Days,
    bool? remindOnDay,
    bool? remindOnParana,
    bool? remindUpcomingParana,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final notifService = NotificationService();

    // 1. Check if notifications are enabled
    final enabled = prefs.getBool('notifications_enabled') ??
        prefs.getBool('enabled') ??
        true;

    // 2. Check notification permission
    final hasPerm = await notifService.hasNotificationPermission();
    if (!enabled || !hasPerm) {
      debugPrint('⏭️ Skipping scheduling - Notifications disabled ($enabled) or permission denied ($hasPerm)');
      await notifService.cancelAll();
      try {
        await NativeNotificationService().cancelAllNotifications();
      } catch (_) {}
      return 0;
    }

    // 3. Cancel outdated tradition-dependent notifications first to prevent stale dates & duplicates
    await notifService.cancelAll();
    try {
      await NativeNotificationService().cancelAllNotifications();
    } catch (_) {}

    // 4. Preserve unrelated notification preferences
    final r1Day = remind1Day ??
        prefs.getBool('remind_one_day_before') ??
        prefs.getBool('remind_1_day') ??
        true;
    final r2Days = remind2Days ??
        prefs.getBool('remind_two_days_before') ??
        prefs.getBool('remind_2_days') ??
        true;
    final rOnDay = remindOnDay ??
        prefs.getBool('remind_on_day') ??
        prefs.getBool('remind_on_start') ??
        true;
    final rOnParana = remindOnParana ??
        prefs.getBool('remind_on_parana') ??
        true;
    final rUpcomingParana = remindUpcomingParana ??
        prefs.getBool('remind_upcoming_parana') ??
        false;

    // If all toggles are disabled, no notifications to schedule
    if (!r1Day && !r2Days && !rOnDay && !rOnParana && !rUpcomingParana) {
      return 0;
    }

    // 5. Resolve events for the selected tradition
    final lang = languageCode ?? prefs.getString('language_code') ?? 'en';
    final tz = timezone ?? prefs.getString('user_timezone') ?? 'IST';

    List<EkadashiDate> eventList = dates ?? [];
    if (eventList.isEmpty) {
      final ekadashiService = EkadashiService();
      ekadashiService.clearCache();
      final loc = await NativeLocationService().getSavedUserLocation();
      eventList = ekadashiService.getEkadashis(
        location: loc,
        timezone: tz,
        languageCode: lang,
        tradition: tradition,
      );
    }

    if (eventList.isEmpty) return 0;

    // 6. Generate tradition-aware localized texts
    final rawTexts = baseTexts ?? LanguageService().localizedStrings;
    final traditionTexts = NotificationService.getTraditionNotificationTexts(
      baseTexts: rawTexts,
      tradition: tradition,
      languageCode: lang,
    );

    // 7. Schedule native Android WorkManager notifications if applicable
    try {
      final nativeNotifService = NativeNotificationService();
      final ekadashiData = eventList.map((e) => EkadashiNotificationData(
        id: e.id,
        name: e.name,
        fastingStartTime: e.fastingStartIso.isNotEmpty ? e.fastingStartIso : e.fastStartTime,
        paranaStartTime: e.paranaStartIso.isNotEmpty ? e.paranaStartIso : e.fastBreakTime,
      )).toList();

      await nativeNotifService.scheduleAllNotifications(
        ekadashis: ekadashiData,
        texts: traditionTexts,
      );
    } catch (e) {
      debugPrint('Native notification scheduling: $e');
    }

    // 8. Schedule via NotificationService (Flutter local notifications & in-memory tracking)
    final scheduledCount = await notifService.scheduleAllNotifications(
      eventList,
      r1Day,
      r2Days,
      rOnDay,
      traditionTexts,
      remindOnParana: rOnParana,
      remindUpcomingParana: rUpcomingParana,
      tradition: tradition,
      languageCode: lang,
    );

    debugPrint('✅ Rescheduled $scheduledCount tradition-aware notifications for ${tradition.name} ($lang)');
    return scheduledCount;
  }
}
