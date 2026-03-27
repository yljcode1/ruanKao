import SwiftUI
import UIKit

struct RootTabView: View {
    private enum Tab: Hashable {
        case home
        case practice
        case favorites
        case wrongBook
        case analytics
    }

    @ObservedObject var container: AppContainer
    @ObservedObject private var focusSessionStore: FocusSessionStore
    @State private var selection: Tab = .home
    @Environment(\.scenePhase) private var scenePhase

    init(container: AppContainer) {
        self.container = container
        _focusSessionStore = ObservedObject(wrappedValue: container.focusSessionStore)

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.08)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = .secondaryLabel
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.systemFont(ofSize: 11, weight: .medium)
        ]
        itemAppearance.selected.iconColor = .label
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        Group {
            if container.isPrepared {
                tabContent
            } else {
                startupView
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            focusSessionStore.handleScenePhase(newPhase)
        }
        .fullScreenCover(isPresented: focusOverlayBinding) {
            FocusSessionExperienceView(container: container, store: focusSessionStore)
        }
    }

    private var tabContent: some View {
        TabView(selection: $selection) {
            NavigationStack {
                DashboardView(container: container)
            }
            .tabItem {
                tabLabel(title: "首页", activeIcon: "house.fill", inactiveIcon: "house", tab: .home)
            }
            .tag(Tab.home)

            NavigationStack {
                PracticeView(container: container)
            }
            .tabItem {
                tabLabel(title: "刷题", activeIcon: "square.and.pencil", inactiveIcon: "square.and.pencil", tab: .practice)
            }
            .tag(Tab.practice)

            NavigationStack {
                FavoritesView(container: container)
            }
            .tabItem {
                tabLabel(title: "收藏", activeIcon: "star.fill", inactiveIcon: "star", tab: .favorites)
            }
            .tag(Tab.favorites)

            NavigationStack {
                WrongBookView(container: container)
            }
            .tabItem {
                tabLabel(title: "错题本", activeIcon: "exclamationmark.bubble.fill", inactiveIcon: "exclamationmark.bubble", tab: .wrongBook)
            }
            .tag(Tab.wrongBook)

            NavigationStack {
                AnalyticsView(container: container)
            }
            .tabItem {
                tabLabel(title: "分析", activeIcon: "chart.line.uptrend.xyaxis", inactiveIcon: "chart.line.uptrend.xyaxis", tab: .analytics)
            }
            .tag(Tab.analytics)
        }
        .tint(AppTheme.Colors.primary)
        .toolbarBackground(Color.white, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    private var startupView: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(width: 72, height: 72)
                    .background(AppTheme.Colors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(spacing: 8) {
                    Text("正在准备题库")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Text(container.preparationError ?? "首次打开或题库更新时会同步题目，完成后自动进入首页。")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                if container.preparationError == nil {
                    ProgressView()
                        .tint(AppTheme.Colors.primary)
                } else {
                    Button("重新尝试") {
                        container.prepareIfNeeded()
                    }
                    .appButton()
                }
            }
            .padding(28)
        }
    }

    private func tabLabel(title: String, activeIcon: String, inactiveIcon: String, tab: Tab) -> some View {
        Label(title, systemImage: selection == tab ? activeIcon : inactiveIcon)
    }

    private var focusOverlayBinding: Binding<Bool> {
        Binding(
            get: { focusSessionStore.isPresenting },
            set: { shouldPresent in
                if !shouldPresent {
                    focusSessionStore.requestDismissOverlay()
                }
            }
        )
    }
}
