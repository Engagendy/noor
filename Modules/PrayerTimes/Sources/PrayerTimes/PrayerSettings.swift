import Adhan
import Foundation

/// Calculation methods exposed in Settings (plan §5 Phase 1).
public enum CalculationMethodChoice: String, CaseIterable, Identifiable {
    case moonsightingCommittee
    case muslimWorldLeague
    case egyptian
    case ummAlQura
    case karachi
    case dubai
    case northAmerica

    public var id: String { rawValue }

    public var adhanMethod: CalculationMethod {
        switch self {
        case .moonsightingCommittee: .moonsightingCommittee
        case .muslimWorldLeague: .muslimWorldLeague
        case .egyptian: .egyptian
        case .ummAlQura: .ummAlQura
        case .karachi: .karachi
        case .dubai: .dubai
        case .northAmerica: .northAmerica
        }
    }

    public var displayName: LocalizedStringResource {
        switch self {
        case .moonsightingCommittee: "Moonsighting Committee"
        case .muslimWorldLeague: "Muslim World League"
        case .egyptian: "Egyptian General Authority"
        case .ummAlQura: "Umm al-Qura (Makkah)"
        case .karachi: "University of Karachi"
        case .dubai: "Dubai"
        case .northAmerica: "ISNA (North America)"
        }
    }
}

public enum MadhabChoice: String, CaseIterable, Identifiable {
    case shafi, hanafi

    public var id: String { rawValue }
    public var adhanMadhab: Madhab { self == .shafi ? .shafi : .hanafi }
    public var displayName: LocalizedStringResource {
        self == .shafi ? "Shafi'i, Maliki, Hanbali" : "Hanafi"
    }
}

/// Manual city presets — offline-first; GPS location comes later and never
/// leaves the device either way.
public struct CityPreset: Identifiable, Hashable {
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let timeZoneIdentifier: String

    public var id: String { name }

    public static let all: [CityPreset] = [
        CityPreset(name: "Makkah", latitude: 21.4225, longitude: 39.8262, timeZoneIdentifier: "Asia/Riyadh"),
        CityPreset(name: "Madinah", latitude: 24.4672, longitude: 39.6111, timeZoneIdentifier: "Asia/Riyadh"),
        CityPreset(name: "Cairo", latitude: 30.0444, longitude: 31.2357, timeZoneIdentifier: "Africa/Cairo"),
        CityPreset(name: "Riyadh", latitude: 24.7136, longitude: 46.6753, timeZoneIdentifier: "Asia/Riyadh"),
        CityPreset(name: "Dubai", latitude: 25.2048, longitude: 55.2708, timeZoneIdentifier: "Asia/Dubai"),
        CityPreset(name: "Istanbul", latitude: 41.0082, longitude: 28.9784, timeZoneIdentifier: "Europe/Istanbul"),
        CityPreset(name: "London", latitude: 51.5074, longitude: -0.1278, timeZoneIdentifier: "Europe/London"),
        CityPreset(name: "New York", latitude: 40.7128, longitude: -74.0060, timeZoneIdentifier: "America/New_York"),
        CityPreset(name: "Karachi", latitude: 24.8607, longitude: 67.0011, timeZoneIdentifier: "Asia/Karachi"),
        CityPreset(name: "Jakarta", latitude: -6.2088, longitude: 106.8456, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(name: "Kuala Lumpur", latitude: 3.1390, longitude: 101.6869, timeZoneIdentifier: "Asia/Kuala_Lumpur"),
    ]

    public static func named(_ name: String) -> CityPreset {
        all.first { $0.name == name } ?? all[0]
    }
}
