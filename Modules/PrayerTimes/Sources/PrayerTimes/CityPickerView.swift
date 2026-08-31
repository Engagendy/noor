import DesignSystem
import SwiftUI

/// Searchable city list (English and Arabic names both searchable).
struct CityPickerView: View {
    @Binding var cityName: String
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    private var filtered: [CityPreset] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return CityPreset.all }
        return CityPreset.all.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.nameArabic.contains(query)
        }
    }

    var body: some View {
        List(filtered) { city in
            Button {
                cityName = city.name
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: city.displayName(arabicUI: isArabicUI))
                            .foregroundStyle(NoorColor.inkPrimary)
                        Text(verbatim: city.displayName(arabicUI: !isArabicUI))
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                    Spacer()
                    if city.name == cityName {
                        Image(systemName: "checkmark")
                            .foregroundStyle(NoorColor.accentPrimary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: Text("City name"))
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("City"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}