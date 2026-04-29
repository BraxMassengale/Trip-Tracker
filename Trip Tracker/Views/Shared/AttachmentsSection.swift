import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private struct SafariRoute: Identifiable {
    let id = UUID()
    let url: URL
}

struct AttachmentsSection: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    let attachments: [Attachment]
    let onAttach: (Attachment) -> Void
    var embedded: Bool = false

    init(
        attachments: [Attachment],
        embedded: Bool = false,
        onAttach: @escaping (Attachment) -> Void
    ) {
        self.attachments = attachments
        self.embedded = embedded
        self.onAttach = onAttach
    }

    @State private var showingFileImporter = false
    @State private var linkDraft: AttachmentLinkDraft?
    @State private var renameDraft: AttachmentRenameDraft?
    @State private var showingLocationPicker = false
    @State private var selectedLocation: TripLocation?
    @State private var safariRoute: SafariRoute?
    @State private var quickLookFile: QuickLookFile?
    @State private var errorMessage: String?
    @State private var showingError = false

    private var sortedAttachments: [Attachment] {
        attachments.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                SectionCard(title: "Attachments") {
                    content
                }
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
        .sheet(item: $linkDraft) { draft in
            AttachmentLinkForm(draft: draft) { title, url in
                addLink(title: title, url: url)
            }
        }
        .sheet(item: $renameDraft) { draft in
            AttachmentRenameForm(draft: draft) { attachment, title in
                rename(attachment, title: title)
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerSheet(location: $selectedLocation)
                .onDisappear(perform: commitSelectedLocation)
        }
        .sheet(item: $safariRoute) { route in
            SafariView(url: route.url)
        }
        .sheet(item: $quickLookFile) { file in
            QuickLookView(file: file)
        }
        .alert("Attachment Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            if embedded {
                Text("Attachments")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ColorToken.ink)
            }

            addMenu

            if sortedAttachments.isEmpty {
                Text("Attach tickets, confirmations, links, or saved places.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedAttachments) { attachment in
                        attachmentRow(attachment)
                    }
                }
            }
        }
    }

    private var addMenu: some View {
        Menu {
            Button {
                showingFileImporter = true
            } label: {
                Label("Add file", systemImage: "doc.badge.plus")
            }

            Button {
                linkDraft = AttachmentLinkDraft()
            } label: {
                Label("Add link", systemImage: "link.badge.plus")
            }

            Button {
                selectedLocation = nil
                showingLocationPicker = true
            } label: {
                Label("Add location", systemImage: "mappin.and.ellipse")
            }
        } label: {
            Label("Add", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func attachmentRow(_ attachment: Attachment) -> some View {
        Button {
            open(attachment)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: attachment.kind.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.ColorToken.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ColorToken.ink)
                        .lineLimit(1)

                    Text(attachment.sortedSubtitle)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.ColorToken.canvas)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                renameDraft = AttachmentRenameDraft(attachment: attachment, title: attachment.title)
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button(role: .destructive) {
                delete(attachment)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let values = try url.resourceValues(forKeys: [.contentTypeKey])
            let attachment = Attachment(
                kind: .file,
                title: url.deletingPathExtension().lastPathComponent,
                fileData: data,
                fileName: url.lastPathComponent,
                mimeType: values.contentType?.preferredMIMEType
            )
            insert(attachment)
        } catch {
            showError("Couldn't import that file.")
        }
    }

    private func addLink(title: String, url: URL) {
        let attachment = Attachment(kind: .url, title: title, url: url)
        insert(attachment)
    }

    private func commitSelectedLocation() {
        guard let location = selectedLocation else { return }
        selectedLocation = nil

        let attachment = Attachment(
            kind: .location,
            title: location.destinationName,
            latitude: location.latitude,
            longitude: location.longitude,
            address: location.country
        )
        insert(attachment)
    }

    private func insert(_ attachment: Attachment) {
        context.insert(attachment)
        onAttach(attachment)
        save(action: "save attachment")
        Haptics.success()
    }

    private func rename(_ attachment: Attachment, title: String) {
        attachment.title = title
        save(action: "rename attachment")
        Haptics.selection()
    }

    private func delete(_ attachment: Attachment) {
        context.delete(attachment)
        save(action: "delete attachment")
        Haptics.selection()
    }

    private func open(_ attachment: Attachment) {
        switch attachment.kind {
        case .file:
            openFile(attachment)
        case .url:
            guard let url = attachment.url else {
                showError("This link is missing its URL.")
                return
            }
            safariRoute = SafariRoute(url: url)
        case .location:
            guard let mapsURL = attachment.mapsURL else {
                showError("This location is missing coordinates.")
                return
            }
            openURL(mapsURL)
        }
    }

    private func openFile(_ attachment: Attachment) {
        guard let data = attachment.fileData else {
            showError("This file is missing its stored data.")
            return
        }

        do {
            let fileName = attachment.fileName ?? "\(attachment.title).dat"
            let folderURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(attachment.id.uuidString)
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            let fileURL = folderURL.appendingPathComponent(fileName)
            try data.write(to: fileURL, options: .atomic)
            quickLookFile = QuickLookFile(url: fileURL)
        } catch {
            showError("Couldn't preview that file.")
        }
    }

    private func save(action: String) {
        if let error = PersistenceReporter.save(context, action: action) {
            errorMessage = PersistenceReporter.userMessage(for: action, error: error)
            showingError = true
            Haptics.error()
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
        Haptics.error()
    }
}
