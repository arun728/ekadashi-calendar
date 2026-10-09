// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get app_title => 'Ekadashi Calendar';

  @override
  String get home => 'Home';

  @override
  String get calendar => 'Calendar';

  @override
  String get settings => 'Settings';

  @override
  String get start_fasting => 'Start Fasting';

  @override
  String get break_fasting => 'Break Fasting';

  @override
  String get view_details => 'View Details';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get passed => 'Passed';

  @override
  String in_days(String value0) {
    return 'in $value0 days';
  }

  @override
  String get locating => 'Locating...';

  @override
  String get detecting_location => 'Detecting Location...';

  @override
  String get location_denied => 'Location Denied';

  @override
  String get failed_load => 'Failed to load data';

  @override
  String get no_ekadashi => 'No Ekadashi on this day';

  @override
  String get significance => 'Significance';

  @override
  String get story_history => 'Story and History';

  @override
  String get fasting_rules => 'Fasting Rules';

  @override
  String get spiritual_benefits => 'Spiritual Benefits';

  @override
  String get appearance => 'Appearance';

  @override
  String get dark_mode => 'Dark Mode';

  @override
  String get notifications => 'Notifications';

  @override
  String get enable_notifications => 'Enable Notifications';

  @override
  String reminders_active(String value0) {
    return '$value0/4 active';
  }

  @override
  String get notify_2day => '2 Days Before';

  @override
  String get notify_1day => '1 Day Before';

  @override
  String get notify_start => 'Start Fasting';

  @override
  String get notify_parana => 'Break Fasting';

  @override
  String get status_active => 'Active';

  @override
  String get status_disabled => 'Disabled';

  @override
  String get test_notification => 'Test Notification';

  @override
  String get test_notification_desc => 'Send a test notification';

  @override
  String get test_notif_title => '🙏 Hari Om!';

  @override
  String get test_notif_body => 'Your test notification works!';

  @override
  String get notifications_off => 'Notifications disabled';

  @override
  String get permissions => 'Permissions';

  @override
  String get permissions_ok => 'All set';

  @override
  String get permissions_needed => 'Action needed';

  @override
  String get alarms_reminders => 'Alarms';

  @override
  String get alarms_enabled => 'Enabled';

  @override
  String get alarms_disabled => 'Disabled';

  @override
  String get battery_optimization => 'Battery';

  @override
  String get battery_desc => 'Open App Settings';

  @override
  String get open_settings => 'Open';

  @override
  String get settings_button => 'Settings';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get rate_app => 'Rate App';

  @override
  String get rate_app_desc => 'Rate us on Play Store';

  @override
  String get notif_test_title => '🙏 Hari Om!';

  @override
  String get notif_test_body => 'Your test notification works!';

  @override
  String get notif_2day_title => 'Upcoming Ekadashi';

  @override
  String get notif_2day_body => 'is in 2 days. Prepare for your fast.';

  @override
  String get notif_1day_title => 'Ekadashi Tomorrow!';

  @override
  String get notif_1day_body => 'is tomorrow. Fasting starts at';

  @override
  String get notif_start_title => 'Ekadashi Starts Now';

  @override
  String get notif_start_body => 'Today is';

  @override
  String get notif_start_suffix => 'Fasting begins now.';

  @override
  String get notif_parana_title => 'Parana Time';

  @override
  String get notif_parana_body => '- You can break your fast now.';

  @override
  String get notif_sent_msg => 'Notification sent!';

  @override
  String get info_close => 'Got it';

  @override
  String get alarms_info_title => 'Alarms & Reminders';

  @override
  String get alarms_info_why => 'Why it\'s needed';

  @override
  String get alarms_info_why_desc =>
      'Ekadashi fasting times are based on specific sunrise times. Exact alarms ensure you receive reminders at the precise moment.';

  @override
  String get alarms_info_steps => 'How to enable';

  @override
  String get alarms_info_step1 => '1. Tap \"Open\" to go to settings';

  @override
  String get alarms_info_step2 => '2. Toggle \"Allow setting alarms\" ON';

  @override
  String get alarms_info_note =>
      'Note: On some devices, this may already be enabled and cannot be changed.';

  @override
  String get battery_info_title => 'Battery Optimization';

  @override
  String get battery_info_why => 'Why it\'s needed';

  @override
  String get battery_info_why_desc =>
      'If battery optimization is enabled, Android may delay or skip your Ekadashi reminders to save power.';

  @override
  String get battery_info_steps => 'How to allow background usage';

  @override
  String get battery_info_step1 => '1. Tap \"Open\" to go to App Info';

  @override
  String get battery_info_step2 =>
      '2. Tap \"Battery\" or \"App battery usage\"';

  @override
  String get battery_info_step3 =>
      '3. Enable \"Allow background usage\" or select \"Unrestricted\"';

  @override
  String get battery_info_note =>
      'This ensures notifications are delivered on time, even when your phone is idle.';

  @override
  String get share_app => 'Share App';

  @override
  String get share_app_desc => 'Tell friends about this app';

  @override
  String get share_message =>
      '🙏 Ekadashi Calendar - Never miss an Ekadashi!\n\nGet reminders for fasting times, read stories & significance of each Ekadashi.\n\nDownload now: https://play.google.com/store/apps/details?id=com.applausestudios.ekadashi_calendar';

  @override
  String get select_city => 'Select City';

  @override
  String get search_city => 'Search city...';

  @override
  String get auto_detect_location => 'Auto-detect Location';

  @override
  String get auto_detect_desc => 'Use GPS to find your city';

  @override
  String get using_auto_location => 'Using auto-detected location';

  @override
  String get disable_auto_manual =>
      'Turn off auto-detect to select a city manually';

  @override
  String get save => 'Save';

  @override
  String get location => 'Location';

  @override
  String get change_city => 'Change City';

  @override
  String get location_permission_title => 'Location Required';

  @override
  String get location_permission_permanent =>
      'Location permission is permanently disabled. Please enable it in App Settings to use location-based features.';

  @override
  String get cancel => 'Cancel';

  @override
  String get app_settings => 'App Settings';

  @override
  String get app_settings_desc => 'Manage permissions & battery';

  @override
  String get perm_guide_title => 'Permissions Guide';

  @override
  String get perm_guide_desc =>
      'For accurate notifications and location features, please allow:\n• Notifications\n• Location\n• Battery (Unrestricted/Background)';

  @override
  String get vrat => 'Vrat';

  @override
  String get journey => 'Vrat';

  @override
  String get overview => 'Overview';

  @override
  String get vrat_tracker => 'Vrat Tracker';

  @override
  String get vrat_tracker_desc =>
      'Keep a private record of your Ekadashi observance.';

  @override
  String get enable_vrat_tracker => 'Enable Vrat Tracker';

  @override
  String get disable_vrat_tracker => 'Disable Vrat Tracker';

  @override
  String get tracker_enabled_msg =>
      'Vrat Tracker enabled. You can now record your observance.';

  @override
  String get tracker_disabled_msg =>
      'Vrat Tracker disabled. Your existing history remains saved.';

  @override
  String get observed => 'Observed';

  @override
  String get partial => 'Partial';

  @override
  String get missed => 'Missed';

  @override
  String get unrecorded => 'Unrecorded';

  @override
  String get not_recorded => 'Not Recorded';

  @override
  String get tap_to_record_instruction =>
      'Tap an Ekadashi to record your observance';

  @override
  String get tap_to_record_semantics => 'Tap to record Vrat';

  @override
  String get record_vrat => 'Record Vrat';

  @override
  String get view_vrat_status => 'View Vrat Status';

  @override
  String get record_observance => 'Record Observance';

  @override
  String get edit_record => 'Edit Record';

  @override
  String get delete_record => 'Delete Record';

  @override
  String get current_streak => 'Current Streak';

  @override
  String get longest_streak => 'Longest Streak';

  @override
  String get annual_completion => 'Annual Completion';

  @override
  String get total_observed => 'Total Observed';

  @override
  String get total_partial => 'Total Partial';

  @override
  String get total_missed => 'Total Missed';

  @override
  String get fasting_method => 'Fasting Method';

  @override
  String get method_full_fast => 'Full Fast';

  @override
  String get method_water_only => 'Water Only';

  @override
  String get method_fruits_milk => 'Fruits / Milk';

  @override
  String get method_one_meal => 'One Meal';

  @override
  String get method_other => 'Other';

  @override
  String get method_other_hint => 'Enter fasting method';

  @override
  String get notes => 'Personal Notes';

  @override
  String get notes_hint => 'Add an optional personal note...';

  @override
  String get history => 'History';

  @override
  String get statistics => 'Statistics';

  @override
  String get achievements => 'Achievements';

  @override
  String get achievement_unlocked => 'Achievement Unlocked';

  @override
  String get next_milestone => 'Next Milestone';

  @override
  String get locked => 'Locked';

  @override
  String get unlocked => 'Unlocked';

  @override
  String get ekadashis_unit => 'Ekadashis';

  @override
  String get filter_all => 'All';

  @override
  String get year => 'Year';

  @override
  String get cannot_record_future =>
      'Future Ekadashis cannot be marked as Observed in advance.';

  @override
  String get delete_confirm => 'Delete this observance record?';

  @override
  String get delete_confirm_desc =>
      'This will remove your record from history. Original calendar data will remain untouched.';

  @override
  String get achievement_first_vrat_title => 'First Vrat';

  @override
  String get achievement_first_vrat_desc =>
      'Your first recorded Ekadashi observance.';

  @override
  String get achievement_5_vrat_title => '5 Ekadashis';

  @override
  String get achievement_5_vrat_desc =>
      'Completed 5 qualifying Ekadashi observances.';

  @override
  String get achievement_10_vrat_title => '10 Ekadashis';

  @override
  String get achievement_10_vrat_desc =>
      'Completed 10 qualifying Ekadashi observances.';

  @override
  String get achievement_12_vrat_title => '12 Ekadashis';

  @override
  String get achievement_12_vrat_desc =>
      'Completed 12 qualifying Ekadashi observances.';

  @override
  String get achievement_consistent_title => 'Consistent Observance';

  @override
  String get achievement_consistent_desc =>
      'Observed 3 consecutive Ekadashis with devotion.';

  @override
  String get achievement_full_year_title => 'Full-Year Observance';

  @override
  String get achievement_full_year_desc =>
      'Observed all Ekadashis in a single calendar year.';

  @override
  String get filter_google => 'Google';

  @override
  String get filter_custom => 'Custom';

  @override
  String get filter_ekadashi => 'Ekadashi';

  @override
  String get all_day => 'All day';

  @override
  String get no_entries => 'No entries for this day';

  @override
  String get add_entry => 'Add entry';

  @override
  String get edit_entry => 'Edit entry';

  @override
  String get entry_title => 'Title';

  @override
  String get entry_notes => 'Notes (optional)';

  @override
  String get entry_starts => 'Starts';

  @override
  String get entry_ends => 'Ends';

  @override
  String get invalid_entry =>
      'Enter a title and an end time after the start time.';

  @override
  String get sync_google => 'Import Google Calendar';

  @override
  String get disconnect_google => 'Disconnect Google Calendar';

  @override
  String get sign_in_cancelled => 'Google sign-in cancelled';

  @override
  String get no_google_calendars => 'No Google calendars found';

  @override
  String get no_google_events =>
      'No events in selected calendars for this year';

  @override
  String imported_google_events(String value0) {
    return 'Imported $value0 Google events';
  }

  @override
  String imported_google_range(String value0, String value1, String value2) {
    return 'Imported $value0 Google events ($value1 – $value2)';
  }

  @override
  String get google_sync_failed =>
      'Calendar import failed. Previous entries were kept. Please try again.';

  @override
  String get storage_failed =>
      'Calendar storage is unavailable. Please try again.';

  @override
  String get retry => 'Try again';

  @override
  String get choose_calendars => 'Calendars to import';

  @override
  String get choose_calendars_help =>
      'Select calendars to display in this app. Import does not change your Google events.';

  @override
  String get switch_google_account => 'Use another account';

  @override
  String get google_calendar => 'Google Calendar';

  @override
  String get primary_calendar => 'Primary';

  @override
  String get import_selected => 'Import selected';

  @override
  String get content_fallback =>
      'This archived content is currently available in English.';

  @override
  String get translation_pending =>
      'Translations are awaiting language review.';

  @override
  String get tracker_storage_failed =>
      'Your record could not be saved. Please try again.';

  @override
  String get next_ekadashi => 'Next Ekadashi';

  @override
  String get search => 'Search';

  @override
  String get search_hint => 'Search Ekadashi, Katha, Mantra, Food...';

  @override
  String get recent_searches => 'Recent Searches';

  @override
  String get clear_all => 'Clear All';

  @override
  String get no_results_found => 'No results found for';

  @override
  String get offline_indicator => 'Offline — showing downloaded content';

  @override
  String get online_only => 'Online Only';

  @override
  String get download => 'Download';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get try_searching => 'Try searching for:';

  @override
  String get filter_by => 'Filter by category';

  @override
  String get did_you_mean => 'Did you mean:';

  @override
  String get category_all => 'All';

  @override
  String get category_ekadashi => 'Ekadashi';

  @override
  String get category_katha => 'Katha';

  @override
  String get category_mantra => 'Mantra';

  @override
  String get category_food => 'Food';

  @override
  String get category_vrat => 'Vrat Info';

  @override
  String get category_festival => 'Festival';

  @override
  String get category_temple => 'Temple';

  @override
  String get category_event => 'Event';

  @override
  String get widgets => 'Widgets';

  @override
  String get widget_preview => 'Widget Preview';

  @override
  String get widget_preview_desc => 'Preview Home Screen Widgets';

  @override
  String get fasting_active => 'Fasting active';

  @override
  String get parana_available => 'Parana available';

  @override
  String get parana_completed => 'Parana completed';

  @override
  String get open_app_to_refresh => 'Open the app to refresh timings';

  @override
  String get upcoming_ekadashis => 'Upcoming Ekadashis';

  @override
  String get widget_today_title => 'Ekadashi Today';

  @override
  String get widget_parana_in => 'Parana in';

  @override
  String get widget_parana_ends => 'Parana ends in';

  @override
  String get widget_starts_in => 'Starts in';

  @override
  String get widget_notice => 'Notice';

  @override
  String get widget_now => 'Now';

  @override
  String get widget_day_unit => 'd';

  @override
  String get widget_hour_unit => 'h';

  @override
  String get widget_minute_unit => 'min';

  @override
  String get hari_om => 'Hari Om 🙏';

  @override
  String get offline_mode => 'Offline mode active';

  @override
  String get online_mode => 'Online search mode';

  @override
  String get search_start => 'Search across Ekadashi content';

  @override
  String results_count(String value0) {
    return '$value0 results';
  }

  @override
  String get saved_offline => 'Saved for offline reading';

  @override
  String get share => 'Share';

  @override
  String get search_content_language => 'Content language';

  @override
  String get search_script => 'Script';

  @override
  String get search_transliteration => 'Transliteration';

  @override
  String get search_meaning => 'Meaning';

  @override
  String get search_ingredients => 'Ingredients';

  @override
  String get search_steps => 'Steps';

  @override
  String get search_rules => 'Rules';

  @override
  String get search_stages => 'Stages';

  @override
  String get search_levels => 'Levels';

  @override
  String get search_location => 'Location';

  @override
  String get search_deity => 'Deity';

  @override
  String get search_date => 'Date';

  @override
  String get search_organizers => 'Organizers';

  @override
  String get paksha_krishna => 'Krishna';

  @override
  String get paksha_shukla => 'Shukla';

  @override
  String get lunar_month_adhika => 'Adhika';

  @override
  String get lunar_month_ashadha => 'Ashadha';

  @override
  String get lunar_month_ashwin => 'Ashwin';

  @override
  String get lunar_month_bhadrapada => 'Bhadrapada';

  @override
  String get lunar_month_chaitra => 'Chaitra';

  @override
  String get lunar_month_jyeshtha => 'Jyeshtha';

  @override
  String get lunar_month_kartik => 'Kartik';

  @override
  String get lunar_month_magha => 'Magha';

  @override
  String get lunar_month_margashirsha => 'Margashirsha';

  @override
  String get lunar_month_pausha => 'Pausha';

  @override
  String get lunar_month_phalguna => 'Phalguna';

  @override
  String get lunar_month_shravana => 'Shravana';

  @override
  String get lunar_month_vaishakha => 'Vaishakha';

  @override
  String get splash_mantra => 'Om Namo Narayana!';

  @override
  String get no_offline_results =>
      'No offline results found. Save content for offline access.';

  @override
  String get premium_title => 'Ekadashi Premium';

  @override
  String get premium_benefits =>
      'Unlock everything in Ekadashi Premium. Ekadashi dates, reminders, widgets, custom entries and your saved Vrat history stay free.';

  @override
  String get premium_free_achievements =>
      'Your first three Vrat entries and first three achievements are free. Premium unlocks the rest.';

  @override
  String get premium_monthly => 'Monthly';

  @override
  String get premium_yearly => 'Yearly';

  @override
  String get premium_lifetime => 'Lifetime';

  @override
  String get premium_monthly_terms =>
      'Full price charged each month. Automatically renews until canceled in Google Play.';

  @override
  String get premium_yearly_terms =>
      'Full price charged each year. Automatically renews until canceled in Google Play.';

  @override
  String get premium_lifetime_terms =>
      'One payment, no renewal. Manage or cancel an existing subscription before buying lifetime to avoid duplicate charges.';

  @override
  String get premium_sign_in => 'Sign in securely with Google';

  @override
  String get premium_continue_free => 'Continue free';

  @override
  String get premium_restore => 'Restore purchases';

  @override
  String get premium_manage => 'Manage subscription in Google Play';

  @override
  String get premium_active => 'Premium access active';

  @override
  String get premium_current_plan => 'Your current plan';

  @override
  String get premium_best_value => 'Best value';

  @override
  String get premium_per_month => 'per month';

  @override
  String get premium_per_year => 'per year';

  @override
  String get premium_one_time => 'one-time';

  @override
  String get premium_cancelled_title => 'Subscription cancelled';

  @override
  String get premium_cancelled_body =>
      'Premium stays on until the end of the period you paid for. Reactivate anytime to keep it.';

  @override
  String get premium_reactivate => 'Reactivate';

  @override
  String get free_sync_unverified =>
      'Couldn\'t check your free sync. Check your connection, or get Premium.';

  @override
  String get premium_upgrade => 'Upgrade';

  @override
  String get premium_restored => 'Purchases restored. Premium is active.';

  @override
  String get premium_restore_none =>
      'No purchases found for this Google Play account.';

  @override
  String get premium_lifetime_thanks_title => 'Thank you, lifetime member! 🙏';

  @override
  String get premium_lifetime_thanks_body =>
      'Every Premium feature is yours for life, including all future features and updates. We look forward to serving you for years to come.';

  @override
  String get premium_subscriber_title => 'You have Premium ✨';

  @override
  String get premium_subscriber_body => 'Switch plans or go lifetime anytime.';

  @override
  String get premium_cancel_subscription_note =>
      'Your subscription is still active. Cancel it in Google Play so you are not charged again. Lifetime stays yours.';

  @override
  String get premium_cancel_subscription_action =>
      'Cancel subscription in Google Play';

  @override
  String get premium_lifetime_confirm_title =>
      'You already have a subscription';

  @override
  String get premium_lifetime_confirm_body =>
      'Google Play does not cancel subscriptions automatically. After buying lifetime, cancel your subscription in Google Play to stop renewals.';

  @override
  String get premium_buy_lifetime_anyway => 'Buy lifetime';

  @override
  String get premium_unavailable =>
      'Purchases are unavailable right now. Install the app from Google Play and try again. Free features still work.';

  @override
  String get premium_verification_failed =>
      'Purchase verification is pending. Try Restore purchases; access is granted only after verification.';

  @override
  String get premium_pending => 'Awaiting payment confirmation';

  @override
  String get premium_wallet => 'Fasting rewards';

  @override
  String get premium_reward_rules =>
      'Earn 10 coins per completed Ekadashi. Completing every Ekadashi in a supported year adds a bonus to reach 300 coins. Redeem 300 coins for six months of premium access. Rewards require no purchase and are self-reported. Coins have no cash value, cannot be bought or transferred, and cannot be refunded as money. Correcting or deleting completion reverses its coins.';

  @override
  String get premium_reward_consent =>
      'Activate cloud rewards? Completion identifiers, status and your selected calendar region are uploaded with sync metadata. Notes and fasting details remain on your phone.';

  @override
  String get premium_reward_activate => 'Activate rewards';

  @override
  String get premium_reward_sync_failed =>
      'Rewards could not sync. Your private Vrat records are safe. Retry after connecting; conflicting edits may require support.';

  @override
  String get premium_redeem => 'Redeem 300 coins for six months';

  @override
  String get premium_redemption_failed =>
      'Credit could not be redeemed. Manage any paused subscription, or retry later. Pending credit is reserved and is never charged twice.';

  @override
  String get premium_delete_account => 'Delete cloud account';

  @override
  String get premium_delete_warning =>
      'Delete cloud rewards and account data? Local Vrat history remains on your phone. This does not cancel Google Play subscriptions; manage them first.';

  @override
  String get premium_terms => 'Privacy and reward terms';

  @override
  String get premium_coins => 'Coins';

  @override
  String get premium_more_achievements => 'More achievements with Premium';

  @override
  String get premium_reward_example =>
      'Typical year: 24 × 10 = 240 coins, plus a 60-coin full-year bonus = 300 coins. In a 26-Ekadashi year: 260 + 40 = 300.';

  @override
  String get premium_feature_calendar =>
      'Google Calendar sync for your whole subscription year (one free month sync)';

  @override
  String get premium_feature_vrat =>
      'Unlimited Vrat entries (the first three are free) and all achievements';

  @override
  String get premium_feature_panchang =>
      'Full daily Panchang: all five limbs, city timings and observances';

  @override
  String get terms_of_service => 'Terms of service';

  @override
  String get privacy_policy => 'Privacy policy';

  @override
  String get google_free_sync_used =>
      'Free sync used. Upgrade to sync the whole year.';

  @override
  String get google_sign_in_failed =>
      'Google sign-in failed. Check your connection and try again.';

  @override
  String get vrat_free_limit_reached =>
      'You\'ve used your three free Vrat entries. Get Premium to keep recording.';

  @override
  String get google_premium_events_removed =>
      'Your Premium has ended, so the Google events it synced were removed. Renew to sync again.';

  @override
  String observed_of_total(String value0, String value1) {
    return '$value0 of $value1 Ekadashis';
  }

  @override
  String get timezone_IST => 'IST';

  @override
  String get timezone_EST => 'EST';

  @override
  String get timezone_CST => 'CST';

  @override
  String get timezone_MST => 'MST';

  @override
  String get timezone_PST => 'PST';

  @override
  String utc_offset(String value0) {
    return 'UTC$value0';
  }
}
