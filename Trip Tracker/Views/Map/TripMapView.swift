import SwiftUI
import SwiftData
import MapKit
import UIKit

struct TripMapView: View {
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedPlaceID: String?
    @State private var selectedCarouselTripID: String?

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
            .onChange(of: selectedCarouselTripID) { _, _ in
                Haptics.selection()
            }
        }
    }

    private var selectedPlace: TripMapPlace? {
        guard let selectedPlaceID else { return nil }
        return mapPlaces.first { $0.id == selectedPlaceID }
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
                        .stroke(segment.color.opacity(segment.dimmed ? 0.05 : 0.20), lineWidth: segment.glowLineWidth)
                }

                MapPolyline(segment.polyline)
                    .stroke(
                        segment.color.opacity(segment.routeOpacity),
                        style: segment.strokeStyle
                    )
            }

            ForEach(mapPlaces) { place in
                Annotation(place.title, coordinate: place.coordinate) {
                    Button {
                        select(place)
                    } label: {
                        TripMapPlacePin(
                            count: place.visitCount,
                            isSelected: place.id == selectedPlaceID,
                            isDimmed: selectedPlaceID != nil && place.id != selectedPlaceID,
                            isFavorite: place.containsFavoriteTrip,
                            kind: place.primaryKind
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabel(for: place))
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .safeAreaInset(edge: .top) {
            mapSummaryBar
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

    private var mapPlaces: [TripMapPlace] {
        let groupedLocations = Dictionary(grouping: mapLocations) { location in
            placeKey(for: location)
        }

        return groupedLocations.map { key, locations in
            TripMapPlace(
                id: key,
                locations: locations,
                tripID: { trip in tripID(for: trip) }
            )
        }
        .sorted { first, second in
            if first.lastVisited == second.lastVisited {
                return first.title < second.title
            }
            return first.lastVisited > second.lastVisited
        }
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

        return zip(locations, locations.dropFirst()).map { start, end in
            let startPlaceID = placeKey(for: start)
            let endPlaceID = placeKey(for: end)
            let touchesSelection = selectedPlaceID.map { selectedID in
                startPlaceID == selectedID || endPlaceID == selectedID
            } ?? false

            return TripRouteSegment(
                id: "\(start.id)-to-\(end.id)",
                start: start.location.coordinate,
                end: end.location.coordinate,
                mode: end.arrivalMode,
                color: color,
                dimmed: selectedPlaceID != nil && !touchesSelection,
                highlighted: touchesSelection
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
        if let selectedPlace {
            VStack(spacing: 12) {
                Capsule()
                    .fill(AppTheme.ColorToken.muted.opacity(0.55))
                    .frame(width: 38, height: 5)
                    .padding(.top, 8)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedPlace.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.ColorToken.ink)
                            .lineLimit(1)

                        Text(selectedPlace.summary)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    }

                    Spacer()

                    Button {
                        clearSelection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close selected place")
                }
                .padding(.horizontal, 16)

                TabView(selection: $selectedCarouselTripID) {
                    ForEach(selectedPlace.trips) { trip in
                        NavigationLink(value: trip) {
                            TripMapTripCard(
                                trip: trip,
                                matchingLocations: selectedPlace.locations(for: trip) { trip in
                                    tripID(for: trip)
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .tag(tripID(for: trip) as String?)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 218)

                if selectedPlace.trips.count > 1 {
                    TripMapPageIndicator(
                        count: selectedPlace.trips.count,
                        selectedIndex: selectedIndex(in: selectedPlace)
                    )
                    .padding(.top, -4)
                }
            }
            .padding(.bottom, selectedPlace.trips.count > 1 ? 12 : 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppTheme.ColorToken.cardBorder.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 8)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 6)
        } else {
            HStack(spacing: 10) {
                Image(systemName: "hand.tap")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.ColorToken.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Journey map")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.ColorToken.ink)

                    Text("\(mapPlacesLabel) · tap markers to preview trips")
                        .font(.caption)
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.ColorToken.cardBorder.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 5)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
    }

    private var mapSummaryBar: some View {
        HStack(spacing: 10) {
            MapSummaryMetric(value: "\(mapPlaces.count)", label: "Places")

            Divider()
                .frame(height: 20)

            MapSummaryMetric(value: "\(tripsWithMappedLocationsCount)", label: "Trips")

            Divider()
                .frame(height: 20)

            MapSummaryMetric(value: "\(routeSegments.count)", label: "Routes")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(AppTheme.ColorToken.cardBorder.opacity(0.65), lineWidth: 1)
        )
        .padding(.top, 0)
    }

    private var tripsWithMappedLocationsCount: Int {
        Set(mapLocations.map { tripID(for: $0.trip) }).count
    }

    private var mapPlacesLabel: String {
        mapPlaces.count == 1
            ? "1 destination marker"
            : "\(mapPlaces.count) destination markers"
    }

    private func select(_ place: TripMapPlace) {
        selectedPlaceID = place.id
        selectedCarouselTripID = place.trips.first.map { tripID(for: $0) }
        position = .region(region(focusingOn: place))
        Haptics.selection()
    }

    private func clearSelection() {
        selectedPlaceID = nil
        selectedCarouselTripID = nil
        refreshCameraPosition()
        Haptics.selection()
    }

    private func pruneSelection() {
        guard let selectedPlaceID else { return }
        guard mapPlaces.contains(where: { $0.id == selectedPlaceID }) else {
            self.selectedPlaceID = nil
            selectedCarouselTripID = nil
            return
        }
    }

    private func refreshCameraPosition() {
        guard selectedPlace == nil else { return }
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

    private func region(focusingOn place: TripMapPlace) -> MKCoordinateRegion {
        let center = place.coordinate
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.22, longitudeDelta: 0.22)
        )
    }

    private func tripID(for trip: Trip) -> String {
        String(describing: trip.persistentModelID)
    }

    private func placeKey(for location: TripJourneyLocation) -> String {
        let label = location.location.locationLabel
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let roundedLatitude = (location.location.latitude * 100).rounded() / 100
        let roundedLongitude = (location.location.longitude * 100).rounded() / 100

        if label.isEmpty {
            return "\(roundedLatitude),\(roundedLongitude)"
        }
        return "\(label)|\(roundedLatitude),\(roundedLongitude)"
    }

    private func routeColor(for trip: Trip, fallbackIndex: Int) -> Color {
        let key = "\(trip.title)-\(tripID(for: trip))"
        let hash = key.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31) &+ Int(scalar.value)
        }
        let index = abs(hash == Int.min ? fallbackIndex : hash) % Self.routePalette.count
        return Self.routePalette[index]
    }

    private func accessibilityLabel(for place: TripMapPlace) -> String {
        "\(place.title), \(place.summary)"
    }

    private func selectedIndex(in place: TripMapPlace) -> Int {
        guard let selectedCarouselTripID else { return 0 }
        return place.trips.firstIndex { tripID(for: $0) == selectedCarouselTripID } ?? 0
    }

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
    let highlighted: Bool

    var polyline: MKGeodesicPolyline {
        var coordinates = [start, end]
        return MKGeodesicPolyline(coordinates: &coordinates, count: coordinates.count)
    }

    var isFlight: Bool {
        mode == .flight
    }

    var routeOpacity: Double {
        if dimmed {
            return 0.16
        }
        return highlighted ? 0.98 : 0.78
    }

    var glowLineWidth: CGFloat {
        highlighted ? 12 : 8
    }

    var strokeStyle: StrokeStyle {
        let width: CGFloat = highlighted ? 5.5 : 4

        switch mode {
        case .flight:
            return StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: [9, 7])
        case .train:
            return StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: [12, 4, 2, 4])
        case .car, .bus:
            return StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        case .ferry:
            return StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: [2, 7])
        case .walk, .bike:
            return StrokeStyle(lineWidth: highlighted ? 4 : 2.5, lineCap: .round, lineJoin: .round, dash: [1, 6])
        case .other, nil:
            return StrokeStyle(lineWidth: highlighted ? 4 : 2.5, lineCap: .round, lineJoin: .round, dash: [6, 6])
        }
    }
}

private struct TripMapPlace: Identifiable {
    let id: String
    let locations: [TripJourneyLocation]
    let tripID: (Trip) -> String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: locations.map(\.location.latitude).average,
            longitude: locations.map(\.location.longitude).average
        )
    }

    var title: String {
        let labels = orderedUnique(locations.map(\.location.shortLabel))
        if labels.count == 1 {
            return labels[0]
        }
        return "\(labels.count) nearby places"
    }

    var summary: String {
        let tripText = trips.count == 1 ? "1 trip" : "\(trips.count) trips"
        let visitText = visitCount == 1 ? "1 visit" : "\(visitCount) visits"
        return "\(tripText) · \(visitText)"
    }

    var visitCount: Int {
        locations.count
    }

    var lastVisited: Date {
        locations.map(\.date).max() ?? .distantPast
    }

    var trips: [Trip] {
        var seen: Set<String> = []
        return locations
            .sorted { $0.date > $1.date }
            .compactMap { location in
                let id = tripID(location.trip)
                guard seen.insert(id).inserted else { return nil }
                return location.trip
            }
    }

    var containsFavoriteTrip: Bool {
        trips.contains { $0.favorite }
    }

    var primaryKind: TripJourneyLocationKind {
        if locations.contains(where: { $0.kind == .stop }) {
            return .stop
        }
        if locations.contains(where: { $0.kind == .end }) {
            return .end
        }
        return .start
    }

    func locations(for trip: Trip, tripID: (Trip) -> String) -> [TripJourneyLocation] {
        let id = tripID(trip)
        return locations.filter { tripID($0.trip) == id }
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard seen.insert(trimmed.lowercased()).inserted else { continue }
            result.append(trimmed)
        }

        return result
    }
}

private struct MapSummaryMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.ColorToken.ink)
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
        }
        .frame(minWidth: 44)
    }
}

private struct TripMapPageIndicator: View {
    let count: Int
    let selectedIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == selectedIndex
                        ? AppTheme.ColorToken.accent
                        : AppTheme.ColorToken.secondaryInk.opacity(0.28))
                    .frame(width: index == selectedIndex ? 18 : 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.24, dampingFraction: 0.85), value: selectedIndex)
        .accessibilityLabel("Trip \(selectedIndex + 1) of \(count)")
    }
}

private struct TripMapPlacePin: View {
    let count: Int
    let isSelected: Bool
    let isDimmed: Bool
    let isFavorite: Bool
    let kind: TripJourneyLocationKind

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isSelected ? AppTheme.ColorToken.accent : AppTheme.ColorToken.cardFill)
                    .frame(width: 38, height: 38)

                Circle()
                    .stroke(AppTheme.ColorToken.cardBorder, lineWidth: 1)
                    .frame(width: 38, height: 38)

                Image(systemName: symbolName)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(isSelected ? AppTheme.ColorToken.cardFill : AppTheme.ColorToken.accent)

                if count > 1 {
                    Text("\(min(count, 99))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppTheme.ColorToken.routeRose, in: Capsule())
                        .offset(x: 16, y: -15)
                }
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
        .opacity(isDimmed ? 0.32 : 1)
        .shadow(color: Color.black.opacity(isSelected ? 0.18 : 0.10), radius: 10, x: 0, y: 4)
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isSelected)
        .animation(.easeInOut(duration: 0.18), value: isDimmed)
    }

    private var symbolName: String {
        if isFavorite {
            return "heart.fill"
        }

        switch kind {
        case .start:
            return "house.fill"
        case .end:
            return "flag.checkered"
        case .stop:
            return "mappin"
        }
    }
}

private struct TripMapTripCard: View {
    let trip: Trip
    let matchingLocations: [TripJourneyLocation]

    var body: some View {
        HStack(spacing: 14) {
            hero

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(trip.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.ColorToken.ink)
                            .lineLimit(2)

                        if trip.favorite {
                            Image(systemName: "heart.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.ColorToken.accent)
                        }
                    }

                    Text(trip.displayDestinationSummary)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Label(dateLabel, systemImage: "calendar")
                    Label(matchLabel, systemImage: "mappin.and.ellipse")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                .lineLimit(1)

                transportChain

                HStack {
                    Text("Open trip")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.ColorToken.accent)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.ColorToken.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(AppTheme.ColorToken.cardFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.ColorToken.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trip.title), \(trip.displayDestinationSummary), \(dateLabel)")
    }

    @ViewBuilder
    private var hero: some View {
        if let data = trip.previewPhotoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 108, height: 142)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if trip.favorite {
                        Image(systemName: "heart.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(.ultraThinMaterial, in: Circle())
                            .padding(8)
                    }
                }
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.ColorToken.accentSoft)
                .frame(width: 108, height: 142)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "map")
                            .font(.title2.weight(.semibold))
                        Text("Trip")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.ColorToken.accent)
                }
        }
    }

    private var transportChain: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(trip.journeyLocations.enumerated()), id: \.element.id) { index, location in
                    if index > 0 {
                        Image(systemName: location.arrivalMode?.symbolName ?? "arrow.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.ColorToken.accent)
                    }

                    Text(transportLabel(for: location, index: index))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.ColorToken.ink)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .background(AppTheme.ColorToken.canvas, in: Capsule())
    }

    private var dateLabel: String {
        let start = Self.dateFormatter.string(from: trip.startDate)
        guard let end = trip.endDate, end > trip.startDate else { return start }
        return "\(start) - \(Self.dateFormatter.string(from: end))"
    }

    private var matchLabel: String {
        let count = matchingLocations.count
        return count == 1 ? "1 match" : "\(count) matches"
    }

    private func transportLabel(for location: TripJourneyLocation, index: Int) -> String {
        switch location.kind {
        case .start:
            return "Start"
        case .end:
            return trip.returnsToStart ? "Back" : "End"
        case .stop:
            let label = location.location.shortLabel
            return label == "Location" ? "Stop \(index + 1)" : label
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
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
