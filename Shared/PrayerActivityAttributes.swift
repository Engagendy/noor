#if os(iOS)
import ActivityKit
import Foundation

/// Shared between the app (starts/ends the activity) and the widget
/// extension (renders it).
public struct NoorPrayerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Localized prayer name (already in the app's language).
        public var prayerName: String
        /// The adhan moment the countdown targets.
        public var time: Date

        public init(prayerName: String, time: Date) {
            self.prayerName = prayerName
            self.time = time
        }
    }

    /// City label shown alongside.
    public var city: String
    /// Render in Arabic (app language), regardless of device language.
    public var isArabic: Bool

    public init(city: String, isArabic: Bool = false) {
        self.city = city
        self.isArabic = isArabic
    }
}
#endif
