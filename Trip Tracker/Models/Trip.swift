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
        favorite: Bool = false
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
    }
}

extension Trip {
    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }
}
