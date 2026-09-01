import DesignSystem
import SwiftUI

/// Bundled hadith: An-Nawawi's Forty + Forty Hadith Qudsi (offline,
/// public-domain dataset — see LICENSES.md).
struct HadithItem: Identifiable, Decodable {
    let collection: String
    let collectionArabic: String
    let collectionEnglish: String
    let number: Int
    let arabic: String
    let english: String

    var id: String { "\(collection)-\(number)" }
}

enum HadithStore {
    static func load() -> [HadithItem] {
        guard let url = Bundle.main.url(forResource: "hadith", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([HadithItem].self, from: data)
        else { return [] }
        return items
    }

    /// Deterministic daily pick across both collections.
    static func daily(from items: [HadithItem], date: Date) -> HadithItem? {
        guard !items.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return items[(day &* 13) % items.count]
    }
}

/// Browsable list of the bundled hadith collections.
struct HadithListView: View {
    let items: [HadithItem]
    let isArabicUI: Bool
    var initial: HadithItem?
    @Environment(\.dismiss) private var dismiss
    @State private var selected: HadithItem?

    private var collections: [(key: String, title: String, items: [HadithItem])] {
        Dictionary(grouping: items, by: \.collection)
            .map { (key: $0.key,
                    title: isArabicUI ? $0.value[0].collectionArabic : $0.value[0].collectionEnglish,
                    items: $0.value.sorted { $0.number < $1.number }) }
            .sorted { $0.key > $1.key }  // nawawi before qudsi
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        HadithCollectionsView(isArabicUI: isArabicUI)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "books.vertical.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(NoorColor.accentPrimary)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hadith library")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(NoorColor.inkPrimary)
                                Text(verbatim: "صحيح البخاري · صحيح مسلم")
                                    .font(NoorFont.caption)
                                    .foregroundStyle(NoorColor.inkSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear)
                }
                ForEach(collections, id: \.key) { collection in
                    Section {
                        ForEach(collection.items) { hadith in
                            Button {
                                selected = hadith
                            } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text(verbatim: isArabicUI ? hadith.number.arabicIndic : "\(hadith.number)")
                                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                        .foregroundStyle(NoorColor.accentGold)
                                        .frame(width: 30, alignment: .center)
                                    Text(verbatim: hadith.arabic)
                                        .font(.noorScaled(15))
                                        .foregroundStyle(NoorColor.inkPrimary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .listRowBackground(Color.clear)
                        }
                    } header: {
                        Text(verbatim: collection.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(NoorColor.accentPrimary)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(NoorColor.bgPrimary)
            .environment(\.layoutDirection, .rightToLeft)
            .navigationTitle(Text("Hadith"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selected) { hadith in
                HadithDetailView(hadith: hadith, isArabicUI: isArabicUI)
            }
            .onAppear {
                if let initial { selected = initial }
            }
        }
    }
}

/// Full hadith text (Arabic always; translation in English UI) + share.
struct HadithDetailView: View {
    let hadith: HadithItem
    let isArabicUI: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var sharing = false

    private var reference: String {
        isArabicUI
            ? "\(hadith.collectionArabic) · الحديث \(hadith.number.arabicIndic)"
            : "\(hadith.collectionEnglish) · Hadith \(hadith.number)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(verbatim: hadith.arabic)
                        .font(.noorScaled(18))
                        .foregroundStyle(NoorColor.inkPrimary)
                        .lineSpacing(10)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, .rightToLeft)
                    if !isArabicUI && !hadith.english.isEmpty {
                        Rectangle()
                            .fill(NoorColor.accentGold.opacity(0.3))
                            .frame(height: 0.7)
                        Text(verbatim: hadith.english)
                            .font(.noorScaled(15.5))
                            .foregroundStyle(NoorColor.inkPrimary.opacity(0.9))
                            .lineSpacing(7)
                    }
                    Text(verbatim: reference)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NoorColor.accentGold)
                }
                .padding(20)
            }
            .background(NoorColor.bgPrimary)
            .navigationTitle(Text("Hadith"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        sharing = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share")
                }
            }
            .sheet(isPresented: $sharing) {
                NoorShareSheet(
                    arabicText: hadith.arabic,
                    translation: isArabicUI ? nil : (hadith.english.isEmpty ? nil : hadith.english),
                    reference: reference,
                    attribution: "نور Noor",
                    useQuranFont: false)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}


#Preview("Hadith AR-RTL") {
    HadithListView(items: HadithStore.load(), isArabicUI: true)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
}
