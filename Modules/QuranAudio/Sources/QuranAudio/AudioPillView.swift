import DesignSystem
import SwiftUI

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
        }
    }

    public var body: some View {
        if let current = player.current {
            HStack(spacing: 12) {
                // Icon AND name open the reciter picker (system Menu follows
                // the process language, breaking RTL — custom sheet instead).
                Button { showReciterPicker = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.wave.2")
                            .font(.system(size: 15))
                            .foregroundStyle(NoorColor.accentPrimary)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(NoorColor.accentPrimary.opacity(0.15)))
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
                }
                .accessibilityLabel("Next ayah")

                Button { showModePicker = true } label: {
                    Image(systemName: modeIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(player.mode == .continuous ? NoorColor.inkSecondary : NoorColor.accentPrimary)
                }
                .accessibilityLabel("Playback mode")

                Button { player.stop() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
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
                        if !reciter.flag.isEmpty {
                            Text(verbatim: reciter.flag)
                                .font(.system(size: 18))
                        }
                        Text(verbatim: reciter.displayName(arabicUI: isArabicUI))
                            .font(.system(size: 16, weight: selection == reciter.rawValue ? .semibold : .regular))
                            .foregroundStyle(NoorColor.inkPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
        .presentationDetents([.height(260), .medium])
    }
}
