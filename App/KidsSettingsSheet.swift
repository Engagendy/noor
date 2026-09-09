import DesignSystem
import QuranAudio
import SwiftUI

/// The child's own settings — the three things they may change without a
/// grown-up: the interface language, whether they are listening or
/// memorising, and who is reciting.
///
/// Deliberately NOT offered here: translation audio, the Warsh readers,
/// playback speed and the sleep timer. Named "Settings" rather than
/// "Sound" once language joined it; everything is large and unlabelled by
/// jargon.
struct KidsSettingsSheet: View {
    let age: Int
    let onDone: () -> Void

    @AppStorage(KidsMode.listenModeKey) private var listenMode = false
    /// The app's ONE language mechanism: RootView observes this key and
    /// re-applies the locale + layout direction to the whole tree (kids
    /// shell included), so nothing extra is needed here.
    @AppStorage("app.language") private var language = "system"
    @AppStorage("audio.reciter") private var reciterRaw = Reciter.alafasy.rawValue
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    /// The teaching recitation first, then the rest. Hafs only — the mushaf
    /// a child reads here is Hafs, and Warsh audio would not match it.
    private var reciters: [Reciter] {
        let all = Reciter.all(riwayah: .hafs)
        return [.husaryMuallim] + all.filter { $0 != .husaryMuallim }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(NoorFont.screenTitle)
                    .foregroundStyle(NoorColor.inkPrimary)
                Spacer()
                Button(action: onDone) {
                    Text("Done")
                        .font(.noorScaled(17, weight: .semibold))
                        .foregroundStyle(NoorColor.accentPrimary)
                        .frame(minWidth: NoorMetrics.minTapTarget,
                               minHeight: NoorMetrics.minTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    languagePicker
                    modePicker
                    reciterList
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .background(NoorColor.bgPrimary)
        .task {
            // Screenshot/UI-test hook, same family as NOOR_TAB / NOOR_OPEN:
            // NOOR_KIDS_LANG=<language code> taps the card for us so the
            // LIVE switch (not a relaunch) can be captured.
            guard let target = ProcessInfo.processInfo.environment["NOOR_KIDS_LANG"],
                  let language = NoorLanguage(rawValue: target) else { return }
            try? await Task.sleep(for: .seconds(4))
            self.language = language.rawValue
        }
    }

    // MARK: Language

    /// Each option is written in its OWN language, so a child recognises
    /// the one they want without having to read the other.
    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Language")
                .font(NoorFont.sectionHeader)
                .foregroundStyle(NoorColor.accentPrimary)
            // Ten languages no longer fit one row of big cards, so they
            // wrap in a two-column grid — still one large tap target each,
            // still nothing to read but the language's own name.
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                ForEach(NoorLanguage.allCases, id: \.rawValue) { option in
                    languageCard(option)
                }
            }
        }
    }

    private func languageCard(_ option: NoorLanguage) -> some View {
        // "system" resolves to whichever language the device is using, so
        // the matching card still reads as selected.
        let selected = NoorLanguage.resolve(language) == option
        return Button {
            language = option.rawValue
        } label: {
            Text(verbatim: option.endonym)
                .font(NoorAppFont.font(showing: option, size: 22, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(selected ? NoorColor.bgPrimary : NoorColor.inkPrimary)
                .environment(\.layoutDirection, option.layoutDirection)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selected ? NoorColor.accentPrimary : NoorColor.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(selected ? Color.clear : NoorColor.inkPrimary.opacity(0.1), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: option.endonym))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Listen or memorise

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                modeCard(
                    title: Text("Listen"),
                    detail: Text("Plays straight through"),
                    symbol: "speaker.wave.2",
                    selected: listenMode,
                    action: { listenMode = true })
                modeCard(
                    title: Text("Memorise"),
                    detail: KidsMode.repeatCount(age: age) > 1
                        ? Text("Each ayah \(KidsMode.repeatCount(age: age)) times")
                        : Text("Plays straight through"),
                    symbol: "repeat",
                    selected: !listenMode,
                    action: { listenMode = false })
            }
        }
    }

    private func modeCard(title: Text, detail: Text, symbol: String,
                          selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold))
                title
                    .font(.noorScaled(19, weight: .semibold))
                detail
                    .font(NoorFont.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(selected
                                     ? NoorColor.bgPrimary.opacity(0.85)
                                     : NoorColor.inkSecondary)
            }
            .foregroundStyle(selected ? NoorColor.bgPrimary : NoorColor.inkPrimary)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(selected ? NoorColor.accentPrimary : NoorColor.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(selected ? Color.clear : NoorColor.inkPrimary.opacity(0.1), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Reciter

    private var reciterList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reciter")
                .font(NoorFont.sectionHeader)
                .foregroundStyle(NoorColor.accentPrimary)
            ForEach(reciters) { reciter in
                reciterRow(reciter)
            }
        }
    }

    private func reciterRow(_ reciter: Reciter) -> some View {
        let selected = reciter.rawValue == reciterRaw
        return Button {
            reciterRaw = reciter.rawValue
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: reciter.displayName(arabicUI: isArabicUI))
                        .font(.noorScaled(18, weight: selected ? .semibold : .regular))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .multilineTextAlignment(.leading)
                    if reciter == .husaryMuallim {
                        Text("Reads slowly, for learning")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.accentGold)
                    }
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(NoorColor.accentPrimary)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? NoorColor.stateReciting : NoorColor.bgElevated)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: reciter.displayName(arabicUI: isArabicUI)))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("Kids settings — EN LTR") {
    KidsSettingsSheet(age: 5, onDone: {})
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)
}

#Preview("Kids settings — AR RTL") {
    KidsSettingsSheet(age: 5, onDone: {})
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}
