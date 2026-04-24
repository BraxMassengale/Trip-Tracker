import SwiftUI
import SwiftData

struct RootTabView: View {
    @State private var tripsViewModel = TripsViewModel()
    @AppStorage("appearance") private var appearance = AppearancePreference.system.rawValue

    var body: some View {
        TabView {
            TripsListView(vm: tripsViewModel)
                .tabItem { Label("Trips", systemImage: "suitcase") }

            TripMapView()
                .tabItem { Label("Map", systemImage: "map") }

            TimelineView()
                .tabItem { Label("Timeline", systemImage: "clock") }

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(AppTheme.ColorToken.accent)
        .preferredColorScheme(currentAppearance.colorScheme)
    }

    private var currentAppearance: AppearancePreference {
        AppearancePreference(rawValue: appearance) ?? .system
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: Trip.self, inMemory: true)
}
