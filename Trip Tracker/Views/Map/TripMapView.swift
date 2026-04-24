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
                if mapStops.isEmpty {
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

    private var coordinateSnapshot: String {
        mapStops
            .map { summary in
                "\(summary.id)-\(summary.latitude ?? 0)-\(summary.longitude ?? 0)"
            }
            .joined(separator: "|")
    }

    private var mapContent: some View {
        Map(position: $position) {
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
                title: "Pinned destinations",
                subtitle: mapStops.count == 1
                    ? "1 stop on the map"
                    : "\(mapStops.count) stops on the map"
            ) {
                Text("Tap any pin to preview the stop and jump into its trip timeline.")
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
        guard !mapStops.isEmpty else { return .automatic }

        let latitudes = mapStops.compactMap(\.latitude)
        let longitudes = mapStops.compactMap(\.longitude)

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

    private func annotationTitle(for summary: TripStopSummary) -> String {
        summary.locationLabel.isEmpty ? summary.trip.title : summary.locationLabel
    }

    private func dateLabel(for summary: TripStopSummary) -> String {
        return Self.dateFormatter.string(from: summary.occurredAt)
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
