import ContentDB
import DesignSystem
import Foundation
import Observation

@Observable
public final class SurahReaderViewModel {
    public struct PageGroup: Identifiable {
        public let page: Int
        public let verses: [Verse]
        public var id: Int { page }
    }

    /// One rendered stretch of a mushaf page: an optional surah header
    /// (ornament + basmala) followed by that surah's verses on the page.
    public struct PageSection: Identifiable {
        public let id: Int
        public let headerSurah: Surah?
        public let basmala: String?
        public let verses: [Verse]
    }

    public private(set) var surah: Surah?
    public private(set) var verses: [Verse] = []
    /// The opened surah's pages (ayah-mode scope + initial position).
    public private(set) var pages: [PageGroup] = []
    /// Global hizb-quarter starts keyed by surah*1000+ayah.
    public private(set) var quarterStarts: [Int: Int] = [:]
    /// Sajdah ayat keyed by surah*1000+ayah.
    public private(set) var sajdaKeys: Set<Int> = []
    public private(set) var juz = 1
    public private(set) var basmala: String?
    public private(set) var loadError: Error?
    public private(set) var allSurahs: [Surah] = []

    private var structure: QuranStructure?
    private let database: QuranDatabase
    private let surahId: Int
    private var pageCache: [Int: [PageSection]] = [:]
    private var flowCache: [Int: [FlowItem]] = [:]

    public init(database: QuranDatabase, surahId: Int) {
        self.database = database
        self.surahId = surahId
    }

    public func load() {
        do {
            allSurahs = try database.allSurahs()
            surah = allSurahs.first { $0.id == surahId }
            verses = try database.verses(surahId: surahId)
            if surahId != 1 && surahId != 9 {
                basmala = try database.verses(surahId: 1).first?.text
            }
            let structure = try database.structure()
            self.structure = structure
            juz = structure.juz(surahId: surahId, ayah: 1)
            quarterStarts = Dictionary(uniqueKeysWithValues:
                structure.quarterStarts.map { ($0.surahId * 1000 + $0.ayah, $0.idx) })
            sajdaKeys = Set(structure.sajdaAyat.map { $0.surahId * 1000 + $0.ayah })
            pages = Dictionary(grouping: verses) { structure.page(surahId: surahId, ayah: $0.ayah) }
                .map { PageGroup(page: $0.key, verses: $0.value.sorted { $0.ayah < $1.ayah }) }
                .sorted { $0.page < $1.page }
        } catch {
            loadError = error
        }
    }

    public func page(containing ayah: Int) -> Int? {
        structure.map { $0.page(surahId: surahId, ayah: ayah) }
    }

    public func page(surahId: Int, ayah: Int) -> Int? {
        structure.map { $0.page(surahId: surahId, ayah: ayah) }
    }

    public func juz(forPage page: Int) -> Int {
        guard let structure,
              let start = structure.pageStarts.first(where: { $0.idx == page })
        else { return juz }
        return structure.juz(surahId: start.surahId, ayah: start.ayah)
    }

    /// The surah shown at the top of a page (for the title while swiping).
    public func surah(forPage page: Int) -> Surah? {
        guard let structure,
              let start = structure.pageStarts.first(where: { $0.idx == page })
        else { return surah }
        return allSurahs.first { $0.id == start.surahId }
    }

    public func surahInfo(_ id: Int) -> Surah? {
        allSurahs.first { $0.id == id }
    }

    /// Full page content across surah boundaries — the mushaf flows on.
    public func sections(forPage page: Int) -> [PageSection] {
        if let cached = pageCache[page] { return cached }
        guard let structure else { return [] }
        let pageVerses = (try? database.verses(page: page, structure: structure)) ?? []
        var sections: [PageSection] = []
        for (surahId, group) in Dictionary(grouping: pageVerses, by: \.surahId).sorted(by: { $0.key < $1.key }) {
            let sorted = group.sorted { $0.ayah < $1.ayah }
            let startsHere = sorted.first?.ayah == 1
            sections.append(PageSection(
                id: surahId,
                headerSurah: startsHere ? surahInfo(surahId) : nil,
                basmala: startsHere && surahId != 1 && surahId != 9 ? basmalaText : nil,
                verses: sorted))
        }
        pageCache[page] = sections
        return sections
    }

    private var basmalaText: String? {
        (try? database.verses(surahId: 1))?.first?.text
    }

    // MARK: Tappable mushaf flow

    /// One tappable fragment of the continuous mushaf flow. Words come from
    /// splitting the checksummed Tanzil text on spaces — layout only, the
    /// text itself is never altered.
    public struct FlowItem: Identifiable, Hashable {
        public enum Kind { case word, marker, quarter, sajda }
        public let id: Int
        public let surahId: Int
        public let ayah: Int
        public let text: String
        public let kind: Kind
    }

    public func flowItems(section: PageSection, page: Int) -> [FlowItem] {
        let cacheKey = page * 1000 + section.id
        if let cached = flowCache[cacheKey] { return cached }
        var items: [FlowItem] = []
        var index = 0
        func add(_ surahId: Int, _ ayah: Int, _ text: String, _ kind: FlowItem.Kind) {
            items.append(FlowItem(id: index, surahId: surahId, ayah: ayah, text: text, kind: kind))
            index += 1
        }
        for verse in section.verses {
            let key = verse.surahId * 1000 + verse.ayah
            if quarterStarts[key] != nil {
                add(verse.surahId, verse.ayah, "۞", .quarter)
            }
            for word in verse.text.split(separator: " ") {
                add(verse.surahId, verse.ayah, String(word), .word)
            }
            if sajdaKeys.contains(key) {
                add(verse.surahId, verse.ayah, "۩", .sajda)
            }
            add(verse.surahId, verse.ayah,
                "\u{2067}﴿\(verse.ayah.arabicIndic)﴾\u{2069}", .marker)
        }
        flowCache[cacheKey] = items
        return items
    }
}
