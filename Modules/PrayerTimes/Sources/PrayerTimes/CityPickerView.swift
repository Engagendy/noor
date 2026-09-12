import ContentDB
import DesignSystem
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Offline city picker over the bundled GeoNames database (34k places).
/// A "use my location" row on top, then, for an empty query: Nearby (from a
/// cached device fix), Popular (the curated presets), and Browse by country.
/// Typing searches Latin names by word start or Arabic names by substring.
/// Nothing here touches the network — the fix is named against the bundled
/// database, never geocoded (CLAUDE.md rule 3).
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
    /// Auto-locate. The same one-shot fetcher the prayer settings sheet uses.
    @State private var fetcher = OneShotLocationFetcher()
    @State private var locating = false
    @State private var locateProblem: CityLocateProblem?
    /// The city the last fix resolved to, so the row can name it at once
    /// (`prayer.useCustom` may already have been true).
    @State private var locatedName: String?
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
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 8) {
                searchField
                locateRow
            }
            .padding(.bottom, 8)
            .background(NoorColor.bgPrimary)
        }
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
        .padding(.top, 8)
    }

    // MARK: - Auto-locate
    //
    // Mirrors Android's onboarding city step: one tap, one coarse fix, named
    // from the offline table, and a visible outcome for every failure — the
    // reader can always fall back to the search field above.
    private var locateRow: some View {
        CityLocateRow(state: locateState, action: locate)
            .padding(.horizontal, 16)
    }

    private var locateState: CityLocateState {
        if locating { return .locating }
        if let locateProblem { return .problem(locateProblem) }
        if useCustomLocation { return .located(locatedCityName) }
        return .idle
    }

    private var locatedCityName: String? {
        guard useCustomLocation else { return nil }
        if let locatedName, !locatedName.isEmpty { return locatedName }
        let name = PrayerLocation.current().displayName(arabicUI: isArabicUI)
        return name.isEmpty ? nil : name
    }

    /// One coarse fix, resolved against the bundled database. Never leaves
    /// the spinner running: every branch clears `locating`.
    private func locate() {
        locateProblem = nil
        locating = true
        Task {
            let outcome = await fetcher.fetchDetailed()
            switch outcome {
            case .coordinate(let coordinate):
                if let db,
                   let city = (try? db.nearest(latitude: coordinate.latitude,
                                               longitude: coordinate.longitude,
                                               limit: 1))?.first {
                    PrayerLocation.saveCustom(latitude: coordinate.latitude,
                                              longitude: coordinate.longitude,
                                              label: city.name,
                                              labelArabic: city.nameArabic)
                    useCustomLocation = true
                    locatedName = city.displayName(arabicUI: isArabicUI)
                    // Nearby has a fix to work from now.
                    loadSuggestions()
                } else {
                    // A fix we cannot name is not a location the reader can
                    // confirm, so say so and leave the search field to them.
                    locateProblem = .noCityNearby
                }
            case .failure(let failure):
                locateProblem = CityLocateProblem(failure)
            }
            locating = false
        }
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
    @State private var query = ""
    @Environment(\.locale) private var locale

    /// Search stays available inside a country, filtering that country's cities.
    private var shown: [City] {
        let q = CityDatabase.fold(query)
        guard !q.isEmpty else { return cities }
        let arabic = CityDatabase.containsArabic(query)
        return cities.filter {
            arabic ? ($0.nameArabic?.contains(query.trimmingCharacters(in: .whitespaces)) ?? false)
                   : CityDatabase.fold($0.name).contains(q)
        }
    }

    var body: some View {
        List {
            CityRows(cities: shown, select: select, isSelected: isSelected)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(NoorColor.bgPrimary)
        .searchable(text: $query, prompt: Text("Search city"))
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

/// Everything that can go wrong when asking the device where it is, and
/// what the reader is told. A silent failure here is the bug this screen
/// has shipped before, so every case carries a sentence.
enum CityLocateProblem: Equatable {
    case denied, restricted, servicesOff, noFix, noCityNearby

    init(_ failure: LocationFixFailure) {
        switch failure {
        case .permissionDenied: self = .denied
        case .permissionRestricted: self = .restricted
        case .servicesOff: self = .servicesOff
        case .noFix: self = .noFix
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .denied: "Allow location access in Settings, or pick a city manually."
        case .restricted: "Location access is restricted on this device. Pick a city manually."
        case .servicesOff: "Location Services are off. Turn them on in Settings, or pick a city manually."
        case .noFix: "Couldn't get your location. Try again, or pick a city manually."
        case .noCityNearby: "No city found near your location. Search for the nearest city."
        }
    }

    /// Only offer Settings where Settings can actually fix it — a restricted
    /// device (Screen Time, MDM) has no switch for the reader to flip.
    var offersSettings: Bool { self == .denied || self == .servicesOff }
}

/// The four things the auto-locate row can be showing.
enum CityLocateState: Equatable {
    case idle
    case locating
    /// A device fix is in use, named from the offline database when known.
    case located(String?)
    case problem(CityLocateProblem)
}

/// "Use my current location", with its outcome underneath. A separate view
/// so every state can be rendered on its own (previews, snapshot checks)
/// instead of only after a real fix on a real device.
struct CityLocateRow: View {
    let state: CityLocateState
    let action: () -> Void

    private var isLocated: Bool {
        if case .located = state { return true }
        return false
    }

    private var cityName: String? {
        if case .located(let name) = state { return name }
        return nil
    }

    private var problem: CityLocateProblem? {
        if case .problem(let problem) = state { return problem }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: isLocated ? "location.fill" : "location")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NoorColor.accentPrimary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(isLocated ? "Using current location" : "Use my current location")
                            .font(NoorFont.body)
                            .foregroundStyle(NoorColor.accentPrimary)
                        if let cityName {
                            Text("Near \(cityName)")
                                .font(NoorFont.caption)
                                .foregroundStyle(NoorColor.inkSecondary)
                        }
                    }
                    Spacer(minLength: 8)
                    if state == .locating {
                        ProgressView()
                            #if os(iOS)
                            .controlSize(.small)
                            #endif
                    } else if isLocated {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(NoorColor.accentPrimary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(NoorColor.stateReciting))
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(state == .locating)
            .accessibilityLabel(state == .locating
                                ? Text("Locating…")
                                : Text(isLocated ? "Using current location"
                                                 : "Use my current location"))
            .accessibilityValue(cityName.map { Text("Near \($0)") } ?? Text(verbatim: ""))
            .accessibilityAddTraits(.isButton)
            if let problem {
                VStack(alignment: .leading, spacing: 2) {
                    Text(problem.message)
                        .font(NoorFont.caption)
                        .foregroundStyle(NoorColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    #if os(iOS)
                    if problem.offersSettings {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Open Settings")
                                .font(NoorFont.caption)
                                .foregroundStyle(NoorColor.accentPrimary)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    #endif
                }
            }
        }
    }
}

#Preview("Locate row states") {
    VStack(spacing: 14) {
        CityLocateRow(state: .idle) {}
        CityLocateRow(state: .locating) {}
        CityLocateRow(state: .located("Cairo")) {}
        CityLocateRow(state: .problem(.denied)) {}
        CityLocateRow(state: .problem(.restricted)) {}
        CityLocateRow(state: .problem(.servicesOff)) {}
        CityLocateRow(state: .problem(.noFix)) {}
        CityLocateRow(state: .problem(.noCityNearby)) {}
    }
    .padding(16)
    .background(NoorColor.bgPrimary)
}

#Preview("Locate row states — Arabic RTL") {
    VStack(spacing: 14) {
        CityLocateRow(state: .located("القاهرة")) {}
        CityLocateRow(state: .problem(.denied)) {}
        CityLocateRow(state: .problem(.noCityNearby)) {}
    }
    .padding(16)
    .background(NoorColor.bgPrimary)
    .environment(\.locale, Locale(identifier: "ar"))
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview {
    NavigationStack { CityPickerView() }
}

#Preview("Arabic RTL") {
    NavigationStack { CityPickerView() }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}
