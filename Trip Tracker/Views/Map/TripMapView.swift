import SwiftUI
import SwiftData
import MapKit
import UIKit

struct TripMapView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedPlaceID: String?
    @State private var selectedCarouselTripID: String?
    @State private var selectedPlaceSheetExpanded = false
    @State private var tripFilter: TripMapTripFilter = .all
    @State private var routeModeFilter: Set<TransportMode> = []
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var routeDensity: TripMapRouteDensity = .balanced

    // Cached derived data — only rebuilt when inputs change, not on every body eval
    @State private var cachedMapPlaces: [TripMapPlace] = []
    @State private var cachedSegments: [TripRouteSegment] = []
    @State private var cachedGroupingID: String = ""
    @State private var hasAnyLocations: Bool = false
    @State private var hasFilteredLocations: Bool = false
    @State private var cachedFittedRegion: MKCoordinateRegion?

    var body: some View {
        NavigationStack {
            Group {
                if !hasAnyLocations {
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
                rebuildData()
                refreshCameraPosition()
            }
            .onChange(of: coordinateSnapshot) { _, _ in
                rebuildData()
                refreshCameraPosition()
            }
            .onChange(of: filterSnapshot) { _, _ in
                rebuildData()
                refreshCameraPosition(force: true)
            }
            .onChange(of: visibleRegionID) { _, _ in
                rebuildPlaces()
            }
            .onChange(of: selectedCarouselTripID) { _, _ in
                Haptics.selection()
            }
        }
    }

    private var selectedPlace: TripMapPlace? {
        guard let selectedPlaceID else { return nil }
        return cachedMapPlaces.first { $0.id == selectedPlaceID }
    }

    // Cheap: just trip + location counts — O(n trips) not O(all coordinates)
    private var coordinateSnapshot: String {
        "\(trips.count)|\(trips.prefix(30).map { "\($0.mapJourneyLocations.count)" }.joined(separator: ","))"
    }

    private var visibleRegionID: String {
        guard let r = visibleRegion else { return "" }
        return "\(Int(r.center.latitude * 100))-\(Int(r.center.longitude * 100))-\(Int(r.span.latitudeDelta * 100))"
    }

    private var filterSnapshot: String {
        "\(tripFilter.rawValue)|\(routeModeFilter.map(\.rawValue).sorted().joined(separator: ","))"
    }

    private var mapContent: some View {
        Map(position: $position) {
            ForEach(displayedSegments) { segment in
                MapPolyline(segment.polyline)
                    .stroke(
                        segment.color.opacity(segment.opacity(selectedPlaceID: selectedPlaceID)),
                        style: segment.strokeStyle
                    )
            }

            ForEach(cachedMapPlaces) { place in
                Annotation(place.title, coordinate: place.coordinate) {
                    Button {
                        select(place)
                    } label: {
                        TripMapPlacePin(
                            count: place.visitCount,
                            isSelected: place.id == selectedPlaceID,
                            isDimmed: selectedPlaceID != nil && place.id != selectedPlaceID,
                            isFavorite: place.containsFavoriteTrip,
                            kind: place.primaryKind,
                            isCluster: place.isCluster
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabel(for: place))
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
        }
        .safeAreaInset(edge: .top) {
            topChrome
        }
        .safeAreaInset(edge: .bottom) {
            bottomCard
        }
    }

    private var filteredTrips: [Trip] {
        let mappedTrips = trips.filter { !$0.mapJourneyLocations.isEmpty }
        switch tripFilter {
        case .all: return mappedTrips
        case .favorites: return mappedTrips.filter(\.favorite)
        case .recent: return Array(mappedTrips.prefix(5))
        }
    }

    // Density-limited view into cachedSegments — cheap to compute each render
    private var displayedSegments: [TripRouteSegment] {
        guard routeDensity.hasLimit, cachedSegments.count > routeDensity.segmentLimit else {
            return cachedSegments
        }
        if let selectedPlaceID {
            let touching = cachedSegments.filter { $0.touchesPlace(selectedPlaceID) }
            let other = cachedSegments.filter { !$0.touchesPlace(selectedPlaceID) }
            return Array((touching + other).prefix(routeDensity.segmentLimit))
        }
        return Array(cachedSegments.prefix(routeDensity.segmentLimit))
    }

    private var hiddenSegmentCount: Int {
        max(cachedSegments.count - displayedSegments.count, 0)
    }

    // MARK: - Cache rebuild

    private func rebuildData() {
        let allLocs = trips.flatMap(\.mapJourneyLocations)
        hasAnyLocations = !allLocs.isEmpty

        let ft = filteredTrips
        let filteredLocs = ft.flatMap(\.mapJourneyLocations).sorted { $0.date > $1.date }
        hasFilteredLocations = !filteredLocs.isEmpty

        let locationsForCamera = filteredLocs.isEmpty
            ? allLocs.sorted { $0.date > $1.date }
            : filteredLocs
        cachedFittedRegion = fittedRegion(for: locationsForCamera)

        let grouping = TripMapPlaceGrouping(
            visibleRegion: visibleRegion,
            fallbackRegion: cachedFittedRegion,
            locationCount: filteredLocs.count
        )
        cachedGroupingID = grouping.id
        cachedMapPlaces = buildPlaces(from: filteredLocs, grouping: grouping)
        cachedSegments = buildSegments(from: ft, grouping: grouping)
        pruneSelection()
    }

    private func rebuildPlaces() {
        let ft = filteredTrips
        let filteredLocs = ft.flatMap(\.mapJourneyLocations).sorted { $0.date > $1.date }
        let grouping = TripMapPlaceGrouping(
            visibleRegion: visibleRegion,
            fallbackRegion: cachedFittedRegion,
            locationCount: filteredLocs.count
        )
        guard grouping.id != cachedGroupingID else { return }
        cachedGroupingID = grouping.id
        cachedMapPlaces = buildPlaces(from: filteredLocs, grouping: grouping)
        cachedSegments = buildSegments(from: ft, grouping: grouping)
        pruneSelection()
    }

    private func buildPlaces(from locations: [TripJourneyLocation], grouping: TripMapPlaceGrouping) -> [TripMapPlace] {
        let grouped = Dictionary(grouping: locations) { placeKey(for: $0, grouping: grouping) }
        return grouped.map { key, locs in
            TripMapPlace(id: key, locations: locs, tripID: { self.tripID(for: $0) })
        }
        .sorted { first, second in
            first.lastVisited != second.lastVisited
                ? first.lastVisited > second.lastVisited
                : first.title < second.title
        }
    }

    private func buildSegments(from trips: [Trip], grouping: TripMapPlaceGrouping) -> [TripRouteSegment] {
        trips.enumerated()
            .flatMap { index, trip in buildTripSegments(for: trip, tripIndex: index, grouping: grouping) }
            .filter { seg in
                routeModeFilter.isEmpty || seg.mode.map { routeModeFilter.contains($0) } == true
            }
    }

    private func buildTripSegments(for trip: Trip, tripIndex: Int, grouping: TripMapPlaceGrouping) -> [TripRouteSegment] {
        let locations = trip.mapJourneyLocations
        guard locations.count > 1 else { return [] }
        let color = routeColor(for: trip, fallbackIndex: tripIndex)
        return zip(locations, locations.dropFirst()).map { start, end in
            TripRouteSegment(
                id: "\(start.id)-to-\(end.id)",
                start: start.location.coordinate,
                end: end.location.coordinate,
                startPlaceID: placeKey(for: start, grouping: grouping),
                endPlaceID: placeKey(for: end, grouping: grouping),
                mode: end.arrivalMode,
                color: color
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
                        .font(.largeTitle.weight(.light))
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
        if !hasFilteredLocations {
            noFilteredResultsCard
        } else if let selectedPlace {
            VStack(spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedPlace.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.ColorToken.ink)
                            .lineLimit(2)

                        Text(selectedPlace.summary)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    }

                    Spacer()

                    if selectedPlace.trips.count > 1 {
                        Button {
                            selectedPlaceSheetExpanded.toggle()
                            Haptics.selection()
                        } label: {
                            Image(systemName: selectedPlaceSheetExpanded ? "chevron.down.circle" : "chevron.up.circle")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(selectedPlaceSheetExpanded ? "Collapse place details" : "Expand place details")
                    }

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
                .padding(.top, 14)

                HStack(spacing: 8) {
                    if let trip = selectedTrip(in: selectedPlace) {
                        NavigationLink(value: trip) {
                            MapControlLabel(title: "Open trip", symbolName: "arrow.up.right", isActive: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open selected trip")
                    }

                    Button {
                        openInMaps(selectedPlace)
                    } label: {
                        MapControlLabel(title: "Maps", symbolName: "map", isActive: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open in Apple Maps")

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)

                if selectedPlaceSheetExpanded {
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
                } else {
                    selectedTripPreview(for: selectedPlace)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, selectedPlaceSheetExpanded && selectedPlace.trips.count > 1 ? 12 : 14)
            .background(.regularMaterial, in: UnevenRoundedRectangle(
                topLeadingRadius: 28,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 24,
                topTrailingRadius: 28,
                style: .continuous
            ))
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 28,
                    bottomLeadingRadius: 24,
                    bottomTrailingRadius: 24,
                    topTrailingRadius: 28,
                    style: .continuous
                )
                    .stroke(AppTheme.ColorToken.cardBorder.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 8)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 6)
            .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: selectedPlaceSheetExpanded)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(selectedPlace.title), \(selectedPlace.summary)")
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
                        .lineLimit(2)
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

    private func selectedTripPreview(for place: TripMapPlace) -> some View {
        let trip = selectedTrip(in: place) ?? place.trips.first
        return HStack(spacing: 10) {
            Image(systemName: symbolName(for: place.primaryKind))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.ColorToken.accent)
                .frame(width: 30, height: 30)
                .background(AppTheme.ColorToken.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(trip?.title ?? "Selected place")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ColorToken.ink)
                    .lineLimit(1)

                Text(compactPlaceDetail(for: place, trip: trip))
                    .font(.caption)
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if place.trips.count > 1 {
                TripMapPageIndicator(
                    count: place.trips.count,
                    selectedIndex: selectedIndex(in: place)
                )
                .frame(width: 46)
            }
        }
        .padding(12)
        .background(AppTheme.ColorToken.cardFill.opacity(0.9), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.ColorToken.cardBorder.opacity(0.8), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(place.title), \(place.summary), \(compactPlaceDetail(for: place, trip: trip))")
    }

    private var noFilteredResultsCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.ColorToken.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("No matches")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.ColorToken.ink)

                Text("Adjust filters to show more mapped trips")
                    .font(.caption)
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Button("Reset") {
                resetFilters()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.ColorToken.accent)
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

    private var topChrome: some View {
        mapControlBar
            .padding(.horizontal)
    }

    private var mapControlBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                MapControlButton(
                    title: "Fit",
                    symbolName: "scope",
                    isActive: false,
                    action: fitAll
                )

                tripFilterMenu
                routeModeMenu
                routeDensityMenu

                if tripFilter != .all || !routeModeFilter.isEmpty {
                    MapControlButton(
                        title: "Reset",
                        symbolName: "arrow.counterclockwise",
                        isActive: false,
                        action: resetFilters
                    )
                }
            }
            .padding(.horizontal, 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var tripFilterMenu: some View {
        Menu {
            Picker("Trips", selection: $tripFilter) {
                ForEach(TripMapTripFilter.allCases) { filter in
                    Label(filter.label, systemImage: filter.symbolName).tag(filter)
                }
            }
        } label: {
            MapControlLabel(
                title: tripFilter.label,
                symbolName: tripFilter.symbolName,
                isActive: tripFilter != .all
            )
        }
        .accessibilityLabel("Trip filter")
        .accessibilityValue(tripFilter.label)
    }

    private var routeModeMenu: some View {
        Menu {
            Button {
                routeModeFilter.removeAll()
                Haptics.selection()
            } label: {
                Label("All modes", systemImage: routeModeFilter.isEmpty ? "checkmark" : "point.topleft.down.curvedto.point.bottomright.up")
            }

            Divider()

            ForEach(TransportMode.allCases) { mode in
                Button {
                    toggleRouteMode(mode)
                } label: {
                    Label(mode.label, systemImage: routeModeFilter.contains(mode) ? "checkmark" : mode.symbolName)
                }
            }
        } label: {
            MapControlLabel(
                title: routeModeTitle,
                symbolName: "point.topleft.down.curvedto.point.bottomright.up",
                isActive: !routeModeFilter.isEmpty
            )
        }
        .accessibilityLabel("Route mode filter")
        .accessibilityValue(routeModeTitle)
    }

    private var routeDensityMenu: some View {
        Menu {
            Picker("Route density", selection: $routeDensity) {
                ForEach(TripMapRouteDensity.allCases) { density in
                    Label(density.label, systemImage: density.symbolName).tag(density)
                }
            }
        } label: {
            MapControlLabel(
                title: routeDensity.label,
                symbolName: routeDensity.symbolName,
                isActive: routeDensity != .balanced || hiddenSegmentCount > 0
            )
        }
        .accessibilityLabel("Route density")
        .accessibilityValue(routeDensity.accessibilityValue(hiddenCount: hiddenSegmentCount))
    }

    private var routeModeTitle: String {
        if routeModeFilter.isEmpty {
            return "Modes"
        }

        if routeModeFilter.count == 1, let mode = routeModeFilter.first {
            return mode.label
        }

        return "\(routeModeFilter.count) modes"
    }

    private var mapPlacesLabel: String {
        cachedMapPlaces.count == 1
            ? "1 destination marker"
            : "\(cachedMapPlaces.count) destination markers"
    }

    private func select(_ place: TripMapPlace) {
        selectedPlaceID = place.id
        selectedCarouselTripID = place.trips.first.map { tripID(for: $0) }
        selectedPlaceSheetExpanded = false
        position = .region(region(focusingOn: place))
        Haptics.selection()
    }

    private func clearSelection() {
        selectedPlaceID = nil
        selectedCarouselTripID = nil
        selectedPlaceSheetExpanded = false
        refreshCameraPosition(force: true)
        Haptics.selection()
    }

    private func fitAll() {
        selectedPlaceID = nil
        selectedCarouselTripID = nil
        selectedPlaceSheetExpanded = false
        refreshCameraPosition(force: true)
        Haptics.selection()
    }

    private func resetFilters() {
        tripFilter = .all
        routeModeFilter.removeAll()
        selectedPlaceID = nil
        selectedCarouselTripID = nil
        selectedPlaceSheetExpanded = false
        Haptics.selection()
    }

    private func toggleRouteMode(_ mode: TransportMode) {
        if routeModeFilter.contains(mode) {
            routeModeFilter.remove(mode)
        } else {
            routeModeFilter.insert(mode)
        }
        Haptics.selection()
    }

    private func pruneSelection() {
        guard let selectedPlaceID else { return }
        guard cachedMapPlaces.contains(where: { $0.id == selectedPlaceID }) else {
            self.selectedPlaceID = nil
            selectedCarouselTripID = nil
            selectedPlaceSheetExpanded = false
            return
        }
    }

    private func refreshCameraPosition(force: Bool = false) {
        guard force || selectedPlace == nil else { return }
        if let region = cachedFittedRegion {
            position = .region(region)
        } else {
            position = .automatic
        }
    }

    private func fittedRegion(for locations: [TripJourneyLocation]) -> MKCoordinateRegion? {
        guard !locations.isEmpty else { return nil }

        let latitudes = locations.map(\.location.latitude)
        let longitudes = locations.map(\.location.longitude)

        guard
            let minLatitude = latitudes.min(),
            let maxLatitude = latitudes.max(),
            let minLongitude = longitudes.min(),
            let maxLongitude = longitudes.max()
        else {
            return nil
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )

        let latitudeDelta = max((maxLatitude - minLatitude) * 1.6, 0.35)
        let longitudeDelta = max((maxLongitude - minLongitude) * 1.6, 0.35)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: latitudeDelta,
                longitudeDelta: longitudeDelta
            )
        )
    }

    private func region(focusingOn place: TripMapPlace) -> MKCoordinateRegion {
        let latitudeDelta = 0.24
        let longitudeDelta = 0.24
        let center = CLLocationCoordinate2D(
            latitude: place.coordinate.latitude - latitudeDelta * 0.22,
            longitude: place.coordinate.longitude
        )
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    private func selectedTrip(in place: TripMapPlace) -> Trip? {
        guard let selectedCarouselTripID else { return place.trips.first }
        return place.trips.first { tripID(for: $0) == selectedCarouselTripID } ?? place.trips.first
    }

    private func compactPlaceDetail(for place: TripMapPlace, trip: Trip?) -> String {
        let destination = trip?.displayDestinationSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let destinationText = destination?.isEmpty == false ? destination : nil
        let visitText = place.visitCount == 1 ? "1 visit" : "\(place.visitCount) visits"
        return [destinationText, visitText].compactMap { $0 }.joined(separator: " · ")
    }

    private func openInMaps(_ place: TripMapPlace) {
        var components = URLComponents()
        components.scheme = "maps"
        components.host = ""
        components.queryItems = [
            URLQueryItem(name: "ll", value: "\(place.coordinate.latitude),\(place.coordinate.longitude)"),
            URLQueryItem(name: "q", value: place.title)
        ]

        guard let url = components.url else { return }
        openURL(url)
        Haptics.selection()
    }

    private func symbolName(for kind: TripJourneyLocationKind) -> String {
        switch kind {
        case .start:
            return "house.fill"
        case .end:
            return "flag.checkered"
        case .stop:
            return "mappin"
        }
    }

    private func tripID(for trip: Trip) -> String {
        String(describing: trip.persistentModelID)
    }

    private func placeKey(for location: TripJourneyLocation, grouping: TripMapPlaceGrouping) -> String {
        let label = location.location.locationLabel
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let roundedLatitude = grouping.bucket(location.location.latitude)
        let roundedLongitude = grouping.bucket(location.location.longitude)
        if label.isEmpty || !grouping.usesLabels {
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
    let startPlaceID: String
    let endPlaceID: String
    let mode: TransportMode?
    let color: Color

    var polyline: MKGeodesicPolyline {
        var coordinates = [start, end]
        return MKGeodesicPolyline(coordinates: &coordinates, count: coordinates.count)
    }

    func touchesPlace(_ placeID: String) -> Bool {
        startPlaceID == placeID || endPlaceID == placeID
    }

    func opacity(selectedPlaceID: String?) -> Double {
        guard let selectedPlaceID else { return 0.62 }
        return touchesPlace(selectedPlaceID) ? 0.98 : 0.12
    }

    var strokeStyle: StrokeStyle {
        switch mode {
        case .flight:
            return StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round, dash: [9, 7])
        case .train:
            return StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round, dash: [12, 4, 2, 4])
        case .car, .bus:
            return StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
        case .ferry:
            return StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round, dash: [2, 7])
        case .walk, .bike:
            return StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [1, 6])
        case .other, nil:
            return StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [6, 6])
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
        let placeText = uniquePlaceCount == 1 ? nil : "\(uniquePlaceCount) places"
        let tripText = trips.count == 1 ? "1 trip" : "\(trips.count) trips"
        let visitText = visitCount == 1 ? "1 visit" : "\(visitCount) visits"
        return [placeText, tripText, visitText].compactMap { $0 }.joined(separator: " · ")
    }

    var visitCount: Int {
        locations.count
    }

    var uniquePlaceCount: Int {
        orderedUnique(locations.map(\.location.shortLabel)).count
    }

    var isCluster: Bool {
        uniquePlaceCount > 1
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

private enum TripMapTripFilter: String, CaseIterable, Identifiable {
    case all
    case recent
    case favorites

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All"
        case .recent: "Recent"
        case .favorites: "Favorites"
        }
    }

    var symbolName: String {
        switch self {
        case .all: "map"
        case .recent: "clock.arrow.circlepath"
        case .favorites: "heart.fill"
        }
    }
}

private enum TripMapRouteDensity: String, CaseIterable, Identifiable {
    case balanced
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .balanced: "Balanced"
        case .all: "All routes"
        }
    }

    var symbolName: String {
        switch self {
        case .balanced: "line.3.horizontal.decrease.circle"
        case .all: "point.topleft.down.curvedto.point.bottomright.up"
        }
    }

    var hasLimit: Bool {
        self == .balanced
    }

    var segmentLimit: Int {
        switch self {
        case .balanced: 200
        case .all: Int.max
        }
    }

    func accessibilityValue(hiddenCount: Int) -> String {
        if hiddenCount > 0 {
            return "\(label), \(hiddenCount) routes hidden"
        }
        return label
    }
}

private struct TripMapPlaceGrouping: Equatable {
    let precision: Double
    let usesLabels: Bool

    var id: String {
        "\(precision)-\(usesLabels)"
    }

    init(
        visibleRegion: MKCoordinateRegion?,
        fallbackRegion: MKCoordinateRegion?,
        locationCount: Int
    ) {
        let region = visibleRegion ?? fallbackRegion
        let latitudeDelta = region?.span.latitudeDelta ?? 180
        let longitudeDelta = region?.span.longitudeDelta ?? 360
        let span = max(latitudeDelta, longitudeDelta)

        if locationCount > 180 || span > 60 {
            precision = 5
            usesLabels = false
        } else if locationCount > 120 || span > 24 {
            precision = 2
            usesLabels = false
        } else if span > 8 {
            precision = 1
            usesLabels = false
        } else if span > 2.4 {
            precision = 0.25
            usesLabels = false
        } else if span > 0.65 {
            precision = 0.05
            usesLabels = true
        } else {
            precision = 0.01
            usesLabels = true
        }
    }

    func bucket(_ value: Double) -> Double {
        (value / precision).rounded() * precision
    }
}

private struct MapControlButton: View {
    let title: String
    let symbolName: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MapControlLabel(title: title, symbolName: symbolName, isActive: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct MapControlLabel: View {
    let title: String
    let symbolName: String
    let isActive: Bool

    var body: some View {
        Label(title, systemImage: symbolName)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(isActive
                ? AppTheme.ColorToken.cardFill
                : AppTheme.ColorToken.ink)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(
                Capsule().fill(isActive
                    ? AppTheme.ColorToken.accent
                    : AppTheme.ColorToken.cardFill.opacity(0.92))
            )
            .overlay(
                Capsule()
                    .stroke(AppTheme.ColorToken.cardBorder.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}

private struct TripMapPageIndicator: View {
    let count: Int
    let selectedIndex: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.85), value: selectedIndex)
        .accessibilityLabel("Trip \(selectedIndex + 1) of \(count)")
    }
}

private struct TripMapPlacePin: View {
    let count: Int
    let isSelected: Bool
    let isDimmed: Bool
    let isFavorite: Bool
    let kind: TripJourneyLocationKind
    let isCluster: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                        .font(.caption2.weight(.bold))
                        .fontDesign(.rounded)
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
        .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.8), value: isSelected)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isDimmed)
    }

    private var symbolName: String {
        if isCluster {
            return "square.grid.3x3.fill"
        }

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
        Attachment.self,
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

#Preview("Dense Map") {
    let container = try! ModelContainer(
        for: Trip.self,
        TripStop.self,
        Attachment.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let context = container.mainContext
    let calendar = Calendar.current
    let citySeeds: [(String, String, Double, Double)] = [
        ("Paris", "France", 48.8566, 2.3522),
        ("Lyon", "France", 45.7640, 4.8357),
        ("Milan", "Italy", 45.4642, 9.1900),
        ("Florence", "Italy", 43.7696, 11.2558),
        ("Zurich", "Switzerland", 47.3769, 8.5417),
        ("Munich", "Germany", 48.1351, 11.5820),
        ("Vienna", "Austria", 48.2082, 16.3738),
        ("Prague", "Czechia", 50.0755, 14.4378)
    ]

    for index in 0..<90 {
        let start = citySeeds[index % citySeeds.count]
        let mid = citySeeds[(index + 2) % citySeeds.count]
        let end = citySeeds[(index + 4) % citySeeds.count]
        let jitter = Double(index % 9) * 0.015
        let startDate = calendar.date(byAdding: .day, value: -index * 9, to: .now) ?? .now

        let stops = [
            TripStop(
                destinationName: mid.0,
                country: mid.1,
                occurredAt: calendar.date(byAdding: .day, value: 2, to: startDate) ?? startDate,
                arrivalMode: index.isMultiple(of: 3) ? .train : .flight,
                latitude: mid.2 + jitter,
                longitude: mid.3 - jitter,
                sortOrder: 0
            ),
            TripStop(
                destinationName: end.0,
                country: end.1,
                occurredAt: calendar.date(byAdding: .day, value: 5, to: startDate) ?? startDate,
                arrivalMode: index.isMultiple(of: 2) ? .car : .train,
                latitude: end.2 - jitter,
                longitude: end.3 + jitter,
                sortOrder: 1
            )
        ]

        let trip = Trip(
            title: "Dense Journey \(index + 1)",
            destinationName: end.0,
            country: end.1,
            startDate: startDate,
            endDate: calendar.date(byAdding: .day, value: 6, to: startDate),
            startLocationName: start.0,
            startLocationCountry: start.1,
            startLatitude: start.2 + jitter,
            startLongitude: start.3 + jitter,
            endLocationName: end.0,
            endLocationCountry: end.1,
            endLatitude: end.2 - jitter,
            endLongitude: end.3 - jitter,
            favorite: index.isMultiple(of: 11),
            stops: stops
        )
        stops.forEach { $0.trip = trip }
        context.insert(trip)
    }

    return TripMapView()
        .modelContainer(container)
}

#Preview("Empty Map") {
    let container = try! ModelContainer(
        for: Trip.self,
        TripStop.self,
        Attachment.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return TripMapView()
        .modelContainer(container)
}
