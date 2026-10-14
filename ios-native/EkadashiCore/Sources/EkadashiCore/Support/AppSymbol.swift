import Foundation

/// Every SF Symbol the app shows, by the place it is used. Android shows the
/// CupertinoIcons twin of each (AppIcons in lib/widgets/app_icons.dart), and
/// both are checked against test/fixtures/app_icons.json (docs/ICONS.md).
public enum AppSymbol {
    public static let achievementFirst = "leaf.fill"
    public static let achievementFive = "star"
    public static let achievementFullYear = "sun.max.fill"
    public static let achievementLocked = "lock"
    public static let achievementStreak = "bolt.fill"
    public static let achievementTen = "checkmark.seal.fill"
    public static let achievementTwelve = "rosette"
    public static let add = "plus"
    public static let addReminder = "plus.circle.fill"
    public static let appSettings = "gearshape"
    public static let back = "chevron.backward"
    public static let backgroundRefresh = "arrow.clockwise.circle"
    public static let breakFasting = "sunrise"
    public static let cardObserved = "checkmark.circle.fill"
    public static let cardUnrecorded = "calendar.badge.plus"
    public static let categoryAmavasya = "moon"
    public static let categoryChaturthi = "hexagon"
    public static let categoryEkadashi = "leaf"
    public static let categoryFestival = "sparkles"
    public static let categoryJayanti = "star"
    public static let categoryMyCalendar = "calendar"
    public static let categoryNavaratri = "flame"
    public static let categoryPradosham = "sunset"
    public static let categoryPurnima = "moon.fill"
    public static let categorySankranti = "sun.max"
    public static let categoryScreen = "arrow.up.right.square"
    public static let categoryShivaratri = "moon.stars"
    public static let checkmark = "checkmark"
    public static let choghadiya = "circle.grid.3x3"
    public static let close = "xmark"
    public static let darkMode = "moon.fill"
    public static let delete = "trash"
    public static let dismissDown = "chevron.down"
    public static let edit = "pencil"
    public static let error = "exclamationmark.circle"
    public static let fiveLimbs = "circle.grid.hex"
    public static let googleAccount = "person.crop.circle"
    public static let googleDisconnect = "person.crop.circle.badge.minus"
    public static let googleMenu = "arrow.triangle.2.circlepath.circle"
    public static let googleSync = "arrow.triangle.2.circlepath"
    public static let homeLanguage = "globe"
    public static let homeTradition = "sparkles"
    public static let homeYear = "calendar"
    public static let hora = "hourglass"
    public static let info = "info.circle"
    public static let journeyBest = "checkmark.seal.fill"
    public static let journeyEmpty = "leaf"
    public static let journeyMilestone = "flag"
    public static let journeyObserved = "checkmark.circle"
    public static let journeyPending = "clock"
    public static let journeyRate = "chart.pie"
    public static let journeyStorageFailed = "exclamationmark.triangle"
    public static let journeyStreak = "flame"
    public static let journeyYear = "calendar"
    public static let lagna = "globe"
    public static let locationDetected = "location.fill"
    public static let locationPicked = "mappin.and.ellipse"
    public static let lock = "lock.fill"
    public static let menuDisclosure = "chevron.down"
    public static let moonRashi = "moon.fill"
    public static let moonrise = "moon.fill"
    public static let moonset = "moon"
    public static let moreDetails = "list.bullet.below.rectangle"
    public static let nakshatra = "star.fill"
    public static let next = "chevron.right"
    public static let noEkadashi = "calendar.badge.minus"
    public static let observanceMajor = "star.fill"
    public static let observanceMinor = "circle.fill"
    public static let observances = "sparkles"
    public static let panchangCity = "mappin.and.ellipse"
    public static let panchangDate = "calendar"
    public static let panchangObservance = "sparkles"
    public static let panchangTithi = "moon"
    public static let panchangUnlock = "star.fill"
    public static let panchangVara = "calendar"
    public static let premium = "star.circle.fill"
    public static let premiumCalendar = "calendar.badge.plus"
    public static let premiumPanchang = "sparkles"
    public static let premiumVrat = "rosette"
    public static let previous = "chevron.left"
    public static let rateApp = "star.fill"
    public static let recentSearch = "clock"
    public static let reminderCustom = "calendar"
    public static let reminderGoogle = "calendar.circle"
    public static let reminderObservance = "sparkles"
    public static let rowDisclosure = "chevron.right"
    public static let save = "square.and.arrow.down"
    public static let search = "magnifyingglass"
    public static let searchAllCategories = "square.grid.2x2"
    public static let searchClear = "xmark.circle.fill"
    public static let share = "square.and.arrow.up"
    public static let shareCardBrand = "leaf.fill"
    public static let shareCardFasting = "sunrise.fill"
    public static let shareCardParana = "sun.max.fill"
    public static let shareCardSignificance = "sparkles"
    public static let shareCardSun = "sun.max.fill"
    public static let startFasting = "sunrise.fill"
    public static let statusMissed = "xmark.circle"
    public static let statusObserved = "checkmark.circle"
    public static let statusPartial = "circle.lefthalf.fill"
    public static let statusUnrecorded = "questionmark.circle"
    public static let sunRashi = "sun.max.fill"
    public static let sunrise = "sunrise.fill"
    public static let sunset = "sunset.fill"
    public static let tabCalendar = "calendar"
    public static let tabHome = "house.fill"
    public static let tabJourney = "rosette"
    public static let tabPanchang = "sparkles"
    public static let tabSettings = "gearshape.fill"
    public static let testNotification = "bell"
    public static let timings = "clock"
    public static let useCurrentLocation = "location"
    public static let warning = "exclamationmark.triangle"
    public static let widgetPreview = "square.grid.2x2"
    public static let year = "calendar"

    /// Every role by its fixture name, for the parity tests.
    public static let all: [String: String] = [
        "achievement_first": achievementFirst,
        "achievement_five": achievementFive,
        "achievement_full_year": achievementFullYear,
        "achievement_locked": achievementLocked,
        "achievement_streak": achievementStreak,
        "achievement_ten": achievementTen,
        "achievement_twelve": achievementTwelve,
        "add": add,
        "add_reminder": addReminder,
        "app_settings": appSettings,
        "back": back,
        "background_refresh": backgroundRefresh,
        "break_fasting": breakFasting,
        "card_observed": cardObserved,
        "card_unrecorded": cardUnrecorded,
        "category_amavasya": categoryAmavasya,
        "category_chaturthi": categoryChaturthi,
        "category_ekadashi": categoryEkadashi,
        "category_festival": categoryFestival,
        "category_jayanti": categoryJayanti,
        "category_my_calendar": categoryMyCalendar,
        "category_navaratri": categoryNavaratri,
        "category_pradosham": categoryPradosham,
        "category_purnima": categoryPurnima,
        "category_sankranti": categorySankranti,
        "category_screen": categoryScreen,
        "category_shivaratri": categoryShivaratri,
        "checkmark": checkmark,
        "choghadiya": choghadiya,
        "close": close,
        "dark_mode": darkMode,
        "delete": delete,
        "dismiss_down": dismissDown,
        "edit": edit,
        "error": error,
        "five_limbs": fiveLimbs,
        "google_account": googleAccount,
        "google_disconnect": googleDisconnect,
        "google_menu": googleMenu,
        "google_sync": googleSync,
        "home_language": homeLanguage,
        "home_tradition": homeTradition,
        "home_year": homeYear,
        "hora": hora,
        "info": info,
        "journey_best": journeyBest,
        "journey_empty": journeyEmpty,
        "journey_milestone": journeyMilestone,
        "journey_observed": journeyObserved,
        "journey_pending": journeyPending,
        "journey_rate": journeyRate,
        "journey_storage_failed": journeyStorageFailed,
        "journey_streak": journeyStreak,
        "journey_year": journeyYear,
        "lagna": lagna,
        "location_detected": locationDetected,
        "location_picked": locationPicked,
        "lock": lock,
        "menu_disclosure": menuDisclosure,
        "moon_rashi": moonRashi,
        "moonrise": moonrise,
        "moonset": moonset,
        "more_details": moreDetails,
        "nakshatra": nakshatra,
        "next": next,
        "no_ekadashi": noEkadashi,
        "observance_major": observanceMajor,
        "observance_minor": observanceMinor,
        "observances": observances,
        "panchang_city": panchangCity,
        "panchang_date": panchangDate,
        "panchang_observance": panchangObservance,
        "panchang_tithi": panchangTithi,
        "panchang_unlock": panchangUnlock,
        "panchang_vara": panchangVara,
        "premium": premium,
        "premium_calendar": premiumCalendar,
        "premium_panchang": premiumPanchang,
        "premium_vrat": premiumVrat,
        "previous": previous,
        "rate_app": rateApp,
        "recent_search": recentSearch,
        "reminder_custom": reminderCustom,
        "reminder_google": reminderGoogle,
        "reminder_observance": reminderObservance,
        "row_disclosure": rowDisclosure,
        "save": save,
        "search": search,
        "search_all_categories": searchAllCategories,
        "search_clear": searchClear,
        "share": share,
        "share_card_brand": shareCardBrand,
        "share_card_fasting": shareCardFasting,
        "share_card_parana": shareCardParana,
        "share_card_significance": shareCardSignificance,
        "share_card_sun": shareCardSun,
        "start_fasting": startFasting,
        "status_missed": statusMissed,
        "status_observed": statusObserved,
        "status_partial": statusPartial,
        "status_unrecorded": statusUnrecorded,
        "sun_rashi": sunRashi,
        "sunrise": sunrise,
        "sunset": sunset,
        "tab_calendar": tabCalendar,
        "tab_home": tabHome,
        "tab_journey": tabJourney,
        "tab_panchang": tabPanchang,
        "tab_settings": tabSettings,
        "test_notification": testNotification,
        "timings": timings,
        "use_current_location": useCurrentLocation,
        "warning": warning,
        "widget_preview": widgetPreview,
        "year": year,
    ]
}
