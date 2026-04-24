import SwiftUI
import UIKit

enum AppTheme {
    enum ColorToken {
        private static func dynamic(_ light: UIColor, _ dark: UIColor) -> Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            })
        }

        static let accent = dynamic(
            UIColor(red: 0.18, green: 0.48, blue: 0.56, alpha: 1),
            UIColor(red: 0.39, green: 0.64, blue: 0.73, alpha: 1)
        )

        static let accentSoft = dynamic(
            UIColor(red: 0.91, green: 0.94, blue: 0.96, alpha: 1),
            UIColor(red: 0.10, green: 0.19, blue: 0.22, alpha: 1)
        )

        static let ink = dynamic(
            UIColor(red: 0.09, green: 0.10, blue: 0.12, alpha: 1),
            UIColor(red: 0.93, green: 0.93, blue: 0.92, alpha: 1)
        )

        static let secondaryInk = dynamic(
            UIColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1),
            UIColor(red: 0.61, green: 0.64, blue: 0.68, alpha: 1)
        )

        static let canvas = dynamic(
            UIColor(red: 0.96, green: 0.96, blue: 0.95, alpha: 1),
            UIColor(red: 0.07, green: 0.08, blue: 0.09, alpha: 1)
        )

        static let cardFill = dynamic(
            UIColor.white,
            UIColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1)
        )

        static let cardBorder = dynamic(
            UIColor(red: 0.89, green: 0.88, blue: 0.85, alpha: 1),
            UIColor(red: 0.17, green: 0.18, blue: 0.20, alpha: 1)
        )

        static let positive = dynamic(
            UIColor(red: 0.29, green: 0.55, blue: 0.43, alpha: 1),
            UIColor(red: 0.48, green: 0.73, blue: 0.63, alpha: 1)
        )

        static let muted = dynamic(
            UIColor(red: 0.75, green: 0.74, blue: 0.72, alpha: 1),
            UIColor(red: 0.22, green: 0.24, blue: 0.26, alpha: 1)
        )

        static let routeBlue = dynamic(
            UIColor(red: 0.20, green: 0.42, blue: 0.86, alpha: 1),
            UIColor(red: 0.43, green: 0.63, blue: 0.95, alpha: 1)
        )

        static let routeViolet = dynamic(
            UIColor(red: 0.48, green: 0.34, blue: 0.78, alpha: 1),
            UIColor(red: 0.66, green: 0.55, blue: 0.93, alpha: 1)
        )

        static let routeRose = dynamic(
            UIColor(red: 0.75, green: 0.27, blue: 0.42, alpha: 1),
            UIColor(red: 0.92, green: 0.50, blue: 0.62, alpha: 1)
        )

        static let routeGold = dynamic(
            UIColor(red: 0.66, green: 0.46, blue: 0.12, alpha: 1),
            UIColor(red: 0.90, green: 0.69, blue: 0.30, alpha: 1)
        )

        static let routeSlate = dynamic(
            UIColor(red: 0.36, green: 0.43, blue: 0.52, alpha: 1),
            UIColor(red: 0.58, green: 0.65, blue: 0.73, alpha: 1)
        )
    }

    enum Metric {
        static let cardCornerRadius: CGFloat = 20
        static let cardPadding: CGFloat = 20
        static let cardSpacing: CGFloat = 14
    }
}

private struct TrackerCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Metric.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.ColorToken.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Metric.cardCornerRadius, style: .continuous)
                    .stroke(AppTheme.ColorToken.cardBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func trackerCard() -> some View {
        modifier(TrackerCardModifier())
    }
}
