import Foundation

/// The one reading marker: a ribbon the reader drags onto the printed line
/// they stopped at, so an interrupted session resumes at that exact line.
/// Unlike bookmarks (a kept list of ayat) there is only ever one, and it
/// moves. Stored as "page:line:surah:ayah:word" under `defaultsKey`: the
/// first word of the marked line — `ayah` is the one in progress there and
/// `word` its 1-based word number (the Madani layout's positions), so the
/// marker lands on the same line in every reading mode.
public struct ReadingMarker: Equatable, Sendable {
    public static let defaultsKey = "reader.marker"

    public let page: Int
    /// Printed line number on `page` (PageLine.line).
    public let line: Int
    public let surahId: Int
    public let ayah: Int
    public let word: Int

    public init(page: Int, line: Int, surahId: Int, ayah: Int, word: Int = 1) {
        self.page = page
        self.line = line
        self.surahId = surahId
        self.ayah = ayah
        self.word = max(word, 1)
    }

    /// surah * 1000 + ayah, the reader's usual ayah key.
    public var key: Int { surahId * 1000 + ayah }

    public var raw: String { "\(page):\(line):\(surahId):\(ayah):\(word)" }

    public init?(raw: String) {
        let parts = raw.split(separator: ":").compactMap { Int($0) }
        // Four parts: a marker saved before word positions existed.
        guard parts.count == 4 || parts.count == 5, parts.allSatisfy({ $0 > 0 }) else { return nil }
        self.init(page: parts[0], line: parts[1], surahId: parts[2], ayah: parts[3],
                  word: parts.count == 5 ? parts[4] : 1)
    }

    public static func load(defaults: UserDefaults = .standard) -> ReadingMarker? {
        ReadingMarker(raw: defaults.string(forKey: defaultsKey) ?? "")
    }
}
