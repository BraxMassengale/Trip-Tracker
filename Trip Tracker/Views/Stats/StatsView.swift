import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]
    @Bindable var tripsViewModel: TripsViewModel
    @Binding var selectedTab: RootTab

    @State private var passportSort: PassportSort = .firstVisit

    private let summaryColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private let passportColumns = [
        GridItem(.adaptive(minimum: 96, maximum: 140), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    heroCard
                    passportCard
                    continentCard
                    topCitiesCard
                    companionsCard
                    yearlyBreakdownCard
                }
                .padding()
            }
            .background(AppTheme.ColorToken.canvas)
            .navigationTitle("Stats")
        }
    }

    private var summaryCard: some View {
        SectionCard(
            title: trips.isEmpty ? "Your journal at a glance" : "Trip snapshot",
            subtitle: trips.isEmpty
                ? "A few simple numbers will start showing up as you log places."
                : "A lightweight look at the trips you've saved."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: summaryColumns, spacing: 12) {
                    StatTile(value: "\(trips.count)", label: "Trips")
                    StatTile(value: "\(visitedCountries.count)", label: "Countries")
                    StatTile(value: "\(favoriteCount)", label: "Favorites")
                    StatTile(value: latestYearLabel, label: "Latest year")
                }

                Text(summaryMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            }
        }
    }

    @ViewBuilder
    private var heroCard: some View {
        let countries = visitedCountries
        let continents = Set(countries.compactMap { $0.record?.continent })

        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                if countries.isEmpty {
                    Text("No countries logged yet")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ColorToken.ink)
                    Text("Add a stop with a country and your passport starts filling out.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                } else {
                    Text(heroNumberLine(countries: countries.count, continents: continents.count))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ColorToken.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    if let latest = countries.max(by: { $0.firstVisit < $1.firstVisit }) {
                        let calendar = Calendar.current
                        let year = calendar.component(.year, from: latest.firstVisit)
                        Text("Most recent first-time visit: \(latest.displayName) · \(String(year))")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    }
                }
            }
        }
    }

    private func heroNumberLine(countries: Int, continents: Int) -> String {
        let countryLabel = countries == 1 ? "1 country" : "\(countries) countries"
        if continents == 0 {
            return countryLabel
        }
        let continentLabel = continents == 1 ? "1 continent" : "\(continents) continents"
        return "\(countryLabel) across \(continentLabel)."
    }

    @ViewBuilder
    private var passportCard: some View {
        let countries = visitedCountries
        let sorted = sortPassport(countries)

        SectionCard(
            title: "Passport stamps",
            subtitle: countries.isEmpty
                ? "Each country you log gets a stamp here."
                : "Tap a stamp to filter your trips by that country."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if !countries.isEmpty {
                    Picker("Sort", selection: $passportSort) {
                        ForEach(PassportSort.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if countries.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                        Text("No country stamps yet — add country names on your stops to start.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LazyVGrid(columns: passportColumns, spacing: 12) {
                        ForEach(sorted) { country in
                            PassportStampTile(country: country) {
                                applyCountryFilter(country)
                            }
                        }
                    }
                }
            }
        }
    }

    private func applyCountryFilter(_ country: VisitedCountry) {
        Haptics.selection()
        tripsViewModel.setCountryFilter(country.filterValue)
        selectedTab = .trips
    }

    @ViewBuilder
    private var continentCard: some View {
        let breakdown = continentBreakdown

        SectionCard(
            title: "Continents",
            subtitle: breakdown.isEmpty
                ? "Continents will fill in as countries are logged."
                : "Where your country stamps land."
        ) {
            if breakdown.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "globe.europe.africa")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    Text("No continent data yet.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ContinentStackedBar(slices: breakdown)
                        .frame(height: 16)

                    VStack(spacing: 8) {
                        ForEach(breakdown, id: \.continent) { slice in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(slice.continent.color)
                                    .frame(width: 10, height: 10)
                                Text(slice.continent.label)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.ColorToken.ink)
                                Spacer()
                                Text(slice.count == 1 ? "1 country" : "\(slice.count) countries")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var topCitiesCard: some View {
        let cities = topCities

        SectionCard(
            title: "Most-visited places",
            subtitle: cities.isEmpty
                ? "Stops you log will rise to the top of this list."
                : "Cities and stops where you've spent the most time."
        ) {
            if cities.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    Text("Add stops to start ranking your most-visited places.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(cities.enumerated()), id: \.element.id) { index, city in
                        HStack(alignment: .center, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(AppTheme.ColorToken.accent)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(AppTheme.ColorToken.accentSoft))
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    if let flag = city.flag {
                                        Text(flag)
                                    }
                                    Text(city.cityName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.ColorToken.ink)
                                }
                                if !city.country.isEmpty {
                                    Text(city.country)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                                }
                            }
                            Spacer()
                            Text(city.visits == 1 ? "1 visit" : "\(city.visits) visits")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.ColorToken.canvas)
                        )
                    }
                }
            }
        }
    }

    private var yearlyBreakdownCard: some View {
        SectionCard(
            title: "Trips by year",
            subtitle: trips.isEmpty
                ? "Once you add trips, this timeline summary will fill in."
                : "A simple year-by-year breakdown."
        ) {
            if tripsByYear.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("0 trips")
                                .font(.headline)
                                .foregroundStyle(AppTheme.ColorToken.ink)
                            Text("0 countries")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                        }
                    }

                    Text("Your travel patterns will start to take shape here after your first entries.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(tripsByYear, id: \.year) { item in
                        HStack {
                            Text(String(item.year))
                                .font(.headline)
                                .foregroundStyle(AppTheme.ColorToken.ink)
                            Spacer()
                            Text(item.count == 1 ? "1 trip" : "\(item.count) trips")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.ColorToken.canvas)
                        )
                    }
                }
            }
        }
    }

    private var companionsCard: some View {
        SectionCard(
            title: "Most traveled with",
            subtitle: companionFrequencies.isEmpty
                ? "Travel partners will appear here as you add them."
                : "The people showing up across your saved trips."
        ) {
            if companionFrequencies.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "person.2")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No companions yet")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ColorToken.ink)
                        Text("Add travel partners from a trip form.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(companionFrequencies.prefix(6), id: \.name) { item in
                        HStack {
                            Text(item.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.ColorToken.ink)
                            Spacer()
                            Text(item.count == 1 ? "1 trip" : "\(item.count) trips")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.ColorToken.canvas)
                        )
                    }
                }
            }
        }
    }

    private var favoriteCount: Int {
        trips.filter(\.favorite).count
    }

    private var latestYearLabel: String {
        guard let latest = trips.max(by: { $0.startDate < $1.startDate }) else {
            return "—"
        }
        return String(Calendar.current.component(.year, from: latest.startDate))
    }

    private var summaryMessage: String {
        if trips.isEmpty {
            return "Add your first trip and you'll start seeing totals, places visited, and yearly patterns."
        }

        if let busiestYear = tripsByYear.max(by: { $0.count < $1.count }) {
            return busiestYear.count == 1
                ? "So far each saved year has a single trip, keeping your timeline nice and balanced."
                : "\(busiestYear.year) is your busiest saved year so far with \(busiestYear.count) trips."
        }

        return "Your stats will keep filling out as you add more trips."
    }

    private var tripsByYear: [(year: Int, count: Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: trips) { trip in
            calendar.component(.year, from: trip.startDate)
        }

        return grouped
            .map { (year: $0.key, count: $0.value.count) }
            .sorted { $0.year > $1.year }
    }

    private var companionFrequencies: [(name: String, count: Int)] {
        var displayNamesByKey: [String: String] = [:]
        var countsByKey: [String: Int] = [:]

        for trip in trips {
            let uniqueCompanions = Set(trip.companions.map { $0.lowercased() })
            for key in uniqueCompanions {
                guard let displayName = trip.companions.first(where: { $0.lowercased() == key }) else {
                    continue
                }
                displayNamesByKey[key] = displayNamesByKey[key] ?? displayName
                countsByKey[key, default: 0] += 1
            }
        }

        return countsByKey
            .map { key, count in
                (name: displayNamesByKey[key] ?? key, count: count)
            }
            .sorted {
                if $0.count == $1.count {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.count > $1.count
            }
    }

    private var visitedCountries: [VisitedCountry] {
        var byKey: [String: VisitedCountry] = [:]

        for trip in trips {
            for entry in tripCountryEntries(trip) {
                let key = entry.key
                if let existing = byKey[key] {
                    let earlier = min(existing.firstVisit, entry.date)
                    byKey[key] = VisitedCountry(
                        key: existing.key,
                        record: existing.record,
                        rawName: existing.rawName,
                        firstVisit: earlier
                    )
                } else {
                    byKey[key] = VisitedCountry(
                        key: key,
                        record: entry.record,
                        rawName: entry.rawName,
                        firstVisit: entry.date
                    )
                }
            }
        }

        return Array(byKey.values)
    }

    private func tripCountryEntries(_ trip: Trip) -> [(key: String, rawName: String, record: CountryRecord?, date: Date)] {
        var entries: [(key: String, rawName: String, record: CountryRecord?, date: Date)] = []

        for summary in trip.stopSummaries {
            let trimmed = summary.country.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let record = CountryCatalog.record(forCountryName: trimmed)
            let key = record?.isoCode ?? trimmed.lowercased()
            entries.append((key: key, rawName: trimmed, record: record, date: summary.occurredAt))
        }

        if entries.isEmpty {
            let trimmed = trip.country.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let record = CountryCatalog.record(forCountryName: trimmed)
                let key = record?.isoCode ?? trimmed.lowercased()
                entries.append((key: key, rawName: trimmed, record: record, date: trip.startDate))
            }
        }

        return entries
    }

    private func sortPassport(_ countries: [VisitedCountry]) -> [VisitedCountry] {
        switch passportSort {
        case .firstVisit:
            return countries.sorted {
                if $0.firstVisit == $1.firstVisit {
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                return $0.firstVisit > $1.firstVisit
            }
        case .alphabetical:
            return countries.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
    }

    private var continentBreakdown: [ContinentSlice] {
        var counts: [Continent: Int] = [:]
        for country in visitedCountries {
            guard let continent = country.record?.continent else { continue }
            counts[continent, default: 0] += 1
        }
        return Continent.allCases
            .compactMap { continent -> ContinentSlice? in
                guard let count = counts[continent], count > 0 else { return nil }
                return ContinentSlice(continent: continent, count: count)
            }
            .sorted { $0.count > $1.count }
    }

    private var topCities: [TopCity] {
        var byKey: [String: TopCity] = [:]

        for trip in trips {
            for summary in trip.stopSummaries {
                let trimmedCity = summary.destinationName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedCity.isEmpty else { continue }
                let trimmedCountry = summary.country.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = "\(trimmedCity.lowercased())|\(trimmedCountry.lowercased())"
                if let existing = byKey[key] {
                    byKey[key] = TopCity(
                        id: existing.id,
                        cityName: existing.cityName,
                        country: existing.country,
                        flag: existing.flag,
                        visits: existing.visits + 1
                    )
                } else {
                    byKey[key] = TopCity(
                        id: key,
                        cityName: trimmedCity,
                        country: trimmedCountry,
                        flag: CountryFlag.emoji(for: trimmedCountry),
                        visits: 1
                    )
                }
            }
        }

        return byKey.values
            .sorted {
                if $0.visits == $1.visits {
                    return $0.cityName.localizedCaseInsensitiveCompare($1.cityName) == .orderedAscending
                }
                return $0.visits > $1.visits
            }
            .prefix(5)
            .map { $0 }
    }

    enum PassportSort: String, CaseIterable, Identifiable {
        case firstVisit
        case alphabetical

        var id: String { rawValue }

        var label: String {
            switch self {
            case .firstVisit: "Most recent"
            case .alphabetical: "A → Z"
            }
        }
    }

    struct VisitedCountry: Identifiable, Hashable {
        let key: String
        let record: CountryRecord?
        let rawName: String
        let firstVisit: Date

        var id: String { key }

        var displayName: String {
            record?.name ?? rawName
        }

        var flag: String? {
            record?.flag ?? CountryFlag.emoji(for: rawName)
        }

        var firstVisitYear: Int {
            Calendar.current.component(.year, from: firstVisit)
        }

        var filterValue: String {
            record?.name ?? rawName
        }
    }

    struct ContinentSlice: Hashable {
        let continent: Continent
        let count: Int
    }

    struct TopCity: Identifiable, Hashable {
        let id: String
        let cityName: String
        let country: String
        let flag: String?
        let visits: Int
    }
}

private struct PassportStampTile: View {
    let country: StatsView.VisitedCountry
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(country.flag ?? "🏳️")
                    .font(.system(size: 36))
                Text(country.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.ColorToken.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(String(country.firstVisitYear))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.ColorToken.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.ColorToken.canvas)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.ColorToken.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(country.displayName), first visit \(country.firstVisitYear). Tap to filter trips.")
    }
}

private struct ContinentStackedBar: View {
    let slices: [StatsView.ContinentSlice]

    var body: some View {
        GeometryReader { proxy in
            let total = max(1, slices.reduce(0) { $0 + $1.count })
            HStack(spacing: 2) {
                ForEach(slices, id: \.continent) { slice in
                    let width = proxy.size.width * CGFloat(slice.count) / CGFloat(total)
                    Rectangle()
                        .fill(slice.continent.color)
                        .frame(width: max(width, 6))
                }
            }
            .clipShape(Capsule())
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ColorToken.ink)
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.ColorToken.canvas)
        )
    }
}

#Preview("With Stats") {
    let container = try! ModelContainer(
        for: Trip.self,
        TripStop.self,
        Attachment.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let context = container.mainContext
    context.insert(
        Trip(
            title: "Mexico City Weekend",
            destinationName: "Mexico City",
            country: "Mexico",
            startDate: .now.addingTimeInterval(-60 * 60 * 24 * 40),
            companions: ["Ana", "Mom"],
            favorite: true
        )
    )
    context.insert(
        Trip(
            title: "Berlin Summer",
            destinationName: "Berlin",
            country: "Germany",
            startDate: .now.addingTimeInterval(-60 * 60 * 24 * 420),
            companions: ["Ana"]
        )
    )

    return RootTabView()
        .modelContainer(container)
}

#Preview("Empty Stats") {
    let container = try! ModelContainer(
        for: Trip.self,
        TripStop.self,
        Attachment.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return RootTabView()
        .modelContainer(container)
}
