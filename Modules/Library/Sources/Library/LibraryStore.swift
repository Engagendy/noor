import Foundation
import Observation
import SwiftData

/// A saved bookmark (user data → SwiftData per CLAUDE.md conventions).
@Model
public final class Bookmark {
    // CloudKit-backed SwiftData requires default values on every attribute.
    public var surahId: Int = 1
    public var ayah: Int = 1
    public var createdAt: Date = Date.now

    public init(surahId: Int, ayah: Int, createdAt: Date = .now) {
        self.surahId = surahId
        self.ayah = ayah
        self.createdAt = createdAt
    }
}

/// Plain value handed to feature modules (features never import each other;
/// the app layer maps between them).
public struct BookmarkItem: Identifiable, Hashable, Sendable {
    public let surahId: Int
    public let ayah: Int
    public let createdAt: Date

    public var id: String { "\(surahId):\(ayah)" }

    public init(surahId: Int, ayah: Int, createdAt: Date) {
        self.surahId = surahId
        self.ayah = ayah
        self.createdAt = createdAt
    }
}

@Observable
@MainActor
public final class LibraryStore {
    public private(set) var bookmarks: [BookmarkItem] = []

    private let container: ModelContainer

    public init(inMemory: Bool = false) throws {
        if inMemory {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try ModelContainer(for: Bookmark.self, configurations: configuration)
        } else if let cloud = try? ModelContainer(
            for: Bookmark.self,
            configurations: ModelConfiguration(
                cloudKitDatabase: .private("iCloud.com.engagendy.Noor"))) {
            // Bookmarks sync via the user's private iCloud (nothing shared).
            container = cloud
        } else {
            // No iCloud account / entitlement (e.g. macOS dev build): local.
            let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
            container = try ModelContainer(for: Bookmark.self, configurations: configuration)
        }
        refresh()
    }

    /// CloudKit merges arrive in the background — re-read on demand.
    public func reload() { refresh() }

    public func isBookmarked(surahId: Int, ayah: Int) -> Bool {
        bookmarks.contains { $0.surahId == surahId && $0.ayah == ayah }
    }

    public func toggle(surahId: Int, ayah: Int) {
        let context = container.mainContext
        if let existing = try? context.fetch(Self.descriptor(surahId: surahId, ayah: ayah)).first {
            context.delete(existing)
        } else {
            context.insert(Bookmark(surahId: surahId, ayah: ayah))
        }
        try? context.save()
        refresh()
    }

    public func remove(_ item: BookmarkItem) {
        let context = container.mainContext
        for model in (try? context.fetch(Self.descriptor(surahId: item.surahId, ayah: item.ayah))) ?? [] {
            context.delete(model)
        }
        try? context.save()
        refresh()
    }

    private static func descriptor(surahId: Int, ayah: Int) -> FetchDescriptor<Bookmark> {
        FetchDescriptor(predicate: #Predicate { $0.surahId == surahId && $0.ayah == ayah })
    }

    private func refresh() {
        let all = (try? container.mainContext.fetch(
            FetchDescriptor<Bookmark>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
        bookmarks = all.map { BookmarkItem(surahId: $0.surahId, ayah: $0.ayah, createdAt: $0.createdAt) }
    }
}
