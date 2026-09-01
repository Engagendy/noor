import Foundation
import Observation

/// The major hadith collections, downloadable as offline packs
/// (fawazahmed0/hadith-api, public domain — see LICENSES.md).
enum HadithCollectionID: String, CaseIterable, Identifiable {
    case bukhari, muslim

    var id: String { rawValue }
    var arabicName: String {
        switch self {
        case .bukhari: "صحيح البخاري"
        case .muslim: "صحيح مسلم"
        }
    }
    var englishName: String {
        switch self {
        case .bukhari: "Sahih al-Bukhari"
        case .muslim: "Sahih Muslim"
        }
    }
    /// Approximate download size shown before fetching.
    var sizeLabel: String {
        switch self {
        case .bukhari: "~14 MB"
        case .muslim: "~15 MB"
        }
    }
}

struct LibraryHadith: Identifiable {
    let number: String
    let arabic: String
    let english: String
    let book: Int
    var id: String { number }
}

struct HadithBook: Identifiable {
    let index: Int
    let arabicTitle: String
    let englishTitle: String
    let hadiths: [LibraryHadith]
    var id: Int { index }
}

/// Downloads, caches, and lazily parses a collection (Arabic + English).
@Observable
@MainActor
final class HadithLibrary {
    enum PackState: Equatable {
        case notDownloaded, downloading, ready, failed
    }

    private(set) var states: [HadithCollectionID: PackState] = [:]
    private var cache: [HadithCollectionID: [HadithBook]] = [:]

    init() {
        for collection in HadithCollectionID.allCases {
            states[collection] = Self.isDownloaded(collection) ? .ready : .notDownloaded
        }
    }

    private static func fileURL(_ collection: HadithCollectionID, lang: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("hadith/\(lang)-\(collection.rawValue).json")
    }

    static func isDownloaded(_ collection: HadithCollectionID) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(collection, lang: "ara").path)
            && FileManager.default.fileExists(atPath: fileURL(collection, lang: "eng").path)
    }

    func download(_ collection: HadithCollectionID) async {
        guard states[collection] != .downloading else { return }
        states[collection] = .downloading
        for lang in ["ara", "eng"] {
            let local = Self.fileURL(collection, lang: lang)
            if FileManager.default.fileExists(atPath: local.path) { continue }
            guard let url = URL(string:
                "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/\(lang)-\(collection.rawValue).min.json"),
                let (temp, response) = try? await URLSession.shared.download(from: url),
                (response as? HTTPURLResponse)?.statusCode == 200
            else {
                states[collection] = .failed
                return
            }
            try? FileManager.default.createDirectory(
                at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: local)
            guard (try? FileManager.default.moveItem(at: temp, to: local)) != nil else {
                states[collection] = .failed
                return
            }
        }
        states[collection] = .ready
    }

    func remove(_ collection: HadithCollectionID) {
        for lang in ["ara", "eng"] {
            try? FileManager.default.removeItem(at: Self.fileURL(collection, lang: lang))
        }
        cache[collection] = nil
        states[collection] = .notDownloaded
    }

    /// Parses off the main actor; result cached for the session.
    func books(for collection: HadithCollectionID) async -> [HadithBook] {
        if let cached = cache[collection] { return cached }
        let araURL = Self.fileURL(collection, lang: "ara")
        let engURL = Self.fileURL(collection, lang: "eng")
        let parsed = await Task.detached(priority: .userInitiated) {
            Self.parse(araURL: araURL, engURL: engURL)
        }.value
        cache[collection] = parsed
        return parsed
    }

    private struct Edition: Decodable {
        struct Meta: Decodable { let sections: [String: String] }
        struct Item: Decodable {
            let hadithnumber: AnyNumber
            let text: String
            let reference: Ref
        }
        struct Ref: Decodable { let book: AnyNumber }
        let metadata: Meta
        let hadiths: [Item]
    }

    /// The dataset mixes numeric and string numbers.
    struct AnyNumber: Decodable {
        let value: String
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let intValue = try? container.decode(Int.self) {
                value = String(intValue)
            } else if let doubleValue = try? container.decode(Double.self) {
                value = doubleValue.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(doubleValue)) : String(doubleValue)
            } else {
                value = (try? container.decode(String.self)) ?? "0"
            }
        }
    }

    nonisolated private static func parse(araURL: URL, engURL: URL) -> [HadithBook] {
        guard let araData = try? Data(contentsOf: araURL),
              let engData = try? Data(contentsOf: engURL),
              let ara = try? JSONDecoder().decode(Edition.self, from: araData),
              let eng = try? JSONDecoder().decode(Edition.self, from: engData)
        else { return [] }
        let engByNumber = Dictionary(eng.hadiths.map { ($0.hadithnumber.value, $0.text) },
                                     uniquingKeysWith: { first, _ in first })
        var byBook: [Int: [LibraryHadith]] = [:]
        for item in ara.hadiths {
            guard let book = Int(item.reference.book.value) else { continue }
            byBook[book, default: []].append(LibraryHadith(
                number: item.hadithnumber.value,
                arabic: item.text,
                english: engByNumber[item.hadithnumber.value] ?? "",
                book: book))
        }
        return byBook.keys.sorted().compactMap { index in
            guard let hadiths = byBook[index], !hadiths.isEmpty else { return nil }
            return HadithBook(
                index: index,
                arabicTitle: ara.metadata.sections[String(index)] ?? "كتاب \(index)",
                englishTitle: eng.metadata.sections[String(index)] ?? "Book \(index)",
                hadiths: hadiths)
        }
    }
}
