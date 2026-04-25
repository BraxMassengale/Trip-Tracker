import SwiftUI
import SwiftData

struct TimelineView: View {
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]

    private let spineLeading: CGFloat = 28
    private let cardLeading: CGFloat = 64

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    emptyState
                } else {
                    timelineScroll
                }
            }
            .background(AppTheme.ColorToken.canvas)
            .navigationTitle("Timeline")
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip)
            }
        }
    }

    private var timelineScroll: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(yearGroups, id: \.year) { group in
                    Section {
                        yearBody(for: group)
                    } header: {
                        yearHeader(for: group)
                    }
                }
            }
            .padding(.bottom, 48)
        }
    }

    private func yearBody(for group: YearGroup) -> some View {
        ZStack(alignment: .topLeading) {
            spine(dimmed: group.trips.isEmpty)

            Text(String(group.year))
                .font(.system(size: 168, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ColorToken.ink.opacity(0.10))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.leading, cardLeading - 12)
                .padding(.trailing, 8)
                .padding(.top, -10)
                .accessibilityHidden(true)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 24) {
                if group.trips.isEmpty {
                    emptyYearMarker
                } else {
                    ForEach(group.trips) { trip in
                        tripRow(for: trip)
                    }
                }
            }
            .padding(.leading, cardLeading)
            .padding(.trailing, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }

    private func spine(dimmed: Bool) -> some View {
        let baseOpacity = dimmed ? 0.18 : 0.55
        let trailOpacity = dimmed ? 0.08 : 0.25

        return LinearGradient(
            colors: [
                AppTheme.ColorToken.accent.opacity(baseOpacity),
                AppTheme.ColorToken.accent.opacity(trailOpacity)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 2)
        .padding(.leading, spineLeading)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func tripRow(for trip: Trip) -> some View {
        ZStack(alignment: .topLeading) {
            spineMarker
                .offset(x: spineLeading - 6, y: 16)

            NavigationLink(value: trip) {
                TripTimelineCard(trip: trip)
            }
            .buttonStyle(.plain)
        }
    }

    private var spineMarker: some View {
        ZStack {
            Circle()
                .fill(AppTheme.ColorToken.canvas)
                .frame(width: 14, height: 14)
            Circle()
                .stroke(AppTheme.ColorToken.accent, lineWidth: 2)
                .frame(width: 14, height: 14)
            Circle()
                .fill(AppTheme.ColorToken.accent)
                .frame(width: 6, height: 6)
        }
    }

    private var emptyYearMarker: some View {
        HStack(spacing: 12) {
            Text("No trips this year")
                .font(.footnote.italic())
                .foregroundStyle(AppTheme.ColorToken.secondaryInk.opacity(0.7))
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func yearHeader(for group: YearGroup) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(String(group.year))
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.ColorToken.ink)
            statChip(for: group)
            Spacer(minLength: 0)
        }
        .padding(.leading, cardLeading)
        .padding(.trailing, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Rectangle()
                .fill(AppTheme.ColorToken.canvas)
                .ignoresSafeArea(edges: .horizontal)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.ColorToken.cardBorder.opacity(0.4))
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func statChip(for group: YearGroup) -> some View {
        if group.trips.isEmpty {
            Text("Quiet year")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(AppTheme.ColorToken.cardFill))
                .overlay(Capsule().stroke(AppTheme.ColorToken.cardBorder, lineWidth: 1))
        } else {
            Text(group.statSummary)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.ColorToken.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(AppTheme.ColorToken.accentSoft))
        }
    }

    private struct YearGroup {
        let year: Int
        let trips: [Trip]

        var statSummary: String {
            let tripsLabel = trips.count == 1 ? "1 trip" : "\(trips.count) trips"

            var countries: Set<String> = []
            for trip in trips {
                for value in trip.countryValues {
                    countries.insert(value.lowercased())
                }
            }
            let countriesLabel = countries.count == 1 ? "1 country" : "\(countries.count) countries"

            let calendar = Calendar.current
            var travelDays = 0
            for trip in trips {
                let start = calendar.startOfDay(for: trip.startDate)
                let end = calendar.startOfDay(for: trip.endDate ?? trip.startDate)
                let days = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
                travelDays += max(1, days)
            }
            let daysLabel = travelDays == 1 ? "1 travel day" : "\(travelDays) travel days"

            if countries.isEmpty {
                return "\(tripsLabel) · \(daysLabel)"
            }
            return "\(tripsLabel) · \(countriesLabel) · \(daysLabel)"
        }
    }

    private var yearGroups: [YearGroup] {
        let calendar = Calendar.current
        let buckets = Dictionary(grouping: trips) { trip in
            calendar.component(.year, from: trip.startDate)
        }

        guard let earliestYear = buckets.keys.min(),
              let latestYear = buckets.keys.max() else {
            return []
        }

        var groups: [YearGroup] = []
        for year in (earliestYear...latestYear).reversed() {
            let trips = (buckets[year] ?? []).sorted { $0.startDate > $1.startDate }
            groups.append(YearGroup(year: year, trips: trips))
        }
        return groups
    }

    private var emptyState: some View {
        ScrollView {
            SectionCard(
                title: "Your timeline is waiting",
                subtitle: "Each trip you save will drop into a year-by-year story here."
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "clock")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)

                    Text("Once you add your first trip, this screen becomes the long view of where you've been.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
    }
}
