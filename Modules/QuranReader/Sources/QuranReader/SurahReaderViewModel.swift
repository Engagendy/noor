import ContentDB
import Foundation
import Observation

@Observable
public final class SurahReaderViewModel {
    public private(set) var surah: Surah?
    public private(set) var verses: [Verse] = []
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
        } catch {
            loadError = error
        }
    }
}
