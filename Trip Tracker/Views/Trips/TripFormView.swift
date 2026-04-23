import SwiftUI
import SwiftData
import UIKit

struct TripFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let editing: Trip?

    @State private var title: String
    @State private var location: TripLocation?
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var notes: String
    @State private var tags: [String]
    @State private var newTag: String = ""
    @State private var favorite: Bool
    @State private var rating: Int?
    @State private var photos: [Data]

    @State private var showingLocationPicker: Bool = false
    @State private var errorMessage: String?
    @State private var showingError: Bool = false

    init() {
        self.editing = nil
        let now = Date()
        _title = State(initialValue: "")
        _location = State(initialValue: nil)
        _startDate = State(initialValue: now)
        _hasEndDate = State(initialValue: false)
        _endDate = State(initialValue: now)
        _notes = State(initialValue: "")
        _tags = State(initialValue: [])
        _favorite = State(initialValue: false)
        _rating = State(initialValue: nil)
        _photos = State(initialValue: [])
    }

    init(editing trip: Trip) {
        self.editing = trip
        let loc: TripLocation? = {
            guard let lat = trip.latitude, let lon = trip.longitude else { return nil }
            return TripLocation(
                latitude: lat,
                longitude: lon,
                destinationName: trip.destinationName,
                country: trip.country
            )
        }()
        _title = State(initialValue: trip.title)
        _location = State(initialValue: loc)
        _startDate = State(initialValue: trip.startDate)
        _hasEndDate = State(initialValue: trip.endDate != nil)
        _endDate = State(initialValue: trip.endDate ?? trip.startDate)
        _notes = State(initialValue: trip.notes ?? "")
        _tags = State(initialValue: trip.tags)
        _favorite = State(initialValue: trip.favorite)
        _rating = State(initialValue: trip.rating)
        _photos = State(initialValue: trip.photos ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                notesSection
                tagsSection
                photosSection
                extrasSection
            }
            .navigationTitle(editing == nil ? "New Trip" : "Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerSheet(location: $location)
            }
            .alert("Couldn't save", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Title", text: $title)
                .textInputAutocapitalization(.words)

            Button {
                showingLocationPicker = true
            } label: {
                HStack {
                    Text("Location")
                        .foregroundStyle(AppTheme.ColorToken.ink)
                    Spacer()
                    Text(location?.destinationName ?? "Add location")
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                }
            }

            if location != nil {
                Button(role: .destructive) {
                    location = nil
                } label: {
                    Text("Clear location")
                }
            }

            DatePicker("Start", selection: $startDate, displayedComponents: .date)

            Toggle("Has end date", isOn: $hasEndDate.animation())
            if hasEndDate {
                DatePicker(
                    "End",
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: .date
                )
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField(
                "Anything you want to remember",
                text: $notes,
                axis: .vertical
            )
            .lineLimit(3...8)
        }
    }

    private var tagsSection: some View {
        Section("Tags") {
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Button {
                                tags.removeAll { $0 == tag }
                                Haptics.selection()
                            } label: {
                                HStack(spacing: 6) {
                                    Text(tag)
                                        .foregroundStyle(AppTheme.ColorToken.ink)
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                                }
                                .font(.footnote)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(AppTheme.ColorToken.accentSoft))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            HStack {
                TextField("Add a tag", text: $newTag)
                    .onSubmit(addTag)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Add", action: addTag)
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var photosSection: some View {
        Section("Photos") {
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { index, data in
                            if let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 84, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            photos.remove(at: index)
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
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            ImagePicker(images: $photos)
        }
    }

    private var extrasSection: some View {
        Section("Extras") {
            Toggle("Favorite", isOn: $favorite)

            HStack {
                Text("Rating")
                Spacer()
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            rating = (rating == value) ? nil : value
                            Haptics.selection()
                        } label: {
                            Image(systemName: (rating ?? 0) >= value ? "star.fill" : "star")
                                .foregroundStyle((rating ?? 0) >= value
                                    ? AppTheme.ColorToken.accent
                                    : AppTheme.ColorToken.secondaryInk)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let alreadyExists = tags.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        guard !alreadyExists else {
            newTag = ""
            return
        }
        tags.append(trimmed)
        newTag = ""
        Haptics.selection()
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalEndDate: Date? = hasEndDate ? endDate : nil

        let trip: Trip
        if let existing = editing {
            trip = existing
        } else {
            trip = Trip(
                title: trimmedTitle,
                destinationName: location?.destinationName ?? "",
                country: location?.country ?? "",
                startDate: startDate
            )
            context.insert(trip)
        }

        trip.title = trimmedTitle
        trip.destinationName = location?.destinationName ?? ""
        trip.country = location?.country ?? ""
        trip.startDate = startDate
        trip.endDate = finalEndDate
        trip.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        trip.tags = tags
        trip.photos = photos.isEmpty ? nil : photos
        trip.latitude = location?.latitude
        trip.longitude = location?.longitude
        trip.rating = rating
        trip.favorite = favorite

        if let error = PersistenceReporter.save(context, action: "save trip") {
            errorMessage = PersistenceReporter.userMessage(for: "save trip", error: error)
            showingError = true
            Haptics.error()
            return
        }

        Haptics.success()
        dismiss()
    }
}

#Preview {
    TripFormView()
        .modelContainer(for: Trip.self, inMemory: true)
}
