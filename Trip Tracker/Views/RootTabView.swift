import SwiftUI
import SwiftData

struct RootTabView: View {
    var body: some View {
        TabView {
            TripsHarnessTab()
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
        .tint(AppTheme.ColorToken.accent)
    }
}

// Temporary harness so the Trip form can be exercised end-to-end.
// MEN-158 replaces this with the real TripsListView.
private struct TripsHarnessTab: View {
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]
    @State private var showingForm = false

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "suitcase")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                        Text("No trips yet")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ColorToken.ink)
                        Text("Tap + to record your first trip.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(trips) { trip in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trip.title)
                                .foregroundStyle(AppTheme.ColorToken.ink)
                            Text(trip.destinationName.isEmpty ? "No destination" : trip.destinationName)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                        }
                    }
                }
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingForm) {
                TripFormView()
            }
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
