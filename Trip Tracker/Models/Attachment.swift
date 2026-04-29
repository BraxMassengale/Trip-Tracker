import Foundation
import SwiftData

@Model
final class Attachment {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case file
        case url
        case location

        var id: String { rawValue }

        var label: String {
            switch self {
            case .file: "File"
            case .url: "Link"
            case .location: "Location"
            }
        }

        var symbolName: String {
            switch self {
            case .file: "doc.fill"
            case .url: "link"
            case .location: "mappin.circle.fill"
            }
        }
    }

    var id: UUID = UUID()
    var kind: Kind = Kind.file
    var title: String = ""
    var createdAt: Date = Date()

    @Attribute(.externalStorage) var fileData: Data? = nil
    var fileName: String? = nil
    var mimeType: String? = nil

    var urlString: String? = nil

    var latitude: Double? = nil
    var longitude: Double? = nil
    var address: String? = nil

    var trip: Trip? = nil
    var stop: TripStop? = nil

    init(
        kind: Kind,
        title: String,
        fileData: Data? = nil,
        fileName: String? = nil,
        mimeType: String? = nil,
        url: URL? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil
    ) {
        self.id = UUID()
        self.kind = kind
        self.title = title
        self.createdAt = Date()
        self.fileData = fileData
        self.fileName = fileName
        self.mimeType = mimeType
        self.urlString = url?.absoluteString
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
    }

    var url: URL? {
        get {
            guard let urlString else { return nil }
            return URL(string: urlString)
        }
        set {
            urlString = newValue?.absoluteString
        }
    }

    var sortedSubtitle: String {
        switch kind {
        case .file:
            return [fileName, formattedFileSize]
                .compactMap { $0 }
                .joined(separator: " · ")
        case .url:
            return url?.host() ?? urlString ?? "Saved link"
        case .location:
            if let address, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return address
            }
            guard let latitude, let longitude else { return "Saved location" }
            return String(format: "%.4f, %.4f", latitude, longitude)
        }
    }

    var mapsURL: URL? {
        guard kind == .location, let latitude, let longitude else { return nil }

        var components = URLComponents()
        components.scheme = "maps"
        components.host = ""
        components.queryItems = [
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "q", value: title)
        ]
        return components.url
    }

    private var formattedFileSize: String? {
        guard let count = fileData?.count else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}
