import Foundation
import Observation
import SwiftData

/// A saved bookmark (user data → SwiftData per CLAUDE.md conventions).
@Model
public final class Bookmark {
    public var surahId: Int
    public var ayah: Int
    public var createdAt: Date

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
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: Bookmark.self, configurations: configuration)
        refresh()
    }

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
