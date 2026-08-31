import Foundation

/// Mirrors the small reading-progress values through iCloud's key-value
/// store so a new device picks up where the others left off. Only derived
/// progress numbers sync — never location or anything personal.
enum CloudSync {
    private static let keys = [
        "khatmah.maxPage", "khatmah.goalDays", "khatmah.goalStart",
        "khatmah.goalStartPage", "reader.lastSurah", "reader.lastPage",
    ]

    @MainActor
    static func start() {
        let store = NSUbiquitousKeyValueStore.default
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store, queue: .main
        ) { _ in
            Task { @MainActor in pullRemote() }
        }
        store.synchronize()
        pullRemote()
        pushLocal()
    }

    /// Called whenever local progress changes (cheap; values are tiny).
    static func pushLocal() {
        let store = NSUbiquitousKeyValueStore.default
        let defaults = UserDefaults.standard
        for key in keys {
            store.set(defaults.double(forKey: key), forKey: key)
        }
        store.synchronize()
    }

    /// Merge remote → local. Progress counters take the furthest value;
    /// plan settings follow whichever device set them last (KV store's
    /// last-writer-wins is fine for these).
    @MainActor
    private static func pullRemote() {
        let store = NSUbiquitousKeyValueStore.default
        let defaults = UserDefaults.standard
        let remoteMax = Int(store.double(forKey: "khatmah.maxPage"))
        if remoteMax > defaults.integer(forKey: "khatmah.maxPage") {
            defaults.set(remoteMax, forKey: "khatmah.maxPage")
        }
        for key in ["khatmah.goalDays", "khatmah.goalStart", "khatmah.goalStartPage"] {
            let remote = store.double(forKey: key)
            if remote > 0 { defaults.set(remote, forKey: key) }
        }
        // goalDays is read as an integer elsewhere.
        let days = Int(store.double(forKey: "khatmah.goalDays"))
        if days > 0 { defaults.set(days, forKey: "khatmah.goalDays") }
    }
}
