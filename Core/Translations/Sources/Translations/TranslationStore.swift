import Foundation
import Observation

/// Downloads and serves a Quran translation. Stored on disk in the Tanzil
/// text format ("surah|ayah|text" lines) in Application Support, then fully
/// offline. Never mixes with the Arabic text — separate store entirely.
@Observable
@MainActor
public final class TranslationStore {
    public enum State: Equatable {
        case notDownloaded
        case downloading
        case ready
        case failed(String)
    }

    /// Saheeh International English — the edition the app has always
    /// defaulted to, and still the fallback for any language without one
    /// of its own (Arabic, and anything unknown).
    public nonisolated static let defaultEdition = Edition(
        id: "en.sahih",
        language: "en",
        displayName: "English — Saheeh International",
        // Saheeh International is the Umm Muhammad (Emily Assami,
        // Mary Kennedy, Amatullah Bantley) translation — same text.
        mirrorFile: "eng-ummmuhammad")

    /// All offered translations — one per interface language, in the
    /// `NoorLanguage` order, Somali last (no interface language yet; its
    /// default only applies once `so` joins the picker). 1:1 with Android's
    /// `TanzilEditions`. Every one has an equivalent on both hosts (mirror
    /// files verified live: the first five 2026-09-09, the last five
    /// 2026-09-12 — 6236 ayat each, none empty).
    ///
    /// Display names are the edition's OWN language and script (endonyms,
    /// like the language picker — never routed through the string catalog),
    /// because a Bengali reader must find "বাংলা" whatever the interface
    /// language is.
    public nonisolated static let allEditions: [Edition] = [
        defaultEdition,
        Edition(id: "id.indonesian", language: "id", displayName: "Indonesia — Kemenag",
                mirrorFile: "ind-indonesianislam"),
        Edition(id: "ur.jalandhry", language: "ur", displayName: "اردو — جالندہری",
                mirrorFile: "urd-fatehmuhammadja", isRTL: true),
        // Mohammad Mahdi Fooladvand — the same work as the Persian
        // translation AUDIO (TranslationVoice.persian), so text and voice
        // agree ayah for ayah. Catalogue key fas_mohammadmahdifo.
        Edition(id: "fa.fooladvand", language: "fa", displayName: "فارسی — فولادوند",
                mirrorFile: "fas-mohammadmahdifo", isRTL: true),
        Edition(id: "tr.diyanet", language: "tr", displayName: "Türkçe — Diyanet",
                mirrorFile: "tur-diyanetisleri"),
        // Abdullah Muhammad Basmeih (Tafsir Pimpinan Ar-Rahman) — the only
        // Malay edition the mirror carries. Catalogue key msa_abdullahmuhamma.
        Edition(id: "ms.basmeih", language: "ms", displayName: "Bahasa Melayu — Basmeih",
                mirrorFile: "msa-abdullahmuhamma"),
        // Dr. Abu Bakr Muhammad Zakaria (KFGQPC edition). Catalogue key
        // ben_abubakrzakaria; not on tanzil.net, so that source 404s —
        // harmless, it is the last try.
        Edition(id: "bn.zakaria", language: "bn", displayName: "বাংলা — আবু বকর যাকারিয়া",
                mirrorFile: "ben-abubakrzakaria"),
        Edition(id: "fr.hamidullah", language: "fr", displayName: "Français — Hamidullah",
                mirrorFile: "fra-muhammadhamidul"),
        // Muhammad Isa García. Catalogue key spa_muhammadisagarc.
        Edition(id: "es.garcia", language: "es", displayName: "Español — Isa García",
                mirrorFile: "spa-muhammadisagarc"),
        // Mahmud Muhammad Abduh. Catalogue key som_mahmudmuhammada.
        Edition(id: "so.abduh", language: "so", displayName: "Soomaali — Maxamuud Maxamed Cabduh",
                mirrorFile: "som-mahmudmuhammada"),
    ]

    /// UserDefaults key. It holds an edition id only once the user has
    /// picked one in Settings; while it is ABSENT the edition follows the
    /// interface language. Absence is the "never chosen" sentinel (same
    /// idea, same key, on Android), so an explicit choice — English
    /// included — survives every language change, and "Follow app
    /// language" in Settings is simply removing the key.
    public nonisolated static let defaultsKey = "translation.id"

    /// The edition an interface language reads by default. Arabic has no
    /// translation to follow (the Arabic reader reads the Quran itself), so
    /// it — and anything unknown — keeps the English default the app has
    /// always had.
    public nonisolated static func defaultEdition(forLanguage language: String) -> Edition {
        allEditions.first { $0.language == language } ?? defaultEdition
    }

    /// The edition the user pinned in Settings, or nil when they never
    /// chose one (or the stored id is no longer offered).
    public nonisolated static func explicitEdition(
        defaults: UserDefaults = .standard
    ) -> Edition? {
        guard let id = defaults.string(forKey: defaultsKey) else { return nil }
        return allEditions.first { $0.id == id }
    }

    /// The edition to load: the pinned one, else the default for the
    /// interface language (a `NoorLanguage` raw value, e.g. "tr").
    public nonisolated static func selectedEdition(
        interfaceLanguage: String, defaults: UserDefaults = .standard
    ) -> Edition {
        explicitEdition(defaults: defaults) ?? defaultEdition(forLanguage: interfaceLanguage)
    }

    /// The direction the LOADED edition's text reads in (Urdu and Persian
    /// right to left; the rest LTR) — from the edition table, so an edition
    /// can never be listed without saying which way it reads.
    public var isRTL: Bool { edition.isRTL }

    public struct Edition: Sendable, Equatable {
        public let id: String
        /// The `NoorLanguage` raw value this edition is the default for.
        public let language: String
        public let displayName: String
        /// Its file name in fawazahmed0/quran-api. NOTE: that repo's
        /// editions.json KEYS use underscores while the FILES use hyphens —
        /// these are the file names.
        let mirrorFile: String
        /// Whether its text reads right to left.
        public let isRTL: Bool

        init(id: String, language: String, displayName: String, mirrorFile: String, isRTL: Bool = false) {
            self.id = id
            self.language = language
            self.displayName = displayName
            self.mirrorFile = mirrorFile
            self.isRTL = isRTL
        }

        public static func == (lhs: Edition, rhs: Edition) -> Bool { lhs.id == rhs.id }

        /// Where the edition is fetched from, in order; first success wins.
        ///
        /// The jsDelivr mirror leads and tanzil.net trails deliberately:
        /// tanzil.net is a single origin that national/corporate web filters
        /// block wholesale (verified 2026-09-09 from a UAE network — TLS
        /// reset on 443, and plain HTTP answers a filter's "Web Page Blocked
        /// … Category: religion" 503 page), which is how this was reported.
        /// jsDelivr is a global CDN with no rate limits, and its own README
        /// asks callers to carry a fallback, hence the GitHub raw URL in the
        /// middle. Whichever host answers, the file lands on disk in the
        /// same Tanzil line format, so an edition already downloaded from
        /// tanzil.net keeps working untouched.
        public var sources: [URL] {
            [
                "https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/\(mirrorFile).json",
                "https://raw.githubusercontent.com/fawazahmed0/quran-api/1/editions/\(mirrorFile).json",
                "https://tanzil.net/trans/\(id)",
            ].compactMap(URL.init(string:))
        }
    }

    public private(set) var state: State = .notDownloaded
    private var texts: [Int: String] = [:]  // key: surah*1000 + ayah
    private let edition: Edition

    /// `edition` is what `selectedEdition(interfaceLanguage:)` resolves —
    /// required rather than defaulted so a caller can never forget that the
    /// choice depends on the interface language.
    public init(edition: Edition) {
        self.edition = edition
        // NEVER parse in init: view structs re-init on every body pass and
        // a synchronous multi-MB parse on main blew the launch watchdog.
        if FileManager.default.fileExists(atPath: localFile.path) {
            state = .downloading  // "loading" from disk
            Task { await loadAsync() }
        }
    }

    private func loadAsync() async {
        let file = localFile
        let parsed = await Task.detached(priority: .userInitiated) { () -> [Int: String]? in
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { return nil }
            return Self.parse(content)
        }.value
        guard let parsed else {
            state = .failed("unreadable file")
            return
        }
        texts = parsed
        state = parsed.count > 6000 ? .ready : .failed("incomplete download (\(parsed.count) ayat)")
    }

    private var localFile: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("translations/\(edition.id).txt")
    }

    public func translation(surah: Int, ayah: Int) -> String? {
        texts[surah * 1000 + ayah]
    }

    /// Downloads (once) and loads the edition. Safe to call repeatedly, and
    /// safe to call again after a failure — that is what the reader's "tap
    /// to retry" line does.
    public func download() async {
        guard state != .downloading && state != .ready else { return }
        state = .downloading
        let sources = edition.sources
        let destination = localFile
        let outcome = await Task.detached(priority: .userInitiated) { () -> String? in
            for url in sources {
                guard let (data, response) = try? await URLSession.shared.data(from: url),
                      (response as? HTTPURLResponse)?.statusCode == 200,
                      let body = String(data: data, encoding: .utf8),
                      let lines = Self.normalize(body)
                else { continue }
                return lines
            }
            return nil
        }.value
        guard let outcome else {
            state = .failed("no source reachable")
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try outcome.write(to: destination, atomically: true, encoding: .utf8)
        } catch {
            state = .failed(error.localizedDescription)
            return
        }
        await loadAsync()
    }

    /// Accepts either wire format and returns the Tanzil line format we
    /// store, or nil when the body is not a whole Quran (a captive-portal or
    /// web-filter page never survives this).
    nonisolated static func normalize(_ body: String) -> String? {
        let head = body.drop { $0 == "\u{FEFF}" || $0.isWhitespace }
        let lines = head.first == "{" ? jsonToLines(body) : body
        guard let lines, parse(lines).count > 6000 else { return nil }
        return lines
    }

    /// fawazahmed0/quran-api shape: {"quran":[{"chapter":1,"verse":1,…}]}.
    private nonisolated static func jsonToLines(_ body: String) -> String? {
        struct Payload: Decodable {
            struct Ayah: Decodable {
                let chapter: Int
                let verse: Int
                let text: String
            }
            let quran: [Ayah]
        }
        guard let data = body.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }
        // One ayah per line is the storage contract.
        return payload.quran.map { ayah in
            let text = ayah.text.replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
            return "\(ayah.chapter)|\(ayah.verse)|\(text)"
        }.joined(separator: "\n")
    }

    /// Parses Tanzil "surah|ayah|text" lines; ignores comments and blanks.
    nonisolated static func parse(_ content: String) -> [Int: String] {
        var result: [Int: String] = [:]
        for line in content.split(separator: "\n") {
            guard !line.hasPrefix("#") else { continue }
            let parts = line.split(separator: "|", maxSplits: 2)
            guard parts.count == 3, let surah = Int(parts[0]), let ayah = Int(parts[1]) else { continue }
            result[surah * 1000 + ayah] = String(parts[2])
        }
        return result
    }
}
