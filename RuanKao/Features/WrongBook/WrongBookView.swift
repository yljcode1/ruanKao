import SwiftUI

struct WrongBookView: View {
    @StateObject private var viewModel: WrongBookViewModel
    @ObservedObject private var studyDataStore: StudyDataStore
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _studyDataStore = ObservedObject(wrappedValue: container.studyDataStore)
        _viewModel = StateObject(
            wrappedValue: WrongBookViewModel(
                questionRepository: container.questionRepository,
                dataDidChange: {
                    container.studyDataStore.markChanged()
                }
            )
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Metrics.listSectionSpacing) {
                headerSection
                filterSection
                contentSection
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("错题本")
        .appScreenChrome()
        .task {
            viewModel.loadIfNeeded()
        }
        .refreshable {
            viewModel.load(force: true)
        }
        .onReceive(studyDataStore.$revision.dropFirst()) { _ in
            viewModel.load(force: true)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    PracticeView(
                        container: container,
                        preferredMode: .wrongOnly,
                        initialSearchText: viewModel.selectedKnowledgePoint
                    )
                } label: {
                    Text("开始重练")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private var headerSection: some View {
        PrimaryCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("把错题变成提分资产")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Text("自动收集、按知识点聚焦、按危险程度排序，把最值得重练的题顶出来。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                HStack(spacing: 12) {
                    summaryCapsule(title: "未掌握", value: "\(viewModel.unmasteredCount)")
                    summaryCapsule(title: "已掌握", value: "\(viewModel.masteredCount)")
                    summaryCapsule(title: "总数", value: "\(viewModel.totalCount)")
                }

                if let hottestKnowledgePoint = viewModel.hottestKnowledgePoint {
                    HStack(spacing: 8) {
                        Image(systemName: "flame")
                        Text("当前最该优先处理：\(hottestKnowledgePoint)")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                }
            }
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("复习视图", subtitle: "按掌握状态、知识点和危险程度快速切换")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(WrongFilter.allCases) { filter in
                        filterChip(
                            title: "\(filter.title) (\(count(for: filter)))",
                            isActive: viewModel.filter == filter
                        ) {
                            viewModel.filter = filter
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(WrongSortMode.allCases) { mode in
                        filterChip(title: mode.title, isActive: viewModel.sortMode == mode) {
                            viewModel.sortMode = mode
                        }
                    }
                }
            }

            if !viewModel.knowledgePointOptions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        filterChip(title: "全部知识点", isActive: viewModel.selectedKnowledgePoint == nil) {
                            viewModel.selectKnowledgePoint(nil)
                        }

                        ForEach(viewModel.knowledgePointOptions, id: \.self) { knowledgePoint in
                            filterChip(
                                title: knowledgePoint,
                                isActive: viewModel.selectedKnowledgePoint == knowledgePoint
                            ) {
                                viewModel.selectKnowledgePoint(knowledgePoint)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            StatePanel(
                title: "正在加载错题本",
                message: "正在按知识点整理最近做错的题目。",
                icon: "clock.arrow.circlepath"
            ) {
                ProgressView()
                    .tint(AppTheme.Colors.primary)
            }
        } else if let errorMessage = viewModel.errorMessage {
            StatePanel(
                title: "错题本加载失败",
                message: errorMessage,
                icon: "exclamationmark.triangle",
                tint: AppTheme.Colors.danger
            ) {
                Button("重新加载") {
                    viewModel.load(force: true)
                }
                .appButton()
            }
        } else if viewModel.displaySections.allSatisfy(\.items.isEmpty) {
            StatePanel(
                title: "当前筛选下暂无错题",
                message: "可以切换排序方式、放宽掌握状态筛选，或者继续去做题。",
                icon: "checkmark.circle"
            ) {
                Button("查看全部错题") {
                    viewModel.filter = .all
                    viewModel.selectKnowledgePoint(nil)
                }
                .appButton()
            }
        } else {
            LazyVStack(alignment: .leading, spacing: AppTheme.Metrics.listSectionSpacing) {
                ForEach(viewModel.displaySections) { section in
                    if !section.items.isEmpty {
                        wrongSection(section)
                    }
                }
            }
        }
    }

    private func wrongSection(_ section: WrongQuestionSection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        PillTag(title: section.title, icon: "tag.fill", tint: AppTheme.Colors.secondary)
                        Text("\(section.items.count) 题")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    if let subtitle = section.subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }

                Spacer()

                NavigationLink {
                    PracticeView(
                        container: container,
                        preferredMode: .wrongOnly,
                        initialSearchText: section.title == "最近连错" || section.title == "高危错题" ? viewModel.selectedKnowledgePoint : section.title
                    )
                } label: {
                    Text("针对重练")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.card)
                        .overlay {
                            Capsule()
                                .stroke(AppTheme.Colors.stroke)
                        }
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            ForEach(section.items) { item in
                PrimaryCard(style: item.isMastered ? .subtle : .elevated) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    PillTag(
                                        title: item.question.type.title,
                                        icon: "doc.text",
                                        tint: AppTheme.Colors.secondary
                                    )
                                    PillTag(
                                        title: item.question.sourceBadgeTitle,
                                        icon: item.question.sourceBadgeIcon,
                                        tint: item.question.isAdapted ? AppTheme.Colors.accent : AppTheme.Colors.primary
                                    )
                                    PillTag(
                                        title: item.isMastered ? "已掌握" : "待重练",
                                        icon: item.isMastered ? "checkmark" : "exclamationmark",
                                        tint: item.isMastered ? AppTheme.Colors.secondary : AppTheme.Colors.primary,
                                        filled: !item.isMastered
                                    )
                                    if item.wrongCount >= 3 {
                                        PillTag(title: "高危", icon: "flame", tint: AppTheme.Colors.primary)
                                    }
                                }

                                Text(item.question.stem)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                    .lineLimit(3)
                            }

                            Spacer(minLength: 12)
                        }

                        HStack {
                            infoItem(title: "错误次数", value: "\(item.wrongCount)")
                            infoItem(
                                title: "最近错误",
                                value: item.lastWrongAt.formatted(date: .abbreviated, time: .omitted)
                            )
                        }

                        Button(item.isMastered ? "取消掌握" : "标记掌握") {
                            viewModel.toggleMastered(item)
                        }
                        .appButton(item.isMastered ? .secondary : .primary)
                    }
                    .frame(minHeight: AppTheme.Metrics.listRowMinHeight, alignment: .topLeading)
                }
            }
        }
    }

    private func filterChip(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isActive ? Color.white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isActive ? AppTheme.Colors.primary : AppTheme.Colors.elevatedCard)
                .overlay {
                    Capsule()
                        .stroke(isActive ? AppTheme.Colors.primary : AppTheme.Colors.stroke)
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func summaryCapsule(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.Colors.card)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                .stroke(AppTheme.Colors.stroke)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))
    }

    private func infoItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.Colors.card)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                .stroke(AppTheme.Colors.stroke)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))
    }

    private func count(for filter: WrongFilter) -> Int {
        switch filter {
        case .all:
            return viewModel.totalCount
        case .unmastered:
            return viewModel.unmasteredCount
        case .mastered:
            return viewModel.masteredCount
        }
    }
}
