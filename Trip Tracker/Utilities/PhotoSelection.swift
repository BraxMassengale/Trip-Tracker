import Foundation

enum PhotoSelection {
    static func normalizedIDs(for photos: [Data], existingIDs: [UUID]) -> [UUID] {
        var ids = Array(existingIDs.prefix(photos.count))

        while ids.count < photos.count {
            ids.append(UUID())
        }

        return ids
    }

    static func heroPhotoData(photos: [Data], photoIDs: [UUID], heroPhotoID: UUID?) -> Data? {
        guard !photos.isEmpty else { return nil }

        if
            let heroPhotoID,
            let index = photoIDs.firstIndex(of: heroPhotoID),
            photos.indices.contains(index)
        {
            return photos[index]
        }

        return photos.first
    }

    static func cleanedHeroPhotoID(_ heroPhotoID: UUID?, photoIDs: [UUID]) -> UUID? {
        guard let heroPhotoID, photoIDs.contains(heroPhotoID) else { return nil }
        return heroPhotoID
    }
}
