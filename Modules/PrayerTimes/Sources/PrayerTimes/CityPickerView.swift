import ContentDB
import DesignSystem
import SwiftUI

/// Offline city picker over the bundled GeoNames database (34k places).
/// Empty query: Nearby (from a cached device fix), Popular (the curated
/// presets), and Browse by country. Typing searches Latin names by word
/// start or Arabic names by substring. Nothing here touches the network.
public struct CityPickerView: View {
    /// Pop back to the caller after a pick (Settings). Onboarding embeds
    /// the picker in its own page and keeps it on screen instead.
    public var dismissOnSelect: Bool = true

    @AppStorage("prayer.cityId") private var selectedCityId = 0
    @AppStorage("prayer.city") private var legacyCityName = "Makkah"
    @AppStorage("prayer.useCustom") private var useCustomLocation = false
    private var db: CityDatabase? { CityDatabase.shared }
    @State private var query = ""
    @State private var results: [City] = []
    @State private var nearby: [City] = []
    @State private var popular: [City] = []
    @FocusState private var searchFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    public init(dismissOnSelect: Bool = true) {
        self.dismissOnSelect = dismissOnSelect
    }

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    public var body: some View {
        List {
            if trimmedQuery.isEmpty {
                if !nearby.isEmpty {
                    Section {
                        CityRows(cities: nearby, select: select, isSelected: isSelected)
                    } header: {
                        Text("Nearby")
                    }
                }
                if !popular.isEmpty {
                    Section {
                        CityRows(cities: popular, select: select, isSelected: isSelected)
                    } header: {
                        Text("Popular")
                    }
                }
                Section {
                    NavigationLink {
                        CountryListView(select: select, isSelected: isSelected)
                    } label: {
                        Label {
                            Text("Browse by country")
                                .foregroundStyle(NoorColor.inkPrimary)
                        } icon: {
                            Image(systemName: "globe")
                                .foregroundStyle(NoorColor.accentPrimary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            } else if results.isEmpty {
                Text("No cities found")
                    .font(NoorFont.caption)
                    .foregroundStyle(NoorColor.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                CityRows(cities: results, select: select, isSelected: isSelected)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .safeAreaInset(edge: .top, spacing: 0) { searchField }
        .navigationTitle(Text("City"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: query) { _, _ in runSearch() }
        .task {
            loadSuggestions()
            if dismissOnSelect { searchFocused = true }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(NoorColor.inkSecondary)
            TextField(text: $query) {
                Text("Search city")
            }
            .textFieldStyle(.plain)
            .focused($searchFocused)
            #if os(iOS)
            .textInputAutocapitalization(.words)
            #endif
            .autocorrectionDisabled()
            .submitLabel(.search)
            .accessibilityLabel("Search city")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(NoorColor.inkSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(RoundedRectangle(cornerRadius: 10).fill(NoorColor.bgElevated))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(NoorColor.bgPrimary)
    }

    private func loadSuggestions() {
        guard let db else { return }
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "prayer.customLat") != nil {
            nearby = (try? db.nearest(latitude: defaults.double(forKey: "prayer.customLat"),
                                      longitude: defaults.double(forKey: "prayer.customLon"),
                                      limit: 5)) ?? []
        }
        // Presets resolve to DB rows by exact Latin or curated Arabic name;
        // keep the preset order (regional grouping) rather than population.
        let rows = (try? db.cities(named: CityPreset.all.map(\.name),
                                   arabicNames: CityPreset.all.map(\.nameArabic))) ?? []
        popular = CityPreset.all.compactMap { preset in
            rows.first { $0.name == preset.name } ?? rows.first { $0.nameArabic == preset.nameArabic }
        }
    }

    private func runSearch() {
        guard let db, !trimmedQuery.isEmpty else {
            results = []
            return
        }
        results = (try? db.search(trimmedQuery)) ?? []
    }

    private func isSelected(_ city: City) -> Bool {
        guard !useCustomLocation else { return false }
        if selectedCityId > 0 { return city.id == selectedCityId }
        let preset = CityPreset.named(legacyCityName)
        return city.name == preset.name || (city.nameArabic != nil && city.nameArabic == preset.nameArabic)
    }

    private func select(_ city: City) {
        PrayerLocation.select(city: city)
        if dismissOnSelect { dismiss() }
    }
}

/// City rows with a secondary line: the other-language name, the country,
/// and the region code whenever the same name appears twice in the list.
struct CityRows: View {
    let cities: [City]
    let select: (City) -> Void
    let isSelected: (City) -> Bool
    @Environment(\.locale) private var locale

    private var isArabicUI: Bool { locale.language.languageCode?.identifier == "ar" }

    private var duplicatedNames: Set<String> {
        var seen: Set<String> = []
        var duplicates: Set<String> = []
        for city in cities {
            let name = city.displayName(arabicUI: isArabicUI)
            if !seen.insert(name).inserted { duplicates.insert(name) }
        }
        return duplicates
    }

    private func subtitle(_ city: City, duplicates: Set<String>) -> String {
        var parts: [String] = []
        if let other = city.alternateName(arabicUI: isArabicUI) { parts.append(other) }
        parts.append(city.countryName(locale: locale))
        if duplicates.contains(city.displayName(arabicUI: isArabicUI)),
           let admin1 = city.admin1, !admin1.isEmpty {
            parts.append(admin1)
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        let duplicates = duplicatedNames
        ForEach(cities) { city in
            let selected = isSelected(city)
            Button {
                select(city)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: city.displayName(arabicUI: isArabicUI))
                            .foregroundStyle(NoorColor.inkPrimary)
                        Text(verbatim: subtitle(city, duplicates: duplicates))
                            .font(NoorFont.caption)
                            .foregroundStyle(NoorColor.inkSecondary)
                    }
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(NoorColor.accentPrimary)
                    }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .listRowBackground(Color.clear)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }
}

/// Every country in the database, named in the UI language.
struct CountryListView: View {
    let select: (City) -> Void
    let isSelected: (City) -> Bool
    @State private var countries: [Country] = []
    @State private var query = ""
    @Environment(\.locale) private var locale

    private var filtered: [Country] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return countries }
        return countries.filter {
            $0.localizedName(locale: locale).localizedCaseInsensitiveContains(trimmed)
                || $0.name.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        List(filtered) { country in
            NavigationLink {
                CityListView(country: country, select: select, isSelected: isSelected)
            } label: {
                Text(verbatim: country.localizedName(locale: locale))
                    .foregroundStyle(NoorColor.inkPrimary)
                    .frame(minHeight: 44)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .searchable(text: $query, prompt: Text("Country"))
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text("Countries"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if countries.isEmpty {
                countries = (try? CityDatabase.shared?.countries(locale: locale)) ?? []
            }
        }
    }
}

/// Cities of one country, largest first.
struct CityListView: View {
    let country: Country
    let select: (City) -> Void
    let isSelected: (City) -> Bool
    @State private var cities: [City] = []
    @Environment(\.locale) private var locale

    var body: some View {
        List {
            CityRows(cities: cities, select: select, isSelected: isSelected)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .navigationTitle(Text(verbatim: country.localizedName(locale: locale)))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if cities.isEmpty {
                cities = (try? CityDatabase.shared?.cities(inCountry: country.code)) ?? []
            }
        }
    }
}

#Preview {
    NavigationStack { CityPickerView() }
}

#Preview("Arabic RTL") {
    NavigationStack { CityPickerView() }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}
