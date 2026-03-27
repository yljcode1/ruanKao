import SwiftUI

enum PrimaryCardStyle {
    case elevated
    case subtle
    case gradient(LinearGradient)
}

struct PrimaryCard<Content: View>: View {
    let style: PrimaryCardStyle
    let content: Content

    init(style: PrimaryCardStyle = .elevated, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppTheme.Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous)
                    .strokeBorder(AppTheme.Colors.stroke)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous))
    }

    @ViewBuilder
    private var cardBackground: some View {
        switch style {
        case .elevated:
            AppTheme.Colors.elevatedCard
        case .subtle:
            AppTheme.Colors.card
        case .gradient(let gradient):
            gradient
        }
    }

}

struct StatePanel<Accessory: View>: View {
    let title: String
    let message: String
    let icon: String
    var tint: Color
    let accessory: Accessory

    init(
        title: String,
        message: String,
        icon: String,
        tint: Color = AppTheme.Colors.secondary,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.tint = tint
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            accessory
        }
        .padding(AppTheme.Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.card)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous)
                .stroke(AppTheme.Colors.stroke)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous))
    }
}

enum AppButtonTone {
    case primary
    case secondary
    case success
    case danger
}

private struct AppBorderedButtonModifier: ViewModifier {
    let tone: AppButtonTone

    func body(content: Content) -> some View {
        switch tone {
        case .primary:
            content
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.controlRadius))
                .tint(AppTheme.Colors.accent)
        case .secondary:
            content
                .controlSize(.large)
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.controlRadius))
                .tint(AppTheme.Colors.primary)
        case .success:
            content
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.controlRadius))
                .tint(AppTheme.Colors.success)
        case .danger:
            content
                .controlSize(.large)
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: AppTheme.Metrics.controlRadius))
                .tint(AppTheme.Colors.danger)
        }
    }
}

private struct AppScreenChromeModifier: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(tint)
    }
}

extension View {
    func appButton(_ tone: AppButtonTone = .primary) -> some View {
        modifier(AppBorderedButtonModifier(tone: tone))
    }

    func appScreenChrome(tint: Color = AppTheme.Colors.primary) -> some View {
        modifier(AppScreenChromeModifier(tint: tint))
    }
}
