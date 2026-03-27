import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel: FavoritesViewModel
    @ObservedObject private var studyDataStore: StudyDataStore
    @State private var editingItem: FavoriteQuestionItem?
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _studyDataStore = ObservedObject(wrappedValue: container.studyDataStore)
        _viewModel = StateObject(
            wrappedValue: FavoritesViewModel(
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
                if !viewModel.availableTags.isEmpty {
                    tagFilterSection
                }
                contentSection
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("收藏夹")
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
        .sheet(item: $editingItem) { item in
            FavoriteAnnotationEditor(item: item) { tags, note in
                viewModel.saveAnnotation(questionID: item.id, tags: tags, note: note)
            }
        }
    }

    private var headerSection: some View {
        PrimaryCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("把值得反复看的题收藏起来")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("收藏夹适合放高频易错题、经典真题和论文题素材，考前回顾效率很高。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                HStack(spacing: 10) {
                    PillTag(title: "已收藏 \(viewModel.count) 题", icon: "star.fill", tint: AppTheme.Colors.secondary)

                    if let selectedTag = viewModel.selectedTag {
                        PillTag(title: "标签：\(selectedTag)", icon: "tag.fill", tint: AppTheme.Colors.primary, filled: true)
                    }
                }
            }
        }
    }

    private var tagFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("标签筛选", subtitle: "把重点题按自己的复习维度整理起来")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        viewModel.selectTag(nil)
                    } label: {
                        PillTag(
                            title: "全部",
                            icon: "line.3.horizontal.decrease.circle",
                            tint: viewModel.selectedTag == nil ? AppTheme.Colors.primary : AppTheme.Colors.secondary,
                            filled: viewModel.selectedTag == nil
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(viewModel.availableTags, id: \.self) { tag in
                        Button {
                            viewModel.selectTag(tag)
                        } label: {
                            PillTag(
                                title: tag,
                                icon: "tag",
                                tint: viewModel.selectedTag == tag ? AppTheme.Colors.primary : AppTheme.Colors.secondary,
                                filled: viewModel.selectedTag == tag
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            StatePanel(
                title: "正在加载收藏夹",
                message: "正在读取你标记过的重要题目。",
                icon: "clock.arrow.circlepath"
            ) {
                ProgressView()
                    .tint(AppTheme.Colors.primary)
            }
        } else if let errorMessage = viewModel.errorMessage {
            StatePanel(
                title: "收藏夹暂时打不开",
                message: errorMessage,
                icon: "exclamationmark.triangle",
                tint: AppTheme.Colors.danger
            ) {
                Button("重新加载") {
                    viewModel.load(force: true)
                }
                .appButton()
            }
        } else if viewModel.items.isEmpty {
            StatePanel(
                title: "还没有收藏题目",
                message: "在刷题页点星标，就能把重点题沉淀到这里。",
                icon: "star"
            ) {
                NavigationLink {
                    PracticeView(container: container, preferredMode: .sequential)
                } label: {
                    Text("去刷题")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .appButton()
            }
        } else if viewModel.filteredItems.isEmpty {
            StatePanel(
                title: "当前标签下还没有题目",
                message: "切换到其他标签，或者清空筛选后查看全部收藏。",
                icon: "tag"
            ) {
                Button("查看全部") {
                    viewModel.selectTag(nil)
                }
                .appButton()
            }
        } else {
            LazyVStack(alignment: .leading, spacing: AppTheme.Metrics.listItemSpacing) {
                ForEach(viewModel.filteredItems) { item in
                    favoriteCard(item)
                }
            }
        }
    }

    private func favoriteCard(_ item: FavoriteQuestionItem) -> some View {
        let question = item.question

        return PrimaryCard(style: .subtle) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        PillTag(title: question.type.title, icon: "doc.text", tint: AppTheme.Colors.secondary)
                        PillTag(
                            title: question.sourceBadgeTitle,
                            icon: question.sourceBadgeIcon,
                            tint: question.isAdapted ? AppTheme.Colors.accent : AppTheme.Colors.primary
                        )
                        PillTag(title: question.category, icon: "folder", tint: AppTheme.Colors.primary)
                    }
                    Spacer()
                    Button {
                        viewModel.removeFavorite(questionID: question.id)
                    } label: {
                        Image(systemName: "star.fill")
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }

                Text(question.stem)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(3)

                HStack {
                    Text(question.sourceText)
                    Spacer()
                    Text(question.knowledgePoints.first ?? "未分类")
                }
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)

                if item.annotation.hasTags {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(item.annotation.tags, id: \.self) { tag in
                                PillTag(title: tag, icon: "tag", tint: AppTheme.Colors.secondary)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }

                if item.annotation.hasNote {
                    Text(item.annotation.note)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(AppTheme.Colors.background)
                        .overlay {
                            RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                                .stroke(AppTheme.Colors.stroke)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))
                }

                HStack(spacing: 12) {
                    NavigationLink {
                        PracticeView(
                            container: container,
                            preferredMode: .sequential,
                            initialCategory: question.category,
                            initialYear: question.year
                        )
                    } label: {
                        Text("去同年份 / 同类别继续练")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .appButton()

                    Button {
                        editingItem = item
                    } label: {
                        Text(item.annotation.isEmpty ? "添加标签 / 备注" : "编辑标签 / 备注")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .appButton(.secondary)
                }
            }
            .frame(minHeight: AppTheme.Metrics.listRowMinHeight, alignment: .topLeading)
        }
    }
}

private struct FavoriteAnnotationEditor: View {
    let item: FavoriteQuestionItem
    let onSave: ([String], String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tagText: String
    @State private var noteText: String

    init(item: FavoriteQuestionItem, onSave: @escaping ([String], String) -> Void) {
        self.item = item
        self.onSave = onSave
        _tagText = State(initialValue: item.annotation.tags.joined(separator: "，"))
        _noteText = State(initialValue: item.annotation.note)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    PrimaryCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("题目摘要")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            Text(item.question.stem)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }

                    PrimaryCard(style: .subtle) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("标签")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            TextField("例如：高频、论文素材、考前回顾", text: $tagText)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(AppTheme.Colors.background)
                                .overlay {
                                    RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                                        .stroke(AppTheme.Colors.stroke)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))

                            Text("支持用逗号分隔多个标签。")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }

                    PrimaryCard(style: .subtle) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("备注")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)

                            TextEditor(text: $noteText)
                                .frame(minHeight: 160)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .background(AppTheme.Colors.background)
                                .overlay {
                                    RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous)
                                        .stroke(AppTheme.Colors.stroke)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Metrics.controlRadius, style: .continuous))

                            Text("可以记错因、答题框架，或者临考前想重点回顾的点。")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("标签与备注")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(parsedTags, noteText)
                        dismiss()
                    }
                }
            }
        }
    }

    private var parsedTags: [String] {
        tagText
            .split { ",，;；\n".contains($0) }
            .map(String.init)
    }
}
