import Foundation
import SwiftData

@Model
final class Trip {
    var title: String = ""
    var destinationName: String = ""
    var country: String = ""
    var startDate: Date = Date()
    var endDate: Date? = nil
    var notes: String? = nil
    var tags: [String] = []
    @Attribute(.externalStorage) var photos: [Data]? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var rating: Int? = nil
    var favorite: Bool = false
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \TripStop.trip) var stops: [TripStop] = []

    init(
        title: String,
        destinationName: String,
        country: String,
        startDate: Date,
        endDate: Date? = nil,
        notes: String? = nil,
        tags: [String] = [],
        photos: [Data]? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        rating: Int? = nil,
        favorite: Bool = false,
        stops: [TripStop] = []
    ) {
        self.title = title
        self.destinationName = destinationName
        self.country = country
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.tags = tags
        self.photos = photos
        self.latitude = latitude
        self.longitude = longitude
        self.rating = rating
        self.favorite = favorite
        self.createdAt = Date()
        self.stops = stops
    }
}

extension Trip {
    var orderedStops: [TripStop] {
        stops.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.occurredAt < $1.occurredAt
            }
            return $0.sortOrder < $1.sortOrder
        }
    }

    var stopSummaries: [TripStopSummary] {
        if !orderedStops.isEmpty {
            return orderedStops.map { stop in
                TripStopSummary(
                    id: String(describing: stop.persistentModelID),
                    trip: self,
                    destinationName: stop.destinationName,
                    country: stop.country,
                    occurredAt: stop.occurredAt,
                    notes: stop.notes,
                    journal: stop.journal,
                    arrivalMode: stop.arrivalMode,
                    photos: stop.photos ?? [],
                    latitude: stop.latitude,
                    longitude: stop.longitude,
                    sortOrder: stop.sortOrder,
                    isLegacy: false
                )
            }
        }

        guard hasLegacyLocationData else { return [] }

        return [
            TripStopSummary(
                id: "legacy-\(String(describing: persistentModelID))",
                trip: self,
                destinationName: destinationName,
                country: country,
                occurredAt: startDate,
                notes: nil,
                journal: nil,
                arrivalMode: nil,
                photos: [],
                latitude: latitude,
                longitude: longitude,
                sortOrder: 0,
                isLegacy: true
            )
        ]
    }

    var hasLegacyLocationData: Bool {
        !destinationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || latitude != nil
        || longitude != nil
    }

    var hasCoordinates: Bool {
        mapStopSummaries.contains { $0.hasCoordinates }
    }

    var mapStopSummaries: [TripStopSummary] {
        stopSummaries.filter { $0.hasCoordinates }
    }

    var previewPhotoData: Data? {
        if let firstTripPhoto = (photos ?? []).first {
            return firstTripPhoto
        }
        return stopSummaries.lazy.compactMap { $0.photos.first }.first
    }

    var hasAnyPhotos: Bool {
        !(photos ?? []).isEmpty || stopSummaries.contains { !$0.photos.isEmpty }
    }

    var earliestStopJournalExcerpt: String? {
        let maxLength = 80
        for summary in stopSummaries {
            let trimmed = (summary.journal ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.count <= maxLength {
                return trimmed
            }
            let endIndex = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
            let truncated = String(trimmed[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            return truncated + "…"
        }
        return nil
    }

    var timelineSubtitle: String? {
        let trimmedNotes = (notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            return trimmedNotes
        }
        return earliestStopJournalExcerpt
    }

    var stopCountLabel: String {
        let count = stopSummaries.count
        return count == 1 ? "1 stop" : "\(count) stops"
    }

    var displayDestinationSummary: String {
        let labels = stopSummaries
            .map(\.locationLabel)
            .filter { !$0.isEmpty }

        if labels.isEmpty {
            return [destinationName, country]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        }

        if labels.count == 1 {
            return labels[0]
        }

        let first = labels[0]
        let last = labels[labels.count - 1]
        if first == last {
            return "\(first) · \(labels.count) stops"
        }
        return "\(first) -> \(last) · \(labels.count) stops"
    }

    var countryValues: [String] {
        let stopCountries = stopSummaries
            .map(\.country)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !stopCountries.isEmpty {
            return orderedUnique(stopCountries)
        }

        let legacyCountry = country.trimmingCharacters(in: .whitespacesAndNewlines)
        return legacyCountry.isEmpty ? [] : [legacyCountry]
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for value in values where seen.insert(value.lowercased()).inserted {
            result.append(value)
        }

        return result
    }
}
