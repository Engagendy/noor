import CoreLocation
import Foundation

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
                label: String(localized: "My location"),
                isCustom: true)
        }
        let city = CityPreset.named(defaults.string(forKey: "prayer.city") ?? "Makkah")
        return city.location
    }

    public static func saveCustom(latitude: Double, longitude: Double,
                                  defaults: UserDefaults = .standard) {
        defaults.set(latitude, forKey: "prayer.customLat")
        defaults.set(longitude, forKey: "prayer.customLon")
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
/// reused offline; no continuous tracking.
public final class OneShotLocationFetcher: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer  // coarse is plenty
    }

    public func fetch() async -> CLLocationCoordinate2D? {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.first?.coordinate)
        continuation = nil
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        #if os(macOS)
        let authorized = status == .authorized || status == .authorizedAlways
        #else
        let authorized = status == .authorizedWhenInUse || status == .authorizedAlways
        #endif
        if authorized {
            manager.requestLocation()
        } else if status == .denied || status == .restricted {
            continuation?.resume(returning: nil)
            continuation = nil
        }
    }
}
