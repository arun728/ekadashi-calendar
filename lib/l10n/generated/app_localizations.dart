import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
    Locale('gu'),
    Locale('hi'),
    Locale('ta'),
    Locale('te'),
  ];

  /// No description provided for @app_title.
  ///
  /// In en, this message translates to:
  /// **'Ekadashi Calendar'**
  String get app_title;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @start_fasting.
  ///
  /// In en, this message translates to:
  /// **'Start Fasting'**
  String get start_fasting;

  /// No description provided for @break_fasting.
  ///
  /// In en, this message translates to:
  /// **'Break Fasting'**
  String get break_fasting;

  /// No description provided for @view_details.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get view_details;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @passed.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get passed;

  /// No description provided for @in_days.
  ///
  /// In en, this message translates to:
  /// **'in {value0} days'**
  String in_days(String value0);

  /// No description provided for @locating.
  ///
  /// In en, this message translates to:
  /// **'Locating...'**
  String get locating;

  /// No description provided for @detecting_location.
  ///
  /// In en, this message translates to:
  /// **'Detecting Location...'**
  String get detecting_location;

  /// No description provided for @location_denied.
  ///
  /// In en, this message translates to:
  /// **'Location Denied'**
  String get location_denied;

  /// No description provided for @failed_load.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data'**
  String get failed_load;

  /// No description provided for @no_ekadashi.
  ///
  /// In en, this message translates to:
  /// **'No Ekadashi on this day'**
  String get no_ekadashi;

  /// No description provided for @significance.
  ///
  /// In en, this message translates to:
  /// **'Significance'**
  String get significance;

  /// No description provided for @story_history.
  ///
  /// In en, this message translates to:
  /// **'Story and History'**
  String get story_history;

  /// No description provided for @fasting_rules.
  ///
  /// In en, this message translates to:
  /// **'Fasting Rules'**
  String get fasting_rules;

  /// No description provided for @spiritual_benefits.
  ///
  /// In en, this message translates to:
  /// **'Spiritual Benefits'**
  String get spiritual_benefits;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @dark_mode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get dark_mode;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @enable_notifications.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get enable_notifications;

  /// No description provided for @reminders_active.
  ///
  /// In en, this message translates to:
  /// **'{value0}/4 active'**
  String reminders_active(String value0);

  /// No description provided for @notify_2day.
  ///
  /// In en, this message translates to:
  /// **'2 Days Before'**
  String get notify_2day;

  /// No description provided for @notify_1day.
  ///
  /// In en, this message translates to:
  /// **'1 Day Before'**
  String get notify_1day;

  /// No description provided for @notify_start.
  ///
  /// In en, this message translates to:
  /// **'Start Fasting'**
  String get notify_start;

  /// No description provided for @notify_parana.
  ///
  /// In en, this message translates to:
  /// **'Break Fasting'**
  String get notify_parana;

  /// No description provided for @status_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get status_active;

  /// No description provided for @status_disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get status_disabled;

  /// No description provided for @test_notification.
  ///
  /// In en, this message translates to:
  /// **'Test Notification'**
  String get test_notification;

  /// No description provided for @test_notification_desc.
  ///
  /// In en, this message translates to:
  /// **'Send a test notification'**
  String get test_notification_desc;

  /// No description provided for @test_notif_title.
  ///
  /// In en, this message translates to:
  /// **'🙏 Hari Om!'**
  String get test_notif_title;

  /// No description provided for @test_notif_body.
  ///
  /// In en, this message translates to:
  /// **'Your test notification works!'**
  String get test_notif_body;

  /// No description provided for @notifications_off.
  ///
  /// In en, this message translates to:
  /// **'Notifications disabled'**
  String get notifications_off;

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// No description provided for @permissions_ok.
  ///
  /// In en, this message translates to:
  /// **'All set'**
  String get permissions_ok;

  /// No description provided for @permissions_needed.
  ///
  /// In en, this message translates to:
  /// **'Action needed'**
  String get permissions_needed;

  /// No description provided for @alarms_reminders.
  ///
  /// In en, this message translates to:
  /// **'Alarms'**
  String get alarms_reminders;

  /// No description provided for @alarms_enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get alarms_enabled;

  /// No description provided for @alarms_disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get alarms_disabled;

  /// No description provided for @battery_optimization.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get battery_optimization;

  /// No description provided for @battery_desc.
  ///
  /// In en, this message translates to:
  /// **'Open App Settings'**
  String get battery_desc;

  /// No description provided for @open_settings.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open_settings;

  /// No description provided for @settings_button.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_button;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @rate_app.
  ///
  /// In en, this message translates to:
  /// **'Rate App'**
  String get rate_app;

  /// No description provided for @rate_app_desc.
  ///
  /// In en, this message translates to:
  /// **'Rate us on Play Store'**
  String get rate_app_desc;

  /// No description provided for @notif_test_title.
  ///
  /// In en, this message translates to:
  /// **'🙏 Hari Om!'**
  String get notif_test_title;

  /// No description provided for @notif_test_body.
  ///
  /// In en, this message translates to:
  /// **'Your test notification works!'**
  String get notif_test_body;

  /// No description provided for @notif_2day_title.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Ekadashi'**
  String get notif_2day_title;

  /// No description provided for @notif_2day_body.
  ///
  /// In en, this message translates to:
  /// **'is in 2 days. Prepare for your fast.'**
  String get notif_2day_body;

  /// No description provided for @notif_1day_title.
  ///
  /// In en, this message translates to:
  /// **'Ekadashi Tomorrow!'**
  String get notif_1day_title;

  /// No description provided for @notif_1day_body.
  ///
  /// In en, this message translates to:
  /// **'is tomorrow. Fasting starts at'**
  String get notif_1day_body;

  /// No description provided for @notif_start_title.
  ///
  /// In en, this message translates to:
  /// **'Ekadashi Starts Now'**
  String get notif_start_title;

  /// No description provided for @notif_start_body.
  ///
  /// In en, this message translates to:
  /// **'Today is'**
  String get notif_start_body;

  /// No description provided for @notif_start_suffix.
  ///
  /// In en, this message translates to:
  /// **'Fasting begins now.'**
  String get notif_start_suffix;

  /// No description provided for @notif_parana_title.
  ///
  /// In en, this message translates to:
  /// **'Parana Time'**
  String get notif_parana_title;

  /// No description provided for @notif_parana_body.
  ///
  /// In en, this message translates to:
  /// **'- You can break your fast now.'**
  String get notif_parana_body;

  /// No description provided for @notif_sent_msg.
  ///
  /// In en, this message translates to:
  /// **'Notification sent!'**
  String get notif_sent_msg;

  /// No description provided for @info_close.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get info_close;

  /// No description provided for @alarms_info_title.
  ///
  /// In en, this message translates to:
  /// **'Alarms & Reminders'**
  String get alarms_info_title;

  /// No description provided for @alarms_info_why.
  ///
  /// In en, this message translates to:
  /// **'Why it\'s needed'**
  String get alarms_info_why;

  /// No description provided for @alarms_info_why_desc.
  ///
  /// In en, this message translates to:
  /// **'Ekadashi fasting times are based on specific sunrise times. Exact alarms ensure you receive reminders at the precise moment.'**
  String get alarms_info_why_desc;

  /// No description provided for @alarms_info_steps.
  ///
  /// In en, this message translates to:
  /// **'How to enable'**
  String get alarms_info_steps;

  /// No description provided for @alarms_info_step1.
  ///
  /// In en, this message translates to:
  /// **'1. Tap \"Open\" to go to settings'**
  String get alarms_info_step1;

  /// No description provided for @alarms_info_step2.
  ///
  /// In en, this message translates to:
  /// **'2. Toggle \"Allow setting alarms\" ON'**
  String get alarms_info_step2;

  /// No description provided for @alarms_info_note.
  ///
  /// In en, this message translates to:
  /// **'Note: On some devices, this may already be enabled and cannot be changed.'**
  String get alarms_info_note;

  /// No description provided for @battery_info_title.
  ///
  /// In en, this message translates to:
  /// **'Battery Optimization'**
  String get battery_info_title;

  /// No description provided for @battery_info_why.
  ///
  /// In en, this message translates to:
  /// **'Why it\'s needed'**
  String get battery_info_why;

  /// No description provided for @battery_info_why_desc.
  ///
  /// In en, this message translates to:
  /// **'If battery optimization is enabled, Android may delay or skip your Ekadashi reminders to save power.'**
  String get battery_info_why_desc;

  /// No description provided for @battery_info_steps.
  ///
  /// In en, this message translates to:
  /// **'How to allow background usage'**
  String get battery_info_steps;

  /// No description provided for @battery_info_step1.
  ///
  /// In en, this message translates to:
  /// **'1. Tap \"Open\" to go to App Info'**
  String get battery_info_step1;

  /// No description provided for @battery_info_step2.
  ///
  /// In en, this message translates to:
  /// **'2. Tap \"Battery\" or \"App battery usage\"'**
  String get battery_info_step2;

  /// No description provided for @battery_info_step3.
  ///
  /// In en, this message translates to:
  /// **'3. Enable \"Allow background usage\" or select \"Unrestricted\"'**
  String get battery_info_step3;

  /// No description provided for @battery_info_note.
  ///
  /// In en, this message translates to:
  /// **'This ensures notifications are delivered on time, even when your phone is idle.'**
  String get battery_info_note;

  /// No description provided for @share_app.
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get share_app;

  /// No description provided for @share_app_desc.
  ///
  /// In en, this message translates to:
  /// **'Tell friends about this app'**
  String get share_app_desc;

  /// No description provided for @share_message.
  ///
  /// In en, this message translates to:
  /// **'🙏 Ekadashi Calendar - Never miss an Ekadashi!\n\nGet reminders for fasting times, read stories & significance of each Ekadashi.\n\nDownload now: https://play.google.com/store/apps/details?id=com.applausestudios.ekadashi_calendar'**
  String get share_message;

  /// No description provided for @select_city.
  ///
  /// In en, this message translates to:
  /// **'Select City'**
  String get select_city;

  /// No description provided for @search_city.
  ///
  /// In en, this message translates to:
  /// **'Search city...'**
  String get search_city;

  /// No description provided for @auto_detect_location.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect Location'**
  String get auto_detect_location;

  /// No description provided for @auto_detect_desc.
  ///
  /// In en, this message translates to:
  /// **'Use GPS to find your city'**
  String get auto_detect_desc;

  /// No description provided for @using_auto_location.
  ///
  /// In en, this message translates to:
  /// **'Using auto-detected location'**
  String get using_auto_location;

  /// No description provided for @disable_auto_manual.
  ///
  /// In en, this message translates to:
  /// **'Turn off auto-detect to select a city manually'**
  String get disable_auto_manual;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @change_city.
  ///
  /// In en, this message translates to:
  /// **'Change City'**
  String get change_city;

  /// No description provided for @location_permission_title.
  ///
  /// In en, this message translates to:
  /// **'Location Required'**
  String get location_permission_title;

  /// No description provided for @location_permission_permanent.
  ///
  /// In en, this message translates to:
  /// **'Location permission is permanently disabled. Please enable it in App Settings to use location-based features.'**
  String get location_permission_permanent;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @app_settings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get app_settings;

  /// No description provided for @app_settings_desc.
  ///
  /// In en, this message translates to:
  /// **'Manage permissions & battery'**
  String get app_settings_desc;

  /// No description provided for @perm_guide_title.
  ///
  /// In en, this message translates to:
  /// **'Permissions Guide'**
  String get perm_guide_title;

  /// No description provided for @perm_guide_desc.
  ///
  /// In en, this message translates to:
  /// **'For accurate notifications and location features, please allow:\n• Notifications\n• Location\n• Battery (Unrestricted/Background)'**
  String get perm_guide_desc;

  /// No description provided for @vrat.
  ///
  /// In en, this message translates to:
  /// **'Vrat'**
  String get vrat;

  /// No description provided for @journey.
  ///
  /// In en, this message translates to:
  /// **'Vrat'**
  String get journey;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @vrat_tracker.
  ///
  /// In en, this message translates to:
  /// **'Vrat Tracker'**
  String get vrat_tracker;

  /// No description provided for @vrat_tracker_desc.
  ///
  /// In en, this message translates to:
  /// **'Keep a private record of your Ekadashi observance.'**
  String get vrat_tracker_desc;

  /// No description provided for @enable_vrat_tracker.
  ///
  /// In en, this message translates to:
  /// **'Enable Vrat Tracker'**
  String get enable_vrat_tracker;

  /// No description provided for @disable_vrat_tracker.
  ///
  /// In en, this message translates to:
  /// **'Disable Vrat Tracker'**
  String get disable_vrat_tracker;

  /// No description provided for @tracker_enabled_msg.
  ///
  /// In en, this message translates to:
  /// **'Vrat Tracker enabled. You can now record your observance.'**
  String get tracker_enabled_msg;

  /// No description provided for @tracker_disabled_msg.
  ///
  /// In en, this message translates to:
  /// **'Vrat Tracker disabled. Your existing history remains saved.'**
  String get tracker_disabled_msg;

  /// No description provided for @observed.
  ///
  /// In en, this message translates to:
  /// **'Observed'**
  String get observed;

  /// No description provided for @partial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get partial;

  /// No description provided for @missed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get missed;

  /// No description provided for @unrecorded.
  ///
  /// In en, this message translates to:
  /// **'Unrecorded'**
  String get unrecorded;

  /// No description provided for @not_recorded.
  ///
  /// In en, this message translates to:
  /// **'Not Recorded'**
  String get not_recorded;

  /// No description provided for @tap_to_record_instruction.
  ///
  /// In en, this message translates to:
  /// **'Tap an Ekadashi to record your observance'**
  String get tap_to_record_instruction;

  /// No description provided for @tap_to_record_semantics.
  ///
  /// In en, this message translates to:
  /// **'Tap to record Vrat'**
  String get tap_to_record_semantics;

  /// No description provided for @record_vrat.
  ///
  /// In en, this message translates to:
  /// **'Record Vrat'**
  String get record_vrat;

  /// No description provided for @view_vrat_status.
  ///
  /// In en, this message translates to:
  /// **'View Vrat Status'**
  String get view_vrat_status;

  /// No description provided for @record_observance.
  ///
  /// In en, this message translates to:
  /// **'Record Observance'**
  String get record_observance;

  /// No description provided for @edit_record.
  ///
  /// In en, this message translates to:
  /// **'Edit Record'**
  String get edit_record;

  /// No description provided for @delete_record.
  ///
  /// In en, this message translates to:
  /// **'Delete Record'**
  String get delete_record;

  /// No description provided for @current_streak.
  ///
  /// In en, this message translates to:
  /// **'Current Streak'**
  String get current_streak;

  /// No description provided for @longest_streak.
  ///
  /// In en, this message translates to:
  /// **'Longest Streak'**
  String get longest_streak;

  /// No description provided for @annual_completion.
  ///
  /// In en, this message translates to:
  /// **'Annual Completion'**
  String get annual_completion;

  /// No description provided for @total_observed.
  ///
  /// In en, this message translates to:
  /// **'Total Observed'**
  String get total_observed;

  /// No description provided for @total_partial.
  ///
  /// In en, this message translates to:
  /// **'Total Partial'**
  String get total_partial;

  /// No description provided for @total_missed.
  ///
  /// In en, this message translates to:
  /// **'Total Missed'**
  String get total_missed;

  /// No description provided for @fasting_method.
  ///
  /// In en, this message translates to:
  /// **'Fasting Method'**
  String get fasting_method;

  /// No description provided for @method_full_fast.
  ///
  /// In en, this message translates to:
  /// **'Full Fast'**
  String get method_full_fast;

  /// No description provided for @method_water_only.
  ///
  /// In en, this message translates to:
  /// **'Water Only'**
  String get method_water_only;

  /// No description provided for @method_fruits_milk.
  ///
  /// In en, this message translates to:
  /// **'Fruits / Milk'**
  String get method_fruits_milk;

  /// No description provided for @method_one_meal.
  ///
  /// In en, this message translates to:
  /// **'One Meal'**
  String get method_one_meal;

  /// No description provided for @method_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get method_other;

  /// No description provided for @method_other_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter fasting method'**
  String get method_other_hint;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Personal Notes'**
  String get notes;

  /// No description provided for @notes_hint.
  ///
  /// In en, this message translates to:
  /// **'Add an optional personal note...'**
  String get notes_hint;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @achievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievements;

  /// No description provided for @achievement_unlocked.
  ///
  /// In en, this message translates to:
  /// **'Achievement Unlocked'**
  String get achievement_unlocked;

  /// No description provided for @next_milestone.
  ///
  /// In en, this message translates to:
  /// **'Next Milestone'**
  String get next_milestone;

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @unlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get unlocked;

  /// No description provided for @ekadashis_unit.
  ///
  /// In en, this message translates to:
  /// **'Ekadashis'**
  String get ekadashis_unit;

  /// No description provided for @filter_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filter_all;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @cannot_record_future.
  ///
  /// In en, this message translates to:
  /// **'Future Ekadashis cannot be marked as Observed in advance.'**
  String get cannot_record_future;

  /// No description provided for @delete_confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this observance record?'**
  String get delete_confirm;

  /// No description provided for @delete_confirm_desc.
  ///
  /// In en, this message translates to:
  /// **'This will remove your record from history. Original calendar data will remain untouched.'**
  String get delete_confirm_desc;

  /// No description provided for @achievement_first_vrat_title.
  ///
  /// In en, this message translates to:
  /// **'First Vrat'**
  String get achievement_first_vrat_title;

  /// No description provided for @achievement_first_vrat_desc.
  ///
  /// In en, this message translates to:
  /// **'Your first recorded Ekadashi observance.'**
  String get achievement_first_vrat_desc;

  /// No description provided for @achievement_5_vrat_title.
  ///
  /// In en, this message translates to:
  /// **'5 Ekadashis'**
  String get achievement_5_vrat_title;

  /// No description provided for @achievement_5_vrat_desc.
  ///
  /// In en, this message translates to:
  /// **'Completed 5 qualifying Ekadashi observances.'**
  String get achievement_5_vrat_desc;

  /// No description provided for @achievement_10_vrat_title.
  ///
  /// In en, this message translates to:
  /// **'10 Ekadashis'**
  String get achievement_10_vrat_title;

  /// No description provided for @achievement_10_vrat_desc.
  ///
  /// In en, this message translates to:
  /// **'Completed 10 qualifying Ekadashi observances.'**
  String get achievement_10_vrat_desc;

  /// No description provided for @achievement_12_vrat_title.
  ///
  /// In en, this message translates to:
  /// **'12 Ekadashis'**
  String get achievement_12_vrat_title;

  /// No description provided for @achievement_12_vrat_desc.
  ///
  /// In en, this message translates to:
  /// **'Completed 12 qualifying Ekadashi observances.'**
  String get achievement_12_vrat_desc;

  /// No description provided for @achievement_consistent_title.
  ///
  /// In en, this message translates to:
  /// **'Consistent Observance'**
  String get achievement_consistent_title;

  /// No description provided for @achievement_consistent_desc.
  ///
  /// In en, this message translates to:
  /// **'Observed 3 consecutive Ekadashis with devotion.'**
  String get achievement_consistent_desc;

  /// No description provided for @achievement_full_year_title.
  ///
  /// In en, this message translates to:
  /// **'Full-Year Observance'**
  String get achievement_full_year_title;

  /// No description provided for @achievement_full_year_desc.
  ///
  /// In en, this message translates to:
  /// **'Observed all Ekadashis in a single calendar year.'**
  String get achievement_full_year_desc;

  /// No description provided for @filter_google.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get filter_google;

  /// No description provided for @filter_custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get filter_custom;

  /// No description provided for @filter_ekadashi.
  ///
  /// In en, this message translates to:
  /// **'Ekadashi'**
  String get filter_ekadashi;

  /// No description provided for @all_day.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get all_day;

  /// No description provided for @no_entries.
  ///
  /// In en, this message translates to:
  /// **'No entries for this day'**
  String get no_entries;

  /// No description provided for @add_entry.
  ///
  /// In en, this message translates to:
  /// **'Add entry'**
  String get add_entry;

  /// No description provided for @edit_entry.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get edit_entry;

  /// No description provided for @entry_title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get entry_title;

  /// No description provided for @entry_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get entry_notes;

  /// No description provided for @entry_starts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get entry_starts;

  /// No description provided for @entry_ends.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get entry_ends;

  /// No description provided for @invalid_entry.
  ///
  /// In en, this message translates to:
  /// **'Enter a title and an end time after the start time.'**
  String get invalid_entry;

  /// No description provided for @sync_google.
  ///
  /// In en, this message translates to:
  /// **'Import Google Calendar'**
  String get sync_google;

  /// No description provided for @disconnect_google.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Google Calendar'**
  String get disconnect_google;

  /// No description provided for @sign_in_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in cancelled'**
  String get sign_in_cancelled;

  /// No description provided for @no_google_calendars.
  ///
  /// In en, this message translates to:
  /// **'No Google calendars found'**
  String get no_google_calendars;

  /// No description provided for @no_google_events.
  ///
  /// In en, this message translates to:
  /// **'No events in selected calendars for this year'**
  String get no_google_events;

  /// No description provided for @imported_google_events.
  ///
  /// In en, this message translates to:
  /// **'Imported {value0} Google events'**
  String imported_google_events(String value0);

  /// No description provided for @imported_google_range.
  ///
  /// In en, this message translates to:
  /// **'Imported {value0} Google events ({value1} – {value2})'**
  String imported_google_range(String value0, String value1, String value2);

  /// No description provided for @google_sync_failed.
  ///
  /// In en, this message translates to:
  /// **'Calendar import failed. Previous entries were kept. Please try again.'**
  String get google_sync_failed;

  /// No description provided for @storage_failed.
  ///
  /// In en, this message translates to:
  /// **'Calendar storage is unavailable. Please try again.'**
  String get storage_failed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @choose_calendars.
  ///
  /// In en, this message translates to:
  /// **'Calendars to import'**
  String get choose_calendars;

  /// No description provided for @choose_calendars_help.
  ///
  /// In en, this message translates to:
  /// **'Select calendars to display in this app. Import does not change your Google events.'**
  String get choose_calendars_help;

  /// No description provided for @switch_google_account.
  ///
  /// In en, this message translates to:
  /// **'Use another account'**
  String get switch_google_account;

  /// No description provided for @google_calendar.
  ///
  /// In en, this message translates to:
  /// **'Google Calendar'**
  String get google_calendar;

  /// No description provided for @primary_calendar.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get primary_calendar;

  /// No description provided for @import_selected.
  ///
  /// In en, this message translates to:
  /// **'Import selected'**
  String get import_selected;

  /// No description provided for @content_fallback.
  ///
  /// In en, this message translates to:
  /// **'This archived content is currently available in English.'**
  String get content_fallback;

  /// No description provided for @translation_pending.
  ///
  /// In en, this message translates to:
  /// **'Translations are awaiting language review.'**
  String get translation_pending;

  /// No description provided for @tracker_storage_failed.
  ///
  /// In en, this message translates to:
  /// **'Your record could not be saved. Please try again.'**
  String get tracker_storage_failed;

  /// No description provided for @next_ekadashi.
  ///
  /// In en, this message translates to:
  /// **'Next Ekadashi'**
  String get next_ekadashi;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search Ekadashi, Katha, Mantra, Food...'**
  String get search_hint;

  /// No description provided for @recent_searches.
  ///
  /// In en, this message translates to:
  /// **'Recent Searches'**
  String get recent_searches;

  /// No description provided for @clear_all.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clear_all;

  /// No description provided for @no_results_found.
  ///
  /// In en, this message translates to:
  /// **'No results found for'**
  String get no_results_found;

  /// No description provided for @offline_indicator.
  ///
  /// In en, this message translates to:
  /// **'Offline — showing downloaded content'**
  String get offline_indicator;

  /// No description provided for @online_only.
  ///
  /// In en, this message translates to:
  /// **'Online Only'**
  String get online_only;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @try_searching.
  ///
  /// In en, this message translates to:
  /// **'Try searching for:'**
  String get try_searching;

  /// No description provided for @filter_by.
  ///
  /// In en, this message translates to:
  /// **'Filter by category'**
  String get filter_by;

  /// No description provided for @did_you_mean.
  ///
  /// In en, this message translates to:
  /// **'Did you mean:'**
  String get did_you_mean;

  /// No description provided for @category_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get category_all;

  /// No description provided for @category_ekadashi.
  ///
  /// In en, this message translates to:
  /// **'Ekadashi'**
  String get category_ekadashi;

  /// No description provided for @category_katha.
  ///
  /// In en, this message translates to:
  /// **'Katha'**
  String get category_katha;

  /// No description provided for @category_mantra.
  ///
  /// In en, this message translates to:
  /// **'Mantra'**
  String get category_mantra;

  /// No description provided for @category_food.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get category_food;

  /// No description provided for @category_vrat.
  ///
  /// In en, this message translates to:
  /// **'Vrat Info'**
  String get category_vrat;

  /// No description provided for @category_festival.
  ///
  /// In en, this message translates to:
  /// **'Festival'**
  String get category_festival;

  /// No description provided for @category_temple.
  ///
  /// In en, this message translates to:
  /// **'Temple'**
  String get category_temple;

  /// No description provided for @category_event.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get category_event;

  /// No description provided for @widgets.
  ///
  /// In en, this message translates to:
  /// **'Widgets'**
  String get widgets;

  /// No description provided for @widget_preview.
  ///
  /// In en, this message translates to:
  /// **'Widget Preview'**
  String get widget_preview;

  /// No description provided for @widget_preview_desc.
  ///
  /// In en, this message translates to:
  /// **'Preview Home Screen Widgets'**
  String get widget_preview_desc;

  /// No description provided for @fasting_active.
  ///
  /// In en, this message translates to:
  /// **'Fasting active'**
  String get fasting_active;

  /// No description provided for @parana_available.
  ///
  /// In en, this message translates to:
  /// **'Parana available'**
  String get parana_available;

  /// No description provided for @parana_completed.
  ///
  /// In en, this message translates to:
  /// **'Parana completed'**
  String get parana_completed;

  /// No description provided for @open_app_to_refresh.
  ///
  /// In en, this message translates to:
  /// **'Open the app to refresh timings'**
  String get open_app_to_refresh;

  /// No description provided for @upcoming_ekadashis.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Ekadashis'**
  String get upcoming_ekadashis;

  /// No description provided for @widget_today_title.
  ///
  /// In en, this message translates to:
  /// **'Ekadashi Today'**
  String get widget_today_title;

  /// No description provided for @widget_parana_in.
  ///
  /// In en, this message translates to:
  /// **'Parana in'**
  String get widget_parana_in;

  /// No description provided for @widget_parana_ends.
  ///
  /// In en, this message translates to:
  /// **'Parana ends in'**
  String get widget_parana_ends;

  /// No description provided for @widget_starts_in.
  ///
  /// In en, this message translates to:
  /// **'Starts in'**
  String get widget_starts_in;

  /// No description provided for @widget_notice.
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get widget_notice;

  /// No description provided for @widget_now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get widget_now;

  /// No description provided for @widget_day_unit.
  ///
  /// In en, this message translates to:
  /// **'d'**
  String get widget_day_unit;

  /// No description provided for @widget_hour_unit.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get widget_hour_unit;

  /// No description provided for @widget_minute_unit.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get widget_minute_unit;

  /// No description provided for @hari_om.
  ///
  /// In en, this message translates to:
  /// **'Hari Om 🙏'**
  String get hari_om;

  /// No description provided for @offline_mode.
  ///
  /// In en, this message translates to:
  /// **'Offline mode active'**
  String get offline_mode;

  /// No description provided for @online_mode.
  ///
  /// In en, this message translates to:
  /// **'Online search mode'**
  String get online_mode;

  /// No description provided for @search_start.
  ///
  /// In en, this message translates to:
  /// **'Search across Ekadashi content'**
  String get search_start;

  /// No description provided for @results_count.
  ///
  /// In en, this message translates to:
  /// **'{value0} results'**
  String results_count(String value0);

  /// No description provided for @saved_offline.
  ///
  /// In en, this message translates to:
  /// **'Saved for offline reading'**
  String get saved_offline;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @search_content_language.
  ///
  /// In en, this message translates to:
  /// **'Content language'**
  String get search_content_language;

  /// No description provided for @search_script.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get search_script;

  /// No description provided for @search_transliteration.
  ///
  /// In en, this message translates to:
  /// **'Transliteration'**
  String get search_transliteration;

  /// No description provided for @search_meaning.
  ///
  /// In en, this message translates to:
  /// **'Meaning'**
  String get search_meaning;

  /// No description provided for @search_ingredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get search_ingredients;

  /// No description provided for @search_steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get search_steps;

  /// No description provided for @search_rules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get search_rules;

  /// No description provided for @search_stages.
  ///
  /// In en, this message translates to:
  /// **'Stages'**
  String get search_stages;

  /// No description provided for @search_levels.
  ///
  /// In en, this message translates to:
  /// **'Levels'**
  String get search_levels;

  /// No description provided for @search_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get search_location;

  /// No description provided for @search_deity.
  ///
  /// In en, this message translates to:
  /// **'Deity'**
  String get search_deity;

  /// No description provided for @search_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get search_date;

  /// No description provided for @search_organizers.
  ///
  /// In en, this message translates to:
  /// **'Organizers'**
  String get search_organizers;

  /// No description provided for @paksha_krishna.
  ///
  /// In en, this message translates to:
  /// **'Krishna'**
  String get paksha_krishna;

  /// No description provided for @paksha_shukla.
  ///
  /// In en, this message translates to:
  /// **'Shukla'**
  String get paksha_shukla;

  /// No description provided for @lunar_month_adhika.
  ///
  /// In en, this message translates to:
  /// **'Adhika'**
  String get lunar_month_adhika;

  /// No description provided for @lunar_month_ashadha.
  ///
  /// In en, this message translates to:
  /// **'Ashadha'**
  String get lunar_month_ashadha;

  /// No description provided for @lunar_month_ashwin.
  ///
  /// In en, this message translates to:
  /// **'Ashwin'**
  String get lunar_month_ashwin;

  /// No description provided for @lunar_month_bhadrapada.
  ///
  /// In en, this message translates to:
  /// **'Bhadrapada'**
  String get lunar_month_bhadrapada;

  /// No description provided for @lunar_month_chaitra.
  ///
  /// In en, this message translates to:
  /// **'Chaitra'**
  String get lunar_month_chaitra;

  /// No description provided for @lunar_month_jyeshtha.
  ///
  /// In en, this message translates to:
  /// **'Jyeshtha'**
  String get lunar_month_jyeshtha;

  /// No description provided for @lunar_month_kartik.
  ///
  /// In en, this message translates to:
  /// **'Kartik'**
  String get lunar_month_kartik;

  /// No description provided for @lunar_month_magha.
  ///
  /// In en, this message translates to:
  /// **'Magha'**
  String get lunar_month_magha;

  /// No description provided for @lunar_month_margashirsha.
  ///
  /// In en, this message translates to:
  /// **'Margashirsha'**
  String get lunar_month_margashirsha;

  /// No description provided for @lunar_month_pausha.
  ///
  /// In en, this message translates to:
  /// **'Pausha'**
  String get lunar_month_pausha;

  /// No description provided for @lunar_month_phalguna.
  ///
  /// In en, this message translates to:
  /// **'Phalguna'**
  String get lunar_month_phalguna;

  /// No description provided for @lunar_month_shravana.
  ///
  /// In en, this message translates to:
  /// **'Shravana'**
  String get lunar_month_shravana;

  /// No description provided for @lunar_month_vaishakha.
  ///
  /// In en, this message translates to:
  /// **'Vaishakha'**
  String get lunar_month_vaishakha;

  /// No description provided for @splash_mantra.
  ///
  /// In en, this message translates to:
  /// **'Om Namo Narayana!'**
  String get splash_mantra;

  /// No description provided for @no_offline_results.
  ///
  /// In en, this message translates to:
  /// **'No offline results found. Save content for offline access.'**
  String get no_offline_results;

  /// No description provided for @premium_title.
  ///
  /// In en, this message translates to:
  /// **'Ekadashi Premium'**
  String get premium_title;

  /// No description provided for @premium_benefits.
  ///
  /// In en, this message translates to:
  /// **'Unlock everything in Ekadashi Premium. Ekadashi dates, reminders, widgets, custom entries and your saved Vrat history stay free.'**
  String get premium_benefits;

  /// No description provided for @premium_free_achievements.
  ///
  /// In en, this message translates to:
  /// **'Your first three Vrat entries and first three achievements are free. Premium unlocks the rest.'**
  String get premium_free_achievements;

  /// No description provided for @premium_monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get premium_monthly;

  /// No description provided for @premium_yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get premium_yearly;

  /// No description provided for @premium_lifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get premium_lifetime;

  /// No description provided for @premium_monthly_terms.
  ///
  /// In en, this message translates to:
  /// **'Full price charged each month. Automatically renews until canceled in Google Play.'**
  String get premium_monthly_terms;

  /// No description provided for @premium_yearly_terms.
  ///
  /// In en, this message translates to:
  /// **'Full price charged each year. Automatically renews until canceled in Google Play.'**
  String get premium_yearly_terms;

  /// No description provided for @premium_lifetime_terms.
  ///
  /// In en, this message translates to:
  /// **'One payment, no renewal. Manage or cancel an existing subscription before buying lifetime to avoid duplicate charges.'**
  String get premium_lifetime_terms;

  /// No description provided for @premium_sign_in.
  ///
  /// In en, this message translates to:
  /// **'Sign in securely with Google'**
  String get premium_sign_in;

  /// No description provided for @premium_continue_free.
  ///
  /// In en, this message translates to:
  /// **'Continue free'**
  String get premium_continue_free;

  /// No description provided for @premium_restore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get premium_restore;

  /// No description provided for @premium_manage.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription in Google Play'**
  String get premium_manage;

  /// No description provided for @premium_active.
  ///
  /// In en, this message translates to:
  /// **'Premium access active'**
  String get premium_active;

  /// No description provided for @premium_current_plan.
  ///
  /// In en, this message translates to:
  /// **'Your current plan'**
  String get premium_current_plan;

  /// No description provided for @premium_best_value.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get premium_best_value;

  /// No description provided for @premium_per_month.
  ///
  /// In en, this message translates to:
  /// **'per month'**
  String get premium_per_month;

  /// No description provided for @premium_per_year.
  ///
  /// In en, this message translates to:
  /// **'per year'**
  String get premium_per_year;

  /// No description provided for @premium_one_time.
  ///
  /// In en, this message translates to:
  /// **'one-time'**
  String get premium_one_time;

  /// No description provided for @premium_cancelled_title.
  ///
  /// In en, this message translates to:
  /// **'Subscription cancelled'**
  String get premium_cancelled_title;

  /// No description provided for @premium_cancelled_body.
  ///
  /// In en, this message translates to:
  /// **'Premium stays on until the end of the period you paid for. Reactivate anytime to keep it.'**
  String get premium_cancelled_body;

  /// No description provided for @premium_reactivate.
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get premium_reactivate;

  /// No description provided for @free_sync_unverified.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check your free sync. Check your connection, or get Premium.'**
  String get free_sync_unverified;

  /// No description provided for @premium_upgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get premium_upgrade;

  /// No description provided for @premium_restored.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored. Premium is active.'**
  String get premium_restored;

  /// No description provided for @premium_restore_none.
  ///
  /// In en, this message translates to:
  /// **'No purchases found for this Google Play account.'**
  String get premium_restore_none;

  /// No description provided for @premium_lifetime_thanks_title.
  ///
  /// In en, this message translates to:
  /// **'Thank you, lifetime member! 🙏'**
  String get premium_lifetime_thanks_title;

  /// No description provided for @premium_lifetime_thanks_body.
  ///
  /// In en, this message translates to:
  /// **'Every Premium feature is yours for life, including all future features and updates. We look forward to serving you for years to come.'**
  String get premium_lifetime_thanks_body;

  /// No description provided for @premium_subscriber_title.
  ///
  /// In en, this message translates to:
  /// **'You have Premium ✨'**
  String get premium_subscriber_title;

  /// No description provided for @premium_subscriber_body.
  ///
  /// In en, this message translates to:
  /// **'Switch plans or go lifetime anytime.'**
  String get premium_subscriber_body;

  /// No description provided for @premium_cancel_subscription_note.
  ///
  /// In en, this message translates to:
  /// **'Your subscription is still active. Cancel it in Google Play so you are not charged again. Lifetime stays yours.'**
  String get premium_cancel_subscription_note;

  /// No description provided for @premium_cancel_subscription_action.
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription in Google Play'**
  String get premium_cancel_subscription_action;

  /// No description provided for @premium_lifetime_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'You already have a subscription'**
  String get premium_lifetime_confirm_title;

  /// No description provided for @premium_lifetime_confirm_body.
  ///
  /// In en, this message translates to:
  /// **'Google Play does not cancel subscriptions automatically. After buying lifetime, cancel your subscription in Google Play to stop renewals.'**
  String get premium_lifetime_confirm_body;

  /// No description provided for @premium_buy_lifetime_anyway.
  ///
  /// In en, this message translates to:
  /// **'Buy lifetime'**
  String get premium_buy_lifetime_anyway;

  /// No description provided for @premium_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Purchases are unavailable right now. Install the app from Google Play and try again. Free features still work.'**
  String get premium_unavailable;

  /// No description provided for @premium_verification_failed.
  ///
  /// In en, this message translates to:
  /// **'Purchase verification is pending. Try Restore purchases; access is granted only after verification.'**
  String get premium_verification_failed;

  /// No description provided for @premium_pending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment confirmation'**
  String get premium_pending;

  /// No description provided for @premium_wallet.
  ///
  /// In en, this message translates to:
  /// **'Fasting rewards'**
  String get premium_wallet;

  /// No description provided for @premium_reward_rules.
  ///
  /// In en, this message translates to:
  /// **'Earn 10 coins per completed Ekadashi. Completing every Ekadashi in a supported year adds a bonus to reach 300 coins. Redeem 300 coins for six months of premium access. Rewards require no purchase and are self-reported. Coins have no cash value, cannot be bought or transferred, and cannot be refunded as money. Correcting or deleting completion reverses its coins.'**
  String get premium_reward_rules;

  /// No description provided for @premium_reward_consent.
  ///
  /// In en, this message translates to:
  /// **'Activate cloud rewards? Completion identifiers, status and your selected calendar region are uploaded with sync metadata. Notes and fasting details remain on your phone.'**
  String get premium_reward_consent;

  /// No description provided for @premium_reward_activate.
  ///
  /// In en, this message translates to:
  /// **'Activate rewards'**
  String get premium_reward_activate;

  /// No description provided for @premium_reward_sync_failed.
  ///
  /// In en, this message translates to:
  /// **'Rewards could not sync. Your private Vrat records are safe. Retry after connecting; conflicting edits may require support.'**
  String get premium_reward_sync_failed;

  /// No description provided for @premium_redeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem 300 coins for six months'**
  String get premium_redeem;

  /// No description provided for @premium_redemption_failed.
  ///
  /// In en, this message translates to:
  /// **'Credit could not be redeemed. Manage any paused subscription, or retry later. Pending credit is reserved and is never charged twice.'**
  String get premium_redemption_failed;

  /// No description provided for @premium_delete_account.
  ///
  /// In en, this message translates to:
  /// **'Delete cloud account'**
  String get premium_delete_account;

  /// No description provided for @premium_delete_warning.
  ///
  /// In en, this message translates to:
  /// **'Delete cloud rewards and account data? Local Vrat history remains on your phone. This does not cancel Google Play subscriptions; manage them first.'**
  String get premium_delete_warning;

  /// No description provided for @premium_terms.
  ///
  /// In en, this message translates to:
  /// **'Privacy and reward terms'**
  String get premium_terms;

  /// No description provided for @premium_coins.
  ///
  /// In en, this message translates to:
  /// **'Coins'**
  String get premium_coins;

  /// No description provided for @premium_more_achievements.
  ///
  /// In en, this message translates to:
  /// **'More achievements with Premium'**
  String get premium_more_achievements;

  /// No description provided for @premium_reward_example.
  ///
  /// In en, this message translates to:
  /// **'Typical year: 24 × 10 = 240 coins, plus a 60-coin full-year bonus = 300 coins. In a 26-Ekadashi year: 260 + 40 = 300.'**
  String get premium_reward_example;

  /// No description provided for @premium_feature_calendar.
  ///
  /// In en, this message translates to:
  /// **'Google Calendar sync for your whole subscription year (one free month sync)'**
  String get premium_feature_calendar;

  /// No description provided for @premium_feature_vrat.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Vrat entries (the first three are free) and all achievements'**
  String get premium_feature_vrat;

  /// No description provided for @premium_feature_panchang.
  ///
  /// In en, this message translates to:
  /// **'Full daily Panchang: all five limbs, city timings and observances'**
  String get premium_feature_panchang;

  /// No description provided for @terms_of_service.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get terms_of_service;

  /// No description provided for @privacy_policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacy_policy;

  /// No description provided for @google_free_sync_used.
  ///
  /// In en, this message translates to:
  /// **'Free sync used. Upgrade to sync the whole year.'**
  String get google_free_sync_used;

  /// No description provided for @google_sign_in_failed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Check your connection and try again.'**
  String get google_sign_in_failed;

  /// No description provided for @vrat_free_limit_reached.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used your three free Vrat entries. Get Premium to keep recording.'**
  String get vrat_free_limit_reached;

  /// No description provided for @google_premium_events_removed.
  ///
  /// In en, this message translates to:
  /// **'Your Premium has ended, so the Google events it synced were removed. Renew to sync again.'**
  String get google_premium_events_removed;

  /// No description provided for @search_filter_ekadashi.
  ///
  /// In en, this message translates to:
  /// **'Ekadashi'**
  String get search_filter_ekadashi;

  /// No description provided for @search_filter_festival.
  ///
  /// In en, this message translates to:
  /// **'Festivals'**
  String get search_filter_festival;

  /// No description provided for @search_filter_amavasya.
  ///
  /// In en, this message translates to:
  /// **'Amavasya'**
  String get search_filter_amavasya;

  /// No description provided for @search_filter_purnima.
  ///
  /// In en, this message translates to:
  /// **'Purnima'**
  String get search_filter_purnima;

  /// No description provided for @search_filter_shivaratri.
  ///
  /// In en, this message translates to:
  /// **'Shivaratri'**
  String get search_filter_shivaratri;

  /// No description provided for @search_filter_chaturthi.
  ///
  /// In en, this message translates to:
  /// **'Chaturthi'**
  String get search_filter_chaturthi;

  /// No description provided for @search_filter_pradosham.
  ///
  /// In en, this message translates to:
  /// **'Pradosham'**
  String get search_filter_pradosham;

  /// No description provided for @search_filter_navaratri.
  ///
  /// In en, this message translates to:
  /// **'Navaratri'**
  String get search_filter_navaratri;

  /// No description provided for @search_filter_sankranti.
  ///
  /// In en, this message translates to:
  /// **'Sankranti'**
  String get search_filter_sankranti;

  /// No description provided for @search_filter_jayanti.
  ///
  /// In en, this message translates to:
  /// **'Jayanti'**
  String get search_filter_jayanti;

  /// No description provided for @search_filter_my_calendar.
  ///
  /// In en, this message translates to:
  /// **'My calendar'**
  String get search_filter_my_calendar;

  /// No description provided for @search_filter_screen.
  ///
  /// In en, this message translates to:
  /// **'In the app'**
  String get search_filter_screen;

  /// No description provided for @search_screen_panchang.
  ///
  /// In en, this message translates to:
  /// **'Panchang'**
  String get search_screen_panchang;

  /// No description provided for @search_hint_all.
  ///
  /// In en, this message translates to:
  /// **'Search Ekadashi, festivals, events…'**
  String get search_hint_all;

  /// No description provided for @search_start_all.
  ///
  /// In en, this message translates to:
  /// **'Find Ekadashis, festivals, Amavasya, Purnima and your events'**
  String get search_start_all;

  /// No description provided for @search_premium_locked.
  ///
  /// In en, this message translates to:
  /// **'Unlock with Premium'**
  String get search_premium_locked;

  /// No description provided for @search_no_results_hint.
  ///
  /// In en, this message translates to:
  /// **'Check the spelling, or try another year or filter.'**
  String get search_no_results_hint;

  /// No description provided for @search_all_years.
  ///
  /// In en, this message translates to:
  /// **'All years'**
  String get search_all_years;

  /// No description provided for @panchang_day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get panchang_day;

  /// No description provided for @panchang_night.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get panchang_night;

  /// No description provided for @panchang_am.
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get panchang_am;

  /// No description provided for @panchang_pm.
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get panchang_pm;

  /// No description provided for @panchang_next_day_marker.
  ///
  /// In en, this message translates to:
  /// **'(next day)'**
  String get panchang_next_day_marker;

  /// No description provided for @panchang_previous_day_marker.
  ///
  /// In en, this message translates to:
  /// **'(previous day)'**
  String get panchang_previous_day_marker;

  /// No description provided for @panchang_section_keydays.
  ///
  /// In en, this message translates to:
  /// **'Key days'**
  String get panchang_section_keydays;

  /// No description provided for @panchang_section_daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get panchang_section_daily;

  /// No description provided for @panchang_section_muhurta.
  ///
  /// In en, this message translates to:
  /// **'Muhurta'**
  String get panchang_section_muhurta;

  /// No description provided for @panchang_section_ekadashi.
  ///
  /// In en, this message translates to:
  /// **'Ekadashi'**
  String get panchang_section_ekadashi;

  /// No description provided for @panchang_section_rashi.
  ///
  /// In en, this message translates to:
  /// **'Rashi'**
  String get panchang_section_rashi;

  /// No description provided for @panchang_search_location.
  ///
  /// In en, this message translates to:
  /// **'Search city or use location'**
  String get panchang_search_location;

  /// No description provided for @panchang_previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get panchang_previous;

  /// No description provided for @panchang_next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get panchang_next;

  /// No description provided for @panchang_pick_date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get panchang_pick_date;

  /// No description provided for @panchang_month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get panchang_month;

  /// No description provided for @panchang_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get panchang_done;

  /// No description provided for @panchang_location_not_saved.
  ///
  /// In en, this message translates to:
  /// **'Location changed, but could not be saved.'**
  String get panchang_location_not_saved;

  /// No description provided for @panchang_notes_title.
  ///
  /// In en, this message translates to:
  /// **'How the Panchang is calculated'**
  String get panchang_notes_title;

  /// No description provided for @panchang_notes_body.
  ///
  /// In en, this message translates to:
  /// **'Everything is calculated on your phone for the chosen location, with its own time zone. Tithi, nakshatra, yoga and karana are taken at local sunrise; times after midnight are marked as the next day. Sunrise and sunset use the visible upper edge of the Sun at sea level, so hills and buildings can shift them by a few minutes.'**
  String get panchang_notes_body;

  /// No description provided for @panchang_notes_traditions.
  ///
  /// In en, this message translates to:
  /// **'Festival dates follow the traditional time-of-day rules and published calendars; regional and family traditions can differ. Months are shown in both the Amanta and Purnimanta systems. Ekadashi dates in Key days, the calendar, reminders and Journey come from the published schedule.'**
  String get panchang_notes_traditions;

  /// No description provided for @panchang_notes_sources.
  ///
  /// In en, this message translates to:
  /// **'Astronomy: VSOP87 and ELP 2000-82B with the Lahiri ayanamsa. Cities: GeoNames (CC BY 4.0). Time zones: IANA database.'**
  String get panchang_notes_sources;

  /// No description provided for @panchang_premium_title.
  ///
  /// In en, this message translates to:
  /// **'Full Panchang is part of Premium'**
  String get panchang_premium_title;

  /// No description provided for @panchang_premium_body.
  ///
  /// In en, this message translates to:
  /// **'Unlock the five limbs, good times and times to avoid, Choghadiya, Hora, Rashi, and every festival and observance in Key days.'**
  String get panchang_premium_body;

  /// No description provided for @panchang_unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock full Panchang'**
  String get panchang_unlock;

  /// No description provided for @panchang_unlock_short.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get panchang_unlock_short;

  /// No description provided for @panchang_key_days_locked.
  ///
  /// In en, this message translates to:
  /// **'Festivals and observances are part of Premium. Ekadashis are free.'**
  String get panchang_key_days_locked;

  /// No description provided for @panchang_no_key_days.
  ///
  /// In en, this message translates to:
  /// **'No key days this month for this filter.'**
  String get panchang_no_key_days;

  /// No description provided for @panchang_days_ago.
  ///
  /// In en, this message translates to:
  /// **'{value0} days ago'**
  String panchang_days_ago(String value0);

  /// No description provided for @panchang_tithi_at_sunrise.
  ///
  /// In en, this message translates to:
  /// **'Tithi at sunrise'**
  String get panchang_tithi_at_sunrise;

  /// No description provided for @panchang_tithi_at_six.
  ///
  /// In en, this message translates to:
  /// **'Tithi at 6 AM (no sunrise)'**
  String get panchang_tithi_at_six;

  /// No description provided for @panchang_until.
  ///
  /// In en, this message translates to:
  /// **'until {value0}'**
  String panchang_until(String value0);

  /// No description provided for @panchang_after.
  ///
  /// In en, this message translates to:
  /// **'after {value0}'**
  String panchang_after(String value0);

  /// No description provided for @panchang_starts_at.
  ///
  /// In en, this message translates to:
  /// **'starts {value0}'**
  String panchang_starts_at(String value0);

  /// No description provided for @panchang_amanta.
  ///
  /// In en, this message translates to:
  /// **'Amanta'**
  String get panchang_amanta;

  /// No description provided for @panchang_purnimanta.
  ///
  /// In en, this message translates to:
  /// **'Purnimanta'**
  String get panchang_purnimanta;

  /// No description provided for @panchang_sunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get panchang_sunrise;

  /// No description provided for @panchang_sunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get panchang_sunset;

  /// No description provided for @panchang_moonrise.
  ///
  /// In en, this message translates to:
  /// **'Moonrise'**
  String get panchang_moonrise;

  /// No description provided for @panchang_moonset.
  ///
  /// In en, this message translates to:
  /// **'Moonset'**
  String get panchang_moonset;

  /// No description provided for @panchang_five_limbs.
  ///
  /// In en, this message translates to:
  /// **'Five limbs'**
  String get panchang_five_limbs;

  /// No description provided for @panchang_tithi.
  ///
  /// In en, this message translates to:
  /// **'Tithi'**
  String get panchang_tithi;

  /// No description provided for @panchang_nakshatra.
  ///
  /// In en, this message translates to:
  /// **'Nakshatra'**
  String get panchang_nakshatra;

  /// No description provided for @panchang_yoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get panchang_yoga;

  /// No description provided for @panchang_karana.
  ///
  /// In en, this message translates to:
  /// **'Karana'**
  String get panchang_karana;

  /// No description provided for @panchang_vara.
  ///
  /// In en, this message translates to:
  /// **'Vara'**
  String get panchang_vara;

  /// No description provided for @panchang_timings.
  ///
  /// In en, this message translates to:
  /// **'Timings'**
  String get panchang_timings;

  /// No description provided for @panchang_good_times.
  ///
  /// In en, this message translates to:
  /// **'Good times'**
  String get panchang_good_times;

  /// No description provided for @panchang_avoid_times.
  ///
  /// In en, this message translates to:
  /// **'Times to avoid'**
  String get panchang_avoid_times;

  /// No description provided for @panchang_observances.
  ///
  /// In en, this message translates to:
  /// **'Observances'**
  String get panchang_observances;

  /// No description provided for @panchang_more_details.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get panchang_more_details;

  /// No description provided for @panchang_sun_rashi.
  ///
  /// In en, this message translates to:
  /// **'Sun rashi'**
  String get panchang_sun_rashi;

  /// No description provided for @panchang_moon_rashi.
  ///
  /// In en, this message translates to:
  /// **'Moon rashi'**
  String get panchang_moon_rashi;

  /// No description provided for @panchang_nakshatra_pada.
  ///
  /// In en, this message translates to:
  /// **'Nakshatra pada'**
  String get panchang_nakshatra_pada;

  /// No description provided for @panchang_ritu.
  ///
  /// In en, this message translates to:
  /// **'Ritu'**
  String get panchang_ritu;

  /// No description provided for @panchang_ayana.
  ///
  /// In en, this message translates to:
  /// **'Ayana'**
  String get panchang_ayana;

  /// No description provided for @panchang_samvat.
  ///
  /// In en, this message translates to:
  /// **'Samvat'**
  String get panchang_samvat;

  /// No description provided for @panchang_samvat_value.
  ///
  /// In en, this message translates to:
  /// **'Shaka {value0} · Vikrama {value1}'**
  String panchang_samvat_value(String value0, String value1);

  /// No description provided for @panchang_anandadi.
  ///
  /// In en, this message translates to:
  /// **'Anandadi yoga'**
  String get panchang_anandadi;

  /// No description provided for @panchang_special_yogas.
  ///
  /// In en, this message translates to:
  /// **'Special yogas'**
  String get panchang_special_yogas;

  /// No description provided for @panchang_none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get panchang_none;

  /// No description provided for @panchang_ayanamsa.
  ///
  /// In en, this message translates to:
  /// **'Lahiri ayanamsa'**
  String get panchang_ayanamsa;

  /// No description provided for @panchang_no_solar_day.
  ///
  /// In en, this message translates to:
  /// **'No complete solar day here today, so sunrise-based periods are unavailable.'**
  String get panchang_no_solar_day;

  /// No description provided for @panchang_transitions.
  ///
  /// In en, this message translates to:
  /// **'Changes until the next sunrise'**
  String get panchang_transitions;

  /// No description provided for @panchang_choghadiya.
  ///
  /// In en, this message translates to:
  /// **'Choghadiya'**
  String get panchang_choghadiya;

  /// No description provided for @panchang_choghadiya_hint.
  ///
  /// In en, this message translates to:
  /// **'Amrit, Shubh and Labh are favourable; Chal is neutral; Rog, Kaal and Udveg are best avoided.'**
  String get panchang_choghadiya_hint;

  /// No description provided for @panchang_hora.
  ///
  /// In en, this message translates to:
  /// **'Hora'**
  String get panchang_hora;

  /// No description provided for @panchang_lagna.
  ///
  /// In en, this message translates to:
  /// **'Udaya Lagna'**
  String get panchang_lagna;

  /// No description provided for @panchang_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable for this day and place.'**
  String get panchang_unavailable;

  /// No description provided for @panchang_now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get panchang_now;

  /// No description provided for @panchang_rashi.
  ///
  /// In en, this message translates to:
  /// **'Rashi'**
  String get panchang_rashi;

  /// No description provided for @panchang_rashi_note.
  ///
  /// In en, this message translates to:
  /// **'These are the Sun and Moon positions for the day (sidereal, Lahiri). Your personal birth rashi needs your birth date, time and place.'**
  String get panchang_rashi_note;

  /// No description provided for @panchang_smarta.
  ///
  /// In en, this message translates to:
  /// **'Smarta'**
  String get panchang_smarta;

  /// No description provided for @panchang_gaudiya.
  ///
  /// In en, this message translates to:
  /// **'Vaishnava · Gaudiya/ISKCON'**
  String get panchang_gaudiya;

  /// No description provided for @panchang_smarta_rule.
  ///
  /// In en, this message translates to:
  /// **'Householders: the Ekadashi at sunrise; when it touches two sunrises, the first day.'**
  String get panchang_smarta_rule;

  /// No description provided for @panchang_gaudiya_rule.
  ///
  /// In en, this message translates to:
  /// **'Gaudiya/ISKCON: Ekadashi must hold 96 minutes before sunrise (Arunodaya), with Mahadvadashi rules.'**
  String get panchang_gaudiya_rule;

  /// No description provided for @panchang_calculation_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not calculate this month.'**
  String get panchang_calculation_failed;

  /// No description provided for @panchang_no_calculated_fast.
  ///
  /// In en, this message translates to:
  /// **'No calculated fast for this month and place; a local sunrise is needed.'**
  String get panchang_no_calculated_fast;

  /// No description provided for @panchang_calculated_preview.
  ///
  /// In en, this message translates to:
  /// **'A calculated preview: the calendar, reminders and Journey keep using the published Ekadashi schedule.'**
  String get panchang_calculated_preview;

  /// No description provided for @panchang_fast_day.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get panchang_fast_day;

  /// No description provided for @panchang_parana.
  ///
  /// In en, this message translates to:
  /// **'Parana'**
  String get panchang_parana;

  /// No description provided for @panchang_near_boundary.
  ///
  /// In en, this message translates to:
  /// **'A change of tithi or nakshatra is within five minutes of a deciding moment. Check this date with your tradition\'s calendar.'**
  String get panchang_near_boundary;

  /// No description provided for @panchang_calculation_details.
  ///
  /// In en, this message translates to:
  /// **'Calculation details'**
  String get panchang_calculation_details;

  /// No description provided for @panchang_rule.
  ///
  /// In en, this message translates to:
  /// **'Rule'**
  String get panchang_rule;

  /// No description provided for @panchang_hari_vasara_ends.
  ///
  /// In en, this message translates to:
  /// **'Hari Vasara ends'**
  String get panchang_hari_vasara_ends;

  /// No description provided for @panchang_search_cities.
  ///
  /// In en, this message translates to:
  /// **'Search cities worldwide'**
  String get panchang_search_cities;

  /// No description provided for @panchang_locating.
  ///
  /// In en, this message translates to:
  /// **'Locating…'**
  String get panchang_locating;

  /// No description provided for @panchang_use_current_location.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get panchang_use_current_location;

  /// No description provided for @panchang_location_name.
  ///
  /// In en, this message translates to:
  /// **'Location name'**
  String get panchang_location_name;

  /// No description provided for @panchang_latitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get panchang_latitude;

  /// No description provided for @panchang_longitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get panchang_longitude;

  /// No description provided for @panchang_timezone.
  ///
  /// In en, this message translates to:
  /// **'Time zone (IANA)'**
  String get panchang_timezone;

  /// No description provided for @panchang_location_footer.
  ///
  /// In en, this message translates to:
  /// **'Example: Asia/Kolkata or America/New_York. City data: GeoNames (CC BY 4.0). Calculations and city search work offline.'**
  String get panchang_location_footer;

  /// No description provided for @panchang_location_title.
  ///
  /// In en, this message translates to:
  /// **'Panchang location'**
  String get panchang_location_title;

  /// No description provided for @panchang_save_location.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get panchang_save_location;

  /// No description provided for @panchang_location_denied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied. Search or enter a location instead.'**
  String get panchang_location_denied;

  /// No description provided for @panchang_location_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable. Search or enter a location instead.'**
  String get panchang_location_unavailable;

  /// No description provided for @panchang_location_received.
  ///
  /// In en, this message translates to:
  /// **'Coordinates received. Check the time zone before saving.'**
  String get panchang_location_received;

  /// No description provided for @journey_tab.
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get journey_tab;

  /// No description provided for @journey_record_after_parana.
  ///
  /// In en, this message translates to:
  /// **'You can record this fast once Parana begins'**
  String get journey_record_after_parana;

  /// No description provided for @settings_premium_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything for your Ekadashi journey'**
  String get settings_premium_subtitle;

  /// No description provided for @premium_feature_panchang_v2.
  ///
  /// In en, this message translates to:
  /// **'Full Panchang: every festival in Key days, the five limbs, timings, Muhurta and Rashi'**
  String get premium_feature_panchang_v2;

  /// No description provided for @settings_premium_from.
  ///
  /// In en, this message translates to:
  /// **'From {value0} a month · Lifetime {value1}'**
  String settings_premium_from(String value0, String value1);

  /// No description provided for @settings_premium_cta.
  ///
  /// In en, this message translates to:
  /// **'See plans'**
  String get settings_premium_cta;

  /// No description provided for @settings_premium_plan.
  ///
  /// In en, this message translates to:
  /// **'Your plan: {value0}'**
  String settings_premium_plan(String value0);

  /// No description provided for @settings_premium_manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get settings_premium_manage;

  /// No description provided for @settings_premium_plans.
  ///
  /// In en, this message translates to:
  /// **'Change plan'**
  String get settings_premium_plans;

  /// No description provided for @widget_today_is_ekadashi.
  ///
  /// In en, this message translates to:
  /// **'Today is Ekadashi'**
  String get widget_today_is_ekadashi;

  /// No description provided for @widget_days_to_go.
  ///
  /// In en, this message translates to:
  /// **'{value0} days to go'**
  String widget_days_to_go(String value0);

  /// No description provided for @widget_fast_done.
  ///
  /// In en, this message translates to:
  /// **'{value0}% of the fast done'**
  String widget_fast_done(String value0);

  /// No description provided for @widget_name_ekadashi.
  ///
  /// In en, this message translates to:
  /// **'Ekadashi'**
  String get widget_name_ekadashi;

  /// No description provided for @widget_desc_ekadashi.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Ekadashi with your fast\'s progress, or the next Ekadashi and the days to go.'**
  String get widget_desc_ekadashi;

  /// No description provided for @widget_desc_upcoming.
  ///
  /// In en, this message translates to:
  /// **'The next Ekadashis at a glance.'**
  String get widget_desc_upcoming;

  /// No description provided for @widget_preview_during.
  ///
  /// In en, this message translates to:
  /// **'Left: now · Right: during the next Ekadashi'**
  String get widget_preview_during;

  /// No description provided for @event_reminder_today.
  ///
  /// In en, this message translates to:
  /// **'{value0} is today ({value1})'**
  String event_reminder_today(String value0, String value1);

  /// No description provided for @event_reminder_tomorrow.
  ///
  /// In en, this message translates to:
  /// **'{value0} is tomorrow ({value1})'**
  String event_reminder_tomorrow(String value0, String value1);

  /// No description provided for @event_reminder_in_days.
  ///
  /// In en, this message translates to:
  /// **'{value0} is in {value2} days ({value1})'**
  String event_reminder_in_days(String value0, String value1, String value2);

  /// No description provided for @event_reminder_all_custom.
  ///
  /// In en, this message translates to:
  /// **'All my entries'**
  String get event_reminder_all_custom;

  /// No description provided for @event_reminder_all_google.
  ///
  /// In en, this message translates to:
  /// **'All Google Calendar events'**
  String get event_reminder_all_google;

  /// No description provided for @event_reminder_group_festival.
  ///
  /// In en, this message translates to:
  /// **'Festivals'**
  String get event_reminder_group_festival;

  /// No description provided for @event_reminder_group_monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly observances'**
  String get event_reminder_group_monthly;

  /// No description provided for @event_reminder_group_my_calendar.
  ///
  /// In en, this message translates to:
  /// **'My calendar'**
  String get event_reminder_group_my_calendar;

  /// No description provided for @notifications_section_ekadashi.
  ///
  /// In en, this message translates to:
  /// **'Ekadashi'**
  String get notifications_section_ekadashi;

  /// No description provided for @notifications_section_events.
  ///
  /// In en, this message translates to:
  /// **'Festivals and events'**
  String get notifications_section_events;

  /// No description provided for @notifications_events_desc.
  ///
  /// In en, this message translates to:
  /// **'Get reminded before festivals, Panchang days and your calendar entries.'**
  String get notifications_events_desc;

  /// No description provided for @notifications_add_event.
  ///
  /// In en, this message translates to:
  /// **'Add a reminder'**
  String get notifications_add_event;

  /// No description provided for @notifications_edit_event.
  ///
  /// In en, this message translates to:
  /// **'Edit reminder'**
  String get notifications_edit_event;

  /// No description provided for @notifications_choose_event.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get notifications_choose_event;

  /// No description provided for @notifications_lead_title.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get notifications_lead_title;

  /// No description provided for @notifications_lead_0.
  ///
  /// In en, this message translates to:
  /// **'On the day'**
  String get notifications_lead_0;

  /// No description provided for @notifications_lead_1.
  ///
  /// In en, this message translates to:
  /// **'1 day before'**
  String get notifications_lead_1;

  /// No description provided for @notifications_lead_n.
  ///
  /// In en, this message translates to:
  /// **'{value0} days before'**
  String notifications_lead_n(String value0);

  /// No description provided for @notifications_time.
  ///
  /// In en, this message translates to:
  /// **'At'**
  String get notifications_time;

  /// No description provided for @notifications_delete_event.
  ///
  /// In en, this message translates to:
  /// **'Delete reminder'**
  String get notifications_delete_event;

  /// No description provided for @notifications_lead_required.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one day'**
  String get notifications_lead_required;

  /// No description provided for @notifications_premium_events.
  ///
  /// In en, this message translates to:
  /// **'Festival and Panchang reminders are part of Premium. Reminders for your calendar entries are free.'**
  String get notifications_premium_events;

  /// No description provided for @notifications_no_events.
  ///
  /// In en, this message translates to:
  /// **'No reminders yet'**
  String get notifications_no_events;

  /// No description provided for @notifications_off_hint.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications to use reminders.'**
  String get notifications_off_hint;

  /// No description provided for @notifications_search_events.
  ///
  /// In en, this message translates to:
  /// **'Search events'**
  String get notifications_search_events;

  /// No description provided for @panchang_enter_name.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get panchang_enter_name;

  /// No description provided for @panchang_invalid_coordinate.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from -{value0} to {value0}'**
  String panchang_invalid_coordinate(String value0);

  /// No description provided for @panchang_invalid_timezone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid time zone, such as Asia/Kolkata'**
  String get panchang_invalid_timezone;

  /// No description provided for @panchang_city_search_unavailable.
  ///
  /// In en, this message translates to:
  /// **'City search is unavailable. Enter the coordinates below.'**
  String get panchang_city_search_unavailable;

  /// No description provided for @observed_of_total.
  ///
  /// In en, this message translates to:
  /// **'{value0} of {value1} Ekadashis'**
  String observed_of_total(String value0, String value1);

  /// No description provided for @timezone_IST.
  ///
  /// In en, this message translates to:
  /// **'IST'**
  String get timezone_IST;

  /// No description provided for @timezone_EST.
  ///
  /// In en, this message translates to:
  /// **'EST'**
  String get timezone_EST;

  /// No description provided for @timezone_CST.
  ///
  /// In en, this message translates to:
  /// **'CST'**
  String get timezone_CST;

  /// No description provided for @timezone_MST.
  ///
  /// In en, this message translates to:
  /// **'MST'**
  String get timezone_MST;

  /// No description provided for @timezone_PST.
  ///
  /// In en, this message translates to:
  /// **'PST'**
  String get timezone_PST;

  /// No description provided for @utc_offset.
  ///
  /// In en, this message translates to:
  /// **'UTC{value0}'**
  String utc_offset(String value0);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'bn',
    'en',
    'gu',
    'hi',
    'ta',
    'te',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
