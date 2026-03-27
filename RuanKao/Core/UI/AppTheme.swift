import SwiftUI

enum AppTheme {
    enum Colors {
        static let primary = Color(red: 0.11, green: 0.12, blue: 0.14)
        static let secondary = Color(red: 0.43, green: 0.45, blue: 0.50)
        static let accent = Color(red: 0.22, green: 0.41, blue: 0.82)
        static let success = Color(red: 0.22, green: 0.56, blue: 0.40)
        static let danger = Color(red: 0.74, green: 0.34, blue: 0.31)
        static let background = Color(red: 0.96, green: 0.96, blue: 0.97)
        static let card = Color.white
        static let elevatedCard = Color.white
        static let muted = Color.black.opacity(0.025)
        static let stroke = Color.black.opacity(0.06)
        static let textPrimary = Color(uiColor: .label)
        static let textSecondary = Color(uiColor: .secondaryLabel)
        static let textTertiary = Color(uiColor: .tertiaryLabel)
    }

    enum Gradients {
        static let hero = LinearGradient(
            colors: [
                Color.white,
                Color(red: 0.95, green: 0.96, blue: 0.98)
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
