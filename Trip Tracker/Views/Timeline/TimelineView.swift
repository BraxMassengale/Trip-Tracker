import SwiftUI
import SwiftData

struct TimelineView: View {
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]

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
            LazyVStack(alignment: .leading, spacing: 24, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedByYear, id: \.year) { group in
                    Section {
                        VStack(spacing: 16) {
                            ForEach(group.trips) { trip in
                                NavigationLink(value: trip) {
                                    TripTimelineCard(trip: trip)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        yearHeader(for: group)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    private struct YearGroup {
        let year: Int
        let trips: [Trip]
    }

    private var groupedByYear: [YearGroup] {
        let calendar = Calendar.current
        let buckets = Dictionary(grouping: trips) { trip in
            calendar.component(.year, from: trip.startDate)
        }
        return buckets
            .map { entry in
                YearGroup(
                    year: entry.key,
                    trips: entry.value.sorted { $0.startDate > $1.startDate }
                )
            }
            .sorted { $0.year > $1.year }
    }

    private func yearHeader(for group: YearGroup) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(String(group.year))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.ColorToken.ink)
            Text(group.trips.count == 1 ? "1 trip" : "\(group.trips.count) trips")
                .font(.subheadline)
                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.ColorToken.canvas)
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
