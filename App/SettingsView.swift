import DesignSystem
import PrayerTimes
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
    @AppStorage("notifications.enabled") private var notificationsEnabled = false
    @AppStorage("prayer.sound") private var soundRaw = AdhanSound.adhanShort.rawValue
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
                Picker(selection: $soundRaw) {
                    ForEach(AdhanSound.allCases) { sound in
                        Text(sound.displayName).tag(sound.rawValue)
                    }
                } label: {
                    Text("Notification sound")
                }
            } header: {
                Text("Prayer")
            } footer: {
                Text("Notifications are scheduled on your device for the next 12 days and roll forward automatically. Toggle individual prayers with the bell on the Prayer screen. Authentic adhan audio clips arrive once licensing is confirmed.")
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
                Picker(selection: $reciterRaw) {
                    ForEach(Reciter.allCases) { reciter in
                        Text(verbatim: reciter.displayName(arabicUI: isArabicUI)).tag(reciter.rawValue)
                    }
                } label: {
                    Text("Reciter")
                }
                NavigationLink {
                    TajweedGuideView()
                } label: {
                    Text("Tajweed Guide")
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
        .onChange(of: language) { _, newValue in
            // Keep system-level strings in sync for the next cold launch;
            // the UI itself switches immediately via RootView's locale.
            switch newValue {
            case "system": UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            case "ar": UserDefaults.standard.set(["ar"], forKey: "AppleLanguages")
            default: UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
            }
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
