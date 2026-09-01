import DesignSystem
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Compact floating player pill (design 1c): reciter, ayah reference,
/// previous/play/next, stop. Shown over the reader while audio plays.
public struct AudioPillView: View {
    @Bindable var player: QuranAudioPlayer
    @Environment(\.locale) private var locale
    @State private var showReciterPicker = false
    @State private var showModePicker = false

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    public init(player: QuranAudioPlayer) {
        self.player = player
    }

    private var modeIcon: String {
        switch player.mode {
        case .continuous: "repeat"
        case .repeatAyah: "repeat.1"
        case .pageOnly: "doc.text"
        case .memorize: "brain.head.profile"
        }
    }

    public var body: some View {
        if let current = player.current {
            HStack(spacing: 12) {
                // Icon AND name open the reciter picker (system Menu follows
                // the process language, breaking RTL — custom sheet instead).
                Button { showReciterPicker = true } label: {
                    HStack(spacing: 10) {
                        ReciterAvatar(reciter: player.reciter, size: 38)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: player.reciter.displayName(arabicUI: isArabicUI))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(NoorColor.inkPrimary)
                                .lineLimit(1)
                            Text("\(player.surahTitle) · \(String(localized: "Ayah \(current.ayah)"))")
                                .font(.system(size: 11.5))
                                .foregroundStyle(NoorColor.inkSecondary)
                                .lineLimit(1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Reciter: \(player.reciter.displayName)")
                Spacer(minLength: 4)

                Button { player.previous() } label: {
                    Image(systemName: "backward.fill").font(.system(size: 14))
                        .frame(width: 38, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Previous ayah")

                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(NoorColor.bgPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(NoorColor.accentPrimary))
                }
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

                Button { player.next() } label: {
                    Image(systemName: "forward.fill").font(.system(size: 14))
                        .frame(width: 38, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Next ayah")

                Button { showModePicker = true } label: {
                    Image(systemName: modeIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(player.mode == .continuous ? NoorColor.inkSecondary : NoorColor.accentPrimary)
                        .frame(width: 38, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Playback mode")

                Button { player.stop() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Stop")
            }
            .buttonStyle(.plain)
            .foregroundStyle(NoorColor.inkSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(NoorColor.bgElevated)
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
            )
            .padding(.horizontal, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            // The pill itself is forced LTR (control order), so derive the
            // sheets' direction from the UI language, not the inherited env.
            .sheet(isPresented: $showReciterPicker) {
                ReciterPickerSheet(
                    selection: Binding(
                        get: { player.reciter.rawValue },
                        set: { player.reciter = Reciter(rawValue: $0) ?? .alafasy }),
                    isArabicUI: isArabicUI)
                    .environment(\.locale, locale)
                    .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
            }
            .sheet(isPresented: $showModePicker) {
                PlaybackModeSheet(player: player)
                    .environment(\.locale, locale)
                    .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
            }
        }
    }
}

/// RTL-correct reciter list (sheets don't inherit layoutDirection; the
/// presenter re-applies it).
public struct ReciterPickerSheet: View {
    @Binding var selection: String
    let isArabicUI: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    public init(selection: Binding<String>, isArabicUI: Bool) {
        _selection = selection
        self.isArabicUI = isArabicUI
    }

    private var filtered: [Reciter] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return Reciter.allCases }
        return Reciter.allCases.filter {
            $0.arabicName.localizedCaseInsensitiveContains(query)
                || $0.englishName.localizedCaseInsensitiveContains(query)
        }
    }

    public var body: some View {
        NavigationStack {
            List(filtered) { reciter in
                Button {
                    selection = reciter.rawValue
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        ReciterAvatar(reciter: reciter, size: 38)
                        if !reciter.flag.isEmpty {
                            Text(verbatim: reciter.flag)
                                .font(.system(size: 15))
                        }
                        Text(verbatim: reciter.displayName(arabicUI: isArabicUI))
                            .font(.system(size: 16, weight: selection == reciter.rawValue ? .semibold : .regular))
                            .foregroundStyle(NoorColor.inkPrimary)
                        if reciter.qfTimingId != nil {
                            // Supports word-by-word follow-along.
                            Text(isArabicUI ? "تتبع الكلمات" : "word tracking")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(NoorColor.accentPrimary.opacity(0.12)))
                                .foregroundStyle(NoorColor.accentPrimary)
                        }
                        Spacer(minLength: 4)
                        if selection == reciter.rawValue {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(NoorColor.accentPrimary)
                        }
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(NoorColor.bgPrimary)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(NoorColor.inkSecondary)
                    // Custom placeholder: the system one ignores the RTL
                    // environment and anchors to the process language.
                    TextField("", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .leading) {
                            if searchText.isEmpty {
                                Text("Search reciters")
                                    .font(.system(size: 15))
                                    .foregroundStyle(NoorColor.inkSecondary.opacity(0.8))
                                    .allowsHitTesting(false)
                            }
                        }
                        .accessibilityLabel("Search reciters")
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(NoorColor.inkSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 11).fill(NoorColor.bgElevated))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(NoorColor.bgPrimary)
            }
            .navigationTitle(Text("Reciter"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// RTL-correct playback-mode picker.
struct PlaybackModeSheet: View {
    @Bindable var player: QuranAudioPlayer
    @Environment(\.dismiss) private var dismiss

    private let options: [(QuranAudioPlayer.PlaybackMode, LocalizedStringKey, String)] = [
        (.continuous, "Continuous", "arrow.forward"),
        (.repeatAyah, "Repeat ayah", "repeat.1"),
        (.pageOnly, "This page only", "doc.text"),
    ]
    @State private var showMemorize = false

    var body: some View {
        NavigationStack {
            List(options, id: \.0) { option in
                Button {
                    player.mode = option.0
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: option.2)
                            .font(.system(size: 15))
                            .foregroundStyle(NoorColor.accentPrimary)
                            .frame(width: 26)
                        Text(option.1)
                            .font(.system(size: 16, weight: player.mode == option.0 ? .semibold : .regular))
                            .foregroundStyle(NoorColor.inkPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if player.mode == option.0 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(NoorColor.accentPrimary)
                        }
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(NoorColor.bgPrimary)
            .safeAreaInset(edge: .bottom) {
              VStack(spacing: 10) {
                // Playback speed
                HStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 14))
                        .foregroundStyle(NoorColor.inkSecondary)
                    ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                        let isOn = abs(Double(player.rate) - speed) < 0.01
                        Button {
                            player.rate = Float(speed)
                        } label: {
                            Text(verbatim: speed == 1.0 ? "1×" : String(format: "%g×", speed))
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(isOn ? NoorColor.accentPrimary : NoorColor.bgElevated))
                                .foregroundStyle(isOn ? NoorColor.bgPrimary : NoorColor.inkPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                // Sleep timer
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 14))
                        .foregroundStyle(NoorColor.inkSecondary)
                    ForEach([15, 30, 60], id: \.self) { minutes in
                        Button {
                            player.setSleepTimer(minutes: minutes)
                        } label: {
                            Text(verbatim: "\(minutes)")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(NoorColor.bgElevated))
                                .foregroundStyle(NoorColor.inkPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        player.stopAfterSurah.toggle()
                    } label: {
                        Text("End of surah")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(player.stopAfterSurah ? NoorColor.accentPrimary : NoorColor.bgElevated))
                            .foregroundStyle(player.stopAfterSurah ? NoorColor.bgPrimary : NoorColor.inkPrimary)
                    }
                    .buttonStyle(.plain)
                    if let deadline = player.sleepDeadline {
                        Button {
                            player.setSleepTimer(minutes: nil)
                        } label: {
                            HStack(spacing: 3) {
                                Text(deadline, style: .timer)
                                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(NoorColor.accentGold)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                Button {
                    showMemorize = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 16))
                        Text("Memorize a range")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        if player.mode == .memorize {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundStyle(NoorColor.accentPrimary)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(NoorColor.accentPrimary.opacity(0.1)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
              }
              .padding(16)
              .background(NoorColor.bgPrimary)
            }
            .sheet(isPresented: $showMemorize) {
                MemorizeRangeSheet(player: player)
            }
            .navigationTitle(Text("Playback mode"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}


/// Configure the memorize loop: ayah range and repeats per ayah.
struct MemorizeRangeSheet: View {
    @Bindable var player: QuranAudioPlayer
    @Environment(\.dismiss) private var dismiss
    @State private var start = 1
    @State private var end = 5
    @State private var perAyah = 3

    var body: some View {
        NavigationStack {
            Form {
                Stepper(value: $start, in: 1...max(1, player.currentAyahCount)) {
                    HStack {
                        Text("From ayah")
                        Spacer()
                        Text(verbatim: "\(start)").foregroundStyle(NoorColor.accentPrimary)
                    }
                }
                Stepper(value: $end, in: start...max(start, player.currentAyahCount)) {
                    HStack {
                        Text("To ayah")
                        Spacer()
                        Text(verbatim: "\(end)").foregroundStyle(NoorColor.accentPrimary)
                    }
                }
                Stepper(value: $perAyah, in: 1...20) {
                    HStack {
                        Text("Repeat each ayah")
                        Spacer()
                        Text(verbatim: "×\(perAyah)").foregroundStyle(NoorColor.accentPrimary)
                    }
                }
                Button {
                    player.startMemorize(start: start, end: end, perAyah: perAyah)
                    dismiss()
                } label: {
                    Text("Start memorizing")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
            }
            .scrollContentBackground(.hidden)
            .background(NoorColor.bgPrimary)
            .navigationTitle(Text("Memorize a range"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                start = player.memorizeStart
                end = min(max(start, player.memorizeEnd), max(1, player.currentAyahCount))
                perAyah = player.memorizePerAyah
                if let current = player.current {
                    start = current.ayah
                    end = min(current.ayah + 4, max(1, player.currentAyahCount))
                }
            }
        }
        .presentationDetents([.medium])
    }
}


/// Reciter avatar: a bundled image named after the reciter's rawValue
/// when present (licensed photos can be dropped in later), else a
/// deterministic colored monogram of the Arabic initial.
public struct ReciterAvatar: View {
    let reciter: Reciter
    let size: CGFloat

    public init(reciter: Reciter, size: CGFloat) {
        self.reciter = reciter
        self.size = size
    }

    private var initialLetter: String {
        String(reciter.arabicName.trimmingCharacters(in: .whitespaces).prefix(1))
    }

    private var hue: Double {
        let value = reciter.rawValue.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Double(value % 360) / 360.0
    }

    public var body: some View {
        #if canImport(UIKit)
        if let image = UIImage(named: "reciter_\(reciter.rawValue)") {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            monogram
        }
        #else
        monogram
        #endif
    }

    private var monogram: some View {
        ZStack {
            Circle()
                .fill(Color(hue: hue, saturation: 0.32, brightness: 0.52))
            Text(verbatim: initialLetter)
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
