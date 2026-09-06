import SwiftUI

/// "Ask a grown-up" — the lock that stands between a child and anything
/// that leaves kids mode. A randomly generated two-digit multiplication
/// with numeric entry: trivially easy for an adult, out of reach for the
/// 4–12 year olds kids mode is designed for.
///
/// Deliberately dumb: the caller owns what success means (turning kids
/// mode off, exiting the kids shell). Nothing is persisted here.
public struct ParentalGateView: View {
    /// One multiplication question. Pure, so it can be generated and
    /// checked without any view.
    public struct Question: Equatable {
        public let left: Int
        public let right: Int
        public var answer: Int { left * right }

        public init(left: Int, right: Int) {
            self.left = left
            self.right = right
        }

        /// Two factors in 3…12 whose product is never trivially guessable.
        public static func random() -> Question {
            Question(left: Int.random(in: 3...12), right: Int.random(in: 3...12))
        }
    }

    private let onSuccess: () -> Void
    private let onCancel: () -> Void

    @State private var question = Question.random()
    @State private var entry = ""
    @State private var showHint = false
    @FocusState private var focused: Bool
    @Environment(\.locale) private var locale

    public init(onSuccess: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onSuccess = onSuccess
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 24) {
            MihrabLogoMark(size: 44)
                .padding(.top, 8)
                .accessibilityHidden(true)
            Text("Ask a grown-up")
                .font(NoorFont.screenTitle)
                .foregroundStyle(NoorColor.inkPrimary)
                .multilineTextAlignment(.center)

            // The sum itself: digits and × read the same in both
            // directions, so it is pinned LTR to stay unambiguous.
            Text(verbatim: "\(question.left) × \(question.right) = ?")
                .font(.noorScaled(34, weight: .semibold).monospacedDigit())
                .foregroundStyle(NoorColor.accentPrimary)
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityLabel(Text("Ask a grown-up"))
                .accessibilityValue(Text(verbatim: "\(question.left) × \(question.right)"))

            TextField("", text: $entry)
                .textFieldStyle(.plain)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .multilineTextAlignment(.center)
                .font(.noorScaled(28, weight: .semibold).monospacedDigit())
                .foregroundStyle(NoorColor.inkPrimary)
                .environment(\.layoutDirection, .leftToRight)
                .frame(minHeight: NoorMetrics.minTapTarget)
                .frame(maxWidth: 180)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(NoorColor.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(NoorColor.accentPrimary.opacity(0.35), lineWidth: 1)
                )
                .focused($focused)
                .onSubmit(check)
                .accessibilityLabel(Text("Answer"))

            Text("That's not it — here's a new one.")
                .font(NoorFont.caption)
                .foregroundStyle(NoorColor.inkSecondary)
                .multilineTextAlignment(.center)
                .opacity(showHint ? 1 : 0)
                .accessibilityHidden(!showHint)

            VStack(spacing: 10) {
                Button(action: check) {
                    Text("Unlock")
                        .font(.noorScaled(17, weight: .semibold))
                        .foregroundStyle(NoorColor.bgPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: NoorMetrics.minTapTarget)
                        .background(Capsule().fill(NoorColor.accentPrimary))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.noorScaled(17))
                        .foregroundStyle(NoorColor.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: NoorMetrics.minTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
        }
        .padding(28)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NoorColor.bgPrimary)
        .onAppear { focused = true }
        .animation(.easeInOut(duration: 0.2), value: showHint)
    }

    private func check() {
        // Arabic-Indic digits arrive from the Arabic keyboard; normalise
        // before comparing (the locale-safe-formatting rule, read side).
        guard let value = Int(entry.normalizedWesternDigits), value == question.answer else {
            entry = ""
            showHint = true
            question = .random()
            focused = true
            return
        }
        onSuccess()
    }
}

public extension String {
    /// Maps Arabic-Indic (٠-٩) and Eastern Arabic-Indic (۰-۹) digits onto
    /// ASCII so numeric entry parses whatever keyboard produced it.
    var normalizedWesternDigits: String {
        String(unicodeScalars.map { scalar -> Character in
            switch scalar.value {
            case 0x0660...0x0669: Character(UnicodeScalar(scalar.value - 0x0660 + 48)!)
            case 0x06F0...0x06F9: Character(UnicodeScalar(scalar.value - 0x06F0 + 48)!)
            default: Character(scalar)
            }
        })
    }
}

// MARK: - Stars

/// Gold reward stars (0…`total` earned). Geometric, not figurative —
/// the same eight-pointed khatam language as the rest of the app.
public struct StarRow: View {
    let earned: Int
    let total: Int
    var size: CGFloat

    public init(earned: Int, total: Int = 3, size: CGFloat = 20) {
        self.earned = earned
        self.total = total
        self.size = size
    }

    public var body: some View {
        HStack(spacing: size * 0.25) {
            ForEach(0..<max(total, 0), id: \.self) { index in
                EightPointStar()
                    .fill(index < earned ? NoorColor.accentGold : Color.clear)
                    .overlay(
                        EightPointStar()
                            .stroke(index < earned
                                    ? NoorColor.accentGold
                                    : NoorColor.inkSecondary.opacity(0.3),
                                    lineWidth: 1)
                    )
                    .frame(width: size, height: size)
            }
        }
        // Stars read left-to-right as a progress meter in both languages.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(earned) of \(total) stars"))
    }
}

#Preview("Gate — EN") {
    ParentalGateView(onSuccess: {}, onCancel: {})
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)
}

#Preview("Gate — AR RTL") {
    ParentalGateView(onSuccess: {}, onCancel: {})
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Stars") {
    VStack(spacing: 12) {
        StarRow(earned: 0)
        StarRow(earned: 2)
        StarRow(earned: 3, size: 34)
    }
    .padding()
    .background(NoorColor.bgPrimary)
}
