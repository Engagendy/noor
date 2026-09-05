import Foundation

/// Hisn al-Muslim adhkar, bundled offline (see LICENSES.md).
public struct DhikrCategory: Codable, Identifiable, Hashable, Sendable {
    /// Arabic chapter title — the data key (deep links match on it).
    public let category: String
    /// English chapter title for the English interface; nil on rows without one.
    public let categoryEn: String?
    public let items: [Dhikr]
    /// Recording of the whole chapter (Hamad Al-Duraihim), file name only —
    /// resolved by `AthkarAudioStore`. Nil when no recording exists.
    public let chapterAudio: String?
    public var id: String { category }

    enum CodingKeys: String, CodingKey {
        case category, items
        case categoryEn = "category_en"
        case chapterAudio = "chapter_audio"
    }

    public func displayTitle(arabicUI: Bool) -> String {
        arabicUI ? category : (categoryEn ?? category)
    }
}

public struct Dhikr: Codable, Hashable, Sendable, Identifiable {
    public let text: String
    /// How many times this dhikr is repeated (e.g. 3, 33, 100).
    public let count: Int
    /// Recording of this dhikr alone, file name only (see `chapterAudio`).
    public let audio: String?

    public var id: String { text }
}

public enum AthkarStore {
    public static func load() -> [DhikrCategory] {
        guard let url = Bundle.module.url(forResource: "athkar", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let categories = try? JSONDecoder().decode([DhikrCategory].self, from: data)
        else { return [] }
        return categories
    }
}
