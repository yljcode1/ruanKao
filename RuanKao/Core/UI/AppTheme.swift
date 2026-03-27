import SwiftUI

enum AppTheme {
    enum Colors {
        static let primary = dynamic(
            light: UIColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1),
            dark: UIColor(red: 0.25, green: 0.35, blue: 0.62, alpha: 1)
        )
        static let secondary = dynamic(
            light: UIColor(red: 0.43, green: 0.45, blue: 0.50, alpha: 1),
            dark: UIColor(red: 0.67, green: 0.70, blue: 0.76, alpha: 1)
        )
        static let accent = Color(uiColor: .systemBlue)
        static let success = Color(uiColor: .systemGreen)
        static let danger = Color(uiColor: .systemRed)
        static let background = Color(uiColor: .systemGroupedBackground)
        static let card = Color(uiColor: .secondarySystemGroupedBackground)
        static let elevatedCard = Color(uiColor: .systemBackground)
        static let muted = Color(uiColor: .tertiarySystemFill)
        static let stroke = dynamic(
            light: UIColor.black.withAlphaComponent(0.06),
            dark: UIColor.white.withAlphaComponent(0.12)
        )
        static let textPrimary = Color(uiColor: .label)
        static let textSecondary = Color(uiColor: .secondaryLabel)
        static let textTertiary = Color(uiColor: .tertiaryLabel)

        private static func dynamic(light: UIColor, dark: UIColor) -> Color {
            Color(
                uiColor: UIColor { traitCollection in
                    traitCollection.userInterfaceStyle == .dark ? dark : light
                }
            )
        }
    }

    enum Gradients {
        static let hero = LinearGradient(
            colors: [
                Colors.elevatedCard,
                Colors.card
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let accent = LinearGradient(
            colors: [
                Colors.accent.opacity(0.14),
                Colors.accent.opacity(0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    enum Metrics {
        static let cardRadius: CGFloat = 20
        static let chipRadius: CGFloat = 12
        static let controlRadius: CGFloat = 16
        static let compactRadius: CGFloat = 14
        static let cardPadding: CGFloat = 20
        static let listSectionSpacing: CGFloat = 20
        static let listItemSpacing: CGFloat = 16
        static let listRowMinHeight: CGFloat = 172
        static let chartLineWidth: CGFloat = 2.25
        static let chartPointSize: CGFloat = 28
        static let chartBarOpacity: Double = 0.20
        static let chartAreaOpacity: Double = 0.10
        static let shadowRadius: CGFloat = 0
    }
}
