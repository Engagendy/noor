import Foundation
import Observation

/// Favourite athkar: a tiny key set stored locally and merged (union)
/// through iCloud key-value storage — the same shape as the app's hadith
/// bookmarks (`HadithBookmarks`), so favourites follow the user across
/// devices the same way. Same key name on Android.
///
/// A dhikr carries no id in `athkar.json`, but every one of its 267 rows
/// has a distinct recording, so the audio file name is the stable key.
/// Neither the text (four rows repeat one) nor the position (breaks the
/// moment the data is reordered) would survive an update.
@Observable
@MainActor
public final class AthkarFavorites {
    public static let shared = AthkarFavorites()
    public static let storageKey = "athkar.favorites"

    public private(set) var keys: Set<String>
    private let defaults: UserDefaults
    private let cloud: NSUbiquitousKeyValueStore?

    /// `defaults`/`cloud` are injection seams for tests; the app uses the
    /// shared instance with the standard stores.
    public init(defaults: UserDefaults = .standard,
                cloud: NSUbiquitousKeyValueStore? = .default) {
        self.defaults = defaults
        self.cloud = cloud
        keys = Set(defaults.stringArray(forKey: Self.storageKey) ?? [])
        let remote = Set(cloud?.array(forKey: Self.storageKey) as? [String] ?? [])
        if !remote.isEmpty {
            keys.formUnion(remote)
            persist()
        }
    }

    /// The favourite key of a dhikr — its recording's file name. Nil for a
    /// row without one (none in the bundled data today), which then simply
    /// cannot be favourited.
    public static func key(for dhikr: Dhikr) -> String? {
        guard let audio = dhikr.audio, !audio.isEmpty else { return nil }
        return audio
    }

    public func isFavorite(_ key: String) -> Bool { keys.contains(key) }

    public func isFavorite(_ dhikr: Dhikr) -> Bool {
        Self.key(for: dhikr).map(isFavorite) ?? false
    }

    public func toggle(_ key: String) {
        if keys.contains(key) { keys.remove(key) } else { keys.insert(key) }
        persist()
    }

    public func toggle(_ dhikr: Dhikr) {
        guard let key = Self.key(for: dhikr) else { return }
        toggle(key)
    }

    private func persist() {
        let list = Array(keys).sorted()
        defaults.set(list, forKey: Self.storageKey)
        cloud?.set(list, forKey: Self.storageKey)
    }
}
