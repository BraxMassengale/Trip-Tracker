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
    var arrivalMode: TransportMode?
    var photos: [Data]

    init(
        id: UUID = UUID(),
        existingStopID: PersistentIdentifier? = nil,
        date: Date = Date(),
        location: TripLocation? = nil,
        notes: String = "",
        journal: String = "",
        arrivalMode: TransportMode? = nil,
        photos: [Data] = []
    ) {
        self.id = id
        self.existingStopID = existingStopID
        self.date = date
        self.location = location
        self.notes = notes
        self.journal = journal
        self.arrivalMode = arrivalMode
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
        self.arrivalMode = stop.arrivalMode
        self.photos = stop.photos ?? []
    }

    var hasMeaningfulContent: Bool {
        location != nil
        || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !journal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || arrivalMode != nil
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
    @FocusState private var focusedField: Field?

    private enum Field {
        case journal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            locationButton
            DatePicker("Date", selection: $stop.date, displayedComponents: .date)
            transportModePicker

            TextField(
                "What do you want to remember here?",
                text: $stop.notes,
                axis: .vertical
            )
            .lineLimit(2...6)

            journalEditor

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

    private var journalEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            if focusedField == .journal || !stop.journal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Journal")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            }

            ZStack(alignment: .topLeading) {
                if stop.journal.isEmpty && focusedField != .journal {
                    Text("Journal — what do you want to remember?")
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                }

                TextEditor(text: $stop.journal)
                    .focused($focusedField, equals: .journal)
                    .frame(minHeight: 96)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, -5)
                    .padding(.vertical, -8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.ColorToken.cardFill)
            )
        }
    }

    private var transportModePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Arrived by")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.ColorToken.secondaryInk)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TransportMode.allCases) { mode in
                        transportModeButton(for: mode)
                    }
                }
            }
        }
    }

    private func transportModeButton(for mode: TransportMode) -> some View {
        let isSelected = stop.arrivalMode == mode

        return Button {
            stop.arrivalMode = isSelected ? nil : mode
            Haptics.selection()
        } label: {
            Image(systemName: mode.symbolName)
                .font(.headline)
                .frame(width: 42, height: 38)
                .foregroundStyle(isSelected
                    ? AppTheme.ColorToken.cardFill
                    : AppTheme.ColorToken.ink)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected
                            ? AppTheme.ColorToken.accent
                            : AppTheme.ColorToken.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.ColorToken.cardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.label)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(isSelected ? "Clears the arrival mode" : "Sets the arrival mode")
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
