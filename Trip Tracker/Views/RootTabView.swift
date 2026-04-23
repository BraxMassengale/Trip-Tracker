import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            PlaceholderTab(title: "Trips", symbol: "suitcase")
                .tabItem { Label("Trips", systemImage: "suitcase") }

            PlaceholderTab(title: "Map", symbol: "map")
                .tabItem { Label("Map", systemImage: "map") }

            PlaceholderTab(title: "Timeline", symbol: "clock")
                .tabItem { Label("Timeline", systemImage: "clock") }

            PlaceholderTab(title: "Stats", symbol: "chart.bar")
                .tabItem { Label("Stats", systemImage: "chart.bar") }

            PlaceholderTab(title: "Settings", symbol: "gearshape")
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
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
                    .foregroundStyle(.secondary)
                Text("\(title) — coming soon")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(title)
        }
    }
}

#Preview {
    RootTabView()
}
