import SwiftUI
import SwiftData

struct RootTabView: View {
    @State private var tripsViewModel = TripsViewModel()

    var body: some View {
        TabView {
            TripsListView(vm: tripsViewModel)
                .tabItem { Label("Trips", systemImage: "suitcase") }

            PlaceholderTab(title: "Map", symbol: "map")
                .tabItem { Label("Map", systemImage: "map") }

            TimelineView()
                .tabItem { Label("Timeline", systemImage: "clock") }

            PlaceholderTab(title: "Stats", symbol: "chart.bar")
                .tabItem { Label("Stats", systemImage: "chart.bar") }

            PlaceholderTab(title: "Settings", symbol: "gearshape")
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(AppTheme.ColorToken.accent)
    }
}

private struct PlaceholderTab: View {
    let title: String
    let symbol: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                Text("\(title) — coming soon")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(title)
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: Trip.self, inMemory: true)
}
