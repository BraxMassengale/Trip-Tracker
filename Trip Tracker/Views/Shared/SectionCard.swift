import SwiftUI

struct SectionCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    @ViewBuilder var content: () -> Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Metric.cardSpacing) {
            if let title {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ColorToken.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    }
                }
            }
            content()
        }
        .padding(AppTheme.Metric.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .trackerCard()
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            SectionCard(title: "Summary", subtitle: "A calm preview.") {
                Text("Trip Tracker")
                    .foregroundStyle(AppTheme.ColorToken.ink)
            }

            SectionCard {
                Text("Untitled card")
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            }
        }
        .padding()
    }
    .background(AppTheme.ColorToken.canvas)
}
