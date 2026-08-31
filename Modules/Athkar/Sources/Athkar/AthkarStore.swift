import Foundation

/// Hisn al-Muslim adhkar, bundled offline (see LICENSES.md).
public struct DhikrCategory: Codable, Identifiable, Hashable, Sendable {
    public let category: String
    public let items: [Dhikr]
    public var id: String { category }
}

public struct Dhikr: Codable, Hashable, Sendable, Identifiable {
    public let text: String
    /// How many times this dhikr is repeated (e.g. 3, 33, 100).
    public let count: Int

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
