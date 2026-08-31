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

/// Manual city presets — offline-first; the one-shot GPS option never
/// leaves the device either way.
public struct CityPreset: Identifiable, Hashable {
    public let name: String
    public let nameArabic: String
    public let latitude: Double
    public let longitude: Double
    public let timeZoneIdentifier: String

    public var id: String { name }

    public func displayName(arabicUI: Bool) -> String {
        arabicUI ? nameArabic : name
    }

    init(_ name: String, _ nameArabic: String, _ latitude: Double, _ longitude: Double, _ tz: String) {
        self.name = name
        self.nameArabic = nameArabic
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = tz
    }

    public static let all: [CityPreset] = [
        // Arabia & Gulf
        CityPreset("Makkah", "مكة المكرمة", 21.4225, 39.8262, "Asia/Riyadh"),
        CityPreset("Madinah", "المدينة المنورة", 24.4672, 39.6111, "Asia/Riyadh"),
        CityPreset("Riyadh", "الرياض", 24.7136, 46.6753, "Asia/Riyadh"),
        CityPreset("Jeddah", "جدة", 21.4858, 39.1925, "Asia/Riyadh"),
        CityPreset("Dammam", "الدمام", 26.4207, 50.0888, "Asia/Riyadh"),
        CityPreset("Dubai", "دبي", 25.2048, 55.2708, "Asia/Dubai"),
        CityPreset("Abu Dhabi", "أبوظبي", 24.4539, 54.3773, "Asia/Dubai"),
        CityPreset("Sharjah", "الشارقة", 25.3463, 55.4209, "Asia/Dubai"),
        CityPreset("Doha", "الدوحة", 25.2854, 51.5310, "Asia/Qatar"),
        CityPreset("Kuwait City", "مدينة الكويت", 29.3759, 47.9774, "Asia/Kuwait"),
        CityPreset("Manama", "المنامة", 26.2285, 50.5860, "Asia/Bahrain"),
        CityPreset("Muscat", "مسقط", 23.5880, 58.3829, "Asia/Muscat"),
        CityPreset("Sana'a", "صنعاء", 15.3694, 44.1910, "Asia/Aden"),
        // Levant & Iraq
        CityPreset("Amman", "عمّان", 31.9454, 35.9284, "Asia/Amman"),
        CityPreset("Jerusalem", "القدس", 31.7683, 35.2137, "Asia/Jerusalem"),
        CityPreset("Beirut", "بيروت", 33.8938, 35.5018, "Asia/Beirut"),
        CityPreset("Damascus", "دمشق", 33.5138, 36.2765, "Asia/Damascus"),
        CityPreset("Baghdad", "بغداد", 33.3152, 44.3661, "Asia/Baghdad"),
        // Africa
        CityPreset("Cairo", "القاهرة", 30.0444, 31.2357, "Africa/Cairo"),
        CityPreset("Alexandria", "الإسكندرية", 31.2001, 29.9187, "Africa/Cairo"),
        CityPreset("Khartoum", "الخرطوم", 15.5007, 32.5599, "Africa/Khartoum"),
        CityPreset("Tripoli", "طرابلس", 32.8872, 13.1913, "Africa/Tripoli"),
        CityPreset("Tunis", "تونس", 36.8065, 10.1815, "Africa/Tunis"),
        CityPreset("Algiers", "الجزائر", 36.7538, 3.0588, "Africa/Algiers"),
        CityPreset("Casablanca", "الدار البيضاء", 33.5731, -7.5898, "Africa/Casablanca"),
        CityPreset("Rabat", "الرباط", 34.0209, -6.8416, "Africa/Casablanca"),
        CityPreset("Lagos", "لاغوس", 6.5244, 3.3792, "Africa/Lagos"),
        CityPreset("Nairobi", "نيروبي", -1.2921, 36.8219, "Africa/Nairobi"),
        CityPreset("Mogadishu", "مقديشو", 2.0469, 45.3182, "Africa/Mogadishu"),
        CityPreset("Johannesburg", "جوهانسبرغ", -26.2041, 28.0473, "Africa/Johannesburg"),
        // Türkiye, Iran & Central/South Asia
        CityPreset("Istanbul", "إسطنبول", 41.0082, 28.9784, "Europe/Istanbul"),
        CityPreset("Ankara", "أنقرة", 39.9334, 32.8597, "Europe/Istanbul"),
        CityPreset("Tehran", "طهران", 35.6892, 51.3890, "Asia/Tehran"),
        CityPreset("Baku", "باكو", 40.4093, 49.8671, "Asia/Baku"),
        CityPreset("Tashkent", "طشقند", 41.2995, 69.2401, "Asia/Tashkent"),
        CityPreset("Karachi", "كراتشي", 24.8607, 67.0011, "Asia/Karachi"),
        CityPreset("Lahore", "لاهور", 31.5204, 74.3587, "Asia/Karachi"),
        CityPreset("Islamabad", "إسلام آباد", 33.6844, 73.0479, "Asia/Karachi"),
        CityPreset("Dhaka", "دكا", 23.8103, 90.4125, "Asia/Dhaka"),
        CityPreset("Delhi", "دلهي", 28.7041, 77.1025, "Asia/Kolkata"),
        CityPreset("Mumbai", "مومباي", 19.0760, 72.8777, "Asia/Kolkata"),
        // Southeast Asia
        CityPreset("Jakarta", "جاكرتا", -6.2088, 106.8456, "Asia/Jakarta"),
        CityPreset("Kuala Lumpur", "كوالالمبور", 3.1390, 101.6869, "Asia/Kuala_Lumpur"),
        CityPreset("Singapore", "سنغافورة", 1.3521, 103.8198, "Asia/Singapore"),
        // Europe
        CityPreset("London", "لندن", 51.5074, -0.1278, "Europe/London"),
        CityPreset("Paris", "باريس", 48.8566, 2.3522, "Europe/Paris"),
        CityPreset("Berlin", "برلين", 52.5200, 13.4050, "Europe/Berlin"),
        CityPreset("Amsterdam", "أمستردام", 52.3676, 4.9041, "Europe/Amsterdam"),
        CityPreset("Brussels", "بروكسل", 50.8503, 4.3517, "Europe/Brussels"),
        CityPreset("Stockholm", "ستوكهولم", 59.3293, 18.0686, "Europe/Stockholm"),
        CityPreset("Moscow", "موسكو", 55.7558, 37.6173, "Europe/Moscow"),
        // Americas
        CityPreset("New York", "نيويورك", 40.7128, -74.0060, "America/New_York"),
        CityPreset("Toronto", "تورونتو", 43.6532, -79.3832, "America/Toronto"),
        CityPreset("Chicago", "شيكاغو", 41.8781, -87.6298, "America/Chicago"),
        CityPreset("Houston", "هيوستن", 29.7604, -95.3698, "America/Chicago"),
        CityPreset("Los Angeles", "لوس أنجلوس", 34.0522, -118.2437, "America/Los_Angeles"),
        // Oceania
        CityPreset("Sydney", "سيدني", -33.8688, 151.2093, "Australia/Sydney"),
        CityPreset("Melbourne", "ملبورن", -37.8136, 144.9631, "Australia/Melbourne"),
    ]

    public static func named(_ name: String) -> CityPreset {
        all.first { $0.name == name } ?? all[0]
    }
}
