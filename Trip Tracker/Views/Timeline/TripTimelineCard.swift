import SwiftUI
import UIKit

struct TripTimelineCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let trip: Trip

    private var usesExpandedTextLayout: Bool {
        switch dynamicTypeSize {
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return true
        default:
            return false
        }
    }

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
            }
        }
    }

    @ViewBuilder
    private var heroPhoto: some View {
        if let data = trip.previewPhotoData, let image = UIImage(data: data) {
            Color.clear
                .aspectRatio(usesExpandedTextLayout ? 4/3 : 16/9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
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
                        .lineLimit(usesExpandedTextLayout ? 3 : 2)
                        .minimumScaleFactor(usesExpandedTextLayout ? 0.9 : 1)
                        .fixedSize(horizontal: false, vertical: true)
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Text(trip.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.ColorToken.ink)
                        .lineLimit(usesExpandedTextLayout ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    if trip.favorite {
                        Image(systemName: "heart.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.ColorToken.accent)
                            .accessibilityLabel("Favorite")
                    }
                }

                Label(noPhotoLabel, systemImage: "photo")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ColorToken.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.ColorToken.accentSoft, in: Capsule())
                    .accessibilityLabel(noPhotoLabel)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        AppTheme.ColorToken.accentSoft.opacity(0.95),
                        AppTheme.ColorToken.cardFill
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var noPhotoLabel: String {
        trip.hasAnyPhotos ? "Choose hero photo" : "No photos yet"
    }

    private var metadataChips: some View {
        FlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(metadataItems) { item in
                TimelineMetadataChip(item: item)
            }
        }
    }

    private var metadataItems: [TimelineMetadataItem] {
        var items: [TimelineMetadataItem] = [
            TimelineMetadataItem(
                label: trip.stopCountLabel,
                symbolName: "mappin.and.ellipse",
                isProminent: false
            )
        ]

        items.append(TimelineMetadataItem(
            label: photoLabel,
            symbolName: trip.previewPhotoData == nil ? "photo" : "photo.fill",
            isProminent: trip.previewPhotoData != nil
        ))

        if attachmentCount > 0 {
            items.append(TimelineMetadataItem(
                label: attachmentCount == 1 ? "1 attachment" : "\(attachmentCount) attachments",
                symbolName: "paperclip",
                isProminent: false
            ))
        }

        if !trip.companions.isEmpty {
            items.append(TimelineMetadataItem(
                label: companionLabel,
                symbolName: "person.2",
                isProminent: false
            ))
        }

        if trip.mapJourneyLocations.count > 1 {
            items.append(TimelineMetadataItem(
                label: routeLabel,
                symbolName: "point.topleft.down.curvedto.point.bottomright.up",
                isProminent: true
            ))
        } else if trip.hasCoordinates {
            items.append(TimelineMetadataItem(
                label: "On map",
                symbolName: "map",
                isProminent: false
            ))
        }

        return items
    }

    private var photoLabel: String {
        let count = photoCount
        if trip.previewPhotoData != nil {
            return "Hero photo"
        }
        if count == 0 {
            return "No photos"
        }
        return count == 1 ? "1 photo" : "\(count) photos"
    }

    private var photoCount: Int {
        (trip.photos ?? []).count + trip.stopSummaries.reduce(0) { total, summary in
            total + summary.photos.count
        }
    }

    private var attachmentCount: Int {
        trip.attachments.count + trip.orderedStops.reduce(0) { total, stop in
            total + stop.attachments.count
        }
    }

    private var companionLabel: String {
        if trip.companions.count == 1, let companion = trip.companions.first {
            return companion
        }
        return "\(trip.companions.count) companions"
    }

    private var routeLabel: String {
        let segments = max(0, trip.mapJourneyLocations.count - 1)
        return segments == 1 ? "1 route" : "\(segments) routes"
    }

    @ViewBuilder
    private var ratingView: some View {
        if let rating = trip.rating, rating > 0 {
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { value in
                        Image(systemName: rating >= value ? "star.fill" : "star")
                            .font(.caption2.weight(.semibold))
                    }
                }
                .foregroundStyle(AppTheme.ColorToken.accent)
                .accessibilityHidden(true)

                Text("\(min(rating, 5))/5")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ColorToken.ink)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.ColorToken.accentSoft, in: Capsule())
            .accessibilityLabel("Rated \(min(rating, 5)) out of 5")
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            destinationLine

            Text(dateAndDurationLabel)
                .font(.footnote)
                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                .lineLimit(usesExpandedTextLayout ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle = trip.timelineSubtitle {
                Text(subtitle)
                    .font(.footnote)
                    .italic()
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    .lineLimit(usesExpandedTextLayout ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            metadataChips

            if trip.rating != nil {
                ratingView
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
                            .lineLimit(usesExpandedTextLayout ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
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

    private var accessibilitySummary: String {
        var parts = [
            trip.title,
            trip.displayDestinationSummary,
            dateAndDurationLabel,
            trip.stopCountLabel,
            photoLabel
        ]

        if attachmentCount > 0 {
            parts.append(attachmentCount == 1 ? "1 attachment" : "\(attachmentCount) attachments")
        }

        if !trip.companions.isEmpty {
            parts.append(companionLabel)
        }

        if let rating = trip.rating, rating > 0 {
            parts.append("Rated \(min(rating, 5)) out of 5")
        }

        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

private struct TimelineMetadataItem: Identifiable {
    let label: String
    let symbolName: String
    let isProminent: Bool

    var id: String {
        "\(symbolName)-\(label)"
    }
}

private struct TimelineMetadataChip: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let item: TimelineMetadataItem

    private var usesExpandedTextLayout: Bool {
        switch dynamicTypeSize {
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return true
        default:
            return false
        }
    }

    var body: some View {
        Label(item.label, systemImage: item.symbolName)
            .font(.caption.weight(.semibold))
            .lineLimit(usesExpandedTextLayout ? 2 : 1)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(item.isProminent ? AppTheme.ColorToken.accent : AppTheme.ColorToken.secondaryInk)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: usesExpandedTextLayout ? 10 : 999, style: .continuous)
                    .fill(item.isProminent
                    ? AppTheme.ColorToken.accentSoft
                    : AppTheme.ColorToken.canvas)
            )
            .overlay(
                RoundedRectangle(cornerRadius: usesExpandedTextLayout ? 10 : 999, style: .continuous)
                    .stroke(AppTheme.ColorToken.cardBorder.opacity(0.75), lineWidth: 1)
            )
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
            let size = measuredSize(for: subview, maxWidth: maxWidth)
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
            let size = measuredSize(for: subview, maxWidth: bounds.width)
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

    private func measuredSize(for subview: Subviews.Element, maxWidth: CGFloat) -> CGSize {
        guard maxWidth.isFinite else {
            return subview.sizeThatFits(.unspecified)
        }

        let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
        return CGSize(width: min(size.width, maxWidth), height: size.height)
    }
}
