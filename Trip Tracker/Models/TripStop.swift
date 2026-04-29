import Foundation
import SwiftData

enum TransportMode: String, Codable, CaseIterable, Identifiable {
    case flight
    case train
    case car
    case bus
    case ferry
    case walk
    case bike
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .flight: "Flight"
        case .train: "Train"
        case .car: "Car"
        case .bus: "Bus"
        case .ferry: "Ferry"
        case .walk: "Walk"
        case .bike: "Bike"
        case .other: "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .flight: "airplane"
        case .train: "train.side.front.car"
        case .car: "car.fill"
        case .bus: "bus"
        case .ferry: "ferry"
        case .walk: "figure.walk"
        case .bike: "bicycle"
        case .other: "ellipsis"
        }
    }
}

@Model
final class TripStop {
    var destinationName: String = ""
    var country: String = ""
    var occurredAt: Date = Date()
    var notes: String? = nil
    var journal: String? = nil
    var arrivalMode: TransportMode? = nil
    @Attribute(.externalStorage) var photos: [Data]? = nil
    var photoIDs: [UUID] = []
    var heroPhotoID: UUID? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var sortOrder: Int = 0
    @Relationship(deleteRule: .cascade, inverse: \Attachment.stop) var attachments: [Attachment] = []
    var trip: Trip? = nil

    init(
        destinationName: String,
        country: String,
        occurredAt: Date,
        notes: String? = nil,
        journal: String? = nil,
        arrivalMode: TransportMode? = nil,
        photos: [Data]? = nil,
        photoIDs: [UUID] = [],
        heroPhotoID: UUID? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        sortOrder: Int = 0,
        attachments: [Attachment] = []
    ) {
        self.destinationName = destinationName
        self.country = country
        self.occurredAt = occurredAt
        self.notes = notes
        self.journal = journal
        self.arrivalMode = arrivalMode
        self.photos = photos
        self.photoIDs = photoIDs
        self.heroPhotoID = heroPhotoID
        self.latitude = latitude
        self.longitude = longitude
        self.sortOrder = sortOrder
        self.attachments = attachments
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
    let arrivalMode: TransportMode?
    let photos: [Data]
    let photoIDs: [UUID]
    let heroPhotoID: UUID?
    let latitude: Double?
    let longitude: Double?
    let sortOrder: Int
    let isLegacy: Bool
    let stop: TripStop?

    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    var heroPhotoData: Data? {
        let normalizedIDs = PhotoSelection.normalizedIDs(for: photos, existingIDs: photoIDs)
        return PhotoSelection.heroPhotoData(
            photos: photos,
            photoIDs: normalizedIDs,
            heroPhotoID: heroPhotoID
        )
    }

    var locationLabel: String {
        [destinationName, country]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var location: TripLocation? {
        guard let latitude, let longitude else { return nil }
        return TripLocation(
            latitude: latitude,
            longitude: longitude,
            destinationName: destinationName,
            country: country
        )
    }
}
