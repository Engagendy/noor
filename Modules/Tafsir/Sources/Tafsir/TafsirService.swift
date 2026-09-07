import Foundation
import Observation

/// Tafsir editions served per-ayah from the spa5k/tafsir_api CDN bundles
/// (see LICENSES.md). Each fetched ayah is cached to disk — offline after
/// first read.
public struct TafsirEdition: Identifiable, Hashable, Sendable {
    public let slug: String
    public let displayName: String
    public let isArabic: Bool

    public var id: String { slug }

    public static let all: [TafsirEdition] = [
        TafsirEdition(slug: "ar-tafsir-muyassar", displayName: "الميسر", isArabic: true),
        TafsirEdition(slug: "ar-tafseer-al-saddi", displayName: "السعدي", isArabic: true),
        TafsirEdition(slug: "ar-tafsir-ibn-kathir", displayName: "ابن كثير", isArabic: true),
        TafsirEdition(slug: "ar-tafsir-al-tabari", displayName: "الطبري", isArabic: true),
        TafsirEdition(slug: "ar-tafseer-al-qurtubi", displayName: "القرطبي", isArabic: true),
        TafsirEdition(slug: "en-tafisr-ibn-kathir", displayName: "Ibn Kathir (English)", isArabic: false),
        // Word meanings (غريب القرآن) rather than running commentary: each
        // entry glosses the difficult words of its ayah. `gharib` below
        // points the Learn hub's "Quranic word meanings" entry at it — it is
        // an ordinary edition here too, so anyone who prefers it in the ayah
        // sheet can pick it there.
        TafsirEdition(slug: "al-muyassar-fi-al-gharib", displayName: "الميسر في الغريب", isArabic: true),
        // Despite its name, what the API serves under this slug is running
        // commentary in the wording of as-Sa'di, NOT a word glossary
        // (verified 2026-09-07 against 1:1, 2:255 and 18:9) — so it is
        // offered as one more tafsir, not as غريب القرآن.
        TafsirEdition(slug: "asseraj-fi-bayan-gharib-alquran", displayName: "السراج", isArabic: true),
    ]

    /// The edition behind the Learn hub's "Quranic word meanings" entry.
    public static let gharib = named("al-muyassar-fi-al-gharib")

    public static func named(_ slug: String) -> TafsirEdition {
        all.first { $0.slug == slug } ?? all[0]
    }
}

@Observable
@MainActor
public final class TafsirService {
    public enum State: Equatable {
        case idle
        case loading
        case ready(String)
        case failed(String)
    }

    public private(set) var state: State = .idle

    /// Token of the most recent `load` call. A superseded/cancelled request
    /// must never write `state` after a newer request has taken over
    /// (`.task(id:)` cancels the old task, whose URLSession error would
    /// otherwise land as `.failed("cancelled")` on top of the new result).
    private var currentRequest = UUID()

    public init() {}

    private func commit(_ request: UUID, _ newState: State) {
        guard request == currentRequest, !Task.isCancelled else { return }
        state = newState
    }

    nonisolated private static func surahDirectory(edition: TafsirEdition, surah: Int) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("tafsir/\(edition.slug)/\(surah)")
    }

    nonisolated private static func cacheFile(edition: TafsirEdition, surah: Int, ayah: Int) -> URL {
        surahDirectory(edition: edition, surah: surah).appendingPathComponent("\(ayah).txt")
    }

    /// Written after a whole surah bundle has been cached. Without it a
    /// directory holding one ayah the user happened to tap in the reader
    /// would look like a complete surah to the browser. It is a marker in
    /// the SAME cache, not a second one — no tafsir text lives here.
    nonisolated private static func completionMarker(edition: TafsirEdition, surah: Int) -> URL {
        surahDirectory(edition: edition, surah: surah).appendingPathComponent(".complete")
    }

    public func load(edition: TafsirEdition, surah: Int, ayah: Int) async {
        let request = UUID()
        currentRequest = request
        state = .loading
        let cache = Self.cacheFile(edition: edition, surah: surah, ayah: ayah)
        if let cached = try? String(contentsOf: cache, encoding: .utf8), !cached.isEmpty {
            commit(request, .ready(cached))
            return
        }
        let url = URL(string:
            "https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir/\(edition.slug)/\(surah)/\(ayah).json")!
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let text = try Self.parse(data)
            try? FileManager.default.createDirectory(
                at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? text.write(to: cache, atomically: true, encoding: .utf8)
            commit(request, .ready(text))
        } catch {
            commit(request, .failed(error.localizedDescription))
        }
    }

    // MARK: - One surah, as a whole (the Learn browser)

    /// One ayah's tafsir. Editions that gloss only some ayat (غريب القرآن)
    /// simply omit the rest, so the browser renders what the edition has
    /// rather than a row per ayah of the surah.
    public struct Entry: Identifiable, Equatable, Sendable {
        public let ayah: Int
        public let text: String
        public var id: Int { ayah }
    }

    public enum SurahState: Equatable {
        case idle
        /// The surah's bundle is being fetched (this is the ONLY fetch the
        /// browser makes — the same per-surah bundle the offline pack uses).
        case downloading
        case ready([Entry])
        case failed(String)
    }

    public private(set) var surahState: SurahState = .idle
    private var currentSurahRequest = UUID()

    private func commitSurah(_ request: UUID, _ newState: SurahState) {
        guard request == currentSurahRequest, !Task.isCancelled else { return }
        surahState = newState
    }

    /// True once this surah's whole bundle is on disk — the browser reads it
    /// with no network at all.
    nonisolated public static func isSurahCached(edition: TafsirEdition, surah: Int) -> Bool {
        FileManager.default.fileExists(atPath: completionMarker(edition: edition, surah: surah).path)
    }

    /// Reads a cached surah out of the per-ayah cache. Same files `load`
    /// writes and reads — there is exactly one tafsir cache in the app.
    nonisolated static func cachedSurah(edition: TafsirEdition, surah: Int) -> [Entry] {
        let directory = surahDirectory(edition: edition, surah: surah)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.compactMap { name -> Entry? in
            guard name.hasSuffix(".txt"), let ayah = Int(name.dropLast(4)), ayah > 0,
                  let text = try? String(contentsOf: directory.appendingPathComponent(name),
                                        encoding: .utf8),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }
            return Entry(ayah: ayah, text: text)
        }
        .sorted { $0.ayah < $1.ayah }
    }

    /// Loads one surah for the Learn browser: cache first (offline), then the
    /// same per-surah bundle `downloadPack` uses, cached the same way.
    public func loadSurah(edition: TafsirEdition, surah: Int) async {
        let request = UUID()
        currentSurahRequest = request
        if Self.isSurahCached(edition: edition, surah: surah) {
            let cached = Self.cachedSurah(edition: edition, surah: surah)
            if !cached.isEmpty {
                commitSurah(request, .ready(cached))
                return
            }
        }
        commitSurah(request, .downloading)
        do {
            // An empty result is a real answer, not a failure: word-meaning
            // editions skip whole surahs.
            commitSurah(request, .ready(try await Self.fetchAndCacheSurah(edition: edition, surah: surah)))
        } catch {
            // Offline with a partial cache (ayat read one by one in the
            // reader) is still worth showing.
            let cached = Self.cachedSurah(edition: edition, surah: surah)
            commitSurah(request, cached.isEmpty ? .failed(error.localizedDescription) : .ready(cached))
        }
    }

    // MARK: - Offline pack download

    public enum PackState: Equatable {
        case idle
        case downloading(surah: Int)
        case done
        case failed(String)
    }

    public private(set) var packState: PackState = .idle

    /// True when every surah of this edition is cached (spot-checked).
    /// The `1.txt` fallback keeps packs downloaded by earlier versions —
    /// which wrote no completion marker — from looking undownloaded.
    nonisolated public static func isPackDownloaded(edition: TafsirEdition) -> Bool {
        [1, 2, 18, 67, 114].allSatisfy { surah in
            isSurahCached(edition: edition, surah: surah)
                || FileManager.default.fileExists(
                    atPath: cacheFile(edition: edition, surah: surah, ayah: 1).path)
        }
    }

    /// One entry of a per-surah CDN bundle. The bundles carry ayah/surah as
    /// numbers (some editions as strings) — accept both.
    private struct PackItem: Decodable {
        let ayah: Int
        let text: String

        enum CodingKeys: String, CodingKey { case ayah, text }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            text = try container.decode(String.self, forKey: .text)
            if let number = try? container.decode(Int.self, forKey: .ayah) {
                ayah = number
            } else {
                ayah = Int(try container.decode(String.self, forKey: .ayah)) ?? 0
            }
        }
    }

    /// THE per-surah fetch: one bundle, written into the per-ayah cache that
    /// `load` reads. Both the whole-edition download and the Learn browser go
    /// through here, so there is one network path and one cache.
    @discardableResult
    private static func fetchAndCacheSurah(edition: TafsirEdition, surah: Int) async throws -> [Entry] {
        let url = URL(string:
            "https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir/\(edition.slug)/\(surah).json")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let directory = surahDirectory(edition: edition, surah: surah)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var entries: [Entry] = []
        for item in try JSONDecoder().decode([PackItem].self, from: data) {
            guard item.ayah > 0 else { continue }
            let text = stripHTML(item.text)
            guard !text.isEmpty else { continue }
            try? text.write(to: cacheFile(edition: edition, surah: surah, ayah: item.ayah),
                            atomically: true, encoding: .utf8)
            entries.append(Entry(ayah: item.ayah, text: text))
        }
        try? Data().write(to: completionMarker(edition: edition, surah: surah))
        return entries.sorted { $0.ayah < $1.ayah }
    }

    /// Downloads the whole edition (114 per-surah bundles) into the same
    /// per-ayah cache `load` reads — tafsir becomes fully offline.
    public func downloadPack(edition: TafsirEdition) async {
        if case .downloading = packState { return }
        packState = .downloading(surah: 0)
        for surah in 1...114 {
            packState = .downloading(surah: surah)
            do {
                try await Self.fetchAndCacheSurah(edition: edition, surah: surah)
            } catch {
                // A cancelled download is not a failure worth reporting.
                if Task.isCancelled { packState = .idle; return }
                packState = .failed("\(surah): \(error.localizedDescription)")
                return
            }
            // Gentle pacing for the CDN.
            try? await Task.sleep(for: .milliseconds(80))
        }
        packState = .done
    }

    nonisolated static func parse(_ data: Data) throws -> String {
        struct Payload: Decodable { let text: String }
        let text = try JSONDecoder().decode(Payload.self, from: data).text
        return Self.stripHTML(text)
    }

    /// The CDN texts occasionally carry basic HTML tags — flatten to plain text.
    nonisolated static func stripHTML(_ html: String) -> String {
        html
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "</p>", with: "\n\n")
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
