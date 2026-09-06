import Athkar
import DesignSystem
import SwiftUI

/// "My athkar" — a short, everyday set for children, drawn verbatim from
/// the bundled Hisn al-Muslim data in the Athkar module. No dhikr text is
/// written here; only the chapters are chosen and shown larger.
struct KidsAthkarView: View {
    /// Chapters a child actually uses in a day, in day order. These are the
    /// exact Arabic `category` keys from `athkar.json` (the data key).
    static let categoryKeys = [
        "أذكار الاستيقاظ من النوم",      // waking up
        "الذكر عند الخروج من المنزل",     // leaving the home
        "الذكر عند دخول المنزل",          // entering the home
        "الدعاء قبل الطعام",              // before eating
        "الدعاء عند الفراغ من الطعام",    // after eating
        "دعاء دخول الخلاء",               // entering the bathroom
        "دعاء الخروج من الخلاء",          // leaving the bathroom
        "دعاء السفر",                     // travelling
        "أذكار النوم",                    // before sleeping
    ]

    @State private var categories: [DhikrCategory] = []
    private let audio = AthkarAudioPlayer.shared
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                ForEach(categories) { category in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(verbatim: category.displayTitle(arabicUI: isArabicUI))
                            .font(NoorFont.sectionHeader)
                            .foregroundStyle(NoorColor.accentPrimary)
                        ForEach(Array(category.items.enumerated()), id: \.offset) { index, dhikr in
                            card(dhikr, id: "\(category.category)#\(index)")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .onAppear(perform: load)
        .onDisappear { audio.stop() }
    }

    private func load() {
        guard categories.isEmpty else { return }
        let all = AthkarStore.load()
        categories = Self.categoryKeys.compactMap { key in
            all.first { $0.category == key }
        }
    }

    private func card(_ dhikr: Dhikr, id: String) -> some View {
        let isActive = audio.nowPlaying == id
        return VStack(alignment: .leading, spacing: 12) {
            Text(dhikr.text)
                .font(.noorScaled(23))
                .foregroundStyle(NoorColor.inkPrimary)
                .lineSpacing(10)
                .arabicBlock()
            HStack {
                if dhikr.count > 1 {
                    Text("Repeat \(dhikr.count)×")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.accentGold)
                }
                Spacer()
                if let file = dhikr.audio {
                    Button {
                        audio.play(file: file, id: id)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isActive ? NoorColor.accentPrimary : NoorColor.accentPrimary.opacity(0.12))
                                .frame(width: 40, height: 40)
                            if isActive && audio.isLoading {
                                ProgressView()
                                    .tint(NoorColor.bgPrimary)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: isActive && audio.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(isActive ? NoorColor.bgPrimary : NoorColor.accentPrimary)
                            }
                        }
                        .frame(width: NoorMetrics.minTapTarget, height: NoorMetrics.minTapTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isActive && audio.isPlaying ? Text("Pause") : Text("Play"))
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            if audio.failed == id {
                Text("Connect once to download this dhikr")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isActive ? NoorColor.stateReciting : NoorColor.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isActive ? NoorColor.accentPrimary.opacity(0.4) : NoorColor.inkPrimary.opacity(0.06),
                        lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

#Preview("Kids athkar — EN LTR") {
    NavigationStack { KidsAthkarView() }
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)
}

#Preview("Kids athkar — AR RTL") {
    NavigationStack { KidsAthkarView() }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}
