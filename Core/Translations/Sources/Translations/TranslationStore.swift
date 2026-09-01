import Foundation
import Observation

/// Downloads and serves a Quran translation (Tanzil text format:
/// "surah|ayah|text" lines). Downloaded once to Application Support, then
/// fully offline. Never mixes with the Arabic text — separate store entirely.
@Observable
@MainActor
public final class TranslationStore {
    public enum State: Equatable {
        case notDownloaded
        case downloading
        case ready
        case failed(String)
    }

    /// Saheeh International English, from Tanzil's translation collection.
    public nonisolated static let defaultEdition = Edition(
        id: "en.sahih",
        displayName: "English — Saheeh International",
        url: URL(string: "https://tanzil.net/trans/en.sahih")!)

    /// All offered translations (Tanzil ids verified live 2026-09-01).
    public nonisolated static let allEditions: [Edition] = [
        defaultEdition,
        Edition(id: "ur.jalandhry", displayName: "اردو — جالندہری",
                url: URL(string: "https://tanzil.net/trans/ur.jalandhry")!),
        Edition(id: "fr.hamidullah", displayName: "Français — Hamidullah",
                url: URL(string: "https://tanzil.net/trans/fr.hamidullah")!),
        Edition(id: "id.indonesian", displayName: "Indonesia — Kemenag",
                url: URL(string: "https://tanzil.net/trans/id.indonesian")!),
        Edition(id: "tr.diyanet", displayName: "Türkçe — Diyanet",
                url: URL(string: "https://tanzil.net/trans/tr.diyanet")!),
    ]

    /// The user's chosen edition (defaults to English).
    public nonisolated static func selectedEdition() -> Edition {
        let id = UserDefaults.standard.string(forKey: "translation.id") ?? defaultEdition.id
        return allEditions.first { $0.id == id } ?? defaultEdition
    }

    /// RTL translations (Urdu) align right.
    public var isRTL: Bool { edition.id.hasPrefix("ur") }

    public struct Edition: Sendable {
        public let id: String
        public let displayName: String
        public let url: URL
    }

    public private(set) var state: State = .notDownloaded
    private var texts: [Int: String] = [:]  // key: surah*1000 + ayah
    private let edition: Edition

    public init(edition: Edition = TranslationStore.selectedEdition()) {
        self.edition = edition
        if FileManager.default.fileExists(atPath: localFile.path) {
            load()
        }
    }

    private var localFile: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("translations/\(edition.id).txt")
    }

    public func translation(surah: Int, ayah: Int) -> String? {
        texts[surah * 1000 + ayah]
    }

    public func download() async {
        guard state != .downloading && state != .ready else { return }
        state = .downloading
        do {
            let (temp, response) = try await URLSession.shared.download(from: edition.url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            try FileManager.default.createDirectory(
                at: localFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: localFile)
            try FileManager.default.moveItem(at: temp, to: localFile)
            load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func load() {
        guard let content = try? String(contentsOf: localFile, encoding: .utf8) else {
            state = .failed("unreadable file")
            return
        }
        texts = Self.parse(content)
        state = texts.count > 6000 ? .ready : .failed("incomplete download (\(texts.count) ayat)")
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
