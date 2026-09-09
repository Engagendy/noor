import ContentDB
import DesignSystem
import SwiftUI

/// Maps a tajweed rule to its ink.
///
/// Hues are the conventional tajweed-mushaf ones so a reader who learned from
/// a printed tajweed mushaf sees the same colours here; the actual values are
/// design tokens (`NoorColor.tajweed*`), which resolve per palette, so this
/// file never hard-codes a colour.
public extension TajweedRule {
    var color: Color {
        switch self {
        case .ghunnah: NoorColor.tajweedGhunnah
        case .idghaamGhunnah: NoorColor.tajweedIdghaamGhunnah
        case .idghaamNoGhunnah: NoorColor.tajweedIdghaamNoGhunnah
        case .idghaamShafawi: NoorColor.tajweedIdghaamShafawi
        case .idghaamMutajanisayn: NoorColor.tajweedIdghaamMutajanisayn
        case .idghaamMutaqaribayn: NoorColor.tajweedIdghaamMutaqaribayn
        case .ikhfa: NoorColor.tajweedIkhfa
        case .ikhfaShafawi: NoorColor.tajweedIkhfaShafawi
        case .iqlab: NoorColor.tajweedIqlab
        case .qalqalah: NoorColor.tajweedQalqalah
        case .madd2: NoorColor.tajweedMadd2
        case .madd246: NoorColor.tajweedMadd246
        case .maddMunfasil: NoorColor.tajweedMaddMunfasil
        case .maddMuttasil: NoorColor.tajweedMaddMuttasil
        case .madd6: NoorColor.tajweedMadd6
        // Letters that are written but not pronounced share one neutral ink —
        // that is itself the convention, and the information is "say nothing".
        case .hamzatWasl, .lamShamsiyyah, .silent: NoorColor.tajweedUnpronounced
        }
    }

    /// Order used by the legend: grouped the way the rules are taught.
    static var legendOrder: [TajweedRule] {
        [.ghunnah, .idghaamGhunnah, .idghaamNoGhunnah, .idghaamShafawi,
         .idghaamMutajanisayn, .idghaamMutaqaribayn,
         .ikhfa, .ikhfaShafawi, .iqlab, .qalqalah,
         .madd2, .madd246, .maddMunfasil, .maddMuttasil, .madd6,
         .hamzatWasl, .lamShamsiyyah, .silent]
    }
}

/// Builds the per-word coloured runs.
public enum TajweedColoring {
    /// Tints one flow word according to the spans of its ayah.
    ///
    /// `spans` are scalar ranges into the WHOLE ayah; `scalarStart` is where
    /// this word begins inside that ayah, so only the overlapping part of each
    /// span is applied. Colouring happens inside a single `Text`'s
    /// `AttributedString`, never by concatenating `Text` values — the bidi and
    /// shaping run stays whole, which is what the flow renderer requires.
    ///
    /// Spans may overlap (a madd letter can also carry a ghunnah); they are
    /// applied in start order, so the later span wins on the shared letters.
    public static func attributed(word: String,
                                  scalarStart: Int,
                                  spans: [TajweedSpan],
                                  base: Color) -> AttributedString {
        var attributed = AttributedString(word)
        attributed.foregroundColor = base
        let length = word.unicodeScalars.count
        guard length > 0 else { return attributed }

        let scalars = attributed.unicodeScalars
        for span in spans {
            let lower = max(span.start - scalarStart, 0)
            let upper = min(span.end - scalarStart, length)
            guard lower < upper else { continue }
            let from = scalars.index(scalars.startIndex, offsetBy: lower)
            let to = scalars.index(scalars.startIndex, offsetBy: upper)
            attributed[from..<to].foregroundColor = span.rule.color
        }
        return attributed
    }

    /// Spans that touch `[scalarStart, scalarStart + length)`.
    ///
    /// Cheap pre-filter so a word only carries the handful of spans that can
    /// possibly tint it.
    public static func spans(_ spans: [TajweedSpan],
                             overlapping scalarStart: Int,
                             length: Int) -> [TajweedSpan] {
        guard length > 0 else { return [] }
        let end = scalarStart + length
        return spans.filter { $0.start < end && $0.end > scalarStart }
    }
}

/// The colour key. Reachable from the reader's options panel whenever tajweed
/// colouring is on.
///
/// Accessibility: colour is never the only cue. The feature is opt-in and off
/// by default, every rule is named here in the UI language (the same names the
/// Learn tajweed guide uses), and each row is one VoiceOver element that reads
/// the rule name — the swatch is decorative and hidden from VoiceOver, since
/// "green square" carries nothing a blind reader can use.
public struct TajweedLegendView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(TajweedRule.legendOrder) { rule in
                        row(rule)
                    }
                } footer: {
                    Text("Letters with no colour are read plainly (iẓhār). Colouring is a study aid — the Quran text itself is never changed.")
                        .font(.noorScaled(12))
                        .foregroundStyle(NoorColor.inkSecondary)
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(NoorColor.bgPrimary)
            .navigationTitle(Text("Tajweed colours"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                    }
                }
            }
        }
    }

    private func row(_ rule: TajweedRule) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 5)
                .fill(rule.color)
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)
            Text(verbatim: rule.name(arabicUI: isArabicUI))
                .font(.noorScaled(15, weight: .semibold))
                .foregroundStyle(NoorColor.inkPrimary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: rule.name(arabicUI: isArabicUI)))
    }
}

#Preview {
    TajweedLegendView()
}

#Preview("AR") {
    TajweedLegendView()
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}
