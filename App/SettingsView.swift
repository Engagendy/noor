import DesignSystem
import PrayerTimes
import Translations
import QuranAudio
import QuranReader
import SwiftUI

struct SettingsView: View {
    /// "system" | "en" | "ar" — applied live via the locale environment,
    /// and to AppleLanguages so system-provided strings follow on relaunch.
    @AppStorage("app.language") private var language = "system"
    /// "system" | "light" | "dark"
    @AppStorage("app.theme") private var theme = "system"
    @AppStorage("reader.fontSize") private var quranFontSize = 26.0
    @AppStorage("reader.mode") private var readerMode = "mushaf"
    @AppStorage("audio.reciter") private var reciterRaw = Reciter.alafasy.rawValue
    @AppStorage("translation.id") private var translationId = "en.sahih"
    @State private var showReciterPicker = false
    @State private var showAdhanSounds = false
    @State private var showZakat = false
    @AppStorage("notifications.enabled") private var notificationsEnabled = false
    @AppStorage("fasting.reminders") private var fastingReminders = false
    @AppStorage("prayer.sound") private var soundRaw = AdhanSound.adhanMadinah.rawValue
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    var body: some View {
        Form {
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
            }

            Section {
                Toggle(isOn: $notificationsEnabled) {
                    Text("Adhan notifications")
                }
                Toggle(isOn: $fastingReminders) {
                    Text("Sunnah fasting reminders")
                }
                Button {
                    showAdhanSounds = true
                } label: {
                    HStack {
                        Text("Notification sound")
                            .foregroundStyle(NoorColor.inkPrimary)
                        Spacer()
                        Text((AdhanSound(rawValue: soundRaw) ?? .adhanMadinah).displayName)
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
                    ReciterPickerSheet(selection: $reciterRaw, isArabicUI: isArabicUI)
                        .environment(\.locale, locale)
                        .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
                }
                NavigationLink {
                    TajweedGuideView()
                } label: {
                    Text("Tajweed Guide")
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
                Text(verbatim: "Quran text: Tanzil.net (Uthmani)")
                Text(verbatim: "Font: KFGQPC Uthmanic Hafs")
                Text(verbatim: "Translation: Saheeh International (Tanzil)")
                Text(verbatim: "Tafsir: Ibn Kathir, Al-Muyassar (spa5k/tafsir_api)")
                Text(verbatim: "Recitations: EveryAyah.com")
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
        .navigationTitle(Text("Settings"))
        // Language is applied entirely via the SwiftUI environment in
        // RootView. Never touch AppleLanguages: a process launched in one
        // direction with the environment forcing the other renders mirrored.
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
