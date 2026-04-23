import SwiftUI
import UIKit

struct TripRowView: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(trip.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ColorToken.ink)
                        .lineLimit(1)
                    if trip.favorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.ColorToken.accent)
                    }
                    Spacer()
                }

                if !destinationLabel.isEmpty {
                    Text(destinationLabel)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                        .lineLimit(1)
                }

                Text(dateLabel)
                    .font(.caption)
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            }
        }
        .padding(.vertical, 4)
    }

    private var destinationLabel: String {
        [trip.destinationName, trip.country]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var dateLabel: String {
        let start = Self.formatter.string(from: trip.startDate)
        guard let end = trip.endDate, end > trip.startDate else { return start }
        return "\(start) – \(Self.formatter.string(from: end))"
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    @ViewBuilder
    private var thumbnail: some View {
        if let data = (trip.photos ?? []).first, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.ColorToken.accentSoft)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "suitcase")
                        .font(.title3)
                        .foregroundStyle(AppTheme.ColorToken.accent)
                )
        }
    }
}
