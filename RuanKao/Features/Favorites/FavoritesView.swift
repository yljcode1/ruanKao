import SwiftUI

struct FavoritesView: View {
    @StateObject private var viewModel: FavoritesViewModel
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(
            wrappedValue: FavoritesViewModel(questionRepository: container.questionRepository)
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
        .navigationTitle("收藏夹")
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
                Text("把值得反复看的题收藏起来")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("收藏夹适合放高频易错题、经典真题和论文题素材，考前回顾效率很高。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                PillTag(title: "已收藏 \(viewModel.count) 题", icon: "star.fill", tint: AppTheme.Colors.secondary)
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if let errorMessage = viewModel.errorMessage {
            StatePanel(
                title: "收藏夹暂时打不开",
                message: errorMessage,
                icon: "exclamationmark.triangle",
                tint: AppTheme.Colors.danger
            ) {
                Button("重新加载") {
                    viewModel.load()
                }
                .appButton()
            }
        } else if viewModel.questions.isEmpty {
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
        } else {
            VStack(alignment: .leading, spacing: AppTheme.Metrics.listItemSpacing) {
                ForEach(viewModel.questions) { question in
                    PrimaryCard(style: .subtle) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                HStack(spacing: 8) {
                                    PillTag(title: question.type.title, icon: "doc.text", tint: AppTheme.Colors.secondary)
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

                            NavigationLink {
                                PracticeView(container: container, preferredMode: .sequential, initialCategory: question.category, initialYear: question.year)
                            } label: {
                                Text("去同年份 / 同类别继续练")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .appButton()
                        }
                        .frame(minHeight: AppTheme.Metrics.listRowMinHeight, alignment: .topLeading)
                    }
                }
            }
        }
    }
}
