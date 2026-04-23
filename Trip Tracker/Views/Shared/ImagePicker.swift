import SwiftUI
import PhotosUI
import UIKit

struct ImagePicker: View {
    @Binding var images: [Data]
    let maxCount: Int

    @State private var selection: [PhotosPickerItem] = []

    init(images: Binding<[Data]>, maxCount: Int = 12) {
        self._images = images
        self.maxCount = maxCount
    }

    var body: some View {
        PhotosPicker(
            selection: $selection,
            maxSelectionCount: max(0, maxCount - images.count),
            matching: .images,
            photoLibrary: .shared()
        ) {
            Label(addLabel, systemImage: "photo.badge.plus")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(images.count >= maxCount
                    ? AppTheme.ColorToken.secondaryInk
                    : AppTheme.ColorToken.accent)
        }
        .disabled(images.count >= maxCount)
        .onChange(of: selection) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                let loaded = await load(newItems)
                images.append(contentsOf: loaded)
                selection = []
            }
        }
    }

    private var addLabel: String {
        images.isEmpty ? "Add photos" : "Add more (\(images.count)/\(maxCount))"
    }

    private func load(_ items: [PhotosPickerItem]) async -> [Data] {
        var result: [Data] = []
        for item in items {
            guard let raw = try? await item.loadTransferable(type: Data.self) else { continue }
            result.append(compress(raw) ?? raw)
        }
        return result
    }

    private func compress(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return image.jpegData(compressionQuality: 0.8)
    }
}
