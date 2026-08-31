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
        TafsirEdition(slug: "ar-tafsir-ibn-kathir", displayName: "ابن كثير", isArabic: true),
        TafsirEdition(slug: "en-tafisr-ibn-kathir", displayName: "Ibn Kathir (English)", isArabic: false),
    ]

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

    public init() {}

    private static func cacheFile(edition: TafsirEdition, surah: Int, ayah: Int) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("tafsir/\(edition.slug)/\(surah)/\(ayah).txt")
    }

    public func load(edition: TafsirEdition, surah: Int, ayah: Int) async {
        state = .loading
        let cache = Self.cacheFile(edition: edition, surah: surah, ayah: ayah)
        if let cached = try? String(contentsOf: cache, encoding: .utf8), !cached.isEmpty {
            state = .ready(cached)
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
            state = .ready(text)
        } catch {
            state = .failed(error.localizedDescription)
        }
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
