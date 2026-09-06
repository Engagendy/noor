import ActivityKit
import DesignSystem
import SwiftUI
import WidgetKit

/// Lock-screen / Dynamic Island countdown to the next prayer.
struct PrayerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NoorPrayerAttributes.self) { context in
            // Lock screen banner — follows the app language.
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(WidgetTheme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: context.state.prayerName)
                        .noorFont(size: 17, weight: .bold)
                    Text(verbatim: context.attributes.city)
                        .noorFont(size: 12)
                        .opacity(0.7)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    // Lock screen stays calm: minute-level countdown (the
                    // Dynamic Island keeps the precise seconds timer).
                    Text(context.state.time, style: .relative)
                        .noorFont(size: 22, weight: .bold, monospacedDigits: true)
                        .multilineTextAlignment(.trailing)
                    Text(context.state.time, style: .time)
                        .noorFont(size: 12, monospacedDigits: true)
                        .opacity(0.7)
                }
            }
            .padding(16)
            .foregroundStyle(WidgetTheme.darkInk)
            .environment(\.locale, context.attributes.isArabic ? Locale(identifier: "ar") : .current)
            .environment(\.layoutDirection, context.attributes.isArabic ? .rightToLeft : .leftToRight)
            .activityBackgroundTint(WidgetTheme.darkBG)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.stars.fill")
                            .foregroundStyle(WidgetTheme.gold)
                        Text(verbatim: context.state.prayerName)
                            .noorFont(size: 16, weight: .bold)
                            .environment(
                                \.locale,
                                context.attributes.isArabic
                                    ? Locale(identifier: "ar") : .current
                            )
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: countdownRange(to: context.state.time), countsDown: true)
                        .noorFont(size: 20, weight: .bold, monospacedDigits: true)
                        .frame(maxWidth: 90)
                        .environment(\.locale, context.attributes.isArabic ? Locale(identifier: "ar") : .current)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.time, style: .time)
                        .noorFont(size: 12, monospacedDigits: true)
                        .opacity(0.7)
                        .environment(\.locale, context.attributes.isArabic ? Locale(identifier: "ar") : .current)
                }
            } compactLeading: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(WidgetTheme.gold)
            } compactTrailing: {
                Text(timerInterval: countdownRange(to: context.state.time), countsDown: true)
                    .noorFont(size: 13, weight: .semibold, monospacedDigits: true)
                    .frame(maxWidth: 52)
                    .environment(\.locale, context.attributes.isArabic ? Locale(identifier: "ar") : .current)
            } minimal: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(WidgetTheme.gold)
            }
        }
    }
}

/// `ClosedRange` traps when lowerBound > upperBound, and the Dynamic Island
/// is re-rendered after the prayer time has passed (stale re-render, locale
/// or appearance change). Clamp so the timer bottoms out at 0:00 instead of
/// crashing the widget extension.
private func countdownRange(to time: Date) -> ClosedRange<Date> {
    let now = Date()
    return now...max(now, time)
}
