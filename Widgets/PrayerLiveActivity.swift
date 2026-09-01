import ActivityKit
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
                        .font(.system(size: 17, weight: .bold))
                    Text(verbatim: context.attributes.city)
                        .font(.system(size: 12))
                        .opacity(0.7)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    // Lock screen stays calm: minute-level countdown (the
                    // Dynamic Island keeps the precise seconds timer).
                    Text(context.state.time, style: .relative)
                        .font(.system(size: 22, weight: .bold).monospacedDigit())
                        .multilineTextAlignment(.trailing)
                    Text(context.state.time, style: .time)
                        .font(.system(size: 12).monospacedDigit())
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
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.time, countsDown: true)
                        .font(.system(size: 20, weight: .bold).monospacedDigit())
                        .frame(maxWidth: 90)
                        .environment(\.locale, context.attributes.isArabic ? Locale(identifier: "ar") : .current)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.time, style: .time)
                        .font(.system(size: 12).monospacedDigit())
                        .opacity(0.7)
                        .environment(\.locale, context.attributes.isArabic ? Locale(identifier: "ar") : .current)
                }
            } compactLeading: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(WidgetTheme.gold)
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.time, countsDown: true)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .frame(maxWidth: 52)
                    .environment(\.locale, context.attributes.isArabic ? Locale(identifier: "ar") : .current)
            } minimal: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(WidgetTheme.gold)
            }
        }
    }
}
