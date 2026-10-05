import Foundation

/// The one reading marker: a ribbon the reader drags onto the printed line
/// they stopped at, so an interrupted session resumes at that exact line.
/// Unlike bookmarks (a kept list of ayat) there is only ever one, and it
/// moves. Stored as "page:line:surah:ayah" under `defaultsKey`; `ayah` is
/// the first ayah on the marked line — the one in progress there.
public struct ReadingMarker: Equatable, Sendable {
    public static let defaultsKey = "reader.marker"

    public let page: Int
    /// Printed line number on `page` (PageLine.line).
    public let line: Int
    public let surahId: Int
    public let ayah: Int

    public init(page: Int, line: Int, surahId: Int, ayah: Int) {
        self.page = page
        self.line = line
        self.surahId = surahId
        self.ayah = ayah
    }

    /// surah * 1000 + ayah, the reader's usual ayah key.
    public var key: Int { surahId * 1000 + ayah }

    public var raw: String { "\(page):\(line):\(surahId):\(ayah)" }

    public init?(raw: String) {
        let parts = raw.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ $0 > 0 }) else { return nil }
        self.init(page: parts[0], line: parts[1], surahId: parts[2], ayah: parts[3])
    }

    public static func load(defaults: UserDefaults = .standard) -> ReadingMarker? {
        ReadingMarker(raw: defaults.string(forKey: defaultsKey) ?? "")
    }
}
