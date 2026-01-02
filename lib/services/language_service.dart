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
      'appearance': 'Appearance',
      'dark_mode': 'Dark Mode',
      'notifications': 'Notifications',
      'enable_notifications': 'Enable Notifications',
      'notify_start': 'Notify when Fasting Begins',
      'notify_1day': 'Notify 1 Day Before',
      'notify_2day': 'Notify 2 Days Before',
      'test_notification': 'Test Notification Now', // Updated Label
      'test_notification_sub': 'Send a test alert now',
      'about': 'About',
      'version': 'Version',
      'significance': 'Significance',
      'story_history': 'Story and History',
      'fasting_rules': 'Fasting Rules',
      'spiritual_benefits': 'Spiritual Benefits',
      'locating': 'Locating...',
      'failed_load': 'Failed to load data. Please check connection.',

      // Notification Text
      'notif_test_title': 'Test Successful! 🔔',
      'notif_test_body': 'This is how your Ekadashi reminders will appear.',
      'notif_2day_title': 'Upcoming Ekadashi',
      'notif_2day_body': 'is in 2 days. Prepare for your fast.',
      'notif_1day_title': 'Ekadashi Tomorrow!',
      'notif_1day_body': 'is tomorrow. Fasting starts at',
      'notif_start_title': 'Ekadashi Starts Now',
      'notif_start_body': 'Today is',
      'notif_start_suffix': 'Fasting begins now.',
      'notif_sent_msg': 'Notification sent! Check your status bar.',
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
      'appearance': 'தோற்றம்',
      'dark_mode': 'இருண்ட பயன்முறை',
      'notifications': 'அறிவிப்புகள்',
      'enable_notifications': 'அறிவிப்புகளை இயக்கு',
      'notify_start': 'விரதத்தின் போது',
      'notify_1day': '1 நாள் முன்',
      'notify_2day': '2 நாட்கள் முன்',
      'test_notification': 'சோதனை அறிவிப்பு',
      'test_notification_sub': 'சோதனை விழிப்பூட்டல் அனுப்பு',
      'about': 'பற்றி',
      'version': 'பதிப்பு',
      'significance': 'சிறப்பு',
      'story_history': 'கதை மற்றும் வரலாறு',
      'fasting_rules': 'விரத விதிமுறைகள்',
      'spiritual_benefits': 'ஆன்மீக பலன்கள்',
      'locating': 'கண்டறிகிறது...',
      'failed_load': 'தரவை ஏற்ற முடியவில்லை. இணைப்பைச் சரிபார்க்கவும்.',

      // Notification Text
      'notif_test_title': 'சோதனை வெற்றி! 🔔',
      'notif_test_body': 'உங்கள் ஏகாதசி நினைவூட்டல்கள் இப்படித்தான் இருக்கும்.',
      'notif_2day_title': 'வரவிருக்கும் ஏகாதசி',
      'notif_2day_body': '2 நாட்களில் வருகிறது. விரதத்திற்கு தயாராகுங்கள்.',
      'notif_1day_title': 'நாளை ஏகாதசி!',
      'notif_1day_body': 'நாளை. விரதம் தொடங்கும் நேரம்:',
      'notif_start_title': 'ஏகாதசி தொடங்குகிறது',
      'notif_start_body': 'இன்று',
      'notif_start_suffix': 'விரதம் இப்போது தொடங்குகிறது.',
      'notif_sent_msg': 'அறிவிப்பு அனுப்பப்பட்டது! உங்கள் நிலைப் பட்டியைச் சரிபார்க்கவும்.',
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
      'appearance': 'दिखावट',
      'dark_mode': 'डार्क मोड',
      'notifications': 'सूचनाएं',
      'enable_notifications': 'सूचनाएं सक्षम करें',
      'notify_start': 'व्रत शुरू होने पर सूचित करें',
      'notify_1day': '1 दिन पहले सूचित करें',
      'notify_2day': '2 दिन पहले सूचित करें',
      'test_notification': 'टेस्ट नोटिफिकेशन',
      'test_notification_sub': 'अभी एक टेस्ट अलर्ट भेजें',
      'about': 'बारे में',
      'version': 'संस्करण',
      'significance': 'महत्व',
      'story_history': 'कथा और इतिहास',
      'fasting_rules': 'व्रत के नियम',
      'spiritual_benefits': 'आध्यात्मिक लाभ',
      'locating': 'स्थान खोज रहा है...',
      'failed_load': 'डेटा लोड करने में विफल। कृपया कनेक्शन जांचें।',

      // Notification Text
      'notif_test_title': 'टेस्ट सफल! 🔔',
      'notif_test_body': 'आपके एकादशी रिमाइंडर इस तरह दिखाई देंगे।',
      'notif_2day_title': 'आने वाली एकादशी',
      'notif_2day_body': '2 दिनों में है। अपने व्रत की तैयारी करें।',
      'notif_1day_title': 'कल एकादशी है!',
      'notif_1day_body': 'कल है। व्रत शुरू होने का समय:',
      'notif_start_title': 'एकादशी अब शुरू',
      'notif_start_body': 'आज है',
      'notif_start_suffix': 'व्रत अब शुरू हो रहा है.',
      'notif_sent_msg': 'नोटिफिकेशन भेजा गया! अपना स्टेटस बार चेक करें।',
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