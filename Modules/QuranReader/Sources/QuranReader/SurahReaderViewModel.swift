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

    public private(set) var surah: Surah?
    public private(set) var verses: [Verse] = []
    public private(set) var pages: [PageGroup] = []
    /// Global hizb-quarter index for ayat that begin one (keyed by ayah number).
    public private(set) var quarterStarts: [Int: Int] = [:]
    /// Ayat in this surah carrying the sajdah mark ۩.
    public private(set) var sajdaAyat: Set<Int> = []
    public private(set) var juz = 1
    /// Basmala text loaded verbatim from the DB (verse 1:1) — shown as the
    /// traditional opening for every surah except Al-Fatiha (it IS its first
    /// ayah there) and At-Tawbah (traditionally opens without it).
    public private(set) var basmala: String?
    public private(set) var loadError: Error?

    private let database: QuranDatabase
    private let surahId: Int

    public init(database: QuranDatabase, surahId: Int) {
        self.database = database
        self.surahId = surahId
    }

    public func load() {
        do {
            surah = try database.allSurahs().first { $0.id == surahId }
            verses = try database.verses(surahId: surahId)
            if surahId != 1 && surahId != 9 {
                basmala = try database.verses(surahId: 1).first?.text
            }
            let structure = try database.structure()
            juz = structure.juz(surahId: surahId, ayah: 1)
            quarterStarts = Dictionary(uniqueKeysWithValues: structure.quarterStarts
                .filter { $0.surahId == surahId }
                .map { ($0.ayah, $0.idx) })
            sajdaAyat = Set(structure.sajdaAyat.filter { $0.surahId == surahId }.map(\.ayah))
            pages = Dictionary(grouping: verses) { structure.page(surahId: surahId, ayah: $0.ayah) }
                .map { PageGroup(page: $0.key, verses: $0.value.sorted { $0.ayah < $1.ayah }) }
                .sorted { $0.page < $1.page }
        } catch {
            loadError = error
        }
    }

    public func page(containing ayah: Int) -> Int? {
        pages.first { $0.verses.contains { $0.ayah == ayah } }?.page
    }

    // MARK: Tappable mushaf flow

    /// One tappable fragment of the continuous mushaf flow. Words come from
    /// splitting the checksummed Tanzil text on spaces — layout only, the
    /// text itself is never altered.
    public struct FlowItem: Identifiable, Hashable {
        public enum Kind { case word, marker, quarter, sajda }
        public let id: Int
        public let ayah: Int
        public let text: String
        public let kind: Kind
    }

    private var flowCache: [Int: [FlowItem]] = [:]

    public func flowItems(for page: PageGroup) -> [FlowItem] {
        if let cached = flowCache[page.page] { return cached }
        var items: [FlowItem] = []
        var index = 0
        func add(_ ayah: Int, _ text: String, _ kind: FlowItem.Kind) {
            items.append(FlowItem(id: index, ayah: ayah, text: text, kind: kind))
            index += 1
        }
        for verse in page.verses {
            if quarterStarts[verse.ayah] != nil {
                add(verse.ayah, "۞", .quarter)
            }
            for word in verse.text.split(separator: " ") {
                add(verse.ayah, String(word), .word)
            }
            if sajdaAyat.contains(verse.ayah) {
                add(verse.ayah, "۩", .sajda)
            }
            add(verse.ayah, "﴿\(verse.ayah.arabicIndic)﴾", .marker)
        }
        flowCache[page.page] = items
        return items
    }
}
