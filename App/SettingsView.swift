import DesignSystem
import Learn
import Notifications
import PrayerTimes
import Translations
import QuranAudio
import QuranReader
import Tafsir
import SwiftUI

struct SettingsView: View {
    static let shareTextAr = "نور: القرآن ومواقيت الصلاة والأذكار، مجانًا للأبد بلا إعلانات ولا تتبّع.\nApp Store: https://apps.apple.com/ae/app/noor-al-muslim/id6807128479\nGoogle Play: https://play.google.com/store/apps/details?id=com.engagendy.noor"
    static let shareTextEn = "Noor: Quran, prayer times and athkar, free forever with no ads and no tracking.\nApp Store: https://apps.apple.com/ae/app/noor-al-muslim/id6807128479\nGoogle Play: https://play.google.com/store/apps/details?id=com.engagendy.noor"
    /// `"system"` or a `NoorLanguage` raw value — applied live via the
    /// locale environment (never AppleLanguages; see `NoorApp`).
    @AppStorage("app.language") private var language = "system"
    /// "system" | "light" | "dark"
    @AppStorage("app.theme") private var theme = "system"
    /// Interface font family — shared key/values with Android (`ui.font`).
    @AppStorage(NoorAppFont.defaultsKey) private var uiFontRaw = NoorAppFont.fallback.rawValue
    @AppStorage("reader.fontSize") private var quranFontSize = 26.0
    @AppStorage("reader.mode") private var readerMode = "mushaf"
    @AppStorage("audio.reciter") private var reciterRaw = Reciter.alafasy.rawValue
    @AppStorage(TranslationVoice.defaultsKey) private var translationVoiceRaw = TranslationVoice.none.rawValue
    @AppStorage("translation.id") private var translationId = "en.sahih"
    /// Same key the reader's options panel writes, so the two places can
    /// never disagree about whether the gloss is on.
    @AppStorage("reader.showTranslation") private var showTranslation = false
    @State private var showReciterPicker = false
    @State private var showAdhanSounds = false
    @State private var showZakat = false
    @AppStorage("notifications.enabled") private var notificationsEnabled = false
    @AppStorage("fasting.reminders") private var fastingReminders = false
    @AppStorage(AthkarReminderScheduler.enabledKey) private var athkarAfterSalah = false
    @AppStorage(AthkarReminderScheduler.minutesKey) private var athkarAfterSalahMinutes
        = AthkarReminderScheduler.defaultMinutes
    @AppStorage("prayer.sound") private var soundRaw = AdhanSound.adhanMadinah.rawValue
    // Kids mode: the toggle never writes `kids.enabled` itself — turning it
    // on goes through the age sheet, turning it off through the gate.
    @AppStorage(KidsMode.enabledKey) private var kidsEnabled = false
    @AppStorage(KidsMode.ageKey) private var kidsAge = KidsMode.defaultAge
    /// Screenshot/UI-test hooks: NOOR_KIDS_AGE_SHEET=1 / NOOR_KIDS_GATE=1
    /// present the two kids-mode sheets at launch.
    @State private var showKidsAge =
        ProcessInfo.processInfo.environment["NOOR_KIDS_AGE_SHEET"] == "1"
    @State private var showKidsGate =
        ProcessInfo.processInfo.environment["NOOR_KIDS_GATE"] == "1"
    /// The learning area is reachable from Settings too, so its cross-source
    /// search needs the same provider the Quran tab gives it.
    @State private var learnSearch = LearnTafsirSearch()
    #if os(iOS)
    /// Screenshot/UI-test hooks: NOOR_LANG_PICKER=1 and NOOR_FONT_PICKER=1
    /// push the language / font list at launch. They are pushed screens
    /// rather than `Picker` pages now (see the first section), and a
    /// simulator cannot be tapped from a script.
    @State private var pushedList: PushedList? = {
        switch ProcessInfo.processInfo.environment {
        case let env where env["NOOR_LANG_PICKER"] == "1": .language
        case let env where env["NOOR_FONT_PICKER"] == "1": .appFont
        default: nil
        }
    }()
    enum PushedList: Hashable { case language, appFont }
    #endif
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    /// The stored language, written in its own language and script — the
    /// same face the row in the pushed list uses, so Urdu stays Nastaliq.
    @ViewBuilder private var languageValueLabel: some View {
        if let option = NoorLanguage(rawValue: language) {
            Text(verbatim: option.endonym)
                .font(NoorAppFont.font(showing: option, size: 15))
                .environment(\.layoutDirection, option.layoutDirection)
                .foregroundStyle(NoorColor.inkSecondary)
        } else {
            Text("System")
                .foregroundStyle(NoorColor.inkSecondary)
        }
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { kidsEnabled },
                    // Both directions are gated, so the switch only moves
                    // once the sheet below has confirmed.
                    set: { wants in
                        if wants { showKidsAge = true } else { showKidsGate = true }
                    })) {
                    Text("Kids mode")
                }
            } footer: {
                Text("A simpler Quran for children, with a grown-up lock.")
            }

            Section {
                // Ten languages and five font families, each row drawn in
                // its OWN face (and, for the languages, its own writing
                // direction): a picker that says "Bengali" to someone who
                // cannot read the current interface language is no picker at
                // all, and a font you cannot see is not a choice either.
                //
                // These are NOT `Picker`s any more. `.pickerStyle(
                // .navigationLink)` builds the pushed page itself, and that
                // page renders NOTHING for a row that is more than a bare,
                // unmodified `Text`: on an iPad Pro 13-inch (iPadOS 26.5,
                // verified 2026-09-12) the pushed "Language" list drew the
                // "System" row and then ten rows that were completely blank
                // — only the checkmark showed a row was there at all. The
                // very same rows draw perfectly inline in this Form, and in
                // a list we push ourselves, so it is the picker's own pushed
                // page and not the rows or the order of their modifiers
                // (every ordering was tried). The font picker had the same
                // shape — `.navigationLink` over a two-line `VStack` row,
                // which is even further from a bare `Text` — so it is moved
                // with it rather than left to fail the same way.
                // macOS keeps a pop-up Picker: it is the native idiom there
                // and it never pushes a page.
                #if os(iOS)
                NavigationLink {
                    LanguageChoiceList(selection: $language)
                } label: {
                    HStack {
                        Text("Language")
                            .foregroundStyle(NoorColor.inkPrimary)
                        Spacer(minLength: 12)
                        languageValueLabel
                    }
                }
                #else
                Picker(selection: $language) {
                    Text("System").tag(NoorLanguage.systemValue)
                    ForEach(NoorLanguage.allCases, id: \.rawValue) { option in
                        Text(verbatim: option.endonym).tag(option.rawValue)
                    }
                } label: {
                    Text("Language")
                }
                #endif
                Picker(selection: $theme) {
                    Text("System").tag("system")
                    Text("Light (Mushaf)").tag("light")
                    Text("Dark (Tahajjud)").tag("dark")
                } label: {
                    Text("Appearance")
                }
                #if os(iOS)
                NavigationLink {
                    AppFontChoiceList(selection: $uiFontRaw)
                } label: {
                    HStack {
                        Text("App font")
                            .foregroundStyle(NoorColor.inkPrimary)
                        Spacer(minLength: 12)
                        Text(verbatim: NoorAppFont(rawValue: uiFontRaw)?.displayName
                            ?? NoorAppFont.fallback.displayName)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                }
                #else
                Picker(selection: $uiFontRaw) {
                    ForEach(NoorAppFont.allCases, id: \.rawValue) { family in
                        Text(verbatim: family.displayName).tag(family.rawValue)
                    }
                } label: {
                    Text("App font")
                }
                #endif
            }

            Section {
                Toggle(isOn: $notificationsEnabled) {
                    Text("Adhan notifications")
                }
                Toggle(isOn: $fastingReminders) {
                    Text("Sunnah fasting reminders")
                }
                Toggle(isOn: $athkarAfterSalah) {
                    Text("After-prayer athkar reminder")
                }
                if athkarAfterSalah {
                    Picker(selection: $athkarAfterSalahMinutes) {
                        ForEach(AthkarReminderScheduler.minuteChoices, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    } label: {
                        Text("After prayer by")
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("After prayer by")
                }
                Button {
                    showAdhanSounds = true
                } label: {
                    HStack {
                        Text("Notification sound")
                            .foregroundStyle(NoorColor.inkPrimary)
                        Spacer()
                        Text(AdhanSound.stored(soundRaw).displayName)
                            .foregroundStyle(NoorColor.inkSecondary)
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(NoorColor.inkSecondary.opacity(0.6))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .sheet(isPresented: $showAdhanSounds) {
                    AdhanSoundPickerView(soundRaw: $soundRaw)
                        .environment(\.locale, locale)
                        .noorInterfaceDirection()
                }
            } header: {
                Text("Prayer")
            } footer: {
                Text("Notifications are scheduled on your device for the next 12 days and roll forward automatically. Toggle individual prayers with the bell on the Prayer screen.")
            }

            Section {
                NavigationLink {
                    StorageView()
                } label: {
                    HStack {
                        Image(systemName: "internaldrive")
                            .font(.system(size: 14))
                            .foregroundStyle(NoorColor.accentPrimary)
                        Text("Storage")
                            .foregroundStyle(NoorColor.inkPrimary)
                    }
                }
                Button {
                    showZakat = true
                } label: {
                    HStack {
                        Image(systemName: "percent")
                            .font(.system(size: 14))
                            .foregroundStyle(NoorColor.accentPrimary)
                        Text("Zakat Calculator")
                            .foregroundStyle(NoorColor.inkPrimary)
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(NoorColor.inkSecondary.opacity(0.6))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .sheet(isPresented: $showZakat) {
                    ZakatView()
                        .environment(\.locale, locale)
                        .noorInterfaceDirection()
                }
            } header: {
                Text("Tools")
            }

            Section {
                Picker(selection: $readerMode) {
                    Text("Mushaf (continuous)").tag("mushaf")
                    Text("Ayah by ayah").tag("ayah")
                } label: {
                    Text("Reading mode")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quran text size")
                    Slider(value: $quranFontSize,
                           in: Double(NoorMetrics.quranSizeRange.lowerBound)...Double(NoorMetrics.quranSizeRange.upperBound),
                           step: 1) {
                        Text("Quran text size")
                    }
                    Text(verbatim: "\(Int(quranFontSize)) pt")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                }
                Button {
                    showReciterPicker = true
                } label: {
                    HStack {
                        Text("Reciter")
                            .foregroundStyle(NoorColor.inkPrimary)
                        Spacer()
                        Text(verbatim: (Reciter(rawValue: reciterRaw) ?? .alafasy).displayName(arabicUI: isArabicUI))
                            .foregroundStyle(NoorColor.inkSecondary)
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(NoorColor.inkSecondary.opacity(0.6))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .sheet(isPresented: $showReciterPicker) {
                    ReciterPickerSheet(selection: $reciterRaw, translationSelection: $translationVoiceRaw,
                                       isArabicUI: isArabicUI)
                        .environment(\.locale, locale)
                        .noorInterfaceDirection()
                }
                Picker(selection: $translationVoiceRaw) {
                    ForEach(TranslationVoice.allCases) { voice in
                        Text(verbatim: voice.displayName(arabicUI: isArabicUI)).tag(voice.rawValue)
                    }
                } label: {
                    Text("Translation audio")
                }
                // The tajweed guide moved to the learning area (Quran tab →
                // Learn). This pointer stays so existing users who learnt to
                // find it here are not left hunting; it opens the same
                // screen, one level in.
                NavigationLink(value: LearnRoute.home) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Learn")
                            .foregroundStyle(NoorColor.inkPrimary)
                        Text("Tajweed guide and memorisation texts — also in the Quran tab.")
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                }
                MushafDownloadRow()
                // WHETHER, then WHICH. The reader's options panel used to own
                // the on/off switch alone, so Settings showed a list of
                // editions with no way to tell — or say — that translations
                // were off at all.
                Toggle(isOn: Binding(
                    get: { showTranslation },
                    set: { on in
                        showTranslation = on
                        // A translation line is per-ayah furniture: the
                        // mushaf and Madani pages have nowhere to draw it, so
                        // switching it on takes the reader to ayah mode
                        // exactly as the reader's own toggle does. Without
                        // this, turning it on here would be another switch
                        // that appears to do nothing.
                        if on {
                            // The reader owns the single download (and now
                            // reports its progress inline), so nothing is
                            // fetched from here — a second store writing the
                            // same file would only race it.
                            readerMode = SurahReaderView.DisplayMode.ayah.rawValue
                        }
                    })) {
                    Text("Show translation")
                }
                .tint(NoorColor.accentPrimary)
                Picker(selection: $translationId) {
                    ForEach(TranslationStore.allEditions, id: \.id) { edition in
                        Text(verbatim: edition.displayName).tag(edition.id)
                    }
                } label: {
                    Text("Translation")
                }
            } header: {
                Text("Quran")
            }

            Section {
                // Marketing share: the bundled poster (QR + store links) with
                // the links as text — drops straight into a WhatsApp status.
                if let poster = Bundle.main.url(forResource: "share_noor", withExtension: "jpg") {
                    ShareLink(item: poster,
                              message: Text(verbatim: isArabicUI ? Self.shareTextAr : Self.shareTextEn)) {
                        Label("Share Noor", systemImage: "square.and.arrow.up")
                            .foregroundStyle(NoorColor.accentPrimary)
                    }
                }
            } footer: {
                Text("Send the app to family and friends — a poster with the store links, ready for a status.")
            }
            Section {
                Text(verbatim: "Quran text: Tanzil.net (Uthmani)")
                Text(verbatim: "Font: KFGQPC Uthmanic Hafs")
                Text(verbatim: "Translations: Saheeh International and Tanzil (mirror: fawazahmed0/quran-api)")
                Text(verbatim: "Tafsir: Ibn Kathir, Al-Muyassar (spa5k/tafsir_api)")
                Text(verbatim: "Recitations: EveryAyah.com")
                Text(verbatim: "Tajweed annotations: cpfair/quran-tajweed (CC BY 4.0)")
                Text(verbatim: "Prayer times: adhan-swift (Batoul Apps)")
                Text(verbatim: "Adhan sounds: Wikimedia Commons (CC BY 3.0 / CC BY-SA)")
            } header: {
                Text("About")
            } footer: {
                Text("Free forever — fi sabilillah. No ads, no tracking.")
            }
            .font(NoorFont.caption)
            .foregroundStyle(NoorColor.inkSecondary)
        }
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .sheet(isPresented: $showKidsAge) {
            KidsAgeSheet(
                age: kidsAge,
                onStart: { age in
                    kidsAge = KidsMode.clampAge(age)
                    // The recitation children learn from — applied on the
                    // FIRST enable only (kids.reciterApplied latches), so a
                    // parent's later choice survives disable/re-enable.
                    reciterRaw = KidsMode.reciterOnEnable(
                        current: reciterRaw, teaching: Reciter.husaryMuallim.rawValue)
                    kidsEnabled = true
                    showKidsAge = false
                },
                onCancel: { showKidsAge = false })
                .environment(\.locale, locale)
                .noorInterfaceDirection()
        }
        .sheet(isPresented: $showKidsGate) {
            ParentalGateView(
                onSuccess: {
                    kidsEnabled = false
                    showKidsGate = false
                },
                onCancel: { showKidsGate = false })
                .environment(\.locale, locale)
                .noorInterfaceDirection()
        }
        #if os(iOS)
        .navigationDestination(item: $pushedList) { list in
            switch list {
            case .language: LanguageChoiceList(selection: $language)
            case .appFont: AppFontChoiceList(selection: $uiFontRaw)
            }
        }
        #endif
        .navigationTitle(Text("Settings"))
        // The learning area is reachable from here too (see the Learn row).
        .learnDestinations { topic in
            switch topic {
            case .browse: TafsirBrowserView()
            case .wordMeanings: TafsirBrowserView(edition: .gharib)
            case .surah(let slug, let surah, let ayah):
                TafsirSurahView(surahId: surah, edition: TafsirEdition.named(slug),
                                isWordMeanings: slug == TafsirEdition.gharib.slug,
                                highlightAyah: ayah)
            }
        }
        .learnSearch(learnSearch)
        // Language is applied entirely via the SwiftUI environment in
        // RootView. Never touch AppleLanguages: a process launched in one
        // direction with the environment forcing the other renders mirrored.
    }
}

#if os(iOS)
/// One row of a pushed choice list: the option, drawn however it wants to be
/// drawn, plus a checkmark when it is the current one.
///
/// Hand-rolled because SwiftUI's `.pickerStyle(.navigationLink)` page cannot
/// render a styled row (see the comment in `SettingsView`'s first section).
/// `Button` + `.buttonStyle(.plain)` keeps the row's own colours instead of
/// tinting the whole label with the accent.
struct NoorChoiceListRow<Content: View>: View {
    let isSelected: Bool
    let select: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: select) {
            HStack(spacing: 12) {
                content
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NoorColor.accentPrimary)
                    .opacity(isSelected ? 1 : 0)
            }
            .frame(minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The interface-language list: every language written in its own language,
/// script and direction, because its reader may not understand a single
/// other word on the screen. Never localised, never in the string catalog.
struct LanguageChoiceList: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            NoorChoiceListRow(isSelected: NoorLanguage(rawValue: selection) == nil,
                              select: { choose(NoorLanguage.systemValue) }) {
                Text("System")
                    .foregroundStyle(NoorColor.inkPrimary)
            }
            ForEach(NoorLanguage.allCases, id: \.rawValue) { option in
                NoorChoiceListRow(isSelected: selection == option.rawValue,
                                  select: { choose(option.rawValue) }) {
                    Text(verbatim: option.endonym)
                        .font(NoorAppFont.font(showing: option))
                        .environment(\.layoutDirection, option.layoutDirection)
                        .foregroundStyle(NoorColor.inkPrimary)
                }
                .accessibilityLabel(Text(verbatim: option.endonym))
            }
        }
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Language"))
    }

    private func choose(_ value: String) {
        // Write first, dismiss second: the whole view tree is rebuilt on a
        // language change (RootView keys its identity on it), so this screen
        // is on its way out either way.
        selection = value
        dismiss()
    }
}

/// The interface-font list: five families, each previewing itself in both
/// scripts (see `AppFontRow`).
struct AppFontChoiceList: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(NoorAppFont.allCases, id: \.rawValue) { family in
                NoorChoiceListRow(isSelected: selection == family.rawValue,
                                  select: {
                                      selection = family.rawValue
                                      dismiss()
                                  }) {
                    AppFontRow(family: family)
                }
                .accessibilityLabel(Text(verbatim: family.displayName))
            }
        }
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("App font"))
    }
}
#endif

/// One row of the App-font picker, drawn in the family it offers so the
/// choice can be judged before it is made — in both scripts, since the app
/// is bilingual and several of these families are Arabic-first.
struct AppFontRow: View {
    let family: NoorAppFont

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Font names are proper nouns: `verbatim`, never localised.
            Text(verbatim: family.displayName)
                .font(family.scaled(17, weight: .medium))
            Text(verbatim: family.arabicSample)
                .font(family.scaled(15))
                .foregroundStyle(NoorColor.inkSecondary)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: family.displayName))
    }
}

#Preview {
    NavigationStack { SettingsView() }
}

#if os(iOS)
#Preview("Language list — AR RTL") {
    NavigationStack { LanguageChoiceList(selection: .constant("ar")) }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Language list — EN LTR") {
    NavigationStack { LanguageChoiceList(selection: .constant("system")) }
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)
}

#Preview("App font list — AR RTL") {
    NavigationStack { AppFontChoiceList(selection: .constant(NoorAppFont.cairo.rawValue)) }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}
#endif

#Preview("App font rows — EN LTR") {
    List {
        ForEach(NoorAppFont.allCases, id: \.rawValue) { AppFontRow(family: $0) }
    }
    .environment(\.locale, Locale(identifier: "en"))
    .environment(\.layoutDirection, .leftToRight)
}

#Preview("App font rows — AR RTL") {
    List {
        ForEach(NoorAppFont.allCases, id: \.rawValue) { AppFontRow(family: $0) }
    }
    .environment(\.locale, Locale(identifier: "ar"))
    .environment(\.layoutDirection, .rightToLeft)
}
