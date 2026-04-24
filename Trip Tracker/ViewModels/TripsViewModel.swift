import Foundation

enum TripSortMode: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case longest
    case highestRated

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: "Newest first"
        case .oldest: "Oldest first"
        case .longest: "Longest trip"
        case .highestRated: "Highest rated"
        }
    }
}

enum TripFilter: String, CaseIterable, Identifiable {
    case all
    case favorites
    case thisYear
    case withPhotos

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All"
        case .favorites: "Favorites"
        case .thisYear: "This year"
        case .withPhotos: "With photos"
        }
    }
}

@Observable
final class TripsViewModel {
    var searchQuery: String = ""
    var sortMode: TripSortMode = .newest
    var filter: TripFilter = .all
    var tagFilters: Set<String> = []
    var companionFilters: Set<String> = []

    var hasActiveFilters: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || filter != .all
        || !tagFilters.isEmpty
        || !companionFilters.isEmpty
    }

    func clearAll() {
        searchQuery = ""
        filter = .all
        tagFilters = []
        companionFilters = []
    }

    func matches(_ trip: Trip) -> Bool {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            let stopHaystack = trip.stopSummaries
                .map { summary in
                    [
                        summary.destinationName,
                        summary.country,
                        summary.notes ?? ""
                    ]
                    .joined(separator: " ")
                }
                .joined(separator: " ")
            let haystack = [
                trip.title,
                trip.displayDestinationSummary,
                trip.journeyEndpointSummary ?? "",
                trip.notes ?? "",
                trip.tags.joined(separator: " "),
                trip.companions.joined(separator: " "),
                stopHaystack
            ]
            .joined(separator: " ")
            .lowercased()
            if !haystack.contains(query) { return false }
        }

        switch filter {
        case .all:
            break
        case .favorites:
            if !trip.favorite { return false }
        case .thisYear:
            let cal = Calendar.current
            let currentYear = cal.component(.year, from: Date())
            let tripYear = cal.component(.year, from: trip.startDate)
            if tripYear != currentYear { return false }
        case .withPhotos:
            if !trip.hasAnyPhotos { return false }
        }

        if !tagFilters.isEmpty {
            let tripTags = Set(trip.tags.map { $0.lowercased() })
            let required = Set(tagFilters.map { $0.lowercased() })
            if !required.isSubset(of: tripTags) { return false }
        }

        if !companionFilters.isEmpty {
            let tripCompanions = Set(trip.companions.map { $0.lowercased() })
            let required = Set(companionFilters.map { $0.lowercased() })
            if !required.isSubset(of: tripCompanions) { return false }
        }

        return true
    }

    func sorted(_ trips: [Trip]) -> [Trip] {
        switch sortMode {
        case .newest:
            return trips.sorted { $0.startDate > $1.startDate }
        case .oldest:
            return trips.sorted { $0.startDate < $1.startDate }
        case .longest:
            return trips.sorted { duration(of: $0) > duration(of: $1) }
        case .highestRated:
            return trips.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
        }
    }

    private func duration(of trip: Trip) -> TimeInterval {
        let end = trip.endDate ?? trip.startDate
        return end.timeIntervalSince(trip.startDate)
    }
}
