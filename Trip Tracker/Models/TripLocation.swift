import CoreLocation
import Foundation

struct TripLocation: Equatable, Hashable {
    var latitude: Double
    var longitude: Double
    var destinationName: String
    var country: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var locationLabel: String {
        [destinationName, country]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var shortLabel: String {
        let trimmedName = destinationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }

        let trimmedCountry = country.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCountry.isEmpty ? "Location" : trimmedCountry
    }
}

enum TripJourneyLocationKind {
    case start
    case stop
    case end
}

struct TripJourneyLocation: Identifiable {
    let id: String
    let trip: Trip
    let location: TripLocation
    let date: Date
    let arrivalMode: TransportMode?
    let kind: TripJourneyLocationKind

    var hasCoordinates: Bool {
        true
    }

    var locationLabel: String {
        location.locationLabel
    }

    var title: String {
        switch kind {
        case .start:
            "Start"
        case .stop:
            location.shortLabel
        case .end:
            "End"
        }
    }
}
