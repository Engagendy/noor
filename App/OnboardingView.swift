import DesignSystem
import Notifications
import PrayerTimes
import SwiftUI

/// First-run welcome: language → city → adhan notifications. Thirty
/// seconds, skippable, never shown again.
struct OnboardingView: View {
    @AppStorage("app.language") private var language = "system"
    @AppStorage("prayer.city") private var cityName = "Makkah"
    @AppStorage("notifications.enabled") private var notificationsEnabled = false
    @Binding var done: Bool

    @State private var step = 0
    @State private var citySearch = ""

    private var isArabicUI: Bool {
        language == "ar" || (language == "system"
            && Locale.current.language.languageCode?.identifier == "ar")
    }

    private var filteredCities: [CityPreset] {
        let query = citySearch.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return CityPreset.all }
        return CityPreset.all.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.nameArabic.contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 14) {
                MihrabLogoMark(size: 64,
                               archColor: NoorColor.accentPrimary,
                               lampColor: NoorColor.accentGold)
                Text(verbatim: isArabicUI ? "أهلًا بك في نور" : "Welcome to Noor")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(NoorColor.inkPrimary)
                Text(verbatim: isArabicUI
                     ? "القرآن ومواقيت الصلاة والأذكار — خاص ومجاني للأبد"
                     : "Quran, prayer times, and athkar — private and free forever")
                    .font(.system(size: 14))
                    .foregroundStyle(NoorColor.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.horizontal, 28)

            // Steps
            TabView(selection: $step) {
                languageStep.tag(0)
                cityStep.tag(1)
                notificationsStep.tag(2)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .animation(.easeInOut(duration: 0.3), value: step)

            // Progress dots
            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index == step ? NoorColor.accentPrimary : NoorColor.inkSecondary.opacity(0.25))
                        .frame(width: index == step ? 8 : 6, height: index == step ? 8 : 6)
                }
            }
            .padding(.bottom, 22)
        }
        .background(NoorColor.bgPrimary)
        .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
        .environment(\.locale, isArabicUI ? Locale(identifier: "ar") : .current)
    }

    // Step 1 — language
    private var languageStep: some View {
        VStack(spacing: 16) {
            Spacer()
            stepTitle(isArabicUI ? "لغة التطبيق" : "App language")
            HStack(spacing: 12) {
                languageChoice(title: "العربية", value: "ar")
                languageChoice(title: "English", value: "en")
            }
            Spacer()
            primaryButton(isArabicUI ? "متابعة" : "Continue") { step = 1 }
        }
        .padding(24)
    }

    private func languageChoice(title: String, value: String) -> some View {
        let isOn = language == value
            || (language == "system"
                && Locale.current.language.languageCode?.identifier == value)
        return Button {
            language = value
        } label: {
            Text(verbatim: title)
                .font(.system(size: 18, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(RoundedRectangle(cornerRadius: 14)
                    .fill(isOn ? NoorColor.accentPrimary : NoorColor.bgElevated))
                .foregroundStyle(isOn ? NoorColor.bgPrimary : NoorColor.inkPrimary)
        }
        .buttonStyle(.plain)
    }

    // Step 2 — city
    private var cityStep: some View {
        VStack(spacing: 12) {
            stepTitle(isArabicUI ? "مدينتك لمواقيت الصلاة" : "Your city for prayer times")
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(NoorColor.inkSecondary)
                TextField("", text: $citySearch)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.leading)
                    .overlay(alignment: .leading) {
                        if citySearch.isEmpty {
                            Text(verbatim: isArabicUI ? "ابحث عن مدينتك" : "Search your city")
                                .foregroundStyle(NoorColor.inkSecondary.opacity(0.7))
                                .allowsHitTesting(false)
                        }
                    }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(NoorColor.bgElevated))
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredCities, id: \.name) { city in
                        Button {
                            cityName = city.name
                        } label: {
                            HStack {
                                Text(verbatim: isArabicUI ? city.nameArabic : city.name)
                                    .font(.system(size: 15, weight: cityName == city.name ? .semibold : .regular))
                                    .foregroundStyle(NoorColor.inkPrimary)
                                Spacer()
                                if cityName == city.name {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(NoorColor.accentPrimary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            primaryButton(isArabicUI ? "متابعة" : "Continue") { step = 2 }
        }
        .padding(24)
    }

    // Step 3 — notifications
    private var notificationsStep: some View {
        VStack(spacing: 16) {
            Spacer()
            stepTitle(isArabicUI ? "تنبيهات الأذان" : "Adhan notifications")
            Text(verbatim: isArabicUI
                 ? "أذان جميل عند كل صلاة. يمكنك تغيير الصوت أو إيقافه لاحقًا."
                 : "A beautiful adhan at every prayer. You can change or silence it anytime.")
                .font(.system(size: 14))
                .foregroundStyle(NoorColor.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            Spacer()
            primaryButton(isArabicUI ? "تفعيل الأذان" : "Enable adhan") {
                Task {
                    let granted = await AdhanNotificationScheduler().requestAuthorization()
                    notificationsEnabled = granted
                    done = true
                }
            }
            Button {
                done = true
            } label: {
                Text(verbatim: isArabicUI ? "لاحقًا" : "Maybe later")
                    .font(.system(size: 15))
                    .foregroundStyle(NoorColor.inkSecondary)
                    .frame(height: 40)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }

    private func stepTitle(_ title: String) -> some View {
        Text(verbatim: title)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(NoorColor.inkPrimary)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NoorColor.bgPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 14).fill(NoorColor.accentPrimary))
        }
        .buttonStyle(.plain)
    }
}
