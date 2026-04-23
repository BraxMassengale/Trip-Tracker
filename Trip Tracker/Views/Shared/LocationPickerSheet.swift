import SwiftUI
import MapKit
import CoreLocation

struct TripLocation: Equatable {
    var latitude: Double
    var longitude: Double
    var destinationName: String
    var country: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct LocationPickerSheet: View {
    @Binding var location: TripLocation?
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching: Bool = false
    @State private var searchError: String?
    @State private var draft: TripLocation?
    @State private var cameraPosition: MapCameraPosition = .automatic

    init(location: Binding<TripLocation?>) {
        self._location = location
        self._draft = State(initialValue: location.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                Divider()
                content
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        location = draft
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(draft == nil)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            TextField("Search a city or place", text: $query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { Task { await runSearch() } }
            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                    searchError = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(AppTheme.ColorToken.canvas)
    }

    @ViewBuilder
    private var content: some View {
        if isSearching {
            VStack { ProgressView() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let message = searchError {
            emptyMessage(message)
        } else if results.isEmpty {
            selectedPreview
        } else {
            resultsList
        }
    }

    private var resultsList: some View {
        List(results, id: \.self) { item in
            Button {
                select(item)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name ?? "Unknown")
                        .foregroundStyle(AppTheme.ColorToken.ink)
                    Text(formattedSubtitle(for: item))
                        .font(.footnote)
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private var selectedPreview: some View {
        if let draft {
            VStack(spacing: 0) {
                Map(position: $cameraPosition) {
                    Marker(draft.destinationName, coordinate: draft.coordinate)
                        .tint(AppTheme.ColorToken.accent)
                }
                .frame(maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.destinationName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ColorToken.ink)
                    if !draft.country.isEmpty {
                        Text(draft.country)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        } else {
            emptyMessage("Search a city, landmark, or country to pick a location.")
        }
    }

    private func emptyMessage(_ text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        searchError = nil
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.address, .pointOfInterest]

        do {
            let response = try await MKLocalSearch(request: request).start()
            results = response.mapItems
            if results.isEmpty {
                searchError = "No results for “\(trimmed)”."
            }
        } catch {
            results = []
            searchError = "Search failed. Check your connection and try again."
        }
    }

    private func select(_ item: MKMapItem) {
        let placemark = item.placemark
        let coordinate = placemark.coordinate
        let primary = item.name
            ?? placemark.locality
            ?? placemark.name
            ?? "Selected location"
        let country = placemark.country ?? ""

        draft = TripLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            destinationName: primary,
            country: country
        )
        results = []
        query = primary
        cameraPosition = .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        ))
        Haptics.selection()
    }

    private func formattedSubtitle(for item: MKMapItem) -> String {
        let placemark = item.placemark
        var parts: [String] = []
        if let locality = placemark.locality, locality != item.name {
            parts.append(locality)
        }
        if let admin = placemark.administrativeArea {
            parts.append(admin)
        }
        if let country = placemark.country {
            parts.append(country)
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    @Previewable @State var location: TripLocation? = nil
    return LocationPickerSheet(location: $location)
}
