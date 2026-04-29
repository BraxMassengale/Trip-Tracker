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
    var companions: [String] = []
    @Attribute(.externalStorage) var photos: [Data]? = nil
    var photoIDs: [UUID] = []
    var heroPhotoID: UUID? = nil
    var startLocationName: String = ""
    var startLocationCountry: String = ""
    var startLatitude: Double? = nil
    var startLongitude: Double? = nil
    var endLocationName: String = ""
    var endLocationCountry: String = ""
    var endLatitude: Double? = nil
    var endLongitude: Double? = nil
    var returnsToStart: Bool = false
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
        companions: [String] = [],
        photos: [Data]? = nil,
        photoIDs: [UUID] = [],
        heroPhotoID: UUID? = nil,
        startLocationName: String = "",
        startLocationCountry: String = "",
        startLatitude: Double? = nil,
        startLongitude: Double? = nil,
        endLocationName: String = "",
        endLocationCountry: String = "",
        endLatitude: Double? = nil,
        endLongitude: Double? = nil,
        returnsToStart: Bool = false,
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
        self.companions = companions
        self.photos = photos
        self.photoIDs = photoIDs
        self.heroPhotoID = heroPhotoID
        self.startLocationName = startLocationName
        self.startLocationCountry = startLocationCountry
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLocationName = endLocationName
        self.endLocationCountry = endLocationCountry
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.returnsToStart = returnsToStart
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
                    photoIDs: stop.photoIDs,
                    heroPhotoID: stop.heroPhotoID,
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
                photoIDs: [],
                heroPhotoID: nil,
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
        mapJourneyLocations.contains { $0.hasCoordinates }
    }

    var mapStopSummaries: [TripStopSummary] {
        stopSummaries.filter { $0.hasCoordinates }
    }

    var startLocation: TripLocation? {
        location(
            name: startLocationName,
            country: startLocationCountry,
            latitude: startLatitude,
            longitude: startLongitude
        )
    }

    var endLocation: TripLocation? {
        if returnsToStart, let startLocation {
            return startLocation
        }

        return location(
            name: endLocationName,
            country: endLocationCountry,
            latitude: endLatitude,
            longitude: endLongitude
        )
    }

    var mapJourneyLocations: [TripJourneyLocation] {
        journeyLocations.filter(\.hasCoordinates)
    }

    var journeyLocations: [TripJourneyLocation] {
        var locations: [TripJourneyLocation] = []

        if let startLocation {
            locations.append(TripJourneyLocation(
                id: "start-\(String(describing: persistentModelID))",
                trip: self,
                location: startLocation,
                date: startDate,
                arrivalMode: nil,
                kind: .start
            ))
        }

        locations.append(contentsOf: stopSummaries.compactMap { summary in
            guard let location = summary.location else { return nil }
            return TripJourneyLocation(
                id: "stop-\(summary.id)",
                trip: self,
                location: location,
                date: summary.occurredAt,
                arrivalMode: summary.arrivalMode,
                kind: .stop
            )
        })

        if let endLocation {
            locations.append(TripJourneyLocation(
                id: "end-\(String(describing: persistentModelID))",
                trip: self,
                location: endLocation,
                date: endDate ?? stopSummaries.last?.occurredAt ?? startDate,
                arrivalMode: nil,
                kind: .end
            ))
        }

        return locations
    }

    var journeyEndpointSummary: String? {
        let start = startLocation?.shortLabel
        let end = endLocation?.shortLabel

        switch (start, end) {
        case let (.some(start), .some(end)):
            return "\(start) -> \(end)"
        case let (.some(start), .none):
            return "Starts in \(start)"
        case let (.none, .some(end)):
            return "Ends in \(end)"
        case (.none, .none):
            return nil
        }
    }

    func setStartLocation(_ location: TripLocation?) {
        startLocationName = location?.destinationName ?? ""
        startLocationCountry = location?.country ?? ""
        startLatitude = location?.latitude
        startLongitude = location?.longitude
    }

    func setEndLocation(_ location: TripLocation?) {
        endLocationName = location?.destinationName ?? ""
        endLocationCountry = location?.country ?? ""
        endLatitude = location?.latitude
        endLongitude = location?.longitude
    }

    var previewPhotoData: Data? {
        if let tripHeroPhotoData {
            return tripHeroPhotoData
        }
        return stopSummaries.lazy.compactMap(\.heroPhotoData).first
    }

    var tripHeroPhotoData: Data? {
        let currentPhotos = photos ?? []
        let currentPhotoIDs = PhotoSelection.normalizedIDs(for: currentPhotos, existingIDs: photoIDs)
        return PhotoSelection.heroPhotoData(
            photos: currentPhotos,
            photoIDs: currentPhotoIDs,
            heroPhotoID: heroPhotoID
        )
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

    private func location(
        name: String,
        country: String,
        latitude: Double?,
        longitude: Double?
    ) -> TripLocation? {
        guard let latitude, let longitude else { return nil }
        return TripLocation(
            latitude: latitude,
            longitude: longitude,
            destinationName: name,
            country: country
        )
    }
}
