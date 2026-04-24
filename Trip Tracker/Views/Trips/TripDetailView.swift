import SwiftUI
import SwiftData
import MapKit
import UIKit

struct TripDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var trip: Trip

    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroPhoto
                headerCard
                if !trip.tags.isEmpty {
                    tagsCard
                }
                if let notes = trip.notes, !notes.isEmpty {
                    notesCard(notes: notes)
                }
                if trip.photos?.count ?? 0 > 1 {
                    tripGalleryCard
                }
                if !trip.stopSummaries.isEmpty {
                    stopsTimelineCard
                }
                if trip.hasCoordinates {
                    mapCard
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(AppTheme.ColorToken.canvas)
        .navigationTitle(trip.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEdit = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button {
                        toggleFavorite()
                    } label: {
                        Label(
                            trip.favorite ? "Remove favorite" : "Mark favorite",
                            systemImage: trip.favorite ? "heart.slash" : "heart"
                        )
                    }
                    Divider()
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete trip", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            TripFormView(editing: trip)
        }
        .confirmationDialog(
            "Delete this trip?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .alert("Couldn't update", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    @ViewBuilder
    private var heroPhoto: some View {
        if let first = trip.previewPhotoData, let image = UIImage(data: first) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metric.cardCornerRadius, style: .continuous))
        }
    }

    private var headerCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.title)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.ColorToken.ink)
                        if !trip.displayDestinationSummary.isEmpty {
                            Text(trip.displayDestinationSummary)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                        }
                    }
                    Spacer()
                    if trip.favorite {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(AppTheme.ColorToken.accent)
                    }
                }

                Label(dateLabel, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)

                Text(trip.stopCountLabel)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.ColorToken.accent)

                if let rating = trip.rating, rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { value in
                            Image(systemName: rating >= value ? "star.fill" : "star")
                                .font(.footnote)
                                .foregroundStyle(rating >= value
                                    ? AppTheme.ColorToken.accent
                                    : AppTheme.ColorToken.muted)
                        }
                    }
                }
            }
        }
    }

    private var tagsCard: some View {
        SectionCard(title: "Tags") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(trip.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.footnote)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(AppTheme.ColorToken.accentSoft))
                            .foregroundStyle(AppTheme.ColorToken.ink)
                    }
                }
            }
        }
    }

    private func notesCard(notes: String) -> some View {
        SectionCard(title: "Notes") {
            Text(notes)
                .foregroundStyle(AppTheme.ColorToken.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var tripGalleryCard: some View {
        SectionCard(title: "Trip Photos") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array((trip.photos ?? []).enumerated()), id: \.offset) { _, data in
                        if let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 140, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    private var stopsTimelineCard: some View {
        SectionCard(
            title: "Trip Timeline",
            subtitle: trip.stopCountLabel
        ) {
            VStack(spacing: 12) {
                ForEach(Array(trip.stopSummaries.enumerated()), id: \.element.id) { index, summary in
                    TripStopTimelineCard(summary: summary, position: index + 1)
                }
            }
        }
    }

    @ViewBuilder
    private var mapCard: some View {
        if !trip.mapStopSummaries.isEmpty {
            SectionCard(title: "Map", subtitle: "Stops with saved coordinates") {
                Map(initialPosition: .region(mapRegion), interactionModes: []) {
                    ForEach(trip.mapStopSummaries) { summary in
                        if let coordinate = coordinate(for: summary) {
                            Marker(
                                summary.locationLabel.isEmpty ? trip.title : summary.locationLabel,
                                coordinate: coordinate
                            )
                            .tint(AppTheme.ColorToken.accent)
                        }
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let start = formatter.string(from: trip.startDate)
        guard let end = trip.endDate, end > trip.startDate else { return start }
        return "\(start) – \(formatter.string(from: end))"
    }

    private var mapRegion: MKCoordinateRegion {
        let coordinates = trip.mapStopSummaries.compactMap(coordinate(for:))

        guard
            let minLatitude = coordinates.map(\.latitude).min(),
            let maxLatitude = coordinates.map(\.latitude).max(),
            let minLongitude = coordinates.map(\.longitude).min(),
            let maxLongitude = coordinates.map(\.longitude).max()
        else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
            )
        }

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLatitude - minLatitude) * 1.6, 0.35),
                longitudeDelta: max((maxLongitude - minLongitude) * 1.6, 0.35)
            )
        )
    }

    private func coordinate(for summary: TripStopSummary) -> CLLocationCoordinate2D? {
        guard let latitude = summary.latitude, let longitude = summary.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func toggleFavorite() {
        trip.favorite.toggle()
        if let error = PersistenceReporter.save(context, action: "update favorite") {
            trip.favorite.toggle()
            errorMessage = PersistenceReporter.userMessage(for: "update favorite", error: error)
            showingError = true
            Haptics.error()
        } else {
            Haptics.selection()
        }
    }

    private func delete() {
        context.delete(trip)
        if let error = PersistenceReporter.save(context, action: "delete trip") {
            errorMessage = PersistenceReporter.userMessage(for: "delete trip", error: error)
            showingError = true
            Haptics.error()
        } else {
            Haptics.success()
            dismiss()
        }
    }
}
