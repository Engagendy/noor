import Adhan
import DesignSystem
import SwiftUI

/// Prayer Times per design 1f: city line, week strip, vertical timeline with
/// the next prayer enlarged (countdown + notification-sound choice), and the
/// calculation-settings row. Updates minute-level, calmly.
public struct PrayerTimesView: View {
    @AppStorage("prayer.city") private var cityName = "Makkah"
    @AppStorage("prayer.useCustom") private var useCustomLocation = false
    @AppStorage("prayer.method") private var methodRaw = CalculationMethodChoice.moonsightingCommittee.rawValue
    @AppStorage("prayer.madhab") private var madhabRaw = MadhabChoice.shafi.rawValue
    @AppStorage("prayer.sound") private var soundRaw = AdhanSound.adhanShort.rawValue

    @State private var dayOffset = 0
    @State private var showSettings = false
    @State private var locationFetcher = OneShotLocationFetcher()

    public init() {}

    private var location: PrayerLocation {
        useCustomLocation ? PrayerLocation.current() : CityPreset.named(cityName).location
    }
    private var method: CalculationMethodChoice {
        CalculationMethodChoice(rawValue: methodRaw) ?? .moonsightingCommittee
    }
    private var madhab: MadhabChoice { MadhabChoice(rawValue: madhabRaw) ?? .shafi }

    public var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let shownDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: now) ?? now
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    cityLine
                    weekStrip(now: now)
                    if let day = PrayerDay.compute(location: location, method: method, madhab: madhab, date: shownDate) {
                        timeline(day: day, now: now, isToday: dayOffset == 0)
                    }
                    settingsRow
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .background(NoorColor.bgPrimary)
            .navigationTitle(Text("Prayer Times"))
        }
        .sheet(isPresented: $showSettings) { settingsSheet }
    }

    private var cityLine: some View {
        HStack(spacing: 6) {
            Image(systemName: useCustomLocation ? "location.fill" : "mappin.and.ellipse")
                .font(.system(size: 12))
            Text(useCustomLocation ? "\(location.label)" : "\(location.label) · manual")
                .font(NoorFont.caption)
        }
        .foregroundStyle(NoorColor.inkSecondary)
    }

    private func weekStrip(now: Date) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { offset in
                let date = Calendar.current.date(byAdding: .day, value: offset, to: now) ?? now
                let isSelected = offset == dayOffset
                VStack(spacing: 2) {
                    Text(date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.system(size: 12))
                    Text(date.formatted(.dateTime.day()))
                        .font(.system(size: 14, weight: isSelected ? .bold : .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? NoorColor.accentPrimary : Color.clear)
                )
                .foregroundStyle(isSelected ? NoorColor.bgPrimary : NoorColor.inkSecondary)
                .contentShape(Rectangle())
                .onTapGesture { dayOffset = offset }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func timeline(day: PrayerDay, now: Date, isToday: Bool) -> some View {
        let next = isToday ? day.next(at: now) : nil
        VStack(spacing: 0) {
            ForEach(day.entries) { entry in
                if entry.prayer == next?.prayer {
                    nextPrayerCard(entry, now: now)
                        .padding(.vertical, 8)
                } else {
                    let passed = isToday && entry.time <= now
                    HStack(spacing: 14) {
                        ZStack {
                            if passed {
                                Circle().fill(NoorColor.accentPrimary)
                            } else {
                                Circle().strokeBorder(NoorColor.inkSecondary.opacity(0.4), lineWidth: 1.5)
                            }
                        }
                        .frame(width: 10, height: 10)
                        Text(entry.name)
                            .font(.system(size: 16))
                            .foregroundStyle(NoorColor.inkPrimary)
                        Spacer()
                        Text(entry.time, format: timeFormat)
                            .font(.system(size: 15).monospacedDigit())
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                    .padding(.vertical, 13)
                    .padding(.horizontal, 4)
                    .opacity(passed ? 0.6 : 1)
                    .overlay(alignment: .top) {
                        Divider().opacity(0.4)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func nextPrayerCard(_ entry: PrayerDay.Entry, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle()
                    .fill(NoorColor.accentPrimary)
                    .frame(width: 10, height: 10)
                    .shadow(color: NoorColor.accentPrimary.opacity(0.4), radius: 4)
                Text(entry.name)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(NoorColor.inkPrimary)
                Text("next · \(entry.time, format: .relative(presentation: .numeric))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NoorColor.accentPrimary)
                Spacer()
                Text(entry.time, format: timeFormat)
                    .font(.system(size: 19, weight: .semibold).monospacedDigit())
                    .foregroundStyle(NoorColor.inkPrimary)
            }
            soundChips
        }
        .padding(18)
        .noorCard()
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(NoorColor.accentPrimary.opacity(0.35), lineWidth: 1)
        )
    }

    /// Sound choice is stored now and honored when adhan notifications land.
    private var soundChips: some View {
        HStack(spacing: 8) {
            ForEach(AdhanSound.allCases) { sound in
                let isOn = soundRaw == sound.rawValue
                Text(sound.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(isOn ? NoorColor.stateReciting : Color.clear)
                    )
                    .overlay(
                        Capsule().stroke(
                            isOn ? NoorColor.accentPrimary.opacity(0.5) : NoorColor.inkSecondary.opacity(0.25),
                            lineWidth: 1)
                    )
                    .foregroundStyle(isOn ? NoorColor.accentPrimary : NoorColor.inkSecondary)
                    .contentShape(Capsule())
                    .onTapGesture { soundRaw = sound.rawValue }
                    .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private var settingsRow: some View {
        Button {
            showSettings = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                Text("\(String(localized: method.displayName)) · \(String(localized: madhab.displayName))")
                    .font(NoorFont.caption)
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(NoorColor.inkSecondary)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { Divider().opacity(0.4) }
    }

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Button {
                    Task {
                        if let coordinate = await locationFetcher.fetch() {
                            PrayerLocation.saveCustom(
                                latitude: coordinate.latitude, longitude: coordinate.longitude)
                            useCustomLocation = true
                        }
                    }
                } label: {
                    Label(useCustomLocation ? "Using current location" : "Use my current location",
                          systemImage: useCustomLocation ? "location.fill" : "location")
                }
                Picker(selection: $cityName) {
                    ForEach(CityPreset.all) { preset in
                        Text(preset.name).tag(preset.name)
                    }
                } label: {
                    Text("City")
                }
                Picker(selection: $methodRaw) {
                    ForEach(CalculationMethodChoice.allCases) { choice in
                        Text(choice.displayName).tag(choice.rawValue)
                    }
                } label: {
                    Text("Calculation method")
                }
                Picker(selection: $madhabRaw) {
                    ForEach(MadhabChoice.allCases) { choice in
                        Text(choice.displayName).tag(choice.rawValue)
                    }
                } label: {
                    Text("Asr madhab")
                }
            }
            .navigationTitle(Text("Prayer Settings"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSettings = false }
                }
            }
            .onChange(of: cityName) {
                // Picking a city switches back to manual mode.
                PrayerLocation.clearCustom()
                useCustomLocation = false
            }
        }
        .presentationDetents([.medium])
    }

    /// Times shown in the selected location's time zone, not the device's.
    private var timeFormat: Date.FormatStyle {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = TimeZone(identifier: location.timeZoneIdentifier) ?? .current
        return style
    }
}

public enum AdhanSound: String, CaseIterable, Identifiable {
    case adhanShort, bell, silent

    public var id: String { rawValue }
    public var displayName: LocalizedStringResource {
        switch self {
        case .adhanShort: "Adhan (short)"
        case .bell: "Bell"
        case .silent: "Silent"
        }
    }
}

#Preview {
    NavigationStack { PrayerTimesView() }
}

#Preview("Tahajjud dark") {
    NavigationStack { PrayerTimesView() }
        .preferredColorScheme(.dark)
}
