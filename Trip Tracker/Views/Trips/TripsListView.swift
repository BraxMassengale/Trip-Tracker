import SwiftUI
import SwiftData

struct TripsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.startDate, order: .reverse) private var allTrips: [Trip]
    @Bindable var vm: TripsViewModel

    @State private var showingForm = false
    @State private var deleteError: String?
    @State private var showingDeleteError = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Trips")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        sortMenu
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingForm = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .searchable(text: $vm.searchQuery, prompt: "Search trips")
                .navigationDestination(for: Trip.self) { trip in
                    TripDetailView(trip: trip)
                }
                .sheet(isPresented: $showingForm) {
                    TripFormView()
                }
                .alert("Couldn't delete", isPresented: $showingDeleteError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(deleteError ?? "Please try again.")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if allTrips.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                filterBar
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                if filteredTrips.isEmpty {
                    noMatches
                } else {
                    List {
                        ForEach(filteredTrips) { trip in
                            NavigationLink(value: trip) {
                                TripRowView(trip: trip)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                }
            }
        }
    }

    private var filteredTrips: [Trip] {
        vm.sorted(allTrips.filter { vm.matches($0) })
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TripFilter.allCases) { option in
                    FilterChip(
                        label: option.label,
                        isSelected: vm.filter == option
                    ) {
                        vm.filter = option
                        Haptics.selection()
                    }
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $vm.sortMode) {
                ForEach(TripSortMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "suitcase")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            Text("Your journal starts here")
                .font(.headline)
                .foregroundStyle(AppTheme.ColorToken.ink)
            Text("Tap + to record your first trip.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private var noMatches: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            Text("No trips match your filters")
                .font(.subheadline)
                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            if vm.hasActiveFilters {
                Button("Clear filters") {
                    vm.clearAll()
                    Haptics.selection()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.ColorToken.accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { filteredTrips[$0] }
        for trip in toDelete {
            context.delete(trip)
        }
        if let error = PersistenceReporter.save(context, action: "delete trips") {
            deleteError = PersistenceReporter.userMessage(for: "delete trips", error: error)
            showingDeleteError = true
            Haptics.error()
        } else {
            Haptics.success()
        }
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(isSelected
                    ? AppTheme.ColorToken.cardFill
                    : AppTheme.ColorToken.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected
                        ? AppTheme.ColorToken.accent
                        : AppTheme.ColorToken.accentSoft)
                )
        }
        .buttonStyle(.plain)
    }
}
