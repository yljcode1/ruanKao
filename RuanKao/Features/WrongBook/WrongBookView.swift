import SwiftUI

struct WrongBookView: View {
    @StateObject private var viewModel: WrongBookViewModel
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(
            wrappedValue: WrongBookViewModel(questionRepository: container.questionRepository)
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
            viewModel.load()
        }
        .refreshable {
            viewModel.load()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    PracticeView(container: container, preferredMode: .wrongOnly)
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

                    Text("自动收集、按知识点聚类、学会后标记掌握，让错题本越来越轻。")
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
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("复习视图", subtitle: "按掌握状态快速切换")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(WrongFilter.allCases) { filter in
                        Button {
                            viewModel.filter = filter
                        } label: {
                            HStack(spacing: 8) {
                                Text(filter.title)
                                Text("(\(count(for: filter)))")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(viewModel.filter == filter ? Color.white : AppTheme.Colors.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(viewModel.filter == filter ? AppTheme.Colors.primary : AppTheme.Colors.elevatedCard)
                            .overlay {
                                Capsule()
                                    .stroke(viewModel.filter == filter ? AppTheme.Colors.primary : AppTheme.Colors.stroke)
                            }
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if let errorMessage = viewModel.errorMessage {
            StatePanel(
                title: "错题本加载失败",
                message: errorMessage,
                icon: "exclamationmark.triangle",
                tint: AppTheme.Colors.danger
            ) {
                Button("重新加载") {
                    viewModel.load()
                }
                .appButton()
            }
        } else if viewModel.groupedItems.isEmpty {
            StatePanel(
                title: "暂无错题",
                message: "继续保持，答错的题会自动沉淀到这里，后面可以集中回看。",
                icon: "checkmark.circle"
            ) {
                NavigationLink {
                    PracticeView(container: container, preferredMode: .sequential)
                } label: {
                    Text("去练几题")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .appButton()
            }
        } else {
            VStack(alignment: .leading, spacing: AppTheme.Metrics.listSectionSpacing) {
                ForEach(viewModel.groupedItems, id: \.0) { group in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            PillTag(title: group.0, icon: "tag.fill", tint: AppTheme.Colors.secondary)
                            Spacer()
                            Text("\(group.1.count) 题")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }

                        ForEach(group.1) { item in
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
                                                    tint: AppTheme.Colors.secondary
                                                )
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
            }
        }
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
