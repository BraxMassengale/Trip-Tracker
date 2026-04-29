import SwiftUI
import SwiftData
import MapKit
import UIKit

struct TripMapView: View {
    @Environment(\.openURL) private var openURL
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedPlaceID: String?
    @State private var selectedCarouselTripID: String?
    @State private var selectedPlaceSheetExpanded = false
    @State private var focusRoutesOnSelectedPlace = false
    @State private var tripFilter: TripMapTripFilter = .all
    @State private var routeModeFilter: Set<TransportMode> = []
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var routeDensity: TripMapRouteDensity = .balanced

    var body: some View {
        NavigationStack {
            Group {
                if allMapLocations.isEmpty {
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
            .onChange(of: filterSnapshot) { _, _ in
                refreshCameraPosition(force: true)
                pruneSelection()
            }
            .onChange(of: placeGrouping.id) { _, _ in
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
        allMapLocations
            .map { location in
                "\(location.id)-\(location.location.latitude)-\(location.location.longitude)"
            }
            .joined(separator: "|")
    }

    private var filterSnapshot: String {
        "\(tripFilter.rawValue)|\(routeModeFilter.map(\.rawValue).sorted().joined(separator: ","))"
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

    private var allMapLocations: [TripJourneyLocation] {
        trips
            .flatMap(\.mapJourneyLocations)
            .sorted { $0.date > $1.date }
    }

    private var mapLocations: [TripJourneyLocation] {
        filteredTrips
            .flatMap(\.mapJourneyLocations)
            .sorted { $0.date > $1.date }
    }

    private var filteredTrips: [Trip] {
        let mappedTrips = trips.filter { !$0.mapJourneyLocations.isEmpty }

        switch tripFilter {
        case .all:
            return mappedTrips
        case .favorites:
            return mappedTrips.filter(\.favorite)
        case .recent:
            return Array(mappedTrips.prefix(5))
        }
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
        let segments = filteredRouteSegments

        guard routeDensity.hasLimit, segments.count > routeDensity.segmentLimit else {
            return segments
        }

        let highlighted = segments.filter(\.highlighted)
        let standard = segments.filter { !$0.highlighted }
        let selectedFirst = highlighted + standard
        return Array(selectedFirst.prefix(routeDensity.segmentLimit))
    }

    private var filteredRouteSegments: [TripRouteSegment] {
        filteredTrips
            .enumerated()
            .flatMap { tripIndex, trip in
                routeSegments(for: trip, tripIndex: tripIndex)
            }
            .filter { segment in
                routeModeFilter.isEmpty || segment.mode.map { routeModeFilter.contains($0) } == true
            }
            .filter { segment in
                guard focusRoutesOnSelectedPlace, let selectedPlaceID else { return true }
                return segment.touchesPlace(selectedPlaceID)
            }
    }

    private var hiddenRouteSegmentCount: Int {
        max(filteredRouteSegments.count - routeSegments.count, 0)
    }

    private var placeGrouping: TripMapPlaceGrouping {
        TripMapPlaceGrouping(
            visibleRegion: visibleRegion,
            fallbackRegion: fittedRegion(for: mapLocations.isEmpty ? allMapLocations : mapLocations),
            locationCount: mapLocations.count
        )
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
                startPlaceID: startPlaceID,
                endPlaceID: endPlaceID,
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
        if mapLocations.isEmpty {
            noFilteredResultsCard
        } else if let selectedPlace {
            VStack(spacing: selectedPlaceSheetExpanded ? 14 : 12) {
                Capsule()
                    .fill(AppTheme.ColorToken.muted.opacity(0.55))
                    .frame(width: 38, height: 5)
                    .padding(.top, 8)

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

                selectedPlaceActions(for: selectedPlace)
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
            .animation(.snappy(duration: 0.24), value: selectedPlaceSheetExpanded)
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

    private func selectedPlaceActions(for place: TripMapPlace) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let selectedTrip = selectedTrip(in: place) {
                    NavigationLink(value: selectedTrip) {
                        MapControlLabel(title: "Open trip", symbolName: "arrow.up.right", isActive: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open selected trip")
                }

                Button {
                    openInMaps(place)
                } label: {
                    MapControlLabel(title: "Maps", symbolName: "map", isActive: false)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open selected place in Apple Maps")

                Button {
                    focusRoutesOnSelectedPlace.toggle()
                    Haptics.selection()
                } label: {
                    MapControlLabel(
                        title: focusRoutesOnSelectedPlace ? "All routes" : "Only routes",
                        symbolName: "point.topleft.down.curvedto.point.bottomright.up",
                        isActive: focusRoutesOnSelectedPlace
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(focusRoutesOnSelectedPlace ? "Show all routes" : "Show only routes touching this place")

                Button {
                    selectedPlaceSheetExpanded.toggle()
                    Haptics.selection()
                } label: {
                    MapControlLabel(
                        title: selectedPlaceSheetExpanded ? "Compact" : "Details",
                        symbolName: selectedPlaceSheetExpanded ? "chevron.down" : "chevron.up",
                        isActive: false
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(selectedPlaceSheetExpanded ? "Collapse selected place" : "Expand selected place")
            }
        }
        .accessibilityElement(children: .contain)
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
                    .lineLimit(1)
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
        VStack(spacing: 8) {
            mapSummaryBar
            mapControlBar
            routeDensityNotice
        }
        .padding(.horizontal)
    }

    private var mapSummaryBar: some View {
        HStack(spacing: 10) {
            MapSummaryMetric(value: "\(mapPlaces.count)", label: "Places")

            Divider()
                .frame(height: 20)

            MapSummaryMetric(value: "\(tripsWithMappedLocationsCount)", label: "Trips")

            Divider()
                .frame(height: 20)

            MapSummaryMetric(value: routeSummaryValue, label: "Routes")
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

                if selectedPlaceID != nil {
                    MapControlButton(
                        title: "Clear",
                        symbolName: "xmark.circle",
                        isActive: true,
                        action: clearSelection
                    )
                }

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

    @ViewBuilder
    private var routeDensityNotice: some View {
        if hiddenRouteSegmentCount > 0 {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ColorToken.accent)

                Text("Showing \(routeSegments.count) of \(filteredRouteSegments.count) routes")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.ColorToken.ink)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button {
                    routeDensity = .all
                    Haptics.selection()
                } label: {
                    Text("Show all")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.ColorToken.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.ColorToken.cardBorder.opacity(0.65), lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Showing \(routeSegments.count) of \(filteredRouteSegments.count) routes. Show all routes.")
        }
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
                isActive: routeDensity != .balanced || hiddenRouteSegmentCount > 0
            )
        }
        .accessibilityLabel("Route density")
        .accessibilityValue(routeDensity.accessibilityValue(hiddenCount: hiddenRouteSegmentCount))
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

    private var tripsWithMappedLocationsCount: Int {
        Set(mapLocations.map { tripID(for: $0.trip) }).count
    }

    private var routeSummaryValue: String {
        guard hiddenRouteSegmentCount > 0 else {
            return "\(routeSegments.count)"
        }
        return "\(routeSegments.count)+"
    }

    private var mapPlacesLabel: String {
        mapPlaces.count == 1
            ? "1 destination marker"
            : "\(mapPlaces.count) destination markers"
    }

    private func select(_ place: TripMapPlace) {
        selectedPlaceID = place.id
        selectedCarouselTripID = place.trips.first.map { tripID(for: $0) }
        selectedPlaceSheetExpanded = false
        focusRoutesOnSelectedPlace = false
        position = .region(region(focusingOn: place))
        Haptics.selection()
    }

    private func clearSelection() {
        selectedPlaceID = nil
        selectedCarouselTripID = nil
        selectedPlaceSheetExpanded = false
        focusRoutesOnSelectedPlace = false
        refreshCameraPosition(force: true)
        Haptics.selection()
    }

    private func fitAll() {
        selectedPlaceID = nil
        selectedCarouselTripID = nil
        selectedPlaceSheetExpanded = false
        focusRoutesOnSelectedPlace = false
        refreshCameraPosition(force: true)
        Haptics.selection()
    }

    private func resetFilters() {
        tripFilter = .all
        routeModeFilter.removeAll()
        selectedPlaceID = nil
        selectedCarouselTripID = nil
        selectedPlaceSheetExpanded = false
        focusRoutesOnSelectedPlace = false
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
        guard mapPlaces.contains(where: { $0.id == selectedPlaceID }) else {
            self.selectedPlaceID = nil
            selectedCarouselTripID = nil
            selectedPlaceSheetExpanded = false
            focusRoutesOnSelectedPlace = false
            return
        }
    }

    private func refreshCameraPosition(force: Bool = false) {
        guard force || selectedPlace == nil else { return }
        position = initialCameraPosition
    }

    private var initialCameraPosition: MapCameraPosition {
        let locations = mapLocations.isEmpty ? allMapLocations : mapLocations
        guard let region = fittedRegion(for: locations) else {
            return .automatic
        }
        return .region(region)
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

    private func placeKey(for location: TripJourneyLocation) -> String {
        let label = location.location.locationLabel
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let roundedLatitude = placeGrouping.bucket(location.location.latitude)
        let roundedLongitude = placeGrouping.bucket(location.location.longitude)

        if label.isEmpty || !placeGrouping.usesLabels {
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
    let dimmed: Bool
    let highlighted: Bool

    var polyline: MKGeodesicPolyline {
        var coordinates = [start, end]
        return MKGeodesicPolyline(coordinates: &coordinates, count: coordinates.count)
    }

    var isFlight: Bool {
        mode == .flight
    }

    func touchesPlace(_ placeID: String) -> Bool {
        startPlaceID == placeID || endPlaceID == placeID
    }

    var routeOpacity: Double {
        if dimmed {
            return 0.12
        }
        return highlighted ? 0.98 : 0.62
    }

    var glowLineWidth: CGFloat {
        highlighted ? 12 : 7
    }

    var strokeStyle: StrokeStyle {
        let width: CGFloat = highlighted ? 5.5 : 3.2

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
    let isCluster: Bool

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
