import CoreLocation
import Foundation

/// Shared container between the app and its widgets.
public enum NoorShared {
    public static let appGroup = "group.com.engagendy.noor"

    /// Cached: constructing UserDefaults(suiteName:) repeatedly re-logs
    /// the harmless cfprefs warning and costs an XPC roundtrip.
    public static let defaults: UserDefaults =
        UserDefaults(suiteName: appGroup) ?? .standard

    /// Keys the app mirrors into the shared suite for widgets.
    public static let mirroredKeys = [
        "prayer.city", "prayer.useCustom", "prayer.customLat", "prayer.customLon",
        "prayer.customLabel", "prayer.method", "prayer.madhab", "app.language",
        // Manual per-prayer offsets: PrayerDay.compute reads them from the
        // defaults it is given, so the widgets need the mirrored copy too.
        "prayer.adj.fajr", "prayer.adj.dhuhr", "prayer.adj.asr",
        "prayer.adj.maghrib", "prayer.adj.isha",
    ]

    /// Copies widget-relevant settings from standard defaults to the group.
    public static func syncFromApp() {
        for key in mirroredKeys {
            defaults.set(UserDefaults.standard.object(forKey: key), forKey: key)
        }
    }
}

/// Where prayer times are computed for: a manual city preset or a one-shot
/// device location. Coordinates never leave the device (CLAUDE.md rule 3).
public struct PrayerLocation: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let timeZoneIdentifier: String
    public let label: String
    public let isCustom: Bool

    public init(latitude: Double, longitude: Double, timeZoneIdentifier: String,
                label: String, isCustom: Bool) {
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
        self.label = label
        self.isCustom = isCustom
    }

    /// Resolves the active location from settings: the saved device location
    /// when enabled, otherwise the selected city preset.
    public static func current(defaults: UserDefaults = .standard) -> PrayerLocation {
        if defaults.bool(forKey: "prayer.useCustom") {
            return PrayerLocation(
                latitude: defaults.double(forKey: "prayer.customLat"),
                longitude: defaults.double(forKey: "prayer.customLon"),
                timeZoneIdentifier: TimeZone.current.identifier,
                label: defaults.string(forKey: "prayer.customLabel") ?? String(localized: "My location"),
                isCustom: true)
        }
        let city = CityPreset.named(defaults.string(forKey: "prayer.city") ?? "Makkah")
        return city.location
    }

    public static func saveCustom(latitude: Double, longitude: Double,
                                  label: String,
                                  defaults: UserDefaults = .standard) {
        defaults.set(latitude, forKey: "prayer.customLat")
        defaults.set(longitude, forKey: "prayer.customLon")
        defaults.set(label, forKey: "prayer.customLabel")
        defaults.set(true, forKey: "prayer.useCustom")
    }

    public static func clearCustom(defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: "prayer.useCustom")
    }
}

extension CityPreset {
    public var location: PrayerLocation {
        PrayerLocation(latitude: latitude, longitude: longitude,
                       timeZoneIdentifier: timeZoneIdentifier, label: name, isCustom: false)
    }
}

/// One-shot when-in-use location fetch. The coordinate is stored locally and
/// reused offline; no continuous tracking, no geocoding — nothing leaves the
/// device.
public final class OneShotLocationFetcher: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer  // coarse is plenty
    }

    /// A stored fix this recent is good enough for city-level prayer times,
    /// so it is returned straight away rather than making the reader wait on
    /// a fresh fix that would name the same place.
    private static let freshEnough: TimeInterval = 30 * 60

    /// requestLocation can simply never call back — indoors, or with location
    /// services degraded — and without this the caller waits forever.
    private static let timeout: TimeInterval = 10

    public func fetch() async -> CLLocationCoordinate2D? {
        // Fast path: a recent fix answers instantly, no spinner at all.
        if let cached = manager.location,
           -cached.timestamp.timeIntervalSinceNow < Self.freshEnough {
            return cached.coordinate
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .notDetermined:
                // Wait for the grant; didChangeAuthorization requests the fix.
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                resume(nil)
            default:
                manager.requestLocation()
            }
            // Whatever happens, stop waiting eventually and fall back to the
            // stored fix, however old, before giving up entirely.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeout) { [weak self] in
                guard let self, self.continuation != nil else { return }
                self.resume(self.manager.location?.coordinate)
            }
        }
    }

    private func resume(_ coordinate: CLLocationCoordinate2D?) {
        continuation?.resume(returning: coordinate)
        continuation = nil
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        resume(locations.first?.coordinate)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // A failure does not mean we know nothing: an earlier fix still names
        // the right city for prayer times.
        resume(manager.location?.coordinate)
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        let status = manager.authorizationStatus
        #if os(macOS)
        let authorized = status == .authorized || status == .authorizedAlways
        #else
        let authorized = status == .authorizedWhenInUse || status == .authorizedAlways
        #endif
        if authorized {
            manager.requestLocation()
        } else if status == .denied || status == .restricted {
            resume(nil)
        }
    }
}
