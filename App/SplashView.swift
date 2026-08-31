import DesignSystem
import SwiftUI

/// Animated intro: the mihrab arch draws itself, the lamp glows on, then
/// نور / Noor fade in — calm, ~1.6 s, honoring Reduce Motion (design §5).
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var archProgress: CGFloat = 0
    @State private var lampOn = false
    @State private var nameOn = false

    private let green = Color(red: 0.055, green: 0.420, blue: 0.361)
    private let paper = Color(red: 0.980, green: 0.965, blue: 0.933)
    private let gold = Color(red: 0.847, green: 0.698, blue: 0.369)

    var body: some View {
        ZStack {
            green.ignoresSafeArea()
            VStack(spacing: 26) {
                ZStack {
                    MihrabShape()
                        .trim(from: 0, to: archProgress)
                        .stroke(paper, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                        .frame(width: 120, height: 150)
                    Circle()
                        .fill(gold)
                        .frame(width: 30, height: 30)
                        .shadow(color: gold.opacity(lampOn ? 0.8 : 0), radius: lampOn ? 22 : 0)
                        .scaleEffect(lampOn ? 1 : 0.4)
                        .opacity(lampOn ? 1 : 0)
                        .offset(y: -18)
                }
                VStack(spacing: 6) {
                    Text(verbatim: "نور")
                        .font(NoorFont.quran(size: 40))
                        .foregroundStyle(gold)
                    Text(verbatim: "Noor")
                        .font(.system(size: 22, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(paper)
                }
                .opacity(nameOn ? 1 : 0)
                .offset(y: nameOn ? 0 : 8)
            }
        }
        .onAppear {
            if reduceMotion {
                archProgress = 1
                lampOn = true
                withAnimation(.easeInOut(duration: 0.4)) { nameOn = true }
            } else {
                withAnimation(.easeInOut(duration: 0.7)) { archProgress = 1 }
                withAnimation(.easeInOut(duration: 0.5).delay(0.55)) { lampOn = true }
                withAnimation(.easeInOut(duration: 0.5).delay(0.85)) { nameOn = true }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Noor")
    }
}

/// The 2a mihrab arch path (same geometry as the app icon).
struct MihrabShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Design coordinates on a 42×52 box (from the 64×64 icon, trimmed).
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

#Preview {
    SplashView()
}
