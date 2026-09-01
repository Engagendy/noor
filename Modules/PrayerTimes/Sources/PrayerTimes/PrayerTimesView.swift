import Adhan
import DesignSystem
import AVFoundation
import SwiftUI

/// Prayer Times per design 1f: city line, week strip, vertical timeline with
/// the next prayer enlarged (countdown + notification-sound choice), and the
/// calculation-settings row. Updates minute-level, calmly.
public struct PrayerTimesView: View {
    @AppStorage("prayer.city") private var cityName = "Makkah"
    @AppStorage("prayer.useCustom") private var useCustomLocation = false
    @AppStorage("prayer.method") private var methodRaw = CalculationMethodChoice.moonsightingCommittee.rawValue
    @AppStorage("prayer.madhab") private var madhabRaw = MadhabChoice.shafi.rawValue
    @AppStorage("prayer.sound") private var soundRaw = AdhanSound.adhanMadinah.rawValue

    // Per-prayer notification toggles (design 6.4: inline on the timeline).
    @AppStorage("notif.fajr") private var notifFajr = true
    @AppStorage("notif.dhuhr") private var notifDhuhr = true
    @AppStorage("notif.asr") private var notifAsr = true
    @AppStorage("notif.maghrib") private var notifMaghrib = true
    @AppStorage("notif.isha") private var notifIsha = true

    @State private var dayOffset = 0
    @State private var showSettings = false
    @State private var showNawafil = false
    @State private var showAdhanSounds = false
    @AppStorage("prayer.prealert") private var preAlertMinutes = 0
    @AppStorage("prayer.adj.fajr") private var adjFajr = 0
    @AppStorage("prayer.adj.dhuhr") private var adjDhuhr = 0
    @AppStorage("prayer.adj.asr") private var adjAsr = 0
    @AppStorage("prayer.adj.maghrib") private var adjMaghrib = 0
    @AppStorage("prayer.adj.isha") private var adjIsha = 0
    @AppStorage("liveactivity.on") private var liveActivityOn = false
    @State private var locationFetcher = OneShotLocationFetcher()
    @State private var fetchingLocation = false
    @State private var locationFailed = false
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var appDirection

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    private func notificationBinding(for prayer: Prayer) -> Binding<Bool>? {
        switch prayer {
        case .fajr: $notifFajr
        case .dhuhr: $notifDhuhr
        case .asr: $notifAsr
        case .maghrib: $notifMaghrib
        case .isha: $notifIsha
        default: nil
        }
    }

    private func bellToggle(for prayer: Prayer) -> some View {
        Group {
            if let binding = notificationBinding(for: prayer) {
                Button {
                    binding.wrappedValue.toggle()
                } label: {
                    Image(systemName: binding.wrappedValue ? "bell" : "bell.slash")
                        .font(.system(size: 15))
                        .foregroundStyle(binding.wrappedValue ? NoorColor.accentPrimary : NoorColor.inkSecondary.opacity(0.5))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Notification")
                .accessibilityAddTraits(binding.wrappedValue ? .isSelected : [])
            }
        }
    }

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
                    liveActivityRow
                    adhanSoundRow
                    nawafilRow
                    settingsRow
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .background(NoorColor.bgPrimary)
            .navigationTitle(Text("Prayer Times"))
        }
        .sheet(isPresented: $showSettings) {
            // Presentations don't inherit layout direction — re-apply.
            settingsSheet
                .environment(\.locale, locale)
                .environment(\.layoutDirection, appDirection)
        }
        // Hear the adhan whenever the choice changes, wherever it was made.
        .onChange(of: soundRaw) {
            AdhanPreviewPlayer.shared.play(AdhanSound(rawValue: soundRaw) ?? .adhanMadinah)
        }
        .onDisappear { AdhanPreviewPlayer.shared.stop() }
        .sheet(isPresented: $showAdhanSounds) {
            AdhanSoundPickerView(soundRaw: $soundRaw)
                .environment(\.locale, locale)
                .environment(\.layoutDirection, appDirection)
        }
        .sheet(isPresented: $showNawafil) {
            NawafilView(isArabicUI: isArabicUI)
                .environment(\.locale, locale)
                .environment(\.layoutDirection, appDirection)
        }
    }

    private var cityLine: some View {
        HStack(spacing: 6) {
            Image(systemName: useCustomLocation ? "location.fill" : "mappin.and.ellipse")
                .font(.system(size: 12))
            Group {
                if useCustomLocation {
                    Text("Near \(CityPreset.named(location.label).displayName(arabicUI: isArabicUI))")
                } else {
                    Text(verbatim: "\(CityPreset.named(cityName).displayName(arabicUI: isArabicUI))")
                }
            }
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
                    Text(date.formatted(.dateTime.weekday(.abbreviated).locale(locale)))
                        .font(.system(size: 12))
                    Text(date.formatted(.dateTime.day().locale(locale)))
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
                        bellToggle(for: entry.prayer)
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
                bellToggle(for: entry.prayer)
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

    /// Sound choice is stored now and honored when adhan notifications
    /// land. Tapping a chip also plays a preview so you choose by ear.
    private var soundChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AdhanSound.allCases) { sound in
                    let isOn = soundRaw == sound.rawValue
                    HStack(spacing: 5) {
                        if sound.fileName != nil {
                            Image(systemName: "speaker.wave.2")
                                .font(.system(size: 10))
                        }
                        Text(sound.displayName)
                    }
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
                    .onTapGesture {
                        soundRaw = sound.rawValue
                        AdhanPreviewPlayer.shared.play(sound)
                    }
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
        .onDisappear { AdhanPreviewPlayer.shared.stop() }
    }

    /// Always-visible entry to the adhan sound picker (the inline chips
    /// only exist on the next-prayer card, which vanishes after Isha).
    /// Live Activity: countdown on the lock screen / Dynamic Island.
    /// The activity targets the next prayer; refreshed on each start.
    @ViewBuilder
    private var liveActivityRow: some View {
        #if os(iOS)
        Button {
            NotificationCenter.default.post(name: .noorToggleLiveActivity, object: nil)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: liveActivityOn ? "clock.badge.checkmark" : "clock.badge")
                    .font(.system(size: 15))
                    .foregroundStyle(liveActivityOn ? NoorColor.accentGold : NoorColor.accentPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live countdown")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NoorColor.inkPrimary)
                    Text(liveActivityOn ? "Active — tap to turn off"
                                        : "Live countdown to the next prayer")
                        .font(NoorFont.caption)
                        .foregroundStyle(liveActivityOn ? NoorColor.accentGold : NoorColor.inkSecondary)
                }
                Spacer()
                Toggle("", isOn: .constant(liveActivityOn))
                    .labelsHidden()
                    .allowsHitTesting(false)
                    .tint(NoorColor.accentPrimary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .noorCard()
        #endif
    }

    private var adhanSoundRow: some View {
        Button {
            showAdhanSounds = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 15))
                    .foregroundStyle(NoorColor.accentPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Adhan sound")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NoorColor.inkPrimary)
                    Text((AdhanSound(rawValue: soundRaw) ?? .adhanMadinah).displayName)
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NoorColor.inkSecondary.opacity(0.6))
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .noorCard()
    }

    /// Voluntary prayers reference (rawatib, duha, qiyam, witr).
    private var nawafilRow: some View {
        Button {
            showNawafil = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 15))
                    .foregroundStyle(NoorColor.accentGold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nawafil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NoorColor.inkPrimary)
                    Text("Voluntary prayers and their times")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NoorColor.inkSecondary.opacity(0.6))
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .noorCard()
    }

    private var settingsRow: some View {
        Button {
            showSettings = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                    .font(.system(size: 15))
                    .foregroundStyle(NoorColor.accentPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Prayer settings")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NoorColor.inkPrimary)
                    Text("\(String(localized: method.displayName)) · \(String(localized: madhab.displayName))")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NoorColor.inkSecondary.opacity(0.6))
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { Divider().opacity(0.4) }
    }

    private func adjustmentStepper(_ title: LocalizedStringKey,
                                   value: Binding<Int>) -> some View {
        Stepper(value: value, in: -30...30) {
            HStack {
                Text(title)
                Spacer()
                Text(verbatim: value.wrappedValue > 0 ? "+\(value.wrappedValue)" : "\(value.wrappedValue)")
                    .foregroundStyle(value.wrappedValue == 0 ? NoorColor.inkSecondary : NoorColor.accentPrimary)
                    .monospacedDigit()
            }
        }
    }

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Button {
                    fetchingLocation = true
                    Task {
                        defer { fetchingLocation = false }
                        if let coordinate = await locationFetcher.fetch() {
                            let nearest = CityPreset.nearest(
                                latitude: coordinate.latitude, longitude: coordinate.longitude)
                            PrayerLocation.saveCustom(
                                latitude: coordinate.latitude,
                                longitude: coordinate.longitude,
                                label: nearest.name)
                            cityName = nearest.name
                            useCustomLocation = true
                        } else {
                            locationFailed = true
                        }
                    }
                } label: {
                    HStack {
                        Label(useCustomLocation ? "Using current location" : "Use my current location",
                              systemImage: useCustomLocation ? "location.fill" : "location")
                        if fetchingLocation {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(fetchingLocation)
                Section {
                    Picker(selection: $preAlertMinutes) {
                        Text("Off").tag(0)
                        Text(verbatim: "5").tag(5)
                        Text(verbatim: "10").tag(10)
                        Text(verbatim: "15").tag(15)
                        Text(verbatim: "30").tag(30)
                    } label: {
                        Text("Alert before prayer (minutes)")
                    }
                } footer: {
                    Text("A gentle reminder before each adhan — time for wudu and the walk to the masjid.")
                }

                Section {
                    adjustmentStepper("Fajr", value: $adjFajr)
                    adjustmentStepper("Dhuhr", value: $adjDhuhr)
                    adjustmentStepper("Asr", value: $adjAsr)
                    adjustmentStepper("Maghrib", value: $adjMaghrib)
                    adjustmentStepper("Isha", value: $adjIsha)
                } header: {
                    Text("Manual adjustments (minutes)")
                } footer: {
                    Text("Match your local masjid exactly. Applies everywhere: timeline, widgets, and notifications.")
                }

                NavigationLink {
                    CityPickerView(cityName: $cityName)
                } label: {
                    HStack {
                        Text("City")
                        Spacer()
                        Text(verbatim: CityPreset.named(cityName).name)
                            .foregroundStyle(.secondary)
                    }
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
            .alert(Text("Couldn't get your location"), isPresented: $locationFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Allow location access in Settings, or pick a city manually.")
            }
        }
        // The sheet grew (pre-alerts + manual adjustments): open at medium,
        // pull up to full height.
        .presentationDetents([.medium, .large])
    }

    /// Times shown in the selected location's time zone, not the device's.
    private var timeFormat: Date.FormatStyle {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = TimeZone(identifier: location.timeZoneIdentifier) ?? .current
        return style
    }
}

public enum AdhanSound: String, CaseIterable, Identifiable {
    case adhanMadinah, adhanMelodic, adhanAzeez, bell, silent

    public var id: String { rawValue }
    public var displayName: LocalizedStringResource {
        switch self {
        case .adhanMadinah: "Adhan (Madinah)"
        case .adhanMelodic: "Adhan (melodic)"
        case .adhanAzeez: "Adhan (Azeez)"
        case .bell: "Bell"
        case .silent: "Silent"
        }
    }

    /// Bundled notification sound file (≤30s, caf); nil = system/none.
    public var fileName: String? {
        switch self {
        case .adhanMadinah: "adhan_madinah.caf"
        case .adhanMelodic: "adhan_melodic.caf"
        case .adhanAzeez: "adhan_azeez.caf"
        case .bell, .silent: nil
        }
    }
}

/// Per-prayer notification enablement, stored in UserDefaults
/// ("notif.fajr" … "notif.isha", default on).
public enum PrayerNotificationPrefs {
    public static let keys: [Prayer: String] = [
        .fajr: "notif.fajr", .dhuhr: "notif.dhuhr", .asr: "notif.asr",
        .maghrib: "notif.maghrib", .isha: "notif.isha",
    ]

    public static func isEnabled(_ prayer: Prayer, defaults: UserDefaults = .standard) -> Bool {
        guard let key = keys[prayer] else { return false }
        return defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
    }

    public static func setEnabled(_ enabled: Bool, for prayer: Prayer, defaults: UserDefaults = .standard) {
        guard let key = keys[prayer] else { return }
        defaults.set(enabled, forKey: key)
    }

    public static func enabledPrayers(defaults: UserDefaults = .standard) -> Set<Prayer> {
        Set(keys.keys.filter { isEnabled($0, defaults: defaults) })
    }
}

#Preview {
    NavigationStack { PrayerTimesView() }
}

#Preview("Tahajjud dark") {
    NavigationStack { PrayerTimesView() }
        .preferredColorScheme(.dark)
}


/// Plays a bundled adhan clip when a sound chip is tapped, so the choice
/// can be made by ear. Stops when the screen goes away.
@MainActor
final class AdhanPreviewPlayer {
    static let shared = AdhanPreviewPlayer()
    private var player: AVAudioPlayer?

    func play(_ sound: AdhanSound) {
        stop()
        guard let file = sound.fileName,
              let url = Bundle.main.url(forResource: (file as NSString).deletingPathExtension,
                                        withExtension: (file as NSString).pathExtension)
        else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        #endif
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }
}


/// Adhan sound list: tapping a row selects it AND plays it immediately.
public struct AdhanSoundPickerView: View {
    @Binding var soundRaw: String
    @Environment(\.dismiss) private var dismiss

    public init(soundRaw: Binding<String>) {
        _soundRaw = soundRaw
    }

    public var body: some View {
        NavigationStack {
            List(AdhanSound.allCases) { sound in
                let isOn = soundRaw == sound.rawValue
                Button {
                    soundRaw = sound.rawValue
                    AdhanPreviewPlayer.shared.play(sound)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: sound.fileName != nil ? "play.circle.fill"
                              : sound == .bell ? "bell" : "bell.slash")
                            .font(.system(size: 22))
                            .foregroundStyle(sound.fileName != nil
                                             ? NoorColor.accentPrimary : NoorColor.inkSecondary)
                        Text(sound.displayName)
                            .font(.system(size: 16, weight: isOn ? .semibold : .regular))
                            .foregroundStyle(NoorColor.inkPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if isOn {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(NoorColor.accentPrimary)
                        }
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(NoorColor.bgPrimary)
            .safeAreaInset(edge: .top) {
                Text("Tap a sound to hear it")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(NoorColor.bgPrimary)
            }
            .navigationTitle(Text("Adhan sound"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        AdhanPreviewPlayer.shared.stop()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onDisappear { AdhanPreviewPlayer.shared.stop() }
    }
}


extension Notification.Name {
    /// Posted by the Prayer tab; the app layer owns ActivityKit.
    public static let noorToggleLiveActivity = Notification.Name("noorToggleLiveActivity")
}
