import SwiftUI
import SwiftData
import MapKit

struct TripMapView: View {
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedTripID: PersistentIdentifier?

    var body: some View {
        NavigationStack {
            Group {
                if tripsWithCoordinates.isEmpty {
                    emptyState
                } else {
                    mapContent
                }
            }
            .background(AppTheme.ColorToken.canvas)
            .navigationTitle("Map")
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip)
            }
            .onAppear {
                refreshCameraPosition()
                pruneSelection()
            }
            .onChange(of: coordinateSnapshot) { _, _ in
                refreshCameraPosition()
                pruneSelection()
            }
        }
    }

    private var tripsWithCoordinates: [Trip] {
        trips.filter(\.hasCoordinates)
    }

    private var selectedTrip: Trip? {
        guard let selectedTripID else { return nil }
        return tripsWithCoordinates.first { $0.persistentModelID == selectedTripID }
    }

    private var coordinateSnapshot: String {
        tripsWithCoordinates
            .map { trip in
                "\(trip.persistentModelID)-\(trip.latitude ?? 0)-\(trip.longitude ?? 0)"
            }
            .joined(separator: "|")
    }

    private var mapContent: some View {
        Map(position: $position) {
            ForEach(tripsWithCoordinates) { trip in
                if let coordinate = coordinate(for: trip) {
                    Annotation(annotationTitle(for: trip), coordinate: coordinate) {
                        Button {
                            select(trip)
                        } label: {
                            TripMapPin(
                                isSelected: trip.persistentModelID == selectedTripID,
                                isFavorite: trip.favorite
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .annotationTitles(.hidden)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomCard
        }
    }

    private var emptyState: some View {
        ScrollView {
            SectionCard(
                title: "No mapped trips yet",
                subtitle: "Add a location to any trip and it will appear here."
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "map")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)

                    Text("Your travel map will start filling in as soon as you save trips with destinations.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
    }

    @ViewBuilder
    private var bottomCard: some View {
        if let selectedTrip {
            NavigationLink(value: selectedTrip) {
                SectionCard(
                    title: selectedTrip.title,
                    subtitle: destinationLabel(for: selectedTrip)
                ) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(dateLabel(for: selectedTrip), systemImage: "calendar")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.ColorToken.secondaryInk)

                            Text("Open trip details")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(AppTheme.ColorToken.accent)
                        }

                        Spacer()

                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.ColorToken.accent)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.clear)
        } else {
            SectionCard(
                title: "Pinned destinations",
                subtitle: tripsWithCoordinates.count == 1
                    ? "1 trip on the map"
                    : "\(tripsWithCoordinates.count) trips on the map"
            ) {
                Text("Tap any pin to preview the trip and jump into its detail screen.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.clear)
        }
    }

    private func select(_ trip: Trip) {
        selectedTripID = trip.persistentModelID
        position = .region(region(focusingOn: trip))
        Haptics.selection()
    }

    private func pruneSelection() {
        guard let selectedTripID else { return }
        guard tripsWithCoordinates.contains(where: { $0.persistentModelID == selectedTripID }) else {
            self.selectedTripID = nil
            return
        }
    }

    private func refreshCameraPosition() {
        guard selectedTrip == nil else { return }
        position = initialCameraPosition
    }

    private var initialCameraPosition: MapCameraPosition {
        guard !tripsWithCoordinates.isEmpty else { return .automatic }

        let latitudes = tripsWithCoordinates.compactMap(\.latitude)
        let longitudes = tripsWithCoordinates.compactMap(\.longitude)

        guard
            let minLatitude = latitudes.min(),
            let maxLatitude = latitudes.max(),
            let minLongitude = longitudes.min(),
            let maxLongitude = longitudes.max()
        else {
            return .automatic
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )

        let latitudeDelta = max((maxLatitude - minLatitude) * 1.6, 0.35)
        let longitudeDelta = max((maxLongitude - minLongitude) * 1.6, 0.35)

        return .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: latitudeDelta,
                longitudeDelta: longitudeDelta
            )
        ))
    }

    private func region(focusingOn trip: Trip) -> MKCoordinateRegion {
        let center = coordinate(for: trip) ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )
    }

    private func coordinate(for trip: Trip) -> CLLocationCoordinate2D? {
        guard let latitude = trip.latitude, let longitude = trip.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func annotationTitle(for trip: Trip) -> String {
        destinationLabel(for: trip).isEmpty ? trip.title : destinationLabel(for: trip)
    }

    private func destinationLabel(for trip: Trip) -> String {
        [trip.destinationName, trip.country]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func dateLabel(for trip: Trip) -> String {
        let start = Self.dateFormatter.string(from: trip.startDate)
        guard let end = trip.endDate, end > trip.startDate else { return start }
        return "\(start) - \(Self.dateFormatter.string(from: end))"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

private struct TripMapPin: View {
    let isSelected: Bool
    let isFavorite: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.cardFill)
                    .frame(width: 38, height: 38)

                Circle()
                    .stroke(AppTheme.ColorToken.cardBorder, lineWidth: 1)
                    .frame(width: 38, height: 38)

                Image(systemName: isFavorite ? "heart.fill" : "mappin")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(isSelected ? AppTheme.ColorToken.cardFill : AppTheme.ColorToken.accent)
            }

            Triangle()
                .fill(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.cardFill)
                .frame(width: 14, height: 10)
                .overlay(alignment: .top) {
                    Triangle()
                        .stroke(AppTheme.ColorToken.cardBorder, lineWidth: 1)
                }
                .offset(y: -1)
        }
        .shadow(color: Color.black.opacity(isSelected ? 0.18 : 0.10), radius: 10, x: 0, y: 4)
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isSelected)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview("Map With Trips") {
    let container = try! ModelContainer(
        for: Trip.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let context = container.mainContext
    context.insert(
        Trip(
            title: "Paris Spring",
            destinationName: "Paris",
            country: "France",
            startDate: .now,
            endDate: .now.addingTimeInterval(60 * 60 * 24 * 4),
            latitude: 48.8566,
            longitude: 2.3522,
            favorite: true
        )
    )
    context.insert(
        Trip(
            title: "Tokyo Nights",
            destinationName: "Tokyo",
            country: "Japan",
            startDate: .now.addingTimeInterval(-60 * 60 * 24 * 180),
            latitude: 35.6764,
            longitude: 139.6500
        )
    )

    return TripMapView()
        .modelContainer(container)
}

#Preview("Empty Map") {
    TripMapView()
        .modelContainer(for: Trip.self, inMemory: true)
}
