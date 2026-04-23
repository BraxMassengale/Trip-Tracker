import Foundation
import OSLog
import SwiftData

enum PersistenceReporter {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "dev.mendia.TripTracker",
        category: "Persistence"
    )

    @MainActor
    @discardableResult
    static func save(_ context: ModelContext, action: String) -> Error? {
        do {
            try context.save()
            return nil
        } catch {
            log(error, action: action)
            return error
        }
    }

    static func log(_ error: Error, action: String) {
        logger.error("Failed to \(action, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }

    static func userMessage(for action: String, error: Error) -> String {
        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else {
            return "Couldn't \(action). Please try again."
        }
        return "Couldn't \(action). \(description)"
    }
}
