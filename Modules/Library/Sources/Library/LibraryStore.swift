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
    /// One instance app-wide — repeated construction spawned repeated
    /// CloudKit container builds.
    public static let sharedInstance = try? LibraryStore()

    public private(set) var bookmarks: [BookmarkItem] = []

    /// Built asynchronously: the CloudKit container can block for seconds
    /// on a signed-in device — doing that in init froze app launch.
    private var container: ModelContainer?

    /// Taps that arrived before the container finished building. They are
    /// applied optimistically to `bookmarks` and replayed once it is ready,
    /// so an early bookmark is never silently dropped.
    private var pendingChanges: [(surahId: Int, ayah: Int, bookmarked: Bool)] = []

    /// `false` while the container is still building — persistence is queued.
    public var isReady: Bool { container != nil }

    public init(inMemory: Bool = false) throws {
        if inMemory {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try ModelContainer(for: Bookmark.self, configurations: configuration)
            refresh()
            return
        }
        Task.detached(priority: .userInitiated) {
            let built: ModelContainer?
            if let cloud = try? ModelContainer(
                for: Bookmark.self,
                configurations: ModelConfiguration(
                    cloudKitDatabase: .private("iCloud.com.engagendy.Noor"))) {
                // Bookmarks sync via the user's private iCloud.
                built = cloud
            } else {
                built = try? ModelContainer(
                    for: Bookmark.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: false))
            }
            await MainActor.run { [weak self] in
                self?.container = built
                self?.flushPendingChanges()
                self?.refresh()
            }
        }
    }

    /// CloudKit merges arrive in the background — re-read on demand.
    public func reload() { refresh() }

    public func isBookmarked(surahId: Int, ayah: Int) -> Bool {
        bookmarks.contains { $0.surahId == surahId && $0.ayah == ayah }
    }

    public func toggle(surahId: Int, ayah: Int) {
        guard let container else {
            enqueue(surahId: surahId, ayah: ayah,
                    bookmarked: !isBookmarked(surahId: surahId, ayah: ayah))
            return
        }
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
        guard let container else {
            enqueue(surahId: item.surahId, ayah: item.ayah, bookmarked: false)
            return
        }
        let context = container.mainContext
        for model in (try? context.fetch(Self.descriptor(surahId: item.surahId, ayah: item.ayah))) ?? [] {
            context.delete(model)
        }
        try? context.save()
        refresh()
    }

    /// Optimistically update the published list and remember the change.
    private func enqueue(surahId: Int, ayah: Int, bookmarked: Bool) {
        pendingChanges.removeAll { $0.surahId == surahId && $0.ayah == ayah }
        pendingChanges.append((surahId: surahId, ayah: ayah, bookmarked: bookmarked))
        bookmarks.removeAll { $0.surahId == surahId && $0.ayah == ayah }
        if bookmarked {
            bookmarks.insert(
                BookmarkItem(surahId: surahId, ayah: ayah, createdAt: .now), at: 0)
        }
    }

    private func flushPendingChanges() {
        guard let container, !pendingChanges.isEmpty else { return }
        let context = container.mainContext
        for change in pendingChanges {
            let existing = (try? context.fetch(
                Self.descriptor(surahId: change.surahId, ayah: change.ayah))) ?? []
            if change.bookmarked {
                if existing.isEmpty {
                    context.insert(Bookmark(surahId: change.surahId, ayah: change.ayah))
                }
            } else {
                for model in existing { context.delete(model) }
            }
        }
        pendingChanges.removeAll()
        try? context.save()
    }

    private static func descriptor(surahId: Int, ayah: Int) -> FetchDescriptor<Bookmark> {
        FetchDescriptor(predicate: #Predicate { $0.surahId == surahId && $0.ayah == ayah })
    }

    private func refresh() {
        guard let container else { return }
        let all = (try? container.mainContext.fetch(
            FetchDescriptor<Bookmark>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
        bookmarks = all.map { BookmarkItem(surahId: $0.surahId, ayah: $0.ayah, createdAt: $0.createdAt) }
    }
}
