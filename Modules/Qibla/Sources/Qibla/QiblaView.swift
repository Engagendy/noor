import CoreLocation
import DesignSystem
import PrayerTimes
import SwiftUI

/// Qibla compass. The needle shows where to turn; when the phone faces the
/// qibla (±6°) the dial turns green, pulses once, and taps a success haptic.
/// Without a compass (iPad/Mac/simulator) it shows the static bearing.
public struct QiblaView: View {
    @AppStorage("prayer.city") private var cityName = "Makkah"
    @AppStorage("prayer.useCustom") private var useCustomLocation = false
    @State private var headingProvider = HeadingProvider()
    @State private var pulse = false

    public init() {}

    private var location: PrayerLocation {
        useCustomLocation ? PrayerLocation.current() : CityPreset.named(cityName).location
    }
    private var bearing: Double {
        QiblaMath.bearing(fromLatitude: location.latitude, longitude: location.longitude)
    }
    /// How far to turn, -180…180 (0 = facing the qibla).
    private var turn: Double {
        guard let heading = headingProvider.heading else { return bearing }
        var delta = (bearing - heading).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }
    private var isAligned: Bool {
        headingProvider.heading != nil && abs(turn) < 6
    }

    public var body: some View {
        VStack(spacing: 28) {
            Text(verbatim: location.label)
                .font(NoorFont.caption)
                .foregroundStyle(NoorColor.inkSecondary)

            ZStack {
                Circle()
                    .stroke(isAligned ? NoorColor.accentPrimary : NoorColor.inkSecondary.opacity(0.2),
                            lineWidth: isAligned ? 3 : 1.5)
                    .frame(width: 250, height: 250)
                    .scaleEffect(pulse ? 1.07 : 1)
                    .animation(.easeInOut(duration: 0.35), value: pulse)
                ForEach(0..<8, id: \.self) { tick in
                    Capsule()
                        .fill(NoorColor.inkSecondary.opacity(tick % 2 == 0 ? 0.5 : 0.25))
                        .frame(width: 2, height: tick % 2 == 0 ? 14 : 8)
                        .offset(y: -118)
                        .rotationEffect(.degrees(Double(tick) * 45))
                }

                // The needle: turn your body until it points straight up.
                Image(systemName: "location.north.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(isAligned ? NoorColor.accentPrimary : NoorColor.accentGold)
                    .rotationEffect(.degrees(turn))
                    .animation(.easeInOut(duration: 0.25), value: turn)
                    .shadow(color: isAligned ? NoorColor.accentPrimary.opacity(0.5) : .clear, radius: 14)

                Text(verbatim: "🕋")
                    .font(.system(size: 34))
                    .offset(y: -155)
            }
            .environment(\.layoutDirection, .leftToRight)  // compass never mirrors

            VStack(spacing: 4) {
                if isAligned {
                    Text("Facing the qibla")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(NoorColor.accentPrimary)
                } else {
                    Text(verbatim: "\(Int(bearing.rounded()))°")
                        .font(.system(size: 34, weight: .semibold).monospacedDigit())
                        .foregroundStyle(NoorColor.inkPrimary)
                    Text(headingProvider.heading == nil
                         ? "Bearing from true north"
                         : "Turn until the arrow points up")
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Qibla"))
        .onAppear { headingProvider.start() }
        .onDisappear { headingProvider.stop() }
        .onChange(of: isAligned) { _, aligned in
            guard aligned else { return }
            pulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pulse = false }
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isAligned ? "Facing the qibla" : "Qibla bearing \(Int(bearing.rounded())) degrees")
    }
}

/// Device compass heading (iPhone). No location permission needed — heading
/// only; the qibla is computed from the chosen prayer location.
@Observable
final class HeadingProvider: NSObject, CLLocationManagerDelegate {
    private(set) var heading: Double?
    private let manager = CLLocationManager()

    func start() {
        #if os(iOS)
        guard CLLocationManager.headingAvailable() else { return }
        manager.delegate = self
        manager.headingFilter = 2
        manager.startUpdatingHeading()
        #endif
    }

    func stop() {
        #if os(iOS)
        manager.stopUpdatingHeading()
        #endif
    }

    #if os(iOS)
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }
    #endif
}

#Preview {
    NavigationStack { QiblaView() }
}
