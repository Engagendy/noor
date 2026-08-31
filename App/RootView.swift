import ContentDB
import DesignSystem
import QuranReader
import SwiftUI

/// Phase 0 root: verify the bundled Quran DB, then render Surah Al-Fatiha.
/// Replaced by real navigation (Home / Reader / Prayer tabs) in Phase 1.
struct RootView: View {
    enum LoadState {
        case loading
        case ready(QuranDatabase)
        case failed(String)
    }

    @State private var state: LoadState = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                NoorColor.bgPrimary.ignoresSafeArea()
            case .ready(let database):
                SurahReaderView(database: database, surahId: 1)
            case .failed(let message):
                ContentUnavailableView(
                    "Content unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            }
        }
        .background(NoorColor.bgPrimary)
        .task {
            do {
                let database = try QuranDatabase()
                try database.verifyIntegrity()
                state = .ready(database)
            } catch {
                state = .failed("The bundled Quran database failed verification: \(error)")
            }
        }
    }
}
