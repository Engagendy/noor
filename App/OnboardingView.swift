import DesignSystem
import Notifications
import PrayerTimes
import SwiftUI

/// First-run welcome: language → city → adhan notifications. Thirty
/// seconds, skippable, never shown again.
struct OnboardingView: View {
    @AppStorage("app.language") private var language = "system"
    @AppStorage("notifications.enabled") private var notificationsEnabled = false
    @Binding var done: Bool

    @State private var step = 0

    /// The language the onboarding itself is shown in — the stored choice,
    /// or the device's if nothing is stored yet. First-run text is in the
    /// string catalog like everything else now, so this only has to supply
    /// the locale and the direction.
    private var resolved: NoorLanguage { NoorLanguage.resolve(language) }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 14) {
                MihrabLogoMark(size: 64,
                               archColor: NoorColor.accentPrimary,
                               lampColor: NoorColor.accentGold)
                Text("Welcome to Noor")
                    .font(.noorScaled(24, weight: .bold))
                    .foregroundStyle(NoorColor.inkPrimary)
                Text("Quran, prayer times, and athkar — private and free forever")
                    .font(.noorScaled(14))
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
            // The CARDS are re-identified on the language, not the whole
            // screen: the city picker is a `List` inside a `NavigationStack`
            // and the UIKit views underneath them keep the writing direction
            // they were built with, so an `\.environment` flip alone leaves
            // an English screen laid out right-to-left. `step` lives outside
            // this id (in OnboardingView itself), so the reader stays on the
            // card they were reading and the TabView takes the selection
            // back from the binding.
            .id(resolved.rawValue)

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
        // Not `noorInterfaceDirection()`: onboarding runs BEFORE anything
        // is stored, so it follows its own resolved choice, live, as the
        // reader taps through the ten cards.
        .environment(\.layoutDirection, resolved.layoutDirection)
        .environment(\.locale, resolved.locale)
    }

    // Step 1 — language
    private var languageStep: some View {
        VStack(spacing: 16) {
            stepTitle(Text("App language"))
            // Ten languages, each written in its own language and script —
            // this is the one screen whose reader may not understand a
            // single other word on it. It scrolls, because ten cards of a
            // 44pt-plus target do not fit a small phone.
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)],
                          spacing: 12) {
                    ForEach(NoorLanguage.allCases, id: \.rawValue) { option in
                        languageChoice(option)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollBounceBehavior(.basedOnSize)
            primaryButton(Text("Continue")) { step = 1 }
        }
        .padding(24)
    }

    private func languageChoice(_ option: NoorLanguage) -> some View {
        let isOn = resolved == option
        return Button {
            language = option.rawValue
            // The app shell re-identifies itself on this key and rebuilds,
            // but onboarding is deliberately outside that (RootView) so the
            // reader does not lose their place — so it refreshes the
            // imperative caches itself. The face and the direction have to
            // land on this very frame: this screen exists to change them.
            NoorAppFont.invalidateCache()
            NoorLanguage.invalidateCache()
            NoorAppFont.applyChromeAppearance()
        } label: {
            Text(verbatim: option.endonym)
                .font(NoorAppFont.font(showing: option, size: 18, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .environment(\.layoutDirection, option.layoutDirection)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(RoundedRectangle(cornerRadius: 14)
                    .fill(isOn ? NoorColor.accentPrimary : NoorColor.bgElevated))
                .foregroundStyle(isOn ? NoorColor.bgPrimary : NoorColor.inkPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: option.endonym))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    // Step 2 — city: the same offline database picker as Settings, kept
    // on the page (no dismiss) so the checkmark and Continue stay visible.
    private var cityStep: some View {
        VStack(spacing: 12) {
            stepTitle(Text("Your city for prayer times"))
            NavigationStack {
                CityPickerView(dismissOnSelect: false)
                    #if os(iOS)
                    .toolbar(.hidden, for: .navigationBar)
                    #endif
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            primaryButton(Text("Continue")) { step = 2 }
        }
        .padding(24)
    }

    // Step 3 — notifications
    private var notificationsStep: some View {
        VStack(spacing: 16) {
            Spacer()
            stepTitle(Text("Adhan notifications"))
            Text("A beautiful adhan at every prayer. You can change or silence it anytime.")
                .font(.noorScaled(14))
                .foregroundStyle(NoorColor.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            Spacer()
            // Grants notification permission and turns adhan notifications
            // ON. It plays nothing — every translation must say "turn on",
            // never "play".
            primaryButton(Text("Enable adhan")) {
                Task {
                    let granted = await AdhanNotificationScheduler().requestAuthorization()
                    notificationsEnabled = granted
                    done = true
                }
            }
            Button {
                done = true
            } label: {
                Text("Maybe later")
                    .font(.noorScaled(15))
                    .foregroundStyle(NoorColor.inkSecondary)
                    .frame(height: 40)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }

    private func stepTitle(_ title: Text) -> some View {
        title
            .font(.noorScaled(18, weight: .semibold))
            .foregroundStyle(NoorColor.inkPrimary)
            .multilineTextAlignment(.center)
    }

    private func primaryButton(_ title: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            title
                .font(.noorScaled(16, weight: .semibold))
                .foregroundStyle(NoorColor.bgPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 14).fill(NoorColor.accentPrimary))
        }
        .buttonStyle(.plain)
    }
}
