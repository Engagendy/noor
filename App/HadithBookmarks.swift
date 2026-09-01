import Foundation
import Observation

/// Hadith bookmarks: tiny key set ("bukhari:123", "nawawi:7"), stored
/// locally and merged (union) through iCloud key-value storage.
@Observable
@MainActor
final class HadithBookmarks {
    static let shared = HadithBookmarks()
    private static let key = "hadith.bookmarks"

    private(set) var keys: Set<String>

    init() {
        keys = Set(UserDefaults.standard.stringArray(forKey: Self.key) ?? [])
        let remote = Set(NSUbiquitousKeyValueStore.default.array(forKey: Self.key) as? [String] ?? [])
        if !remote.isEmpty {
            keys.formUnion(remote)
            persist()
        }
    }

    static func key(collection: String, number: String) -> String {
        "\(collection):\(number)"
    }

    func isBookmarked(_ key: String) -> Bool { keys.contains(key) }

    func toggle(_ key: String) {
        if keys.contains(key) { keys.remove(key) } else { keys.insert(key) }
        persist()
    }

    private func persist() {
        let list = Array(keys).sorted()
        UserDefaults.standard.set(list, forKey: Self.key)
        NSUbiquitousKeyValueStore.default.set(list, forKey: Self.key)
    }
}
