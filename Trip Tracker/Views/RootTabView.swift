import SwiftUI
import SwiftData

enum RootTab: Hashable {
    case trips
    case map
    case timeline
    case stats
    case settings
}

struct RootTabView: View {
    @State private var tripsViewModel = TripsViewModel()
    @State private var selectedTab: RootTab = .trips
    @AppStorage("appearance") private var appearance = AppearancePreference.system.rawValue

    var body: some View {
        TabView(selection: $selectedTab) {
            TripsListView(vm: tripsViewModel)
                .tabItem { Label("Trips", systemImage: "suitcase") }
                .tag(RootTab.trips)

            TripMapView()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(RootTab.map)

            TimelineView()
                .tabItem { Label("Timeline", systemImage: "clock") }
                .tag(RootTab.timeline)

            StatsView(tripsViewModel: tripsViewModel, selectedTab: $selectedTab)
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .tag(RootTab.stats)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(RootTab.settings)
        }
        .tint(AppTheme.ColorToken.accent)
        .preferredColorScheme(currentAppearance.colorScheme)
    }

    private var currentAppearance: AppearancePreference {
        AppearancePreference(rawValue: appearance) ?? .system
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Trip.self,
        TripStop.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return RootTabView()
        .modelContainer(container)
}
