import SwiftUI
import UIKit

struct HeroPhotoGallery: View {
    @Binding var photos: [Data]
    @Binding var photoIDs: [UUID]
    @Binding var heroPhotoID: UUID?

    let thumbnailSize: CGSize

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, data in
                    if let image = UIImage(data: data) {
                        heroPhotoThumbnail(image: image, index: index)
                    }
                }
            }
        }
        .onAppear(perform: normalizeSelection)
        .onChange(of: photos) { _, _ in
            normalizeSelection()
        }
    }

    private func heroPhotoThumbnail(image: UIImage, index: Int) -> some View {
        let photoID = photoIDs.indices.contains(index) ? photoIDs[index] : nil
        let isHero = photoID == heroPhotoID

        return Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: thumbnailSize.width, height: thumbnailSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .topLeading) {
                if isHero {
                    Image(systemName: "star.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(AppTheme.ColorToken.accent, in: Circle())
                        .padding(5)
                        .accessibilityLabel("Hero photo")
                }
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    deletePhoto(at: index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.5))
                        .font(.title3)
                }
                .padding(4)
                .accessibilityLabel("Delete photo")
            }
            .contextMenu {
                if isHero {
                    Button {
                        heroPhotoID = nil
                        Haptics.selection()
                    } label: {
                        Label("Remove hero", systemImage: "star.slash")
                    }
                } else if let photoID {
                    Button {
                        heroPhotoID = photoID
                        Haptics.selection()
                    } label: {
                        Label("Set as hero", systemImage: "star")
                    }
                }
            }
    }

    private func deletePhoto(at index: Int) {
        let removedID = photoIDs.indices.contains(index) ? photoIDs[index] : nil

        photos.remove(at: index)
        if photoIDs.indices.contains(index) {
            photoIDs.remove(at: index)
        }
        if heroPhotoID == removedID {
            heroPhotoID = nil
        }

        normalizeSelection()
        Haptics.selection()
    }

    private func normalizeSelection() {
        photoIDs = PhotoSelection.normalizedIDs(for: photos, existingIDs: photoIDs)
        heroPhotoID = PhotoSelection.cleanedHeroPhotoID(heroPhotoID, photoIDs: photoIDs)
    }
}

struct HeroPhotoReadOnlyGallery: View {
    let photos: [Data]
    let photoIDs: [UUID]
    let heroPhotoID: UUID?
    let thumbnailSize: CGSize

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, data in
                    if let image = UIImage(data: data) {
                        heroPhotoThumbnail(image: image, index: index)
                    }
                }
            }
        }
    }

    private func heroPhotoThumbnail(image: UIImage, index: Int) -> some View {
        let normalizedIDs = PhotoSelection.normalizedIDs(for: photos, existingIDs: photoIDs)
        let photoID = normalizedIDs.indices.contains(index) ? normalizedIDs[index] : nil
        let isHero = photoID == heroPhotoID

        return Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: thumbnailSize.width, height: thumbnailSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .topLeading) {
                if isHero {
                    Image(systemName: "star.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(AppTheme.ColorToken.accent, in: Circle())
                        .padding(5)
                        .accessibilityLabel("Hero photo")
                }
            }
    }
}
