import SafariServices
import SwiftUI
import UIKit

struct OpenClawPortalView: View {
    @AppStorage("openclaw_portal_url") private var storedURLString = "http://110.40.136.189:19888/"
    @AppStorage("openclaw_portal_token") private var storedToken = ""
    @Environment(\.openURL) private var openURL

    @State private var draftURLString = ""
    @State private var draftToken = ""
    @State private var draftPassword = ""
    @State private var activeURLString = ""
    @State private var loadError: String?
    @State private var statusMessage: String?
    @State private var hasInitialized = false
    @State private var presentedPortal: OpenClawPresentedPortal?

    private var activeLaunchContext: OpenClawPortalLaunchContext? {
        resolvedPortalLaunchContext(from: activeURLString)
    }

    private var activeURL: URL? {
        portalURL(for: activeLaunchContext, token: normalizedToken(from: storedToken))
    }

    private var usesWebSocketGateway: Bool {
        isWebSocketURLString(activeURLString)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                PrimaryCard(style: .subtle) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "link.circle.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.primary)
                                .frame(width: 44, height: 44)
                                .background(AppTheme.Colors.muted)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous))

                            VStack(alignment: .leading, spacing: 6) {
                                Text("OpenClaw 工作台")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)

                                Text("支持直接填 OpenClaw Control UI 页面，也支持填 `ws://` 或 `wss://` 网关地址，App 会自动尝试打开同主机同端口的工作台页面。")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }

                            Spacer(minLength: 0)
                        }

                        HStack(spacing: 8) {
                            PillTag(
                                title: usesWebSocketGateway ? "WS 网关" : "网页入口",
                                icon: usesWebSocketGateway ? "point.3.connected.trianglepath.dotted" : "globe",
                                tint: AppTheme.Colors.secondary
                            )

                            PillTag(
                                title: presentedPortal == nil ? "待打开" : "已打开",
                                icon: presentedPortal == nil ? "clock.arrow.circlepath" : "checkmark.circle",
                                tint: presentedPortal == nil ? AppTheme.Colors.secondary : AppTheme.Colors.primary
                            )

                            PillTag(
                                title: activeURL?.host() ?? "未设置",
                                icon: "network",
                                tint: AppTheme.Colors.secondary
                            )
                        }
                    }
                }

                PrimaryCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader("连接地址", subtitle: "可直接填 `http(s)` 页面地址，也可填 `ws(s)` 网关地址")

                        TextField("http://110.40.136.189:19888/ 或 ws://110.40.136.189:19888/", text: $draftURLString)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(AppTheme.Colors.card)
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                                    .stroke(AppTheme.Colors.stroke)
                                }
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))

                        SecureField("可选：网关令牌（启动链接参数）", text: $draftToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(AppTheme.Colors.card)
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                                    .stroke(AppTheme.Colors.stroke)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))

                        SecureField("可选：网页登录密码（单独记住）", text: $draftPassword)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(AppTheme.Colors.card)
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                                    .stroke(AppTheme.Colors.stroke)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))

                        HStack(spacing: 12) {
                            Button("应用内打开") {
                                openPortal()
                            }
                            .appButton()
                            .frame(maxWidth: .infinity)

                            Button("Safari 打开") {
                                openInSafari()
                            }
                            .appButton(.secondary)
                            .frame(maxWidth: .infinity)
                        }

                        if !draftPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button("复制网页登录密码") {
                                copyPasswordToPasteboard()
                            }
                            .appButton(.secondary)
                            .frame(maxWidth: .infinity)
                        }

                        if let loadError {
                            Text(loadError)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(AppTheme.Colors.danger)
                        } else if let statusMessage {
                            Text(statusMessage)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(AppTheme.Colors.primary)
                        } else if !draftPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("网页登录密码会单独保存在本机钥匙串里；打开前 App 会自动复制，进入页面后直接粘贴即可。")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        } else if usesWebSocketGateway {
                            Text("检测到 WebSocket 网关地址，App 会生成 OpenClaw 官方支持的应用内启动链接，并把网关地址带入工作台。")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        } else {
                            Text("如果工作台需要鉴权，可以把 Gateway Token 一起填上，App 会按 OpenClaw 的移动端链接格式带进去。")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("OpenClaw")
        .appScreenChrome()
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            draftURLString = storedURLString
            draftToken = storedToken
            draftPassword = AppConfiguration.openClawPortalPassword ?? ""
            activeURLString = storedURLString
        }
        .fullScreenCover(item: $presentedPortal) { portal in
            OpenClawSafariView(url: portal.url)
                .ignoresSafeArea()
        }
    }

    private func openPortal() {
        let normalized = normalizedURLString(from: draftURLString)
        let normalizedToken = normalizedToken(from: draftToken)
        let normalizedPassword = normalizedPassword(from: draftPassword)
        draftURLString = normalized
        draftToken = normalizedToken
        draftPassword = normalizedPassword
        storedURLString = normalized
        storedToken = normalizedToken
        activeURLString = normalized
        loadError = nil
        statusMessage = nil
        do {
            try AppConfiguration.saveOpenClawPortalPassword(normalizedPassword)
        } catch {
            loadError = error.localizedDescription
            return
        }
        guard let targetURL = portalURL(
            for: resolvedPortalLaunchContext(from: normalized),
            token: normalizedToken
        ) else {
            loadError = "OpenClaw 地址无效，请检查后重试。"
            return
        }

        copyPasswordToPasteboard()
        presentedPortal = OpenClawPresentedPortal(url: targetURL)
    }

    private func openInSafari() {
        let fallback = normalizedURLString(from: draftURLString)
        let normalizedPassword = normalizedPassword(from: draftPassword)
        draftPassword = normalizedPassword
        loadError = nil
        statusMessage = nil
        do {
            try AppConfiguration.saveOpenClawPortalPassword(normalizedPassword)
        } catch {
            loadError = error.localizedDescription
            return
        }
        let targetURL = activeURL ?? portalURL(
            for: resolvedPortalLaunchContext(from: fallback),
            token: normalizedToken(from: draftToken)
        )
        guard let targetURL else { return }
        copyPasswordToPasteboard()
        openURL(targetURL)
    }

    private func normalizedURLString(from rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return storedURLString }
        guard !trimmed.contains("://") else { return trimmed }
        return "http://\(trimmed)"
    }

    private func normalizedToken(from rawValue: String) -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedPassword(from rawValue: String) -> String {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolvedPortalLaunchContext(from rawValue: String) -> OpenClawPortalLaunchContext? {
        let normalized = normalizedURLString(from: rawValue)
        guard let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased()
        else {
            return nil
        }

        switch scheme {
        case "http", "https":
            return OpenClawPortalLaunchContext(pageURL: url, gatewayURLString: nil)
        case "ws", "wss":
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return nil
            }
            let gatewayURLString = components.url?.absoluteString ?? normalized
            components.scheme = scheme == "ws" ? "http" : "https"
            if components.path.isEmpty {
                components.path = "/"
            }
            return components.url.map {
                OpenClawPortalLaunchContext(pageURL: $0, gatewayURLString: gatewayURLString)
            }
        default:
            return nil
        }
    }

    private func isWebSocketURLString(_ rawValue: String) -> Bool {
        let normalized = normalizedURLString(from: rawValue)
        guard let scheme = URL(string: normalized)?.scheme?.lowercased() else {
            return false
        }
        return scheme == "ws" || scheme == "wss"
    }

    private func copyPasswordToPasteboard() {
        let password = normalizedPassword(from: draftPassword)
        guard !password.isEmpty else {
            statusMessage = nil
            return
        }

        UIPasteboard.general.string = password
        statusMessage = "已记住并复制网页登录密码，进入页面后长按即可粘贴。"
    }

    private func portalURL(for context: OpenClawPortalLaunchContext?, token: String) -> URL? {
        guard let context else { return nil }
        guard var components = URLComponents(url: context.pageURL, resolvingAgainstBaseURL: false) else {
            return context.pageURL
        }

        var fragmentItems = URLComponents()
        fragmentItems.queryItems = []

        if let gatewayURLString = context.gatewayURLString, !gatewayURLString.isEmpty {
            fragmentItems.queryItems?.append(URLQueryItem(name: "gatewayUrl", value: gatewayURLString))
        }

        if !token.isEmpty {
            fragmentItems.queryItems?.append(URLQueryItem(name: "token", value: token))
        }

        if let fragment = fragmentItems.percentEncodedQuery, !fragment.isEmpty {
            components.percentEncodedFragment = fragment
        }

        return components.url
    }
}

private struct OpenClawPortalLaunchContext {
    let pageURL: URL
    let gatewayURLString: String?
}

private struct OpenClawPresentedPortal: Identifiable {
    let id = UUID()
    let url: URL
}

private struct OpenClawSafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        controller.preferredControlTintColor = UIColor(AppTheme.Colors.primary)
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
    }
}
