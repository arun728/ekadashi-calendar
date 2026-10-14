import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' show IconData, Icons;

/// Every icon the app shows, by the place it is used: the CupertinoIcons
/// twin of the SF Symbol iOS shows there (AppSymbol in EkadashiCore), checked
/// against test/fixtures/app_icons.json (docs/ICONS.md). Screens use these,
/// never Icons or CupertinoIcons directly.
class AppIcons {
  const AppIcons._();

  /// leaf.fill
  static const achievementFirst = Icons.eco;

  /// star
  static const achievementFive = CupertinoIcons.star;

  /// sun.max.fill
  static const achievementFullYear = CupertinoIcons.sun_max_fill;

  /// lock
  static const achievementLocked = CupertinoIcons.lock;

  /// bolt.fill
  static const achievementStreak = CupertinoIcons.bolt_fill;

  /// checkmark.seal.fill
  static const achievementTen = CupertinoIcons.checkmark_seal_fill;

  /// rosette
  static const achievementTwelve = CupertinoIcons.rosette;

  /// plus
  static const add = CupertinoIcons.plus;

  /// plus.circle.fill
  static const addReminder = CupertinoIcons.plus_circle_fill;

  /// gearshape
  static const appSettings = CupertinoIcons.gear_alt;

  /// chevron.backward
  static const back = CupertinoIcons.chevron_back;

  /// arrow.clockwise.circle
  static const backgroundRefresh = CupertinoIcons.arrow_clockwise_circle;

  /// sunrise
  static const breakFasting = CupertinoIcons.sunrise;

  /// checkmark.circle.fill
  static const cardObserved = CupertinoIcons.checkmark_circle_fill;

  /// calendar.badge.plus
  static const cardUnrecorded = CupertinoIcons.calendar_badge_plus;

  /// moon
  static const categoryAmavasya = CupertinoIcons.moon;

  /// hexagon
  static const categoryChaturthi = CupertinoIcons.hexagon;

  /// leaf
  static const categoryEkadashi = Icons.eco;

  /// sparkles
  static const categoryFestival = CupertinoIcons.sparkles;

  /// star
  static const categoryJayanti = CupertinoIcons.star;

  /// calendar
  static const categoryMyCalendar = CupertinoIcons.calendar;

  /// flame
  static const categoryNavaratri = CupertinoIcons.flame;

  /// sunset
  static const categoryPradosham = CupertinoIcons.sunset;

  /// moon.fill
  static const categoryPurnima = CupertinoIcons.moon_fill;

  /// sun.max
  static const categorySankranti = CupertinoIcons.sun_max;

  /// arrow.up.right.square
  static const categoryScreen = CupertinoIcons.arrow_up_right_square;

  /// moon.stars
  static const categoryShivaratri = CupertinoIcons.moon_stars;

  /// checkmark
  static const checkmark = CupertinoIcons.checkmark;

  /// circle.grid.3x3
  static const choghadiya = CupertinoIcons.circle_grid_3x3;

  /// xmark
  static const close = CupertinoIcons.xmark;

  /// moon.fill
  static const darkMode = CupertinoIcons.moon_fill;

  /// trash
  static const delete = CupertinoIcons.trash;

  /// chevron.down
  static const dismissDown = CupertinoIcons.chevron_down;

  /// pencil
  static const edit = CupertinoIcons.pencil;

  /// exclamationmark.circle
  static const error = CupertinoIcons.exclamationmark_circle;

  /// circle.grid.hex
  static const fiveLimbs = CupertinoIcons.circle_grid_hex;

  /// person.crop.circle
  static const googleAccount = CupertinoIcons.person_crop_circle;

  /// person.crop.circle.badge.minus
  static const googleDisconnect = CupertinoIcons.person_crop_circle_badge_minus;

  /// arrow.triangle.2.circlepath.circle
  static const googleMenu = CupertinoIcons.arrow_2_circlepath_circle;

  /// arrow.triangle.2.circlepath
  static const googleSync = CupertinoIcons.arrow_2_circlepath;

  /// globe
  static const homeLanguage = CupertinoIcons.globe;

  /// sparkles
  static const homeTradition = CupertinoIcons.sparkles;

  /// calendar
  static const homeYear = CupertinoIcons.calendar;

  /// hourglass
  static const hora = CupertinoIcons.hourglass;

  /// info.circle
  static const info = CupertinoIcons.info_circle;

  /// checkmark.seal.fill
  static const journeyBest = CupertinoIcons.checkmark_seal_fill;

  /// leaf
  static const journeyEmpty = Icons.eco;

  /// flag
  static const journeyMilestone = CupertinoIcons.flag;

  /// checkmark.circle
  static const journeyObserved = CupertinoIcons.checkmark_circle;

  /// clock
  static const journeyPending = CupertinoIcons.clock;

  /// chart.pie
  static const journeyRate = CupertinoIcons.chart_pie;

  /// exclamationmark.triangle
  static const journeyStorageFailed = CupertinoIcons.exclamationmark_triangle;

  /// flame
  static const journeyStreak = CupertinoIcons.flame;

  /// calendar
  static const journeyYear = CupertinoIcons.calendar;

  /// globe
  static const lagna = CupertinoIcons.globe;

  /// location.fill
  static const locationDetected = CupertinoIcons.location_fill;

  /// mappin.and.ellipse
  static const locationPicked = CupertinoIcons.map_pin_ellipse;

  /// lock.fill
  static const lock = CupertinoIcons.lock_fill;

  /// chevron.down
  static const menuDisclosure = CupertinoIcons.chevron_down;

  /// moon.fill
  static const moonRashi = CupertinoIcons.moon_fill;

  /// moon.fill
  static const moonrise = CupertinoIcons.moon_fill;

  /// moon
  static const moonset = CupertinoIcons.moon;

  /// list.bullet.below.rectangle
  static const moreDetails = CupertinoIcons.list_bullet_below_rectangle;

  /// star.fill
  static const nakshatra = CupertinoIcons.star_fill;

  /// chevron.right
  static const next = CupertinoIcons.chevron_right;

  /// calendar.badge.minus
  static const noEkadashi = CupertinoIcons.calendar_badge_minus;

  /// star.fill
  static const observanceMajor = CupertinoIcons.star_fill;

  /// circle.fill
  static const observanceMinor = CupertinoIcons.circle_fill;

  /// sparkles
  static const observances = CupertinoIcons.sparkles;

  /// mappin.and.ellipse
  static const panchangCity = CupertinoIcons.map_pin_ellipse;

  /// calendar
  static const panchangDate = CupertinoIcons.calendar;

  /// sparkles
  static const panchangObservance = CupertinoIcons.sparkles;

  /// moon
  static const panchangTithi = CupertinoIcons.moon;

  /// star.fill
  static const panchangUnlock = CupertinoIcons.star_fill;

  /// calendar
  static const panchangVara = CupertinoIcons.calendar;

  /// star.circle.fill
  static const premium = CupertinoIcons.star_circle_fill;

  /// calendar.badge.plus
  static const premiumCalendar = CupertinoIcons.calendar_badge_plus;

  /// sparkles
  static const premiumPanchang = CupertinoIcons.sparkles;

  /// rosette
  static const premiumVrat = CupertinoIcons.rosette;

  /// chevron.left
  static const previous = CupertinoIcons.chevron_left;

  /// star.fill
  static const rateApp = CupertinoIcons.star_fill;

  /// clock
  static const recentSearch = CupertinoIcons.clock;

  /// calendar
  static const reminderCustom = CupertinoIcons.calendar;

  /// calendar.circle
  static const reminderGoogle = CupertinoIcons.calendar_circle;

  /// sparkles
  static const reminderObservance = CupertinoIcons.sparkles;

  /// chevron.right
  static const rowDisclosure = CupertinoIcons.chevron_right;

  /// square.and.arrow.down
  static const save = CupertinoIcons.square_arrow_down;

  /// magnifyingglass
  static const search = CupertinoIcons.search;

  /// square.grid.2x2
  static const searchAllCategories = CupertinoIcons.square_grid_2x2;

  /// xmark.circle.fill
  static const searchClear = CupertinoIcons.xmark_circle_fill;

  /// square.and.arrow.up
  static const share = CupertinoIcons.square_arrow_up;

  /// leaf.fill
  static const shareCardBrand = Icons.eco;

  /// sunrise.fill
  static const shareCardFasting = CupertinoIcons.sunrise_fill;

  /// sun.max.fill
  static const shareCardParana = CupertinoIcons.sun_max_fill;

  /// sparkles
  static const shareCardSignificance = CupertinoIcons.sparkles;

  /// sun.max.fill
  static const shareCardSun = CupertinoIcons.sun_max_fill;

  /// sunrise.fill
  static const startFasting = CupertinoIcons.sunrise_fill;

  /// xmark.circle
  static const statusMissed = CupertinoIcons.xmark_circle;

  /// checkmark.circle
  static const statusObserved = CupertinoIcons.checkmark_circle;

  /// circle.lefthalf.fill
  static const statusPartial = CupertinoIcons.circle_lefthalf_fill;

  /// questionmark.circle
  static const statusUnrecorded = CupertinoIcons.question_circle;

  /// sun.max.fill
  static const sunRashi = CupertinoIcons.sun_max_fill;

  /// sunrise.fill
  static const sunrise = CupertinoIcons.sunrise_fill;

  /// sunset.fill
  static const sunset = CupertinoIcons.sunset_fill;

  /// calendar
  static const tabCalendar = CupertinoIcons.calendar;

  /// house.fill
  static const tabHome = CupertinoIcons.house_fill;

  /// rosette
  static const tabJourney = CupertinoIcons.rosette;

  /// sparkles
  static const tabPanchang = CupertinoIcons.sparkles;

  /// gearshape.fill
  static const tabSettings = CupertinoIcons.gear_alt_fill;

  /// bell
  static const testNotification = CupertinoIcons.bell;

  /// clock
  static const timings = CupertinoIcons.clock;

  /// location
  static const useCurrentLocation = CupertinoIcons.location;

  /// exclamationmark.triangle
  static const warning = CupertinoIcons.exclamationmark_triangle;

  /// square.grid.2x2
  static const widgetPreview = CupertinoIcons.square_grid_2x2;

  /// calendar
  static const year = CupertinoIcons.calendar;

  /// Every role by its fixture name, for the parity tests.
  static const all = <String, IconData>{
    'achievement_first': achievementFirst,
    'achievement_five': achievementFive,
    'achievement_full_year': achievementFullYear,
    'achievement_locked': achievementLocked,
    'achievement_streak': achievementStreak,
    'achievement_ten': achievementTen,
    'achievement_twelve': achievementTwelve,
    'add': add,
    'add_reminder': addReminder,
    'app_settings': appSettings,
    'back': back,
    'background_refresh': backgroundRefresh,
    'break_fasting': breakFasting,
    'card_observed': cardObserved,
    'card_unrecorded': cardUnrecorded,
    'category_amavasya': categoryAmavasya,
    'category_chaturthi': categoryChaturthi,
    'category_ekadashi': categoryEkadashi,
    'category_festival': categoryFestival,
    'category_jayanti': categoryJayanti,
    'category_my_calendar': categoryMyCalendar,
    'category_navaratri': categoryNavaratri,
    'category_pradosham': categoryPradosham,
    'category_purnima': categoryPurnima,
    'category_sankranti': categorySankranti,
    'category_screen': categoryScreen,
    'category_shivaratri': categoryShivaratri,
    'checkmark': checkmark,
    'choghadiya': choghadiya,
    'close': close,
    'dark_mode': darkMode,
    'delete': delete,
    'dismiss_down': dismissDown,
    'edit': edit,
    'error': error,
    'five_limbs': fiveLimbs,
    'google_account': googleAccount,
    'google_disconnect': googleDisconnect,
    'google_menu': googleMenu,
    'google_sync': googleSync,
    'home_language': homeLanguage,
    'home_tradition': homeTradition,
    'home_year': homeYear,
    'hora': hora,
    'info': info,
    'journey_best': journeyBest,
    'journey_empty': journeyEmpty,
    'journey_milestone': journeyMilestone,
    'journey_observed': journeyObserved,
    'journey_pending': journeyPending,
    'journey_rate': journeyRate,
    'journey_storage_failed': journeyStorageFailed,
    'journey_streak': journeyStreak,
    'journey_year': journeyYear,
    'lagna': lagna,
    'location_detected': locationDetected,
    'location_picked': locationPicked,
    'lock': lock,
    'menu_disclosure': menuDisclosure,
    'moon_rashi': moonRashi,
    'moonrise': moonrise,
    'moonset': moonset,
    'more_details': moreDetails,
    'nakshatra': nakshatra,
    'next': next,
    'no_ekadashi': noEkadashi,
    'observance_major': observanceMajor,
    'observance_minor': observanceMinor,
    'observances': observances,
    'panchang_city': panchangCity,
    'panchang_date': panchangDate,
    'panchang_observance': panchangObservance,
    'panchang_tithi': panchangTithi,
    'panchang_unlock': panchangUnlock,
    'panchang_vara': panchangVara,
    'premium': premium,
    'premium_calendar': premiumCalendar,
    'premium_panchang': premiumPanchang,
    'premium_vrat': premiumVrat,
    'previous': previous,
    'rate_app': rateApp,
    'recent_search': recentSearch,
    'reminder_custom': reminderCustom,
    'reminder_google': reminderGoogle,
    'reminder_observance': reminderObservance,
    'row_disclosure': rowDisclosure,
    'save': save,
    'search': search,
    'search_all_categories': searchAllCategories,
    'search_clear': searchClear,
    'share': share,
    'share_card_brand': shareCardBrand,
    'share_card_fasting': shareCardFasting,
    'share_card_parana': shareCardParana,
    'share_card_significance': shareCardSignificance,
    'share_card_sun': shareCardSun,
    'start_fasting': startFasting,
    'status_missed': statusMissed,
    'status_observed': statusObserved,
    'status_partial': statusPartial,
    'status_unrecorded': statusUnrecorded,
    'sun_rashi': sunRashi,
    'sunrise': sunrise,
    'sunset': sunset,
    'tab_calendar': tabCalendar,
    'tab_home': tabHome,
    'tab_journey': tabJourney,
    'tab_panchang': tabPanchang,
    'tab_settings': tabSettings,
    'test_notification': testNotification,
    'timings': timings,
    'use_current_location': useCurrentLocation,
    'warning': warning,
    'widget_preview': widgetPreview,
    'year': year,
  };
}
