import Charts
import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @State private var isSettingsPresented = false
    private let container: AppContainer
    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(
            wrappedValue: DashboardViewModel(
                analyticsRepository: container.analyticsRepository,
                questionRepository: container.questionRepository
            )
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Metrics.listSectionSpacing) {
                overviewSection
                practiceEntrySection
                if !viewModel.topicSummaries.isEmpty {
                    topicEntrySection
                }
                insightSection

                if !viewModel.availableYears.isEmpty {
                    yearSection
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("软考架构师")
        .appScreenChrome()
        .task {
            viewModel.load()
        }
        .refreshable {
            viewModel.load()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isSettingsPresented = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(AppTheme.Colors.background)
        }
    }

    @ViewBuilder
    private var overviewSection: some View {
        if let snapshot = viewModel.snapshot {
            PrimaryCard {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("刷题、错题、提分")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        Text("题库、错题和学习数据都收进一个更轻的离线面板。")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    LazyVGrid(columns: gridColumns, spacing: 10) {
                        overviewMetric(title: "题库", value: "\(snapshot.totalQuestions)")
                        overviewMetric(title: "已做", value: "\(snapshot.answeredQuestions)")
                        overviewMetric(title: "今日", value: "\(snapshot.todayPracticeCount) 题")
                        overviewMetric(
                            title: "正确率",
                            value: snapshot.overallAccuracy.formatted(.percent.precision(.fractionLength(0)))
                        )
                    }

                    HStack(spacing: 12) {
                        NavigationLink {
                            PracticeView(container: container, preferredMode: .sequential)
                        } label: {
                            actionButton("开始刷题", icon: "play.fill", filled: true)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            WrongBookView(container: container)
                        } label: {
                            actionButton("错题本", icon: "arrow.clockwise.circle", filled: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else if let errorMessage = viewModel.errorMessage {
            StatePanel(
                title: "学习概览暂时不可用",
                message: errorMessage,
                icon: "exclamationmark.triangle",
                tint: AppTheme.Colors.danger
            ) {
                Button("重新加载") {
                    viewModel.load()
                }
                .appButton()
            }
        } else {
            StatePanel(
                title: "正在准备学习概览",
                message: "题库规模、刷题进度和正确率会在这里汇总显示。",
                icon: "clock.arrow.circlepath"
            )
        }
    }

    private var practiceEntrySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("练习入口", subtitle: "四种模式直接开练")

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(PracticeMode.allCases) { mode in
                    NavigationLink {
                        PracticeView(container: container, preferredMode: mode)
                    } label: {
                        PrimaryCard(style: .subtle) {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: mode.icon)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.primary)
                                    .frame(width: 32, height: 32)
                                    .background(AppTheme.Colors.muted)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous))

                                Text(mode.title)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)

                                Text(mode.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                    .lineLimit(2)
                            }
                            .frame(minHeight: 116, alignment: .topLeading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var insightSection: some View {
        PrimaryCard(style: .subtle) {
            if let snapshot = viewModel.snapshot {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(
                        "学习洞察",
                        subtitle: viewModel.studyPlan.first?.title ?? "系统会按你的薄弱点自动给建议"
                    )

                    insightRow(
                        title: "今日建议",
                        value: viewModel.studyPlan.first?.subtitle ?? "先做几题，系统会继续补全学习建议。"
                    )

                    insightRow(
                        title: "当前薄弱点",
                        value: snapshot.weakKnowledgePoints.first?.name ?? "暂无，继续保持当前节奏。"
                    )

                    HStack(spacing: 12) {
                        miniStat(title: "连续学习", value: "\(snapshot.currentStreak) 天")
                        miniStat(
                            title: "完成度",
                            value: completionRate(snapshot).formatted(.percent.precision(.fractionLength(0)))
                        )
                    }

                    if !snapshot.weakKnowledgePoints.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("薄弱知识点")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            ForEach(Array(snapshot.weakKnowledgePoints.prefix(3))) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(item.name)
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(AppTheme.Colors.textPrimary)
                                        Spacer()
                                        Text(item.accuracy.formatted(.percent.precision(.fractionLength(0))))
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(weakPointColor(for: item.accuracy))
                                    }

                                    ProgressView(value: item.accuracy)
                                        .tint(weakPointColor(for: item.accuracy))
                                }
                            }
                        }
                    }

                    if !snapshot.recentTrend.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("最近 7 天")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                Spacer()
                                Text(averageAccuracy(of: snapshot.recentTrend).formatted(.percent.precision(.fractionLength(0))))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }

                            Chart(snapshot.recentTrend) { item in
                                LineMark(
                                    x: .value("日期", item.date, unit: .day),
                                    y: .value("正确率", item.accuracy)
                                )
                                .foregroundStyle(AppTheme.Colors.secondary)
                                .lineStyle(
                                    StrokeStyle(
                                        lineWidth: AppTheme.Metrics.chartLineWidth,
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )
                                .interpolationMethod(.catmullRom)

                                AreaMark(
                                    x: .value("日期", item.date, unit: .day),
                                    y: .value("正确率", item.accuracy)
                                )
                                .foregroundStyle(AppTheme.Colors.secondary.opacity(AppTheme.Metrics.chartAreaOpacity))
                            }
                            .frame(height: 160)
                            .chartYScale(domain: 0...1)
                        }
                    }
                }
            } else {
                Text("先完成几道题，这里会逐步长出你的学习建议和趋势。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    private var topicEntrySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("专题题库", subtitle: "按考点直接进入，更适合集中补短板")

            NavigationLink {
                TopicLibraryView(container: container)
            } label: {
                PrimaryCard(style: .subtle) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("专题入口")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)

                                Text("把高频专题拆开练，先补最容易提分的那几块。")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }

                            Spacer(minLength: 12)

                            Image(systemName: "square.grid.2x2")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.primary)
                                .frame(width: 34, height: 34)
                                .background(AppTheme.Colors.muted)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(viewModel.topicSummaries.prefix(3))) { summary in
                                HStack(spacing: 10) {
                                    Text(summary.category)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                        .lineLimit(1)

                                    Spacer()

                                    Text("\(summary.questionCount) 题")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.Colors.textSecondary)
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            miniStat(title: "专题数", value: "\(viewModel.topicSummaries.count)+")
                            miniStat(
                                title: "入口题量",
                                value: "\(viewModel.topicSummaries.map(\.questionCount).reduce(0, +)) 题"
                            )
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var yearSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("历年真题", subtitle: "按年份快速进入")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(viewModel.availableYears.prefix(8)), id: \.self) { year in
                        NavigationLink {
                            PracticeView(container: container, preferredMode: .sequential, initialYear: year)
                        } label: {
                            Text("\(year)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(AppTheme.Colors.card)
                                .overlay {
                                    Capsule()
                                        .stroke(AppTheme.Colors.stroke)
                                }
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func actionButton(_ title: String, icon: String, filled: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(filled ? Color.white : AppTheme.Colors.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(filled ? AppTheme.Colors.accent : AppTheme.Colors.card)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                .stroke(filled ? AppTheme.Colors.accent : AppTheme.Colors.stroke)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))
    }

    private func overviewMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.Colors.card)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                .stroke(AppTheme.Colors.stroke)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))
    }

    private func weakPointColor(for accuracy: Double) -> Color {
        accuracy < 0.6 ? AppTheme.Colors.primary : AppTheme.Colors.secondary
    }

    private func insightRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
    }

    private func miniStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.Colors.card)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                .stroke(AppTheme.Colors.stroke)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))
    }

    private func completionRate(_ snapshot: DashboardSnapshot) -> Double {
        guard snapshot.totalQuestions > 0 else { return 0 }
        return Double(snapshot.answeredQuestions) / Double(snapshot.totalQuestions)
    }

    private func averageAccuracy(of trend: [DailyTrend]) -> Double {
        guard !trend.isEmpty else { return 0 }
        return trend.map(\.accuracy).reduce(0, +) / Double(trend.count)
    }
}

private struct TopicLibraryView: View {
    @StateObject private var viewModel: TopicLibraryViewModel
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(
            wrappedValue: TopicLibraryViewModel(questionRepository: container.questionRepository)
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Metrics.listSectionSpacing) {
                headerSection
                contentSection
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("专题题库")
        .appScreenChrome()
        .task {
            viewModel.load()
        }
        .refreshable {
            viewModel.load()
        }
    }

    private var headerSection: some View {
        PrimaryCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("按专题集中刷，提分更快")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("把题库拆成更清晰的考点入口，适合临考前查缺补漏，也适合长期按模块推进。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                HStack(spacing: 12) {
                    topicStat(title: "专题数", value: "\(viewModel.summaries.count)")
                    topicStat(title: "题量", value: "\(viewModel.totalQuestions)")
                    topicStat(title: "最新年份", value: "\(viewModel.latestYear)")
                }
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if let errorMessage = viewModel.errorMessage {
            StatePanel(
                title: "专题题库加载失败",
                message: errorMessage,
                icon: "exclamationmark.triangle",
                tint: AppTheme.Colors.danger
            ) {
                Button("重新加载") {
                    viewModel.load()
                }
                .appButton()
            }
        } else if viewModel.summaries.isEmpty {
            StatePanel(
                title: "还没有专题数据",
                message: "等题库完成同步后，这里会自动按专题生成入口。",
                icon: "square.grid.2x2"
            )
        } else {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader("全部专题", subtitle: "优先从题量大、主观题多或刚补过的专题开始")

                ForEach(viewModel.summaries) { summary in
                    NavigationLink {
                        PracticeView(
                            container: container,
                            preferredMode: .sequential,
                            initialCategory: summary.category
                        )
                    } label: {
                        PrimaryCard(style: .subtle) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(summary.category)
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(AppTheme.Colors.textPrimary)

                                        Text("最近覆盖到 \(summary.latestYear) 年，适合按专题集中补练。")
                                            .font(.footnote)
                                            .foregroundStyle(AppTheme.Colors.textSecondary)
                                    }

                                    Spacer(minLength: 12)

                                    Text("\(summary.questionCount)")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                }

                                HStack(spacing: 12) {
                                    topicMetaTag(title: "选择题 \(summary.objectiveCount)")
                                    topicMetaTag(title: "主观题 \(summary.subjectiveCount)")
                                    topicMetaTag(title: "\(summary.latestYear)")
                                }
                            }
                            .frame(minHeight: 128, alignment: .topLeading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func topicStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.Colors.card)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                .stroke(AppTheme.Colors.stroke)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))
    }

    private func topicMetaTag(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.Colors.background)
            .overlay {
                Capsule()
                    .stroke(AppTheme.Colors.stroke)
            }
            .clipShape(Capsule())
    }
}

@MainActor
private final class TopicLibraryViewModel: ObservableObject {
    @Published private(set) var summaries: [TopicSummary] = []
    @Published var errorMessage: String?

    private let questionRepository: QuestionRepositoryProtocol

    init(questionRepository: QuestionRepositoryProtocol) {
        self.questionRepository = questionRepository
    }

    var totalQuestions: Int {
        summaries.map(\.questionCount).reduce(0, +)
    }

    var latestYear: Int {
        summaries.map(\.latestYear).max() ?? 0
    }

    func load() {
        do {
            errorMessage = nil
            summaries = try questionRepository.fetchTopicSummaries(limit: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
