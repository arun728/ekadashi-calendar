import Foundation

/// When a detected place becomes Home's Ekadashi city (EkadashiSettings
/// .useDetected on Android).
public enum DetectedCityPolicy {
    /// At a launch the place found now wins over a city picked on Home, as in
    /// v1; back in the app later, a picked city stays.
    public static func replaces(manual: Bool, atLaunch: Bool) -> Bool { !manual || atLaunch }

    /// Whether the Panchang tab moves to [detected] too: when it has no place
    /// yet, or at a launch when it showed Home's previous city. A city set on
    /// the Panchang tab itself stays.
    public static func panchangFollows(panchang: PanchangCity?, previousHome: PanchangCity, detected: PanchangCity,
                                       atLaunch: Bool) -> Bool {
        guard let panchang else { return true }
        return atLaunch && panchang == previousHome && !detected.isSamePlace(as: previousHome)
    }
}

/// The Calendar tab's motion, the same on Android (CalendarScreenState
/// .monthSlide).
public enum CalendarMotion {
    /// Arrows, swipes and paging slide a month in a quarter of a second.
    public static let monthSlideSeconds = 0.25
}
