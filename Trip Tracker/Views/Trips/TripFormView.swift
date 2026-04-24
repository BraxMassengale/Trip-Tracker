import SwiftUI
import SwiftData

struct TripFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let editing: Trip?

    @State private var title: String
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var notes: String
    @State private var tags: [String]
    @State private var newTag: String = ""
    @State private var favorite: Bool
    @State private var rating: Int?
    @State private var tripPhotos: [Data]
    @State private var stops: [TripStopDraft]

    @State private var errorMessage: String?
    @State private var showingError: Bool = false

    init() {
        self.editing = nil
        let now = Date()
        _title = State(initialValue: "")
        _startDate = State(initialValue: now)
        _hasEndDate = State(initialValue: false)
        _endDate = State(initialValue: now)
        _notes = State(initialValue: "")
        _tags = State(initialValue: [])
        _favorite = State(initialValue: false)
        _rating = State(initialValue: nil)
        _tripPhotos = State(initialValue: [])
        _stops = State(initialValue: [TripStopDraft(date: now)])
    }

    init(editing trip: Trip) {
        self.editing = trip
        _title = State(initialValue: trip.title)
        _startDate = State(initialValue: trip.startDate)
        _hasEndDate = State(initialValue: trip.endDate != nil)
        _endDate = State(initialValue: trip.endDate ?? trip.startDate)
        _notes = State(initialValue: trip.notes ?? "")
        _tags = State(initialValue: trip.tags)
        _favorite = State(initialValue: trip.favorite)
        _rating = State(initialValue: trip.rating)
        _tripPhotos = State(initialValue: trip.photos ?? [])
        _stops = State(initialValue: Self.initialStops(from: trip))
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                stopsSection
                notesSection
                tagsSection
                tripPhotosSection
                extrasSection
            }
            .navigationTitle(editing == nil ? "New Trip" : "Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if stops.count > 1 {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
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
        && !stops.contains(where: \.isIncomplete)
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Title", text: $title)
                .textInputAutocapitalization(.words)
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

    private var stopsSection: some View {
        Section {
            ForEach($stops) { $stop in
                TripStopEditorCard(
                    stop: $stop,
                    position: position(for: stop.id),
                    canDelete: stops.count > 1
                ) {
                    removeStop(id: stop.id)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.35)
                        .onEnded { _ in Haptics.impact(.light) }
                )
            }
            .onMove(perform: moveStops)

            if let warning = chronologyWarning {
                chronologyBanner(message: warning)
            }

            Button {
                addStop()
            } label: {
                Label("Add stop", systemImage: "plus")
            }
        } header: {
            Text("Stops")
        } footer: {
            if stops.count > 1 {
                Text("Drag a stop to reorder, or tap Edit to move them.")
            } else if stops.contains(where: \.isIncomplete) {
                Text("Each stop needs a location before it can be saved.")
            } else {
                Text("Build this trip as an ordered set of places.")
            }
        }
    }

    private func chronologyBanner(message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.ColorToken.ink)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            Button {
                sortByDate()
            } label: {
                Label("Sort by date", systemImage: "arrow.up.arrow.down")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.15))
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .listRowBackground(Color.clear)
    }

    private var notesSection: some View {
        Section("Trip Notes") {
            TextField(
                "Anything you want to remember about the whole trip",
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

    private var tripPhotosSection: some View {
        Section("Trip Photos") {
            if !tripPhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(tripPhotos.enumerated()), id: \.offset) { index, data in
                            if let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 84, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            tripPhotos.remove(at: index)
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
            ImagePicker(images: $tripPhotos)
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

    private func addStop() {
        let nextDate = stops.last?.date ?? startDate
        stops.append(TripStopDraft(date: nextDate))
        Haptics.selection()
    }

    private func removeStop(id: UUID) {
        stops.removeAll { $0.id == id }
        Haptics.selection()
    }

    private func moveStops(from source: IndexSet, to destination: Int) {
        stops.move(fromOffsets: source, toOffset: destination)
        Haptics.impact(.light)
    }

    private func sortByDate() {
        let sorted = stops.sorted { $0.date < $1.date }
        guard sorted.map(\.id) != stops.map(\.id) else { return }
        stops = sorted
        Haptics.impact(.light)
    }

    private func position(for stopID: UUID) -> Int {
        (stops.firstIndex { $0.id == stopID } ?? 0) + 1
    }

    private var chronologyWarning: String? {
        guard stops.count > 1 else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        for index in 1..<stops.count {
            let previous = stops[index - 1]
            let current = stops[index]
            if current.date < previous.date {
                let currentDate = formatter.string(from: current.date)
                let previousDate = formatter.string(from: previous.date)
                return "Stop \(index + 1) (\(currentDate)) is now before Stop \(index) (\(previousDate))."
            }
        }
        return nil
    }

    private func save() {
        if stops.contains(where: \.isIncomplete) {
            errorMessage = "Each stop with notes or photos needs a location."
            showingError = true
            Haptics.error()
            return
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalEndDate: Date? = hasEndDate ? endDate : nil
        let keptStops = stops.filter(\.hasMeaningfulContent)

        let trip: Trip
        if let existing = editing {
            trip = existing
        } else {
            trip = Trip(
                title: trimmedTitle,
                destinationName: "",
                country: "",
                startDate: startDate
            )
            context.insert(trip)
        }

        trip.title = trimmedTitle
        trip.startDate = startDate
        trip.endDate = finalEndDate
        trip.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        trip.tags = tags
        trip.photos = tripPhotos.isEmpty ? nil : tripPhotos
        trip.rating = rating
        trip.favorite = favorite

        syncStops(on: trip, with: keptStops)

        if let firstLocation = keptStops.first?.location {
            trip.destinationName = firstLocation.destinationName
            trip.country = firstLocation.country
            trip.latitude = firstLocation.latitude
            trip.longitude = firstLocation.longitude
        } else if editing == nil || !(editing?.orderedStops.isEmpty ?? true) {
            trip.destinationName = ""
            trip.country = ""
            trip.latitude = nil
            trip.longitude = nil
        }

        if let error = PersistenceReporter.save(context, action: "save trip") {
            errorMessage = PersistenceReporter.userMessage(for: "save trip", error: error)
            showingError = true
            Haptics.error()
            return
        }

        Haptics.success()
        dismiss()
    }

    private func syncStops(on trip: Trip, with drafts: [TripStopDraft]) {
        let existingStops = Dictionary(uniqueKeysWithValues: trip.stops.map { ($0.persistentModelID, $0) })
        var keptIDs: Set<PersistentIdentifier> = []

        for (index, draft) in drafts.enumerated() {
            guard let location = draft.location else { continue }

            let trimmedStopNotes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedJournal = draft.journal.trimmingCharacters(in: .whitespacesAndNewlines)

            if let existingID = draft.existingStopID, let stop = existingStops[existingID] {
                stop.destinationName = location.destinationName
                stop.country = location.country
                stop.occurredAt = draft.date
                stop.notes = trimmedStopNotes.isEmpty ? nil : trimmedStopNotes
                stop.journal = trimmedJournal.isEmpty ? nil : trimmedJournal
                stop.photos = draft.photos.isEmpty ? nil : draft.photos
                stop.latitude = location.latitude
                stop.longitude = location.longitude
                stop.sortOrder = index
                stop.trip = trip
                keptIDs.insert(existingID)
            } else {
                let stop = TripStop(
                    destinationName: location.destinationName,
                    country: location.country,
                    occurredAt: draft.date,
                    notes: trimmedStopNotes.isEmpty ? nil : trimmedStopNotes,
                    journal: trimmedJournal.isEmpty ? nil : trimmedJournal,
                    photos: draft.photos.isEmpty ? nil : draft.photos,
                    latitude: location.latitude,
                    longitude: location.longitude,
                    sortOrder: index
                )
                context.insert(stop)
                stop.trip = trip
                keptIDs.insert(stop.persistentModelID)
            }
        }

        for (existingID, stop) in existingStops where !keptIDs.contains(existingID) {
            context.delete(stop)
        }
    }

    private static func initialStops(from trip: Trip) -> [TripStopDraft] {
        let actualStops = trip.orderedStops.map(TripStopDraft.init(stop:))
        if !actualStops.isEmpty {
            return actualStops
        }

        if
            let latitude = trip.latitude,
            let longitude = trip.longitude,
            (!trip.destinationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !trip.country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        {
            return [
                TripStopDraft(
                    date: trip.startDate,
                    location: TripLocation(
                        latitude: latitude,
                        longitude: longitude,
                        destinationName: trip.destinationName,
                        country: trip.country
                    )
                )
            ]
        }

        return [TripStopDraft(date: trip.startDate)]
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Trip.self,
        TripStop.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return TripFormView()
        .modelContainer(container)
}
