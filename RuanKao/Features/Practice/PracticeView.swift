import SwiftUI

struct PracticeView: View {
    @StateObject private var viewModel: PracticeViewModel
    @ObservedObject private var recentActivityStore: RecentActivityStore
    @State private var isFilterExpanded = false

    init(
        container: AppContainer,
        preferredMode: PracticeMode = .sequential,
        initialCategory: String? = nil,
        initialYear: Int? = nil,
        initialSearchText: String? = nil
    ) {
        _isFilterExpanded = State(
            initialValue: initialCategory != nil
                || initialYear != nil
                || !(initialSearchText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        )
        _recentActivityStore = ObservedObject(wrappedValue: container.recentActivityStore)
        _viewModel = StateObject(
            wrappedValue: PracticeViewModel(
                questionRepository: container.questionRepository,
                progressRepository: container.progressRepository,
                aiStudyService: container.aiStudyService,
                recordRecentSearch: { keyword in
                    container.recentActivityStore.recordSearch(keyword)
                },
                recordRecentPractice: { mode, category, year, keyword in
                    container.recentActivityStore.recordPractice(
                        mode: mode,
                        category: category,
                        year: year,
                        keyword: keyword
                    )
                },
                preferredMode: preferredMode,
                initialCategory: initialCategory,
                initialYear: initialYear,
                initialSearchText: initialSearchText
            )
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                modeSelector
                filterPanel
                sessionOverview
                contentSection
            }
            .padding(20)
            .padding(.bottom, 120)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle(viewModel.selectedMode.title)
        .appScreenChrome()
        .task {
            viewModel.loadInitialData()
        }
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.handleSearchTextChanged()
        }
        .onDisappear {
            viewModel.stopExamIfNeeded()
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.selectedMode)
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
    }

    private var modeSelector: some View {
        PrimaryCard(style: .subtle) {
            Picker("练习模式", selection: modeBinding) {
                ForEach(PracticeMode.allCases) { mode in
                    Text(shortTitle(for: mode))
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var filterPanel: some View {
        PrimaryCard(style: .subtle) {
            DisclosureGroup(isExpanded: $isFilterExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppTheme.Colors.textSecondary)

                        TextField("搜索题干 / 知识点", text: $viewModel.searchText)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .submitLabel(.search)
                            .onSubmit {
                                viewModel.applySearch()
                            }

                        Button {
                            if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                viewModel.applySearch()
                            } else {
                                viewModel.searchText = ""
                                viewModel.applySearch()
                            }
                        } label: {
                            Image(systemName: viewModel.searchText.isEmpty ? "arrow.right.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(AppTheme.Colors.background)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                            .stroke(AppTheme.Colors.stroke)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous))

                    if !viewModel.searchSuggestions.isEmpty {
                        searchSuggestionSection
                    }

                    if !recentActivityStore.recentSearches.isEmpty {
                        recentSearchSection
                    }

                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Menu {
                                Button("全部年份") {
                                    viewModel.selectYear(nil)
                                }

                                ForEach(viewModel.years, id: \.self) { year in
                                    Button("\(year)") {
                                        viewModel.selectYear(year)
                                    }
                                }
                            } label: {
                                filterMenuLabel(
                                    title: viewModel.selectedYear.map(String.init) ?? "年份",
                                    icon: "calendar"
                                )
                            }

                            Menu {
                                Button("全部章节") {
                                    viewModel.selectCategory(nil)
                                }

                                ForEach(viewModel.categories, id: \.self) { category in
                                    Button(category) {
                                        viewModel.selectCategory(category)
                                    }
                                }
                            } label: {
                                filterMenuLabel(
                                    title: viewModel.selectedCategory ?? "章节",
                                    icon: "line.3.horizontal.decrease.circle"
                                )
                            }
                        }

                        HStack(spacing: 10) {
                            Menu {
                                ForEach(viewModel.availableQuestionLimits, id: \.self) { limit in
                                    Button("\(limit) 题") {
                                        viewModel.selectQuestionLimit(limit)
                                    }
                                }
                            } label: {
                                filterMenuLabel(
                                    title: "题量 \(viewModel.selectedQuestionLimit)",
                                    icon: "number.circle"
                                )
                            }

                            if viewModel.hasActiveFilters {
                                Button("清空") {
                                    viewModel.clearFilters()
                                }
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .frame(maxWidth: .infinity)
                                .background(AppTheme.Colors.card)
                                .overlay {
                                    Capsule()
                                        .stroke(AppTheme.Colors.stroke)
                                }
                                .clipShape(Capsule())
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .padding(.top, 12)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("题库筛选")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        Text(viewModel.hasActiveFilters ? activeFilterSummary : "年份 / 章节 / 关键词")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
            }
        }
    }

    private var sessionOverview: some View {
        PrimaryCard(style: .subtle) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("当前训练")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)

                        Text(viewModel.selectedMode.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }

                    Spacer()

                    Text(questionPositionText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("完成进度")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Spacer()
                        Text(viewModel.progressText)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }

                    ProgressView(value: progressFraction)
                        .tint(AppTheme.Colors.primary)
                }

                HStack(spacing: 12) {
                    sessionMetric(title: "本轮正确率", value: viewModel.accuracyText)
                    sessionMetric(
                        title: viewModel.selectedMode == .mockExam ? "剩余时间" : "已答题数",
                        value: viewModel.selectedMode == .mockExam
                            ? timeString(viewModel.remainingSeconds)
                            : "\(viewModel.answeredCount) / \(viewModel.questions.count)"
                    )
                }

                if viewModel.hasActiveFilters {
                    Text("筛选：\(activeFilterSummary)")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                } else {
                    Text("本轮题量：\(viewModel.selectedQuestionLimit) 题")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
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
                title: "当前模式暂无题目",
                message: "可以切换模式，或者先把年份、章节、关键词筛选清掉。",
                icon: "square.grid.2x2"
            ) {
                if viewModel.hasActiveFilters {
                    Button("清空筛选") {
                        viewModel.clearFilters()
                    }
                    .appButton()
                } else if viewModel.selectedMode != .sequential {
                    Button("切到顺序刷题") {
                        viewModel.switchMode(.sequential)
                    }
                    .appButton()
                }
            }
        } else if viewModel.finished {
            finishSection
        } else if let question = viewModel.currentQuestion {
            questionSection(question)
        }
    }

    private var finishSection: some View {
        PrimaryCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("这轮练习完成了")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("共答 \(viewModel.answeredCount) 题，当前正确率 \(viewModel.accuracyText)。建议继续做一轮错题重练。")
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                HStack(spacing: 12) {
                    Button("再来一轮") {
                        viewModel.restart()
                    }
                    .appButton()

                    Button("切换到错题重练") {
                        viewModel.switchMode(.wrongOnly)
                    }
                    .appButton(.secondary)
                }
            }
        }
    }

    private func questionSection(_ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            PrimaryCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                PillTag(title: question.type.title, icon: "doc.text", tint: AppTheme.Colors.secondary)
                                sourceBadge(for: question)
                            }

                            Text(question.stem)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 0)

                        Button {
                            viewModel.toggleFavoriteForCurrentQuestion()
                        } label: {
                            Image(systemName: viewModel.currentQuestionIsFavorite ? "star.fill" : "star")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(viewModel.currentQuestionIsFavorite ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("\(question.category) · \(question.sourceText)")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    if !question.knowledgePoints.isEmpty {
                        Text(question.knowledgePoints.prefix(4).joined(separator: " · "))
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    HStack(spacing: 12) {
                        infoPill(icon: "clock", text: "\(question.estimatedMinutes) 分钟")
                        infoPill(icon: "star", text: "\(Int(question.score)) 分")
                    }
                }
            }

            if question.isObjective {
                objectiveAnswerSection(question)
            } else {
                subjectiveAnswerSection(question)
            }

            if viewModel.showAnalysis {
                analysisSection(question)
                aiSection(question)
            }
        }
    }

    private func objectiveAnswerSection(_ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("作答", subtitle: "先独立判断，再提交查看解析")

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
    }

    private func subjectiveAnswerSection(_ question: Question) -> some View {
        PrimaryCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader("主观题", subtitle: "建议先自己列提纲，再对照参考答案")

                Text("案例题和论文题更适合先自己写，再对照参考答案自评。完成后可以标记“已掌握”或“需重练”。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                if !viewModel.showAnalysis {
                    HStack(spacing: 10) {
                        infoPill(icon: "square.and.pencil", text: "先独立作答")
                        infoPill(icon: "checkmark.seal", text: "再自评")
                    }
                } else if viewModel.awaitingSubjectiveAssessment {
                    Text("看完参考答案后，给自己一个结果判断。")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
            }
        }
    }

    private func analysisSection(_ question: Question) -> some View {
        PrimaryCard(style: .subtle) {
            VStack(alignment: .leading, spacing: 14) {
                if let currentAnswerCorrect = viewModel.currentAnswerCorrect {
                    HStack(spacing: 10) {
                        Image(systemName: currentAnswerCorrect ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(currentAnswerCorrect ? AppTheme.Colors.primary : AppTheme.Colors.secondary)
                        Text(currentAnswerCorrect ? "本题掌握良好" : "这题建议加入重点复习")
                            .font(.headline)
                            .foregroundStyle(currentAnswerCorrect ? AppTheme.Colors.primary : AppTheme.Colors.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("参考答案")
                        .font(.subheadline.weight(.semibold))
                    Text(question.answerSummary)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("详细解析")
                        .font(.subheadline.weight(.semibold))
                    Text(question.analysis)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
    }

    private func aiSection(_ question: Question) -> some View {
        PrimaryCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    "AI 学习助手",
                    subtitle: "默认支持离线生成；配置接口后优先走联网 AI"
                )

                HStack(spacing: 10) {
                    aiButton(
                        title: question.isObjective ? "AI 讲解" : "AI 提纲",
                        icon: question.isObjective ? "sparkles" : "list.bullet.rectangle.portrait",
                        tint: AppTheme.Colors.accent
                    ) {
                        viewModel.requestAIInsight(style: question.isObjective ? .explanation : .essayOutline)
                    }

                    aiButton(
                        title: "AI 相似题",
                        icon: "square.stack.3d.up",
                        tint: AppTheme.Colors.accent
                    ) {
                        viewModel.requestAIInsight(style: .similarQuestion)
                    }
                }

                if viewModel.isAILoading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("AI 正在整理讲解…")
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
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
                            PillTag(
                                title: insight.source,
                                icon: insight.source.contains("远程") ? "wifi" : "cpu",
                                tint: AppTheme.Colors.secondary
                            )
                        }

                        Text(insight.summary)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)

                        VStack(alignment: .leading, spacing: 8) {
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

                        Divider()

                        Text("下一步：\(insight.nextAction)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
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
    private var bottomActionBar: some View {
        if viewModel.questions.isEmpty || viewModel.finished || viewModel.errorMessage != nil {
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
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(AppTheme.Colors.background)
            .overlay(alignment: .top) {
                Divider()
            }
        }
    }

    private var progressFraction: Double {
        guard !viewModel.questions.isEmpty else { return 0 }
        return Double(min(viewModel.currentIndex + (viewModel.finished ? 1 : 0), viewModel.questions.count)) / Double(viewModel.questions.count)
    }

    private var questionPositionText: String {
        guard !viewModel.questions.isEmpty else { return "0 / 0" }
        return "\(min(viewModel.currentIndex + 1, viewModel.questions.count)) / \(viewModel.questions.count)"
    }

    private var modeBinding: Binding<PracticeMode> {
        Binding(
            get: { viewModel.selectedMode },
            set: { viewModel.switchMode($0) }
        )
    }

    private var activeFilterSummary: String {
        var items: [String] = []

        if let selectedYear = viewModel.selectedYear {
            items.append("\(selectedYear)")
        }

        if let selectedCategory = viewModel.selectedCategory {
            items.append(selectedCategory)
        }

        let keyword = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keyword.isEmpty {
            items.append(keyword)
        }

        return items.isEmpty ? "年份 / 章节 / 关键词" : items.joined(separator: " · ")
    }

    private var recentSearchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("最近搜索")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Spacer()

                Button("清空记录") {
                    recentActivityStore.clearSearches()
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recentActivityStore.recentSearches, id: \.self) { keyword in
                        Button {
                            viewModel.searchText = keyword
                            viewModel.selectSearchSuggestion(keyword)
                        } label: {
                            PillTag(
                                title: keyword,
                                icon: "clock.arrow.circlepath",
                                tint: isCurrentSearch(keyword) ? AppTheme.Colors.primary : AppTheme.Colors.secondary,
                                filled: isCurrentSearch(keyword)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private var searchSuggestionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("搜索联想")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Spacer()

                Button("收起") {
                    viewModel.dismissSearchSuggestions()
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .buttonStyle(.plain)
            }

            VStack(spacing: 8) {
                ForEach(viewModel.searchSuggestions, id: \.self) { suggestion in
                    Button {
                        viewModel.selectSearchSuggestion(suggestion)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(AppTheme.Colors.textSecondary)

                            Text(suggestion)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 0)

                            Image(systemName: "arrow.up.left")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.textTertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.Colors.background)
                        .overlay {
                            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                                .stroke(AppTheme.Colors.stroke)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func infoPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(AppTheme.Colors.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.Colors.background)
        .overlay {
            Capsule()
                .stroke(AppTheme.Colors.stroke)
        }
        .clipShape(Capsule())
    }

    private func filterMenuLabel(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
                .lineLimit(1)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.card)
        .overlay {
            Capsule()
                .stroke(AppTheme.Colors.stroke)
        }
        .clipShape(Capsule())
    }

    private func sessionMetric(title: String, value: String) -> some View {
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
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .stroke(AppTheme.Colors.stroke)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous))
    }

    private func aiButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
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

    private func sourceBadge(for question: Question) -> some View {
        PillTag(
            title: question.sourceBadgeTitle,
            icon: question.sourceBadgeIcon,
            tint: question.isAdapted ? AppTheme.Colors.accent : AppTheme.Colors.primary
        )
    }

    private func isCurrentSearch(_ keyword: String) -> Bool {
        viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(keyword) == .orderedSame
    }

    private func shortTitle(for mode: PracticeMode) -> String {
        switch mode {
        case .sequential:
            return "顺序"
        case .random:
            return "随机"
        case .mockExam:
            return "模考"
        case .wrongOnly:
            return "错题"
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remain = seconds % 60
        return String(format: "%02d:%02d", minutes, remain)
    }
}
