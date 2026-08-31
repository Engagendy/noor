import DesignSystem
import SwiftUI

struct SettingsView: View {
    /// "system" | "en" | "ar" — applied via AppleLanguages, needs relaunch.
    @AppStorage("app.language") private var language = "system"
    @AppStorage("reader.fontSize") private var quranFontSize = 26.0
    @AppStorage("reader.mode") private var readerMode = "mushaf"
    @AppStorage("notifications.enabled") private var notificationsEnabled = false
    @State private var showRestartNote = false

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
                if showRestartNote {
                    Text("Restart Noor to apply the language change.")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.accentPrimary)
                }
            }

            Section {
                Toggle(isOn: $notificationsEnabled) {
                    Text("Adhan notifications")
                }
            } header: {
                Text("Prayer")
            } footer: {
                Text("Notifications are scheduled on your device for the next 12 days and roll forward automatically.")
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
            } header: {
                Text("Quran")
            }

            Section {
                Text(verbatim: "Quran text: Tanzil.net (Uthmani)")
                Text(verbatim: "Font: KFGQPC Uthmanic Hafs")
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
            switch newValue {
            case "system":
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            case "ar":
                UserDefaults.standard.set(["ar"], forKey: "AppleLanguages")
            default:
                UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
            }
            showRestartNote = true
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
