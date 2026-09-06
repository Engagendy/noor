import DesignSystem
import SwiftUI

/// Asked once, when a grown-up switches kids mode on: the age drives the
/// surah set, the text scale and the repeat count (see `KidsMode`).
struct KidsAgeSheet: View {
    @State private var age: Int
    let onStart: (Int) -> Void
    let onCancel: () -> Void
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    init(age: Int, onStart: @escaping (Int) -> Void, onCancel: @escaping () -> Void) {
        _age = State(initialValue: KidsMode.clampAge(age))
        self.onStart = onStart
        self.onCancel = onCancel
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        VStack(spacing: 24) {
            Text("How old is your child?")
                .font(NoorFont.screenTitle)
                .foregroundStyle(NoorColor.inkPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 28)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(KidsMode.ageRange), id: \.self) { value in
                    chip(value)
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Button {
                    onStart(age)
                } label: {
                    Text("Start")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(NoorColor.bgPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 54)
                        .background(Capsule().fill(NoorColor.accentPrimary))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 17))
                        .foregroundStyle(NoorColor.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: NoorMetrics.minTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NoorColor.bgPrimary)
    }

    private func chip(_ value: Int) -> some View {
        let selected = value == age
        return Button {
            age = value
        } label: {
            Text(verbatim: isArabicUI ? value.arabicIndic : String(value))
                .font(.noorScaled(26, weight: .semibold).monospacedDigit())
                .foregroundStyle(selected ? NoorColor.bgPrimary : NoorColor.inkPrimary)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(selected ? NoorColor.accentPrimary : NoorColor.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(selected ? Color.clear : NoorColor.inkPrimary.opacity(0.1), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Age \(value)"))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("Age sheet — EN LTR") {
    KidsAgeSheet(age: 7, onStart: { _ in }, onCancel: {})
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)
}

#Preview("Age sheet — AR RTL") {
    KidsAgeSheet(age: 7, onStart: { _ in }, onCancel: {})
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}
