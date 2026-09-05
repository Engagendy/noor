import DesignSystem
import SwiftUI

/// Athkar home: tasbih counter up top, then Hisn al-Muslim categories.
public struct AthkarView: View {
    /// Exact `category` title in athkar.json for the after-taslim athkar;
    /// the after-salah reminder deep-links here (same string on Android).
    public static let afterSalahCategory = "الأذكار بعد السلام من الصلاة"

    @State private var categories: [DhikrCategory] = []
    @State private var searchText = ""
    @State private var pushedCategory: DhikrCategory?
    /// Set by the app to push a category (notification tap); cleared once
    /// consumed. Kept as a binding so a request made while this tab is
    /// off-screen is honored when it appears.
    @Binding private var openCategory: String?
    @Environment(\.locale) private var locale
    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    public init(openCategory: Binding<String?> = .constant(nil)) {
        _openCategory = openCategory
    }

    private func consumeOpenRequest() {
        guard let title = openCategory, !categories.isEmpty,
              let category = categories.first(where: { $0.category == title })
        else { return }
        openCategory = nil
        pushedCategory = category
    }

    private var filtered: [DhikrCategory] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return categories }
        return categories.filter {
            $0.category.contains(query)
                || ($0.categoryEn?.localizedCaseInsensitiveContains(query) ?? false)
                || $0.items.contains { $0.text.contains(query) }
        }
    }

    public var body: some View {
        List {
            NavigationLink {
                TasbihView()
            } label: {
                HStack(spacing: 14) {
                    RubElHizbMark(size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tasbih")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(NoorColor.inkPrimary)
                        Text(verbatim: "سبحان الله · الحمد لله · الله أكبر")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)

            NavigationLink {
                RuqyahView()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 20))
                        .foregroundStyle(NoorColor.accentPrimary)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ruqyah")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(NoorColor.inkPrimary)
                        Text(verbatim: "الرقية الشرعية من الكتاب والسنة")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)

            NavigationLink {
                SelectedDuasView()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "hands.and.sparkles")
                        .font(.system(size: 20))
                        .foregroundStyle(NoorColor.accentGold)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selected duas")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(NoorColor.inkPrimary)
                        Text(verbatim: "أدعية قرآنية ونبوية والاستخارة")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)

            NavigationLink {
                AsmaulHusnaView()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 20))
                        .foregroundStyle(NoorColor.accentGold)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Names of Allah")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(NoorColor.inkPrimary)
                        Text(verbatim: "أسماء الله الحسنى · ٩٩")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)

            ForEach(filtered) { category in
                NavigationLink {
                    DhikrListView(category: category)
                } label: {
                    HStack {
                        Text(verbatim: category.displayTitle(arabicUI: isArabicUI))
                            .font(.system(size: 16))
                            .foregroundStyle(NoorColor.inkPrimary)
                        Spacer()
                        Text(verbatim: "\(category.items.count)")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        // The chapter list follows the interface direction; only the Arabic
        // dhikr pages themselves stay right-to-left.
        .searchable(text: $searchText, prompt: Text("Search athkar"))
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Athkar"))
        .navigationDestination(item: $pushedCategory) { category in
            DhikrListView(category: category)
        }
        .task {
            if categories.isEmpty { categories = AthkarStore.load() }
            consumeOpenRequest()
        }
        .onAppear(perform: consumeOpenRequest)
        .onChange(of: openCategory) { _, _ in consumeOpenRequest() }
    }
}

/// One category: tappable dhikr cards that count down their repetitions.
struct DhikrListView: View {
    let category: DhikrCategory
    @State private var progress: [String: Int] = [:]
    @State private var sharing: Dhikr?
    @Environment(\.locale) private var locale
    private let audio = AthkarAudioPlayer.shared

    /// Player id for the whole-chapter recording (distinct from any dhikr id).
    private var chapterAudioId: String { "chapter:" + category.category }
    private var isChapterActive: Bool { audio.nowPlaying == chapterAudioId }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let chapterFile = category.chapterAudio {
                    chapterPill(file: chapterFile)
                }
                ForEach(category.items) { dhikr in
                    DhikrCard(
                        dhikr: dhikr,
                        done: progress[dhikr.id] ?? 0,
                        audioState: dhikr.audio == nil ? nil : DhikrCard.AudioState(
                            isActive: audio.nowPlaying == dhikr.id,
                            isPlaying: audio.nowPlaying == dhikr.id && audio.isPlaying,
                            isLoading: audio.nowPlaying == dhikr.id && audio.isLoading,
                            failed: audio.failed == dhikr.id),
                        onTap: {
                            let current = progress[dhikr.id] ?? 0
                            if current < dhikr.count {
                                progress[dhikr.id] = current + 1
                                #if os(iOS)
                                if current + 1 == dhikr.count {
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                } else {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                                #endif
                            }
                        },
                        onShare: { sharing = dhikr },
                        onPlay: dhikr.audio.map { file in
                            { audio.play(file: file, id: dhikr.id) }
                        })
                }
            }
            .padding(16)
        }
        // Leaving the chapter silences it — no voice from an unseen screen.
        .onDisappear { audio.stop() }
        .sheet(item: $sharing) { dhikr in
            NoorShareSheet(
                arabicText: dhikr.text,
                reference: category.category,
                attribution: "نور Noor · حصن المسلم",
                useQuranFont: false)
                .environment(\.locale, locale)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text(verbatim: category.category))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    progress = [:]
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(NoorColor.accentPrimary)
                }
                .accessibilityLabel("Reset")
            }
        }
    }

    /// "Play chapter" pill: one recording of the whole chapter; toggles to
    /// pause while it plays, spinner while the file downloads.
    private func chapterPill(file: String) -> some View {
        let playing = isChapterActive && audio.isPlaying
        let loading = isChapterActive && audio.isLoading
        return VStack(spacing: 6) {
            Button {
                audio.play(file: file, id: chapterAudioId)
            } label: {
                HStack(spacing: 8) {
                    if loading {
                        ProgressView()
                            .tint(NoorColor.bgPrimary)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    (playing ? Text("Pause") : Text("Play chapter"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(NoorColor.bgPrimary)
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(Capsule().fill(NoorColor.accentPrimary))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(loading)
            .accessibilityLabel(playing ? Text("Pause") : Text("Play chapter"))
            if isChapterActive, audio.progress > 0 {
                ProgressView(value: audio.progress)
                    .tint(NoorColor.accentPrimary)
                    .frame(maxWidth: 220)
                    .accessibilityHidden(true)
            }
            if audio.failed == chapterAudioId {
                Text("Connect once to download this dhikr")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
        .animation(.easeInOut(duration: 0.2), value: playing)
    }
}

struct DhikrCard: View {
    /// Playback state of this card's own recording (nil → no recording).
    struct AudioState: Equatable {
        var isActive = false
        var isPlaying = false
        var isLoading = false
        var failed = false
    }

    let dhikr: Dhikr
    let done: Int
    var audioState: AudioState?
    let onTap: () -> Void
    var onShare: (() -> Void)?
    /// Play/pause this dhikr's recording; nil hides the button.
    var onPlay: (() -> Void)?

    private var isComplete: Bool { done >= dhikr.count }
    private var isReciting: Bool { audioState?.isActive ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Inside RTL, .leading is the right edge — where Arabic starts.
            Text(dhikr.text)
                .font(.noorScaled(19))
                .foregroundStyle(NoorColor.inkPrimary)
                .lineSpacing(8)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                if isComplete {
                    Label {
                        Text("Done")
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NoorColor.accentPrimary)
                } else {
                    Text(verbatim: "\(done) / \(dhikr.count)")
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(NoorColor.inkSecondary)
                }
                Spacer()
                if dhikr.count > 1 {
                    Text("Repeat \(dhikr.count)×")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.accentGold)
                }
                if let onShare {
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundStyle(NoorColor.accentPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Share")
                }
                if let onPlay, let audioState {
                    playButton(audioState, action: onPlay)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            if audioState?.failed == true {
                Text("Connect once to download this dhikr")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isComplete || isReciting ? NoorColor.stateReciting : NoorColor.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isComplete || isReciting ? NoorColor.accentPrimary.opacity(0.4) : NoorColor.inkPrimary.opacity(0.06),
                        lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .animation(.easeInOut(duration: 0.2), value: done)
        .animation(.easeInOut(duration: 0.2), value: isReciting)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(dhikr.text)
        .accessibilityValue("\(done) of \(dhikr.count)")
        .accessibilityAddTraits(.isButton)
    }

    /// Small round play/pause control; spinner while the recording downloads.
    /// Sits inside the card but is its own button so it never counts a tap.
    private func playButton(_ state: AudioState, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(state.isActive ? NoorColor.accentPrimary : NoorColor.accentPrimary.opacity(0.12))
                    .frame(width: 32, height: 32)
                if state.isLoading {
                    ProgressView()
                        .tint(NoorColor.bgPrimary)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(state.isActive ? NoorColor.bgPrimary : NoorColor.accentPrimary)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(state.isLoading)
        .accessibilityLabel(state.isPlaying ? Text("Pause") : Text("Play"))
    }
}

/// Free tasbih: tap the big dial; gentle haptic every 33.
struct TasbihView: View {
    @AppStorage("tasbih.count") private var count = 0
    @AppStorage("tasbih.phrase") private var phraseIndex = 0

    private static let phrases = [
        "سبحان الله", "الحمد لله", "الله أكبر",
        "لا إله إلا الله", "أستغفر الله", "لا حول ولا قوة إلا بالله",
    ]
    private var phrase: String {
        Self.phrases[min(max(phraseIndex, 0), Self.phrases.count - 1)]
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            // The dhikr being counted — tap a chip to switch (resets count).
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(Self.phrases.enumerated()), id: \.offset) { index, text in
                        Button {
                            if phraseIndex != index {
                                phraseIndex = index
                                count = 0
                            }
                        } label: {
                            Text(verbatim: text)
                                .font(.system(size: 14, weight: phraseIndex == index ? .semibold : .regular))
                                .foregroundStyle(phraseIndex == index ? NoorColor.bgPrimary : NoorColor.inkPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule().fill(phraseIndex == index
                                                   ? AnyShapeStyle(NoorColor.accentPrimary)
                                                   : AnyShapeStyle(NoorColor.bgElevated))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .environment(\.layoutDirection, .rightToLeft)
            Button {
                count += 1
                #if os(iOS)
                if count % 33 == 0 {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                #endif
            } label: {
                ZStack {
                    Circle()
                        .fill(NoorColor.accentPrimary.opacity(0.1))
                    Circle()
                        .trim(from: 0, to: CGFloat(count % 33) / 33)
                        .stroke(NoorColor.accentGold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 6) {
                        Text(verbatim: phrase)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(NoorColor.accentPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 24)
                        Text(verbatim: "\(count)")
                            .font(.system(size: 58, weight: .semibold).monospacedDigit())
                            .foregroundStyle(NoorColor.inkPrimary)
                        Text(verbatim: "\(count / 33) × ٣٣")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                }
                .frame(width: 260, height: 260)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Count")
            .accessibilityValue("\(count)")

            Button {
                count = 0
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NoorColor.inkSecondary)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Tasbih"))
    }
}

#Preview {
    NavigationStack { AthkarView() }
}
