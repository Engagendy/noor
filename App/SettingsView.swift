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
    /// "system" | "en" | "ar" — applied live via the locale environment,
    /// and to AppleLanguages so system-provided strings follow on relaunch.
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
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

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
                Picker(selection: $language) {
                    Text("System").tag("system")
                    Text(verbatim: "English").tag("en")
                    Text(verbatim: "العربية").tag("ar")
                } label: {
                    Text("Language")
                }
                Picker(selection: $theme) {
                    Text("System").tag("system")
                    Text("Light (Mushaf)").tag("light")
                    Text("Dark (Tahajjud)").tag("dark")
                } label: {
                    Text("Appearance")
                }
                Picker(selection: $uiFontRaw) {
                    ForEach(NoorAppFont.allCases, id: \.rawValue) { family in
                        AppFontRow(family: family)
                            .tag(family.rawValue)
                    }
                } label: {
                    Text("App font")
                }
                // Five families, each previewing itself, so on iOS the picker
                // must push to a full list rather than collapse to a menu.
                // `.navigationLink` is iOS-only; macOS keeps the default
                // (a pop-up menu), which is the native idiom there anyway.
                #if os(iOS)
                .pickerStyle(.navigationLink)
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
                        .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
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
                        .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
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
                        .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
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
                Text(verbatim: "Translation: Saheeh International (Tanzil)")
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
                .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
        }
        .sheet(isPresented: $showKidsGate) {
            ParentalGateView(
                onSuccess: {
                    kidsEnabled = false
                    showKidsGate = false
                },
                onCancel: { showKidsGate = false })
                .environment(\.locale, locale)
                .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
        }
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
