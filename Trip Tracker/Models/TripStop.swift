import Foundation
import SwiftData

@Model
final class TripStop {
    var destinationName: String = ""
    var country: String = ""
    var occurredAt: Date = Date()
    var notes: String? = nil
    var journal: String? = nil
    @Attribute(.externalStorage) var photos: [Data]? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var sortOrder: Int = 0
    var trip: Trip? = nil

    init(
        destinationName: String,
        country: String,
        occurredAt: Date,
        notes: String? = nil,
        journal: String? = nil,
        photos: [Data]? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        sortOrder: Int = 0
    ) {
        self.destinationName = destinationName
        self.country = country
        self.occurredAt = occurredAt
        self.notes = notes
        self.journal = journal
        self.photos = photos
        self.latitude = latitude
        self.longitude = longitude
        self.sortOrder = sortOrder
    }
}

struct TripStopSummary: Identifiable {
    let id: String
    let trip: Trip
    let destinationName: String
    let country: String
    let occurredAt: Date
    let notes: String?
    let journal: String?
    let photos: [Data]
    let latitude: Double?
    let longitude: Double?
    let sortOrder: Int
    let isLegacy: Bool

    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    var locationLabel: String {
        [destinationName, country]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
