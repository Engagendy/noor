import SwiftUI

/// Rub-el-hizb corner motif: two overlapping squares, one rotated 45°.
/// Used on the surah-header ornament frame corners (design 1a/1b).
public struct RubElHizbMark: View {
    var size: CGFloat
    var color: Color

    public init(size: CGFloat = 12, color: Color = NoorColor.accentGold) {
        self.size = size
        self.color = color
    }

    public var body: some View {
        ZStack {
            Rectangle().stroke(color, lineWidth: 1)
            Rectangle().stroke(color, lineWidth: 1).rotationEffect(.degrees(45))
        }
        .frame(width: size * 0.55, height: size * 0.55)
        .frame(width: size, height: size)
        .background(NoorColor.bgPrimary)
    }
}

/// The single surah-header ornament frame — one design, used everywhere
/// (design rule: no per-surah frames).
public struct SurahOrnamentFrame<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .overlay(RoundedRectangle(cornerRadius: 1).stroke(NoorColor.accentGold, lineWidth: 1))
            .overlay(
                RoundedRectangle(cornerRadius: 1)
                    .stroke(NoorColor.accentGold.opacity(0.45), lineWidth: 1)
                    .padding(3)
            )
            .overlay(alignment: .topLeading) { RubElHizbMark().offset(x: -6, y: -6) }
            .overlay(alignment: .topTrailing) { RubElHizbMark().offset(x: 6, y: -6) }
            .overlay(alignment: .bottomLeading) { RubElHizbMark().offset(x: -6, y: 6) }
            .overlay(alignment: .bottomTrailing) { RubElHizbMark().offset(x: 6, y: 6) }
            .padding(6)
    }
}

/// Diamond (rotated square) surah-number badge from the index design (1g).
public struct SurahNumberBadge: View {
    let number: Int

    public init(_ number: Int) {
        self.number = number
    }

    public var body: some View {
        Text("\(number)")
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .foregroundStyle(NoorColor.accentGold)
            .frame(width: 30, height: 30)
            .background(
                Rectangle()
                    .stroke(NoorColor.accentGold.opacity(0.5), lineWidth: 1)
                    .rotationEffect(.degrees(45))
                    .frame(width: 22, height: 22)
            )
    }
}

/// Circled ayah-end marker with an Arabic-Indic numeral (designs 1b–1d).
public struct AyahEndMarker: View {
    let ayah: Int
    var size: CGFloat

    public init(_ ayah: Int, size: CGFloat = 24) {
        self.ayah = ayah
        self.size = size
    }

    public var body: some View {
        Text(ayah.arabicIndic)
            .font(.system(size: size * 0.5))
            .foregroundStyle(NoorColor.accentGold)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(NoorColor.accentGold, lineWidth: 1.2))
    }
}

public extension Int {
    /// Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩) for ayah markers and Hijri numerals.
    var arabicIndic: String {
        String(String(self).map { char in
            guard let digit = char.wholeNumberValue else { return char }
            return Character(UnicodeScalar(0x0660 + digit)!)
        })
    }
}

/// The brand mihrab arch (app icon / splash geometry).
public struct MihrabShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
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

/// Small brand mark: the mihrab with its lamp.
public struct MihrabLogoMark: View {
    var size: CGFloat
    var archColor: Color
    var lampColor: Color

    public init(size: CGFloat = 36,
                archColor: Color = NoorColor.accentPrimary,
                lampColor: Color = NoorColor.accentGold) {
        self.size = size
        self.archColor = archColor
        self.lampColor = lampColor
    }

    public var body: some View {
        ZStack {
            MihrabShape()
                .stroke(archColor, style: StrokeStyle(lineWidth: size * 0.07, lineJoin: .round))
                .frame(width: size * 0.78, height: size)
            Circle()
                .fill(lampColor)
                .frame(width: size * 0.22, height: size * 0.22)
                .offset(y: -size * 0.12)
        }
    }
}

/// Elevated card treatment used across Today, study reader, and hadith cards.
public struct NoorCardStyle: ViewModifier {
    var cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        content
            .background(NoorColor.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(NoorColor.inkPrimary.opacity(0.07), lineWidth: 1)
            )
    }
}

public extension View {
    func noorCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(NoorCardStyle(cornerRadius: cornerRadius))
    }
}
