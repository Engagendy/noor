import CoreLocation
import DesignSystem
import PrayerTimes
import SwiftUI

/// Qibla direction from the selected city. On iPhone the dial rotates live
/// with the compass; elsewhere it shows the static bearing from true north.
public struct QiblaView: View {
    @AppStorage("prayer.city") private var cityName = "Makkah"
    @State private var headingProvider = HeadingProvider()

    public init() {}

    private var city: CityPreset { CityPreset.named(cityName) }
    private var bearing: Double {
        QiblaMath.bearing(fromLatitude: city.latitude, longitude: city.longitude)
    }

    public var body: some View {
        VStack(spacing: 28) {
            Text("\(city.name) · manual")
                .font(NoorFont.caption)
                .foregroundStyle(NoorColor.inkSecondary)

            ZStack {
                Circle()
                    .stroke(NoorColor.inkSecondary.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 240, height: 240)
                ForEach(0..<8, id: \.self) { tick in
                    Capsule()
                        .fill(NoorColor.inkSecondary.opacity(tick % 2 == 0 ? 0.5 : 0.25))
                        .frame(width: 2, height: tick % 2 == 0 ? 14 : 8)
                        .offset(y: -113)
                        .rotationEffect(.degrees(Double(tick) * 45))
                }
                Image(systemName: "location.north.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(NoorColor.accentPrimary)
                    .offset(y: -66)
                    .rotationEffect(.degrees(dialRotation))
                    .animation(.easeInOut(duration: 0.3), value: dialRotation)
                Text(verbatim: "🕋")
                    .font(.system(size: 40))
            }

            VStack(spacing: 4) {
                Text(verbatim: "\(Int(bearing.rounded()))°")
                    .font(.system(size: 34, weight: .semibold).monospacedDigit())
                    .foregroundStyle(NoorColor.inkPrimary)
                Text(headingProvider.heading == nil
                     ? "Bearing from true north"
                     : "Point the arrow at the Kaaba")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Qibla"))
        .onAppear { headingProvider.start() }
        .onDisappear { headingProvider.stop() }
    }

    private var dialRotation: Double {
        bearing - (headingProvider.heading ?? 0)
    }
}

/// Device compass heading (iPhone). No location permission needed — heading
/// only; the qibla is computed from the manually chosen city.
@Observable
final class HeadingProvider: NSObject, CLLocationManagerDelegate {
    private(set) var heading: Double?
    private let manager = CLLocationManager()

    func start() {
        #if os(iOS)
        guard CLLocationManager.headingAvailable() else { return }
        manager.delegate = self
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
