import SwiftUI
import UIKit

struct TripStopTimelineCard: View {
    let summary: TripStopSummary
    let position: Int

    var body: some View {
        SectionCard(
            title: summary.locationLabel.isEmpty ? "Stop \(position)" : summary.locationLabel,
            subtitle: "Stop \(position) · \(dateLabel)"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let notes = summary.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ColorToken.ink)
                }

                if let journal = summary.journal?.trimmingCharacters(in: .whitespacesAndNewlines), !journal.isEmpty {
                    journalQuote(journal)
                }

                if !summary.photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(summary.photos.enumerated()), id: \.offset) { _, data in
                                if let image = UIImage(data: data) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                            }
                        }
                    }
                }

                if summary.hasCoordinates {
                    Label("Pinned on the map", systemImage: "mappin.circle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.ColorToken.accent)
                }
            }
        }
    }

    private func journalQuote(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(AppTheme.ColorToken.accent.opacity(0.55))
                .frame(width: 3)

            Text(text)
                .font(.callout.italic())
                .foregroundStyle(AppTheme.ColorToken.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 4)
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: summary.occurredAt)
    }
}
