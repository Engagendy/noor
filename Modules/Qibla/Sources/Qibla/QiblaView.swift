import CoreLocation
import DesignSystem
import PrayerTimes
import SwiftUI

/// Qibla finder. The Kaaba sits at the top; a gold arc shows how far to
/// turn (it shrinks as you rotate). Facing the qibla (±6°): everything
/// turns green, pulses, and a success haptic fires. Without a compass
/// (iPad/Mac/simulator) the static bearing is shown.
public struct QiblaView: View {
    @AppStorage("prayer.city") private var cityName = "Makkah"
    @AppStorage("prayer.useCustom") private var useCustomLocation = false
    @State private var headingProvider = HeadingProvider()
    @State private var pulse = false
    @Environment(\.locale) private var locale

    public init() {}

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }
    private var location: PrayerLocation {
        useCustomLocation ? PrayerLocation.current() : CityPreset.named(cityName).location
    }
    private var locationLabel: String {
        useCustomLocation ? location.label : CityPreset.named(cityName).displayName(arabicUI: isArabicUI)
    }
    private var bearing: Double {
        QiblaMath.bearing(fromLatitude: location.latitude, longitude: location.longitude)
    }
    /// How far to turn, -180…180 (0 = facing the qibla).
    private var turn: Double {
        guard let heading = headingProvider.heading else { return 0 }
        var delta = (bearing - heading).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }
    private var hasCompass: Bool { headingProvider.heading != nil }
    private var isAligned: Bool { hasCompass && abs(turn) < 6 }

    public var body: some View {
        VStack(spacing: 22) {
            Text(verbatim: locationLabel)
                .font(NoorFont.caption)
                .foregroundStyle(NoorColor.inkSecondary)

            ZStack {
                // The Kaaba — the target, fixed at the top.
                Text(verbatim: "🕋")
                    .font(.system(size: 44))
                    .offset(y: -150)
                    .scaleEffect(pulse ? 1.15 : 1)
                    .animation(.easeInOut(duration: 0.35), value: pulse)

                // Turn arc: sweeps from the top by the remaining angle.
                if hasCompass && !isAligned {
                    Circle()
                        .trim(from: 0, to: abs(turn) / 360)
                        .stroke(NoorColor.accentGold,
                                style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 224, height: 224)
                        .rotationEffect(.degrees(-90))
                        .scaleEffect(x: turn >= 0 ? 1 : -1)
                        .animation(.easeInOut(duration: 0.25), value: turn)
                }
                Circle()
                    .stroke(isAligned ? NoorColor.accentPrimary : NoorColor.inkSecondary.opacity(0.15),
                            lineWidth: isAligned ? 3 : 1.5)
                    .frame(width: 250, height: 250)
                    .scaleEffect(pulse ? 1.06 : 1)
                    .animation(.easeInOut(duration: 0.35), value: pulse)

                // Prayer-mat motif (geometry, not imagery — design §1.6).
                VStack(spacing: 0) {
                    MihrabArch()
                        .stroke(isAligned ? NoorColor.accentPrimary : NoorColor.accentGold,
                                style: StrokeStyle(lineWidth: 4, lineJoin: .round))
                        .frame(width: 74, height: 96)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(NoorColor.bgElevated.opacity(0.7))
                )
                .rotationEffect(.degrees(hasCompass ? turn : 0))
                .animation(.easeInOut(duration: 0.25), value: turn)
            }
            .frame(height: 330)
            .environment(\.layoutDirection, .leftToRight)  // compass never mirrors

            VStack(spacing: 5) {
                if isAligned {
                    Text("Facing the qibla")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(NoorColor.accentPrimary)
                } else if hasCompass {
                    Text(turn >= 0 ? "Turn right" : "Turn left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(NoorColor.inkPrimary)
                    Text(verbatim: "\(Int(abs(turn).rounded()))°")
                        .font(.system(size: 16).monospacedDigit())
                        .foregroundStyle(NoorColor.inkSecondary)
                } else {
                    Text(verbatim: "\(Int(bearing.rounded()))°")
                        .font(.system(size: 34, weight: .semibold).monospacedDigit())
                        .foregroundStyle(NoorColor.inkPrimary)
                    Text("Bearing from true north")
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
        .accessibilityLabel(isAligned
            ? "Facing the qibla"
            : "Qibla bearing \(Int(bearing.rounded())) degrees")
    }
}

/// The mihrab arch (same geometry as the app icon / splash).
struct MihrabArch: Shape {
    func path(in rect: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + (x - 11) / 42 * rect.width,
                    y: rect.minY + (y - 6) / 52 * rect.height)
        }
        var path = Path()
        path.move(to: pt(11, 58))
        path.addLine(to: pt(11, 42))
        path.addCurve(to: pt(32, 6), control1: pt(11, 25), control2: pt(20, 13))
        path.addCurve(to: pt(53, 42), control1: pt(44, 13), control2: pt(53, 25))
        path.addLine(to: pt(53, 58))
        path.addLine(to: pt(11, 58))
        return path
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
