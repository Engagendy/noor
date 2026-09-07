import DesignSystem
import SwiftUI

/// Reader for a memorisation matn: sections as headers, numbered lines, the
/// two hemistichs side by side (صدر right, عجز left) and stacked when the
/// width is tight.
///
/// This is NOT Quran, so it deliberately uses the *interface* font through
/// the design tokens (never Amiri Quran / QCF / Uthmanic Hafs, which are
/// reserved for the Quran itself) and follows Dynamic Type. All matn content
/// is `Text(verbatim:)` — it must never go through a localisation lookup.
public struct MatnReaderView: View {
    let matn: Matn

    @Environment(\.locale) private var locale
    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    @AppStorage("matn.fontSize") private var fontSize = 20.0
    /// Where the reader was last scrolled to, and which line the user marked
    /// as the one being memorised. Keyed per matn, so a second matn keeps its
    /// own place.
    @AppStorage private var lastLine: Int
    @AppStorage private var markedRaw: String

    @State private var showSizeControl = false
    /// The item at the top of the viewport, read AND written through
    /// `.scrollPosition(id:)`. This one binding does both jobs: setting it
    /// restores the reading position, and the scroll view writes back to it
    /// as the user reads. `.onAppear`-based tracking was tried first and is
    /// wrong here — in a stack whose rows are all built up front it fires for
    /// rows nobody has looked at, which reset the saved line to 1.
    @State private var position: Item?
    @State private var didRestore = false
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private static let sizeRange: ClosedRange<Double> = 15...34

    public init(matn: Matn) {
        self.matn = matn
        _lastLine = AppStorage(wrappedValue: 0, "matn.\(matn.id).lastLine")
        _markedRaw = AppStorage(wrappedValue: "", "matn.\(matn.id).marked")
    }

    private var marked: Set<Int> {
        Set(markedRaw.split(separator: ",").compactMap { Int($0) })
    }

    private func toggleMark(_ number: Int) {
        var set = marked
        if set.contains(number) { set.remove(number) } else { set.insert(number) }
        markedRaw = set.sorted().map(String.init).joined(separator: ",")
    }

    /// The reader's flat content, so every row is a direct child of the
    /// scroll target layout and therefore addressable by `scrollPosition`.
    enum Item: Hashable, Identifiable {
        case title
        case section(String)
        case line(Int)
        case colophon

        var id: Self { self }
    }

    private var items: [Item] {
        var out: [Item] = [.title]
        for section in matn.sections {
            out.append(.section(section.id))
            out.append(contentsOf: matn.lines(in: section).map { .line($0.number) })
        }
        out.append(.colophon)
        return out
    }

    public var body: some View {
        // One decision for the whole reader, not per line: `ViewThatFits`
        // applied per row produced a ragged mix of stacked and side-by-side
        // lines depending on each line's length. A matn reads as a column of
        // consistent couplets, so the layout is chosen once, from the size
        // class — NOT from a `GeometryReader`, whose second pass re-ran the
        // resume `.task` and threw the reader back to the top.
        reader(twoColumn: isWide)
    }

    private var isWide: Bool {
        #if os(iOS)
        return sizeClass == .regular
        #else
        return true
        #endif
    }

    private func reader(twoColumn: Bool) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(items) { item in
                    row(item, twoColumn: twoColumn)
                }
            }
            .scrollTargetLayout()
            // Clears the floating tab bar the Quran tab draws over the
            // reader; harmless slack when opened from Settings.
            .padding(.bottom, 96)
        }
        .scrollPosition(id: $position, anchor: .top)
        .background(NoorColor.bgPrimary)
        .onChange(of: position) { _, new in
            // Where the reader actually is — written only for real lines, so
            // the title and the colophon never clear the saved place.
            if case .line(let number)? = new { lastLine = number }
        }
        .task {
            guard !didRestore else { return }
            didRestore = true
            // Resume where the reader last was. The marked line is
            // deliberately NOT the resume target — it is the line being
            // memorised, one tap away on the toolbar bookmark.
            guard lastLine > 1 else { return }
            position = .line(lastLine)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                    if let target = marked.min() {
                        Button {
                            withAnimation { position = .line(target) }
                        } label: {
                            Image(systemName: "bookmark.fill")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Go to marked line")
                    }
                    Button {
                        showSizeControl = true
                    } label: {
                        Image(systemName: "textformat.size")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Text size")
                }
            }
        .sheet(isPresented: $showSizeControl) {
            sizeControl
                .presentationDetents([.height(170)])
                .environment(\.locale, locale)
                .environment(\.layoutDirection, isArabicUI ? .rightToLeft : .leftToRight)
        }
        .navigationTitle(Text(verbatim: matn.displayTitle(arabicUI: isArabicUI)))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Pieces

    @ViewBuilder
    private func row(_ item: Item, twoColumn: Bool) -> some View {
        switch item {
        case .title:
            header
        case .section(let id):
            if let section = matn.sections.first(where: { $0.id == id }) {
                sectionHeader(section)
            }
        case .line(let number):
            if let line = matn.lines.first(where: { $0.number == number }) {
                lineRow(line, twoColumn: twoColumn)
            }
        case .colophon:
            footer
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: matn.titleAr)
                .font(.noorScaled(22, weight: .semibold))
                .foregroundStyle(NoorColor.inkPrimary)
                .arabicBlock(alignment: .center)
            Text(verbatim: matn.authorAr)
                .font(.noorScaled(15))
                .foregroundStyle(NoorColor.inkSecondary)
                .arabicBlock(alignment: .center)
            if let composed = matn.composedAr {
                Text(verbatim: composed)
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
                    .arabicBlock(alignment: .center)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: 4) {
            // Arabic-Indic numerals in the Arabic interface (see `SurahRow`).
            if isArabicUI {
                Text(verbatim: "\(matn.lines.count.arabicIndic) بيتًا")
            } else {
                Text("\(matn.lines.count) lines")
            }
            Text(verbatim: "\(matn.sourceName) · \(matn.sourceLicense)")
        }
        .font(NoorFont.caption)
        .foregroundStyle(NoorColor.inkSecondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.horizontal, 16)
    }

    private func sectionHeader(_ section: Matn.Section) -> some View {
        Text(verbatim: section.displayTitle(arabicUI: isArabicUI))
            .font(.noorScaled(16, weight: .semibold))
            .foregroundStyle(NoorColor.accentPrimary)
            .frame(maxWidth: .infinity, alignment: isArabicUI ? .trailing : .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(NoorColor.bgElevated)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func lineRow(_ line: Matn.Line, twoColumn: Bool) -> some View {
        let isMarked = marked.contains(line.number)
        HStack(alignment: .top, spacing: 10) {
            Button {
                toggleMark(line.number)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: isMarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 13))
                        .foregroundStyle(isMarked ? NoorColor.accentGold
                                                  : NoorColor.inkSecondary.opacity(0.35))
                    Text(verbatim: isArabicUI ? line.number.arabicIndic : "\(line.number)")
                        .font(NoorFont.caption.monospacedDigit())
                        .foregroundStyle(NoorColor.inkSecondary)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isMarked ? "Remove mark" : "Mark this line")

            hemistichs(line, twoColumn: twoColumn)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isMarked ? NoorColor.accentGold.opacity(0.10) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Line \(line.number)"))
        .accessibilityValue(Text(verbatim: "\(line.first) … \(line.second)"))
    }

    /// The conventional two-column arrangement (صدر right, عجز left) where
    /// the width allows; stacked on a phone, where two columns would leave
    /// each hemistich around 160pt and wrap every one of them.
    @ViewBuilder
    private func hemistichs(_ line: Matn.Line, twoColumn: Bool) -> some View {
        if twoColumn {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                hemistich(line.first)
                hemistich(line.second)
            }
            .environment(\.layoutDirection, .rightToLeft)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                hemistich(line.first)
                hemistich(line.second)
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private func hemistich(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.noorScaled(fontSize))
            .foregroundStyle(NoorColor.inkPrimary)
            .lineSpacing(fontSize * 0.35)
            .fixedSize(horizontal: false, vertical: true)
            .arabicBlock()
    }

    private var sizeControl: some View {
        VStack(spacing: 16) {
            Text("Text size")
                .font(.noorScaled(16, weight: .semibold))
                .foregroundStyle(NoorColor.inkPrimary)
            HStack(spacing: 14) {
                Button {
                    fontSize = max(Self.sizeRange.lowerBound, fontSize - 2)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Smaller")
                Text(verbatim: "\(Int(fontSize))")
                    .font(.noorScaled(17, weight: .semibold).monospacedDigit())
                    .frame(minWidth: 36)
                    .foregroundStyle(NoorColor.inkPrimary)
                Button {
                    fontSize = min(Self.sizeRange.upperBound, fontSize + 2)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Larger")
            }
            .foregroundStyle(NoorColor.accentPrimary)
            Button {
                showSizeControl = false
            } label: {
                Text("Done")
                    .font(.noorScaled(16, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(NoorColor.accentPrimary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NoorColor.bgPrimary)
    }
}

#Preview("Matn — AR RTL") {
    if let matn = MatnStore.load().first {
        NavigationStack { MatnReaderView(matn: matn) }
            .environment(\.locale, Locale(identifier: "ar"))
            .environment(\.layoutDirection, .rightToLeft)
    }
}

#Preview("Matn — EN LTR") {
    if let matn = MatnStore.load().first {
        NavigationStack { MatnReaderView(matn: matn) }
            .environment(\.locale, Locale(identifier: "en"))
            .environment(\.layoutDirection, .leftToRight)
    }
}
