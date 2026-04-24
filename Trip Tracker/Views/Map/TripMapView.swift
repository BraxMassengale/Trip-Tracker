import SwiftUI
import SwiftData
import MapKit

struct TripMapView: View {
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedStopID: String?

    var body: some View {
        NavigationStack {
            Group {
                if mapLocations.isEmpty {
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

    private var mapStops: [TripStopSummary] {
        trips
            .flatMap(\.mapStopSummaries)
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    private var selectedStop: TripStopSummary? {
        guard let selectedStopID else { return nil }
        return mapStops.first { $0.id == selectedStopID }
    }

    private var selectedTripID: String? {
        selectedStop.map(tripID(for:))
    }

    private var coordinateSnapshot: String {
        mapLocations
            .map { location in
                "\(location.id)-\(location.location.latitude)-\(location.location.longitude)"
            }
            .joined(separator: "|")
    }

    private var mapContent: some View {
        Map(position: $position) {
            ForEach(routeSegments) { segment in
                if segment.isFlight {
                    MapPolyline(segment.polyline)
                        .stroke(segment.color.opacity(segment.dimmed ? 0.08 : 0.18), lineWidth: 8)
                }

                MapPolyline(segment.polyline)
                    .stroke(
                        segment.color.opacity(segment.dimmed ? 0.18 : 0.82),
                        style: segment.strokeStyle
                    )
            }

            ForEach(mapStops) { summary in
                if let coordinate = coordinate(for: summary) {
                    Annotation(annotationTitle(for: summary), coordinate: coordinate) {
                        Button {
                            select(summary)
                        } label: {
                            TripMapPin(
                                isSelected: summary.id == selectedStopID,
                                isFavorite: summary.trip.favorite
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .annotationTitles(.hidden)
                }
            }

            ForEach(mapEndpoints) { location in
                Annotation(endpointTitle(for: location), coordinate: location.location.coordinate) {
                    TripEndpointMapPin(kind: location.kind, isReturn: location.kind == .end && location.trip.returnsToStart)
                }
                .annotationTitles(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomCard
        }
    }

    private var mapLocations: [TripJourneyLocation] {
        trips
            .flatMap(\.mapJourneyLocations)
            .sorted { $0.date > $1.date }
    }

    private var mapEndpoints: [TripJourneyLocation] {
        mapLocations.filter { $0.kind == .start || $0.kind == .end }
    }

    private var routeSegments: [TripRouteSegment] {
        trips
            .enumerated()
            .flatMap { tripIndex, trip in
                routeSegments(for: trip, tripIndex: tripIndex)
            }
            .prefix(200)
            .map { $0 }
    }

    private func routeSegments(for trip: Trip, tripIndex: Int) -> [TripRouteSegment] {
        let locations = trip.mapJourneyLocations
        guard locations.count > 1 else { return [] }

        let color = routeColor(for: trip, fallbackIndex: tripIndex)
        let currentTripID = tripID(for: trip)
        let dimmed = selectedTripID.map { $0 != currentTripID } ?? false

        return zip(locations, locations.dropFirst()).map { start, end in
            return TripRouteSegment(
                id: "\(start.id)-to-\(end.id)",
                start: start.location.coordinate,
                end: end.location.coordinate,
                mode: end.arrivalMode,
                color: color,
                dimmed: dimmed
            )
        }
    }

    private var emptyState: some View {
        ScrollView {
            SectionCard(
                title: "No mapped trips yet",
                subtitle: "Add a start, stop, or end location to any trip and it will appear here."
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "map")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)

                    Text("Your travel map will start filling in as soon as you save trips with journey locations.")
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
        if let selectedStop {
            NavigationLink(value: selectedStop.trip) {
                SectionCard(
                    title: selectedStop.trip.title,
                    subtitle: selectedStop.locationLabel.isEmpty
                        ? selectedStop.trip.displayDestinationSummary
                        : selectedStop.locationLabel
                ) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(dateLabel(for: selectedStop), systemImage: "calendar")
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
                title: "Journey map",
                subtitle: mapLocations.count == 1
                    ? "1 place on the map"
                    : "\(mapLocations.count) places on the map"
            ) {
                Text("Tap any stop pin to preview it and jump into the trip timeline.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.clear)
        }
    }

    private func select(_ summary: TripStopSummary) {
        selectedStopID = summary.id
        position = .region(region(focusingOn: summary))
        Haptics.selection()
    }

    private func pruneSelection() {
        guard let selectedStopID else { return }
        guard mapStops.contains(where: { $0.id == selectedStopID }) else {
            self.selectedStopID = nil
            return
        }
    }

    private func refreshCameraPosition() {
        guard selectedStop == nil else { return }
        position = initialCameraPosition
    }

    private var initialCameraPosition: MapCameraPosition {
        guard !mapLocations.isEmpty else { return .automatic }

        let latitudes = mapLocations.map(\.location.latitude)
        let longitudes = mapLocations.map(\.location.longitude)

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

    private func region(focusingOn summary: TripStopSummary) -> MKCoordinateRegion {
        let center = coordinate(for: summary) ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )
    }

    private func coordinate(for summary: TripStopSummary) -> CLLocationCoordinate2D? {
        guard let latitude = summary.latitude, let longitude = summary.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func tripID(for summary: TripStopSummary) -> String {
        tripID(for: summary.trip)
    }

    private func tripID(for trip: Trip) -> String {
        String(describing: trip.persistentModelID)
    }

    private func routeColor(for trip: Trip, fallbackIndex: Int) -> Color {
        let key = "\(trip.title)-\(tripID(for: trip))"
        let hash = key.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31) &+ Int(scalar.value)
        }
        let index = abs(hash == Int.min ? fallbackIndex : hash) % Self.routePalette.count
        return Self.routePalette[index]
    }

    private func annotationTitle(for summary: TripStopSummary) -> String {
        summary.locationLabel.isEmpty ? summary.trip.title : summary.locationLabel
    }

    private func endpointTitle(for location: TripJourneyLocation) -> String {
        switch location.kind {
        case .start:
            return "Start: \(location.location.shortLabel)"
        case .end:
            return location.trip.returnsToStart
                ? "Back home: \(location.location.shortLabel)"
                : "End: \(location.location.shortLabel)"
        case .stop:
            return location.location.shortLabel
        }
    }

    private func dateLabel(for summary: TripStopSummary) -> String {
        return Self.dateFormatter.string(from: summary.occurredAt)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    private static let routePalette: [Color] = [
        AppTheme.ColorToken.accent,
        AppTheme.ColorToken.positive,
        AppTheme.ColorToken.routeBlue,
        AppTheme.ColorToken.routeViolet,
        AppTheme.ColorToken.routeRose,
        AppTheme.ColorToken.routeGold,
        AppTheme.ColorToken.routeSlate
    ]
}

private struct TripRouteSegment: Identifiable {
    let id: String
    let start: CLLocationCoordinate2D
    let end: CLLocationCoordinate2D
    let mode: TransportMode?
    let color: Color
    let dimmed: Bool

    var polyline: MKGeodesicPolyline {
        var coordinates = [start, end]
        return MKGeodesicPolyline(coordinates: &coordinates, count: coordinates.count)
    }

    var isFlight: Bool {
        mode == .flight
    }

    var strokeStyle: StrokeStyle {
        switch mode {
        case .flight:
            StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [9, 7])
        case .train:
            StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [12, 4, 2, 4])
        case .car, .bus:
            StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        case .ferry:
            StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [2, 7])
        case .walk, .bike:
            StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [1, 6])
        case .other, nil:
            StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [6, 6])
        }
    }
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

private struct TripEndpointMapPin: View {
    let kind: TripJourneyLocationKind
    let isReturn: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.ColorToken.cardFill)
                .frame(width: 34, height: 34)

            Circle()
                .stroke(AppTheme.ColorToken.accent, lineWidth: 2)
                .frame(width: 34, height: 34)

            Image(systemName: symbolName)
                .font(.footnote.weight(.bold))
                .foregroundStyle(AppTheme.ColorToken.accent)
        }
        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 3)
        .accessibilityLabel(accessibilityLabel)
    }

    private var symbolName: String {
        switch kind {
        case .start:
            "house.fill"
        case .end:
            isReturn ? "arrow.uturn.left" : "flag.checkered"
        case .stop:
            "mappin"
        }
    }

    private var accessibilityLabel: String {
        switch kind {
        case .start:
            "Trip start"
        case .end:
            isReturn ? "Return destination" : "Trip end"
        case .stop:
            "Trip stop"
        }
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
        TripStop.self,
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
    let container = try! ModelContainer(
        for: Trip.self,
        TripStop.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return TripMapView()
        .modelContainer(container)
}
