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
    @State private var selection: Tab = .home

    init(container: AppContainer) {
        self.container = container

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

    private func tabLabel(title: String, activeIcon: String, inactiveIcon: String, tab: Tab) -> some View {
        Label(title, systemImage: selection == tab ? activeIcon : inactiveIcon)
    }
}
