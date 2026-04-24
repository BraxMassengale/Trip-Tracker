import SwiftUI
import SwiftData
import UIKit

struct TripStopDraft: Identifiable, Equatable {
    let id: UUID
    var existingStopID: PersistentIdentifier?
    var date: Date
    var location: TripLocation?
    var notes: String
    var journal: String
    var photos: [Data]

    init(
        id: UUID = UUID(),
        existingStopID: PersistentIdentifier? = nil,
        date: Date = Date(),
        location: TripLocation? = nil,
        notes: String = "",
        journal: String = "",
        photos: [Data] = []
    ) {
        self.id = id
        self.existingStopID = existingStopID
        self.date = date
        self.location = location
        self.notes = notes
        self.journal = journal
        self.photos = photos
    }

    init(stop: TripStop) {
        self.id = UUID()
        self.existingStopID = stop.persistentModelID
        self.date = stop.occurredAt
        self.location = {
            guard let latitude = stop.latitude, let longitude = stop.longitude else { return nil }
            return TripLocation(
                latitude: latitude,
                longitude: longitude,
                destinationName: stop.destinationName,
                country: stop.country
            )
        }()
        self.notes = stop.notes ?? ""
        self.journal = stop.journal ?? ""
        self.photos = stop.photos ?? []
    }

    var hasMeaningfulContent: Bool {
        location != nil
        || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !journal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !photos.isEmpty
    }

    var isIncomplete: Bool {
        hasMeaningfulContent && location == nil
    }
}

struct TripStopEditorCard: View {
    @Binding var stop: TripStopDraft

    let position: Int
    let canDelete: Bool
    let onDelete: () -> Void

    @State private var showingLocationPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            locationButton
            DatePicker("Date", selection: $stop.date, displayedComponents: .date)

            TextField(
                "What do you want to remember here?",
                text: $stop.notes,
                axis: .vertical
            )
            .lineLimit(2...6)

            TextField(
                "Journal — what do you want to remember?",
                text: $stop.journal,
                axis: .vertical
            )
            .lineLimit(3...10)

            if !stop.photos.isEmpty {
                photoStrip
            }

            ImagePicker(images: $stop.photos)

            if stop.isIncomplete {
                Text("Add a location to keep this stop.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.ColorToken.canvas)
        )
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerSheet(location: $stop.location)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Stop \(position)")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ColorToken.ink)
                if let location = stop.location, !location.country.isEmpty {
                    Text(location.country)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                }
            }

            Spacer()

            if canDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var locationButton: some View {
        Button {
            showingLocationPicker = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Location")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    Text(stop.location?.destinationName ?? "Add location")
                        .font(.subheadline)
                        .foregroundStyle(stop.location == nil
                            ? AppTheme.ColorToken.secondaryInk
                            : AppTheme.ColorToken.ink)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.ColorToken.cardFill)
            )
        }
        .buttonStyle(.plain)
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(stop.photos.enumerated()), id: \.offset) { index, data in
                    if let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 84, height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    stop.photos.remove(at: index)
                                    Haptics.selection()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, .black.opacity(0.5))
                                        .font(.title3)
                                }
                                .padding(4)
                            }
                    }
                }
            }
        }
    }
}
