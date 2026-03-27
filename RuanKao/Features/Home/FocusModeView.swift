import SwiftUI
import UIKit

@MainActor
final class FocusSessionStore: ObservableObject {
    enum Status: String, Codable {
        case running
        case completed
        case interrupted
    }

    struct Session: Identifiable, Codable, Equatable {
        let id: UUID
        let title: String
        let durationMinutes: Int
        let startDate: Date
        let endDate: Date
        var status: Status
        var message: String?
    }

    @Published private(set) var session: Session?
    @Published private(set) var remainingSeconds = 0
    @Published private(set) var progress: Double = 0

    private let userDefaults: UserDefaults
    private let storageKey = "focus_session_store_payload"
    private var timer: Timer?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        restorePersistedSession()
    }

    deinit {
        timer?.invalidate()
    }

    var isPresenting: Bool {
        session != nil
    }

    var isRunning: Bool {
        session?.status == .running
    }

    var currentDurationMinutes: Int {
        session?.durationMinutes ?? 25
    }

    var statusTitle: String {
        switch session?.status {
        case .running:
            return "专注进行中"
        case .completed:
            return "专注完成"
        case .interrupted:
            return "专注已中断"
        case .none:
            return "专注学习"
        }
    }

    var statusMessage: String {
        guard let session else {
            return ""
        }

        switch session.status {
        case .running:
            return ""
        case .completed:
            return "这一轮已完成。"
        case .interrupted:
            return session.message ?? "本次专注已中断。"
        }
    }

    func start(minutes: Int, title: String = "专注学习") {
        let safeMinutes = min(max(minutes, 5), 180)
        let now = Date()
        session = Session(
            id: UUID(),
            title: title,
            durationMinutes: safeMinutes,
            startDate: now,
            endDate: now.addingTimeInterval(TimeInterval(safeMinutes * 60)),
            status: .running,
            message: nil
        )
        persistSession()
        startTimer()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        guard isRunning else { return }
        if phase == .background {
            interrupt(reason: "检测到你离开了前台，本次专注已判定失败。")
        }
    }

    func requestDismissOverlay() {
        guard !isRunning else { return }
        clearSession()
    }

    func acknowledgeResult() {
        clearSession()
    }

    func restartLastSession() {
        let minutes = session?.durationMinutes ?? 25
        start(minutes: minutes)
    }

    private func restorePersistedSession() {
        guard let data = userDefaults.data(forKey: storageKey),
              let storedSession = try? JSONDecoder().decode(Session.self, from: data) else {
            return
        }

        session = storedSession

        switch storedSession.status {
        case .running:
            interrupt(reason: "上一次专注过程中应用离开了前台，本次专注已判定失败。")
        case .completed, .interrupted:
            refreshMetrics()
        }
    }

    private func startTimer() {
        stopTimer()
        UIApplication.shared.isIdleTimerDisabled = true
        refreshMetrics()

        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshMetrics()
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func refreshMetrics() {
        guard let session else {
            remainingSeconds = 0
            progress = 0
            return
        }

        switch session.status {
        case .running:
            let totalSeconds = max(1, Int(session.endDate.timeIntervalSince(session.startDate)))
            let secondsLeft = Int(ceil(session.endDate.timeIntervalSinceNow))
            if secondsLeft <= 0 {
                complete()
                return
            }

            remainingSeconds = secondsLeft
            progress = min(
                max(Double(totalSeconds - secondsLeft) / Double(totalSeconds), 0),
                1
            )
        case .completed, .interrupted:
            remainingSeconds = 0
            progress = 1
        }
    }

    private func complete() {
        guard var session, session.status == .running else { return }
        session.status = .completed
        session.message = "本轮 \(session.durationMinutes) 分钟专注已完成。"
        self.session = session
        stopTimer()
        persistSession()
        refreshMetrics()
    }

    private func interrupt(reason: String) {
        guard var session, session.status == .running else { return }
        session.status = .interrupted
        session.message = reason
        self.session = session
        stopTimer()
        persistSession()
        refreshMetrics()
    }

    private func clearSession() {
        stopTimer()
        session = nil
        remainingSeconds = 0
        progress = 0
        userDefaults.removeObject(forKey: storageKey)
    }

    private func persistSession() {
        guard let session,
              let data = try? JSONEncoder().encode(session) else {
            userDefaults.removeObject(forKey: storageKey)
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }
}

struct FocusModeView: View {
    @ObservedObject var store: FocusSessionStore
    @AppStorage("focus_timer_duration_minutes") private var selectedMinutes = 25

    private let presets = [15, 25, 45, 60, 90, 120]
    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Metrics.listSectionSpacing) {
                heroSection
                currentSessionSection
                presetSection
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("专注学习")
        .appScreenChrome()
    }

    private var heroSection: some View {
        PrimaryCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("禅定计时")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                HStack(spacing: 12) {
                    focusMetric(title: "当前时长", value: "\(selectedMinutes) 分钟")
                    focusMetric(title: "状态", value: store.statusTitle)
                }

                Button(store.isRunning ? "专注进行中" : "开始专注") {
                    guard !store.isRunning else { return }
                    store.start(minutes: selectedMinutes)
                }
                .appButton()
                .disabled(store.isRunning)
            }
        }
    }

    @ViewBuilder
    private var currentSessionSection: some View {
        if let session = store.session {
            PrimaryCard(style: .subtle) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: session.status == .completed ? "checkmark.circle.fill" : session.status == .interrupted ? "xmark.circle.fill" : "timer.circle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(session.status == .completed ? AppTheme.Colors.success : session.status == .interrupted ? AppTheme.Colors.danger : AppTheme.Colors.primary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(store.statusTitle)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            if !store.statusMessage.isEmpty {
                                Text(store.statusMessage)
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                        }

                        Spacer(minLength: 0)
                    }

                    if session.status == .running {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(clockString(store.remainingSeconds))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .monospacedDigit()

                            ProgressView(value: store.progress)
                                .tint(AppTheme.Colors.accent)
                        }
                    } else {
                        HStack(spacing: 12) {
                            Button("重新开始") {
                                store.restartLastSession()
                            }
                            .appButton()
                            .frame(maxWidth: .infinity)

                            Button("收起结果") {
                                store.acknowledgeResult()
                            }
                            .appButton(.secondary)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private var presetSection: some View {
        PrimaryCard(style: .subtle) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader("专注时长")

                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(presets, id: \.self) { minute in
                        Button {
                            selectedMinutes = minute
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(minute)")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)

                                Text("分钟")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                            .padding(16)
                            .background(selectedMinutes == minute ? AppTheme.Colors.accent.opacity(0.10) : AppTheme.Colors.card)
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                                    .stroke(selectedMinutes == minute ? AppTheme.Colors.accent : AppTheme.Colors.stroke, lineWidth: selectedMinutes == minute ? 1.5 : 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("自定义")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Spacer()
                        Text("\(selectedMinutes) 分钟")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }

                    Stepper(value: $selectedMinutes, in: 5 ... 180, step: 5) {
                        Text("5 分钟步进")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    .tint(AppTheme.Colors.accent)
                }
            }
        }
    }

    private func focusMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.Colors.card)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                .stroke(AppTheme.Colors.stroke)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))
    }

}

struct FocusSessionExperienceView: View {
    @ObservedObject var container: AppContainer
    @ObservedObject var store: FocusSessionStore

    var body: some View {
        Group {
            if store.isRunning {
                FocusPracticeSessionView(container: container, store: store)
            } else {
                FocusSessionCoverView(store: store)
            }
        }
    }
}

struct FocusPracticeSessionView: View {
    @StateObject private var viewModel: PracticeViewModel
    @ObservedObject var store: FocusSessionStore

    init(container: AppContainer, store: FocusSessionStore) {
        _viewModel = StateObject(
            wrappedValue: PracticeViewModel(
                questionRepository: container.questionRepository,
                progressRepository: container.progressRepository,
                aiStudyService: container.aiStudyService,
                preferredMode: .random
            )
        )
        self.store = store
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppTheme.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    contentSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 72)
                .padding(.bottom, 120)
            }

            Text(clockString(store.remainingSeconds))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.top, 14)
                .padding(.trailing, 16)
                .allowsHitTesting(false)
        }
        .task {
            viewModel.loadInitialData()
        }
        .onChange(of: viewModel.finished) { _, finished in
            guard finished, store.isRunning, !viewModel.questions.isEmpty else { return }
            viewModel.restart()
        }
        .interactiveDismissDisabled(store.isRunning)
        .safeAreaInset(edge: .bottom) {
            focusBottomActionBar
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if let errorMessage = viewModel.errorMessage {
            StatePanel(
                title: "题目加载失败",
                message: errorMessage,
                icon: "exclamationmark.triangle",
                tint: AppTheme.Colors.danger
            ) {
                Button("重新加载") {
                    viewModel.loadInitialData()
                }
                .appButton()
            }
        } else if viewModel.questions.isEmpty {
            StatePanel(
                title: "当前暂无题目",
                message: "题库暂时没有可用题目，请稍后重试。",
                icon: "square.grid.2x2"
            ) {
                Button("重新加载") {
                    viewModel.loadInitialData()
                }
                .appButton()
            }
        } else if let question = viewModel.currentQuestion {
            VStack(alignment: .leading, spacing: 16) {
                focusQuestionCard(question)

                if question.isObjective {
                    focusObjectiveAnswerSection(question)
                } else {
                    focusSubjectiveAnswerSection()
                }

                if viewModel.showAnalysis {
                    focusAnalysisSection(question)
                }

                focusAISection(question)
            }
        }
    }

    private func focusQuestionCard(_ question: Question) -> some View {
        PrimaryCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(question.stem)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)

                if !question.options.isEmpty, !question.isObjective {
                    ForEach(question.options) { option in
                        Text("\(option.label). \(option.content)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
            }
        }
    }

    private func focusObjectiveAnswerSection(_ question: Question) -> some View {
        VStack(spacing: 12) {
            ForEach(question.options) { option in
                QuestionOptionRow(
                    option: option,
                    isSelected: viewModel.selectedAnswers.contains(option.label),
                    isCorrect: viewModel.showAnalysis ? question.correctAnswers.contains(option.label) : nil
                ) {
                    viewModel.toggleSelection(option.label)
                }
            }
        }
    }

    private func focusSubjectiveAnswerSection() -> some View {
        EmptyView()
    }

    private func focusAnalysisSection(_ question: Question) -> some View {
        PrimaryCard(style: .subtle) {
            VStack(alignment: .leading, spacing: 14) {
                Text(question.answerSummary)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Divider()

                Text(question.analysis)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    private func focusAISection(_ question: Question) -> some View {
        PrimaryCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    focusAIButton(
                        title: question.isObjective ? "AI 讲解" : "AI 提纲",
                        icon: question.isObjective ? "sparkles" : "list.bullet.rectangle.portrait"
                    ) {
                        viewModel.requestAIInsight(style: question.isObjective ? .explanation : .essayOutline)
                    }

                    focusAIButton(
                        title: "AI 相似题",
                        icon: "square.stack.3d.up"
                    ) {
                        viewModel.requestAIInsight(style: .similarQuestion)
                    }
                }

                if viewModel.isAILoading {
                    ProgressView()
                } else if let aiErrorMessage = viewModel.aiErrorMessage {
                    Text(aiErrorMessage)
                        .foregroundStyle(AppTheme.Colors.danger)
                } else if let insight = viewModel.aiInsight {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(insight.title)
                                .font(.headline)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Spacer()
                            PillTag(title: insight.source, tint: AppTheme.Colors.secondary)
                        }

                        Text(insight.summary)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)

                        ForEach(insight.highlights, id: \.self) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(AppTheme.Colors.primary)
                                    .font(.caption)
                                    .padding(.top, 3)
                                Text(item)
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                        }

                    }
                    .padding(14)
                    .background(AppTheme.Colors.background)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                            .stroke(AppTheme.Colors.stroke)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var focusBottomActionBar: some View {
        if viewModel.questions.isEmpty || viewModel.errorMessage != nil || viewModel.finished {
            EmptyView()
        } else if let question = viewModel.currentQuestion {
            VStack(spacing: 10) {
                if question.isObjective {
                    Button {
                        viewModel.showAnalysis ? viewModel.nextQuestion() : viewModel.submitObjectiveAnswer()
                    } label: {
                        Text(viewModel.showAnalysis ? "下一题" : "提交答案")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .appButton()
                    .disabled(!viewModel.showAnalysis && viewModel.selectedAnswers.isEmpty)
                } else if !viewModel.showAnalysis {
                    Button {
                        viewModel.revealSubjectiveReference()
                    } label: {
                        Text("查看参考答案")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .appButton()
                } else if viewModel.awaitingSubjectiveAssessment {
                    HStack(spacing: 12) {
                        Button {
                            viewModel.markSubjectiveResult(isCorrect: false)
                        } label: {
                            Text("需重练")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .appButton(.secondary)

                        Button {
                            viewModel.markSubjectiveResult(isCorrect: true)
                        } label: {
                            Text("已掌握")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .appButton()
                    }
                } else {
                    Button {
                        viewModel.nextQuestion()
                    } label: {
                        Text("下一题")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .appButton()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(AppTheme.Colors.background.opacity(0.92))
        }
    }

    private func focusAIButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.Colors.card)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                    .stroke(AppTheme.Colors.stroke)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct FocusSessionCoverView: View {
    @ObservedObject var store: FocusSessionStore

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: resultIconName)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(resultTint)

                Text(store.statusTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                if let session = store.session {
                    Text("\(session.durationMinutes) 分钟")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                HStack(spacing: 12) {
                    Button("再来一轮") {
                        store.restartLastSession()
                    }
                    .appButton()
                    .frame(maxWidth: .infinity)

                    Button("完成") {
                        store.acknowledgeResult()
                    }
                    .appButton(.secondary)
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
        .interactiveDismissDisabled(false)
    }

    private var resultIconName: String {
        switch store.session?.status {
        case .completed:
            return "checkmark.circle.fill"
        case .interrupted:
            return "xmark.circle.fill"
        default:
            return "timer.circle.fill"
        }
    }

    private var resultTint: Color {
        switch store.session?.status {
        case .completed:
            return AppTheme.Colors.success
        case .interrupted:
            return AppTheme.Colors.danger
        default:
            return AppTheme.Colors.primary
        }
    }
}

private func clockString(_ totalSeconds: Int) -> String {
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
}
