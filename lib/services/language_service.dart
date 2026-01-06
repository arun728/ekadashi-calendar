import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  Locale _currentLocale = const Locale('en');

  Locale get currentLocale => _currentLocale;

  LanguageService() {
    _loadLanguage();
  }

  Map<String, String> get localizedStrings => _localizedValues[_currentLocale.languageCode] ?? _localizedValues['en']!;

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Ekadashi Calendar',
      'home': 'Home',
      'calendar': 'Calendar',
      'settings': 'Settings',
      'start_fasting': 'Start Fasting',
      'break_fasting': 'Break Fasting',
      'view_details': 'View Details',
      'today': 'Today',
      'tomorrow': 'Tomorrow',
      'passed': 'Passed',
      'in_days': 'in {} days',
      'locating': 'Locating...',
      'detecting_location': 'Detecting Location...',
      'location_denied': 'Location Denied',
      'failed_load': 'Failed to load data',
      'no_ekadashi': 'No Ekadashi on this day',
      'significance': 'Significance',
      'story_history': 'Story and History',
      'fasting_rules': 'Fasting Rules',
      'spiritual_benefits': 'Spiritual Benefits',
      'appearance': 'Appearance',
      'dark_mode': 'Dark Mode',
      'notifications': 'Notifications',
      'enable_notifications': 'Enable Notifications',
      'reminders_active': '{}/3 active',
      'notify_start': 'When Fasting Begins',
      'notify_1day': '1 Day Before',
      'notify_2day': '2 Days Before',
      'status_active': 'Active',
      'status_disabled': 'Disabled',
      'test_notification': 'Test Notification',
      'test_notification_desc': 'Send a test notification',
      'notifications_off': 'Notifications disabled',
      'permissions': 'Permissions',
      'permissions_ok': 'All set',
      'permissions_needed': 'Action needed',
      'alarms_reminders': 'Alarms',
      'alarms_enabled': 'Enabled',
      'alarms_disabled': 'Disabled',
      'battery_optimization': 'Battery',
      'battery_desc': 'Open App Settings',
      'open_settings': 'Open',
      'about': 'About',
      'version': 'Version',
      'notif_test_title': 'Hari Om!',
      'notif_test_body': 'Your notifications are working perfectly!',
      'notif_2day_title': 'Upcoming Ekadashi',
      'notif_2day_body': 'is in 2 days. Prepare for your fast.',
      'notif_1day_title': 'Ekadashi Tomorrow!',
      'notif_1day_body': 'is tomorrow. Fasting starts at',
      'notif_start_title': 'Ekadashi Starts Now',
      'notif_start_body': 'Today is',
      'notif_start_suffix': 'Fasting begins now.',
      'notif_sent_msg': 'Notification sent!',
    },

    'ta': {
      'app_title': 'ஏகாதசி காலண்டர்',
      'home': 'முகப்பு',
      'calendar': 'நாட்காட்டி',
      'settings': 'அமைப்புகள்',
      'start_fasting': 'விரதம் ஆரம்பம்',
      'break_fasting': 'விரதம் முடித்தல்',
      'view_details': 'விவரங்கள்',
      'today': 'இன்று',
      'tomorrow': 'நாளை',
      'passed': 'முடிந்தது',
      'in_days': '{} நாட்களில்',
      'locating': 'தேடுகிறது...',
      'detecting_location': 'இருப்பிடம் கண்டறிதல்...',
      'location_denied': 'இருப்பிடம் மறுப்பு',
      'failed_load': 'தரவு ஏற்ற இயலவில்லை',
      'no_ekadashi': 'இந்த நாளில் ஏகாதசி இல்லை',
      'significance': 'சிறப்பு',
      'story_history': 'கதை மற்றும் வரலாறு',
      'fasting_rules': 'விரத விதிமுறைகள்',
      'spiritual_benefits': 'ஆன்மீக பலன்கள்',
      'appearance': 'தோற்றம்',
      'dark_mode': 'இருண்ட பயன்முறை',
      'notifications': 'அறிவிப்புகள்',
      'enable_notifications': 'அறிவிப்புகளை இயக்கு',
      'reminders_active': '{}/3 செயலில்',
      'notify_start': 'விரதம் தொடங்கும்போது',
      'notify_1day': '1 நாள் முன்',
      'notify_2day': '2 நாட்கள் முன்',
      'status_active': 'செயலில்',
      'status_disabled': 'முடக்கம்',
      'test_notification': 'சோதனை அறிவிப்பு',
      'test_notification_desc': 'சோதனை அனுப்பு',
      'notifications_off': 'அறிவிப்புகள் முடக்கம்',
      'permissions': 'அனுமதிகள்',
      'permissions_ok': 'சரி',
      'permissions_needed': 'செயல் தேவை',
      'alarms_reminders': 'அலாரம்',
      'alarms_enabled': 'இயக்கம்',
      'alarms_disabled': 'முடக்கம்',
      'battery_optimization': 'பேட்டரி',
      'battery_desc': 'ஆப் அமைப்புகள்',
      'open_settings': 'திற',
      'about': 'பற்றி',
      'version': 'பதிப்பு',
      'notif_test_title': 'ஹரி ஓம்!',
      'notif_test_body': 'உங்கள் அறிவிப்புகள் சரியாக வேலை செய்கின்றன!',
      'notif_2day_title': 'வரவிருக்கும் ஏகாதசி',
      'notif_2day_body': '2 நாட்களில் வருகிறது. தயாராகுங்கள்.',
      'notif_1day_title': 'நாளை ஏகாதசி!',
      'notif_1day_body': 'நாளை. விரதம் தொடங்கும் நேரம்:',
      'notif_start_title': 'ஏகாதசி தொடங்குகிறது',
      'notif_start_body': 'இன்று',
      'notif_start_suffix': 'விரதம் இப்போது தொடங்குகிறது.',
      'notif_sent_msg': 'அறிவிப்பு அனுப்பப்பட்டது!',
    },

    'hi': {
      'app_title': 'एकादशी कैलेंडर',
      'home': 'होम',
      'calendar': 'कैलेंडर',
      'settings': 'सेटिंग्स',
      'start_fasting': 'व्रत प्रारंभ',
      'break_fasting': 'व्रत पारण',
      'view_details': 'विवरण देखें',
      'today': 'आज',
      'tomorrow': 'कल',
      'passed': 'बीत गया',
      'in_days': '{} दिनों में',
      'locating': 'खोज रहा है...',
      'detecting_location': 'स्थान पता लगा रहा है...',
      'location_denied': 'स्थान अस्वीकृत',
      'failed_load': 'डेटा लोड विफल',
      'no_ekadashi': 'इस दिन एकादशी नहीं है',
      'significance': 'महत्व',
      'story_history': 'कथा और इतिहास',
      'fasting_rules': 'व्रत के नियम',
      'spiritual_benefits': 'आध्यात्मिक लाभ',
      'appearance': 'दिखावट',
      'dark_mode': 'डार्क मोड',
      'notifications': 'सूचनाएं',
      'enable_notifications': 'सूचनाएं सक्षम करें',
      'reminders_active': '{}/3 सक्रिय',
      'notify_start': 'व्रत शुरू होने पर',
      'notify_1day': '1 दिन पहले',
      'notify_2day': '2 दिन पहले',
      'status_active': 'सक्रिय',
      'status_disabled': 'अक्षम',
      'test_notification': 'टेस्ट नोटिफिकेशन',
      'test_notification_desc': 'टेस्ट भेजें',
      'notifications_off': 'सूचनाएं बंद',
      'permissions': 'अनुमतियां',
      'permissions_ok': 'सब ठीक',
      'permissions_needed': 'कार्रवाई जरूरी',
      'alarms_reminders': 'अलार्म',
      'alarms_enabled': 'सक्षम',
      'alarms_disabled': 'अक्षम',
      'battery_optimization': 'बैटरी',
      'battery_desc': 'ऐप सेटिंग्स',
      'open_settings': 'खोलें',
      'about': 'बारे में',
      'version': 'संस्करण',
      'notif_test_title': 'हरि ॐ!',
      'notif_test_body': 'आपकी सूचनाएं बिल्कुल सही काम कर रही हैं!',
      'notif_2day_title': 'आगामी एकादशी',
      'notif_2day_body': '2 दिनों में है। तैयारी करें।',
      'notif_1day_title': 'कल एकादशी!',
      'notif_1day_body': 'कल है। व्रत शुरू:',
      'notif_start_title': 'एकादशी अब शुरू',
      'notif_start_body': 'आज है',
      'notif_start_suffix': 'व्रत अब शुरू।',
      'notif_sent_msg': 'नोटिफिकेशन भेजा गया!',
    }
  };

  String translate(String key) {
    return _localizedValues[_currentLocale.languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  String translateWithArgs(String key, List<String> args) {
    String text = translate(key);
    for (var arg in args) {
      text = text.replaceFirst('{}', arg);
    }
    return text;
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? languageCode = prefs.getString('language_code');
    if (languageCode != null) {
      _currentLocale = Locale(languageCode);
      notifyListeners();
    }
  }

  Future<void> changeLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    _currentLocale = Locale(languageCode);
    notifyListeners();
  }
}