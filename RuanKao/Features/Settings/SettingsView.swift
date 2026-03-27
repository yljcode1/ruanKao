import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance_mode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var aiEndpoint: String
    @State private var aiToken: String
    @State private var aiModel: String
    @State private var aiMessage: String?
    @State private var isAITesting = false

    init() {
        _aiEndpoint = State(initialValue: AppConfiguration.aiServiceEndpointString)
        _aiToken = State(initialValue: AppConfiguration.aiServiceToken ?? "")
        _aiModel = State(initialValue: AppConfiguration.aiServiceModel ?? "")
    }

    private var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }
        set { appearanceModeRaw = newValue.rawValue }
    }

    private var remoteAIEnabled: Bool {
        let trimmed = aiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: trimmed) != nil && !trimmed.isEmpty
    }

    private var roadmapItems: [(title: String, subtitle: String, icon: String)] {
        [
            ("字体大小", "按阅读习惯切换紧凑或舒展排版", "textformat.size"),
            ("每日目标", "设置当天练题量和完成提醒", "target"),
            ("iCloud 同步", "跨设备同步收藏、错题和进度", "icloud")
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerCard
                    appearanceCard
                    aiCard
                    roadmapCard
                }
                .padding(20)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("设置")
            .appScreenChrome()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var headerCard: some View {
        PrimaryCard(style: .subtle) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.Colors.muted)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("偏好设置")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        Text("只保留主题和 AI 两项关键设置，减少分心。")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    Spacer(minLength: 12)

                    PillTag(title: appearanceMode.title, icon: appearanceMode.icon, tint: AppTheme.Colors.secondary)
                }

                Text("一个页面只做一件事：先把使用体验调顺手，再回去专注刷题。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    private var appearanceCard: some View {
        PrimaryCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader("显示模式", subtitle: "支持跟随系统、浅色和深色") {
                    PillTag(title: "当前 \(appearanceMode.title)", tint: AppTheme.Colors.secondary)
                }

                ForEach(AppearanceMode.allCases) { mode in
                    AppearanceOptionRow(
                        mode: mode,
                        description: description(for: mode),
                        isSelected: appearanceMode == mode
                    ) {
                        appearanceModeRaw = mode.rawValue
                    }
                }
            }
        }
    }

    private var roadmapCard: some View {
        PrimaryCard(style: .subtle) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader("预留项", subtitle: "后续优先补这 3 个能力")

                ForEach(roadmapItems, id: \.title) { item in
                    SettingsInfoRow(
                        title: item.title,
                        subtitle: item.subtitle,
                        icon: item.icon
                    )
                }
            }
        }
    }

    private var aiCard: some View {
        PrimaryCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader("AI 助手", subtitle: "题库、错题和统计始终离线可用；这里只给 AI 助手联网") {
                    PillTag(
                        title: remoteAIEnabled ? "已联网" : "离线",
                        icon: remoteAIEnabled ? "network" : "wifi.slash",
                        tint: AppTheme.Colors.secondary
                    )
                }

                HStack(spacing: 12) {
                    Image(systemName: remoteAIEnabled ? "network" : "wifi.slash")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primary)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.Colors.muted)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(remoteAIEnabled ? "远程 AI 已启用" : "当前离线模式")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text(remoteAIEnabled ? "下一次点击 AI 讲解会直接走远程接口" : "未配置接口时，会自动回退到本地 AI 模拟解析")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    Spacer()
                }
                .padding(14)
                .background(AppTheme.Colors.card)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                        .stroke(AppTheme.Colors.stroke)
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))

                settingsField(
                    title: "接口地址",
                    placeholder: "https://aixj.vip / https://api.openai.com/v1",
                    text: $aiEndpoint,
                    keyboardType: .URL
                )

                settingsField(
                    title: "访问令牌（可选）",
                    placeholder: "Bearer Token 或 API Key",
                    text: $aiToken,
                    secure: true
                )

                settingsField(
                    title: "模型（可选）",
                    placeholder: "gpt-5.4 / gpt-4.1-mini / deepseek-chat",
                    text: $aiModel
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("当前令牌：\(AppConfiguration.maskedTokenDescription(for: AppConfiguration.aiServiceToken))")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text("远程接口需支持 HTTPS `POST`，请求体包含 `style` 和 `question`，返回 `title / summary / highlights / nextAction / source`。如果你填的是 `Bearer xxx` 会原样发送；如果只填 Key，系统会自动补 `Bearer `。")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text("现在已支持三种方式：1）自定义接口；2）OpenAI / DeepSeek `chat/completions`；3）`Responses API` 中转站。像 `https://aixj.vip` 这类 `wire_api = responses` 的地址，可以直接填根地址，再把模型填成 `gpt-5.4`。")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text("如果你的中转站走 `chat/completions`，建议填完整接口如 `/v1/chat/completions`；如果走 `responses`，可直接填根地址、`/v1` 或完整 `/v1/responses`。")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text("点 `测试连接` 时，如果当前模型失败，系统会自动轮询一组常见兼容模型，并把成功的模型回填到输入框。")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                if let aiMessage {
                    Text(aiMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(remoteAIEnabled ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                }

                if isAITesting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在测试 AI 连接…")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }

                HStack(spacing: 12) {
                    Button("保存配置") {
                        saveAISettings()
                    }
                    .appButton()
                    .frame(maxWidth: .infinity)

                    Button("测试连接") {
                        testAIConnection()
                    }
                    .appButton(.secondary)
                    .frame(maxWidth: .infinity)
                }

                Button("恢复离线") {
                    resetAISettings()
                }
                .appButton(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func description(for mode: AppearanceMode) -> String {
        switch mode {
        case .system:
            return "自动适配系统主题"
        case .light:
            return "固定使用浅色界面"
        case .dark:
            return "固定使用深色界面"
        }
    }

    @ViewBuilder
    private func settingsField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        secure: Bool = false,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)

            Group {
                if secure {
                    SecureField(placeholder, text: text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.card)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                    .stroke(AppTheme.Colors.stroke)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))
        }
    }

    private func saveAISettings() {
        do {
            try AppConfiguration.saveAIService(endpoint: aiEndpoint, token: aiToken, model: aiModel)
            aiEndpoint = AppConfiguration.aiServiceEndpointString
            aiToken = AppConfiguration.aiServiceToken ?? ""
            aiModel = AppConfiguration.aiServiceModel ?? ""
            aiMessage = remoteAIEnabled ? "已保存，下次点击 AI 助手就会联网。" : "已保存为空配置，当前继续使用离线模式。"
        } catch {
            aiMessage = error.localizedDescription
        }
    }

    private func testAIConnection() {
        guard !isAITesting else { return }

        let endpoint = aiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = aiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = aiModel.trimmingCharacters(in: .whitespacesAndNewlines)

        isAITesting = true
        aiMessage = "正在测试 AI 连接…"

        Task {
            do {
                let modelsToTry = candidateModelsForConnectionTest(
                    endpoint: endpoint,
                    preferredModel: model.isEmpty ? nil : model
                )

                var attempts: [String] = []
                var resolvedSource: String?
                var resolvedModel: String?

                for candidateModel in modelsToTry {
                    let candidateLabel = candidateModel ?? "默认模型"
                    await MainActor.run {
                        self.aiMessage = "正在测试模型：\(candidateLabel)…"
                    }

                    do {
                        let source = try await runAIConnectionTest(
                            endpoint: endpoint,
                            token: token,
                            model: candidateModel
                        )
                        resolvedSource = source
                        resolvedModel = candidateModel
                        break
                    } catch {
                        attempts.append("\(candidateLabel)：\(error.localizedDescription)")
                    }
                }

                guard let source = resolvedSource else {
                    let details = attempts.prefix(3).joined(separator: "\n")
                    throw NSError(
                        domain: "AIConnectionProbe",
                        code: -1,
                        userInfo: [
                            NSLocalizedDescriptionKey: details.isEmpty
                                ? "未找到可用模型。"
                                : "未找到可用模型。\n\(details)"
                        ]
                    )
                }

                await MainActor.run {
                    self.isAITesting = false
                    if let resolvedModel {
                        self.aiModel = resolvedModel
                        self.aiMessage = "测试成功：已连接到 \(source)。可用模型是 \(resolvedModel)，如果没问题，再点“保存配置”。"
                    } else {
                        self.aiMessage = "测试成功：已连接到 \(source)。如果没问题，再点“保存配置”。"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isAITesting = false
                    self.aiMessage = error.localizedDescription
                }
            }
        }
    }

    private func runAIConnectionTest(
        endpoint: String,
        token: String,
        model: String?
    ) async throws -> String {
        let service = RemoteAIStudyService(
            configurationProvider: {
                RemoteAIServiceConfiguration(
                    endpoint: URL(string: endpoint),
                    bearerToken: token.isEmpty ? nil : token,
                    model: model
                )
            }
        )
        return try await service.testConnection()
    }

    private func candidateModelsForConnectionTest(endpoint: String, preferredModel: String?) -> [String?] {
        var candidates: [String?] = [preferredModel]

        guard shouldProbeAlternativeModels(endpoint: endpoint) else {
            return deduplicatedModels(candidates)
        }

        candidates.append(contentsOf: [
            "gpt-4.1-mini",
            "gpt-4.1",
            "gpt-4o-mini",
            "gpt-4o",
            "gpt-5",
            "gpt-5.4",
            "o4-mini"
        ])

        return deduplicatedModels(candidates)
    }

    private func shouldProbeAlternativeModels(endpoint: String) -> Bool {
        guard let url = URL(string: endpoint) else { return false }
        let host = url.host()?.lowercased() ?? ""
        let path = url.path.lowercased()

        if host.contains("openai.com") || host.contains("deepseek.com") {
            return false
        }

        if path.contains("/chat/completions") {
            return false
        }

        return true
    }

    private func deduplicatedModels(_ models: [String?]) -> [String?] {
        var seen = Set<String>()
        var result: [String?] = []

        for model in models {
            let normalized = model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if normalized.isEmpty {
                if !seen.contains("__EMPTY__") {
                    seen.insert("__EMPTY__")
                    result.append(nil)
                }
                continue
            }

            let key = normalized.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                result.append(normalized)
            }
        }

        return result
    }

    private func resetAISettings() {
        do {
            try AppConfiguration.resetAIServiceOverrides()
            aiEndpoint = AppConfiguration.aiServiceEndpointString
            aiToken = AppConfiguration.aiServiceToken ?? ""
            aiModel = AppConfiguration.aiServiceModel ?? ""
            aiMessage = AppConfiguration.isRemoteAIEnabled ? "已恢复到内置远程配置。" : "已切回离线模式。"
        } catch {
            aiMessage = error.localizedDescription
        }
    }
}

private struct AppearanceOptionRow: View {
    let mode: AppearanceMode
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: mode.icon)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(width: 34, height: 34)
                    .background(isSelected ? AppTheme.Colors.primary.opacity(0.06) : AppTheme.Colors.muted)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
            }
            .padding(14)
            .background(isSelected ? AppTheme.Colors.primary.opacity(0.04) : AppTheme.Colors.card)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                    .stroke(isSelected ? AppTheme.Colors.primary.opacity(0.18) : AppTheme.Colors.stroke)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))
            .animation(.easeInOut(duration: 0.18), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsInfoRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.primary)
                .frame(width: 34, height: 34)
                .background(AppTheme.Colors.muted)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(AppTheme.Colors.card)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                .stroke(AppTheme.Colors.stroke)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))
    }
}
