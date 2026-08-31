import ContentDB
import Foundation
import Observation

@Observable
public final class SurahReaderViewModel {
    public private(set) var surah: Surah?
    public private(set) var verses: [Verse] = []
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
        } catch {
            loadError = error
        }
    }
}
