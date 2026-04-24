import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
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
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    StatTile(value: "\(trips.count)", label: "Trips")
                    StatTile(value: "\(countryCount)", label: "Countries")
                    StatTile(value: "\(favoriteCount)", label: "Favorites")
                    StatTile(value: latestYearLabel, label: "Latest year")
                }

                Text(summaryMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
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

    private var countryCount: Int {
        Set(
            trips
                .map(\.country)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        ).count
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
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let context = container.mainContext
    context.insert(
        Trip(
            title: "Mexico City Weekend",
            destinationName: "Mexico City",
            country: "Mexico",
            startDate: .now.addingTimeInterval(-60 * 60 * 24 * 40),
            favorite: true
        )
    )
    context.insert(
        Trip(
            title: "Berlin Summer",
            destinationName: "Berlin",
            country: "Germany",
            startDate: .now.addingTimeInterval(-60 * 60 * 24 * 420)
        )
    )

    return StatsView()
        .modelContainer(container)
}

#Preview("Empty Stats") {
    StatsView()
        .modelContainer(for: Trip.self, inMemory: true)
}
