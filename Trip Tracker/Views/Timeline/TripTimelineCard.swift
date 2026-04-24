import SwiftUI
import UIKit

struct TripTimelineCard: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverImage

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(trip.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.ColorToken.ink)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if trip.favorite, !hasCover {
                        Image(systemName: "heart.fill")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.ColorToken.accent)
                    }
                }

                if !destinationLabel.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(AppTheme.ColorToken.accent)
                        Text(destinationLabel)
                            .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    }
                    .font(.subheadline)
                }

                if let subtitle = trip.timelineSubtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text(dateLabel)
                }
                .font(.caption)
                .foregroundStyle(AppTheme.ColorToken.secondaryInk)

                if let rating = trip.rating, rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { value in
                            Image(systemName: rating >= value ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(rating >= value
                                    ? AppTheme.ColorToken.accent
                                    : AppTheme.ColorToken.muted)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.ColorToken.cardFill)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Metric.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.ColorToken.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metric.cardCornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var hasCover: Bool {
        trip.previewPhotoData != nil
    }

    @ViewBuilder
    private var coverImage: some View {
        if let first = trip.previewPhotoData, let image = UIImage(data: first) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    if trip.favorite {
                        Image(systemName: "heart.fill")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                            .padding(12)
                    }
                }
        }
    }

    private var destinationLabel: String {
        trip.displayDestinationSummary
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let start = formatter.string(from: trip.startDate)
        guard let end = trip.endDate, end > trip.startDate else { return start }
        return "\(start) – \(formatter.string(from: end))"
    }
}
