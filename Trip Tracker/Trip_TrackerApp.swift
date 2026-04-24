import SwiftUI
import SwiftData

@main
struct Trip_TrackerApp: App {
    let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: Trip.self, TripStop.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(modelContainer)
    }
}
