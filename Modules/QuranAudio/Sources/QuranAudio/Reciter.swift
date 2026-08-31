import Foundation

/// Ayah-by-ayah recitations from EveryAyah.com (see LICENSES.md).
public enum Reciter: String, CaseIterable, Identifiable, Codable {
    case alafasy
    case husary
    case minshawi

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .alafasy: "Mishary Alafasy"
        case .husary: "Mahmoud Al-Husary"
        case .minshawi: "Mohamed Al-Minshawi"
        }
    }

    /// EveryAyah folder name (128 kbps sets).
    var folder: String {
        switch self {
        case .alafasy: "Alafasy_128kbps"
        case .husary: "Husary_128kbps"
        case .minshawi: "Minshawy_Murattal_128kbps"
        }
    }

    /// Remote URL for one ayah, e.g. .../Alafasy_128kbps/001001.mp3
    public func url(surah: Int, ayah: Int) -> URL {
        URL(string: "https://everyayah.com/data/\(folder)/\(Self.fileName(surah: surah, ayah: ayah))")!
    }

    public static func fileName(surah: Int, ayah: Int) -> String {
        String(format: "%03d%03d.mp3", surah, ayah)
    }
}
