import SwiftUI
import UIKit

struct TripTimelineCard: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroPhoto
            content
        }
        .background(AppTheme.ColorToken.cardFill)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Metric.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.ColorToken.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metric.cardCornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
    }

    @ViewBuilder
    private var heroPhoto: some View {
        if let data = trip.previewPhotoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .aspectRatio(16/9, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [Color.black.opacity(0.55), Color.black.opacity(0)],
                        startPoint: .bottom,
                        endPoint: .center
                    )
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomLeading) {
                    Text(trip.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .padding(14)
                }
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
        } else {
            HStack {
                Text(trip.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.ColorToken.ink)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if trip.favorite {
                    Image(systemName: "heart.fill")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.ColorToken.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            destinationLine

            Text(dateAndDurationLabel)
                .font(.footnote)
                .foregroundStyle(AppTheme.ColorToken.secondaryInk)

            if let subtitle = trip.timelineSubtitle {
                Text(subtitle)
                    .font(.footnote)
                    .italic()
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    .lineLimit(1)
            }

            if let rating = trip.rating, rating > 0 {
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { value in
                        Circle()
                            .fill(rating >= value
                                ? AppTheme.ColorToken.accent
                                : AppTheme.ColorToken.muted.opacity(0.5))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var destinationLine: some View {
        let stops = destinationStops

        if stops.isEmpty {
            EmptyView()
        } else {
            FlowLayout(horizontalSpacing: 6, verticalSpacing: 4) {
                ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
                    if index > 0 {
                        if let mode = stop.arrivalMode {
                            Image(systemName: mode.symbolName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.ColorToken.accent)
                                .accessibilityLabel(mode.label)
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.ColorToken.secondaryInk.opacity(0.6))
                                .accessibilityHidden(true)
                        }
                    }

                    HStack(spacing: 4) {
                        if let flag = stop.flag {
                            Text(flag)
                                .font(.subheadline)
                        }
                        Text(stop.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.ColorToken.ink)
                    }
                }
            }
        }
    }

    private struct DestinationStop {
        let name: String
        let flag: String?
        let arrivalMode: TransportMode?
    }

    private var destinationStops: [DestinationStop] {
        let stops = trip.stopSummaries
            .map { summary in
                DestinationStop(
                    name: stopShortName(summary),
                    flag: CountryFlag.emoji(for: summary.country),
                    arrivalMode: summary.arrivalMode
                )
            }
            .filter { !$0.name.isEmpty }

        if !stops.isEmpty {
            return stops
        }

        let fallbackName = trip.destinationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fallbackName.isEmpty else { return [] }
        return [
            DestinationStop(
                name: fallbackName,
                flag: CountryFlag.emoji(for: trip.country),
                arrivalMode: nil
            )
        ]
    }

    private func stopShortName(_ summary: TripStopSummary) -> String {
        let trimmedName = summary.destinationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty { return trimmedName }
        return summary.country.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var dateAndDurationLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"

        let start = trip.startDate
        let calendar = Calendar.current

        guard let end = trip.endDate, end > start else {
            let fullFormatter = DateFormatter()
            fullFormatter.dateStyle = .medium
            return fullFormatter.string(from: start)
        }

        let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: end)
        let sameMonth = sameYear && calendar.component(.month, from: start) == calendar.component(.month, from: end)

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"

        let datePart: String
        if sameMonth {
            datePart = "\(formatter.string(from: start))–\(dayFormatter.string(from: end)), \(yearFormatter.string(from: end))"
        } else if sameYear {
            datePart = "\(formatter.string(from: start)) – \(formatter.string(from: end)), \(yearFormatter.string(from: end))"
        } else {
            let full = DateFormatter()
            full.dateFormat = "MMM d, yyyy"
            datePart = "\(full.string(from: start)) – \(full.string(from: end))"
        }

        let days = max(1, (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0) + 1)
        let durationLabel = days == 1 ? "1 day" : "\(days) days"

        return "\(datePart) · \(durationLabel)"
    }
}

private struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        var rowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + verticalSpacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + (rowWidth > 0 ? horizontalSpacing : 0)
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : rowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
