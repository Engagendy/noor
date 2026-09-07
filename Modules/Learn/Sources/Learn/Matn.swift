import Foundation

/// A classical didactic poem (متن) the user memorises, as bundled by
/// `Tools/build_matn_tuhfa.py`.
///
/// The schema is deliberately wider than today's needs: it carries N matns
/// (al-Jazariyyah drops straight in once a *vowelled* source is verified —
/// the Wikisource copy is unvowelled, which is useless for tajweed), and it
/// reserves `audio`/`timings` so follow-along recitation can be added without
/// restructuring anything. No audio ships until a recording's licence is
/// recorded in LICENSES.md (CLAUDE.md rule 5).
public struct Matn: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let titleAr: String
    public let titleEn: String
    /// Short citation forms, for the navigation bar — the full title is the
    /// heading inside the reader. Optional so a matn may omit them.
    public let shortTitleAr: String?
    public let shortTitleEn: String?
    public let authorAr: String
    public let authorEn: String
    /// Arabic composition note, e.g. "فرغ من نظمها سنة ١١٩٨ هـ".
    public let composedAr: String?
    public let composedYearHijri: Int?
    public let sourceName: String
    public let sourceUrl: String
    public let sourceLicense: String
    public let retrieved: String
    /// Reserved: a recitation of the whole matn (file name only).
    public let audio: String?
    /// Reserved: per-line start seconds for follow-along highlighting.
    public let timings: [Double]?
    public let sections: [Section]
    public let lines: [Line]

    public struct Section: Codable, Identifiable, Hashable, Sendable {
        public let id: String
        public let titleAr: String
        public let titleEn: String?

        enum CodingKeys: String, CodingKey {
            case id
            case titleAr = "title_ar"
            case titleEn = "title_en"
        }

        public func displayTitle(arabicUI: Bool) -> String {
            arabicUI ? titleAr : (titleEn ?? titleAr)
        }
    }

    /// One بيت: two hemistichs (صدر / عجز).
    public struct Line: Codable, Identifiable, Hashable, Sendable {
        public let number: Int
        public let sectionId: String
        public let first: String
        public let second: String
        /// Reserved: start second of this line in `Matn.audio`.
        public let start: Double?

        public var id: Int { number }

        enum CodingKeys: String, CodingKey {
            case number, first, second, start
            case sectionId = "section_id"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, sections, lines, audio, timings, retrieved
        case titleAr = "title_ar"
        case titleEn = "title_en"
        case shortTitleAr = "short_title_ar"
        case shortTitleEn = "short_title_en"
        case authorAr = "author_ar"
        case authorEn = "author_en"
        case composedAr = "composed_ar"
        case composedYearHijri = "composed_year_hijri"
        case sourceName = "source_name"
        case sourceUrl = "source_url"
        case sourceLicense = "source_license"
    }

    public func displayTitle(arabicUI: Bool) -> String { arabicUI ? titleAr : titleEn }

    /// The name for a 44pt inline navigation bar: short enough to sit beside
    /// the toolbar buttons without truncating. Falls back to the full title
    /// when a matn declares no short form.
    public func navigationTitle(arabicUI: Bool) -> String {
        (arabicUI ? shortTitleAr : shortTitleEn) ?? displayTitle(arabicUI: arabicUI)
    }
    public func displayAuthor(arabicUI: Bool) -> String { arabicUI ? authorAr : authorEn }

    /// The lines of one section, in order.
    public func lines(in section: Section) -> [Line] {
        lines.filter { $0.sectionId == section.id }
    }
}

public enum MatnStore {
    /// Every bundled matn. Add a file here (and its builder under `Tools/`)
    /// to ship another one — the UI is already N-matn.
    static let bundledFiles = ["matn-tuhfat-al-atfal"]

    public static func load() -> [Matn] {
        let decoder = JSONDecoder()
        return bundledFiles.compactMap { name in
            guard let url = Bundle.module.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url)
            else { return nil }
            return try? decoder.decode(Matn.self, from: data)
        }
    }

    public static func matn(id: String) -> Matn? {
        load().first { $0.id == id }
    }
}
