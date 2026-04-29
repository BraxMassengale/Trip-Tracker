import SwiftUI

struct AttachmentLinkDraft: Identifiable {
    let id = UUID()
    var title: String = ""
    var urlString: String = ""
}

struct AttachmentRenameDraft: Identifiable {
    let id = UUID()
    let attachment: Attachment
    var title: String
}

struct AttachmentLinkForm: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var urlString: String
    @State private var showingInvalidURL = false

    let onSave: (String, URL) -> Void

    init(draft: AttachmentLinkDraft, onSave: @escaping (String, URL) -> Void) {
        _title = State(initialValue: draft.title)
        _urlString = State(initialValue: draft.urlString)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Link") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    TextField("URL", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Add Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Invalid URL", isPresented: $showingInvalidURL) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Enter a full link like https://example.com.")
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL), url.scheme != nil else {
            showingInvalidURL = true
            return
        }

        onSave(trimmedTitle, url)
        dismiss()
    }
}

struct AttachmentRenameForm: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    let draft: AttachmentRenameDraft
    let onSave: (Attachment, String) -> Void

    init(draft: AttachmentRenameDraft, onSave: @escaping (Attachment, String) -> Void) {
        self.draft = draft
        self.onSave = onSave
        _title = State(initialValue: draft.title)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Rename")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft.attachment, title.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
