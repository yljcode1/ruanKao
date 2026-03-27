import SwiftUI

@main
struct RuanKaoApp: App {
    @StateObject private var container = AppContainer.bootstrap()
    @AppStorage("appearance_mode") private var appearanceModeRaw = AppearanceMode.system.rawValue

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(container: container)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
    }
}
