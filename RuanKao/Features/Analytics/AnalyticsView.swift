import Charts
import SwiftUI

struct AnalyticsView: View {
    @StateObject private var viewModel: AnalyticsViewModel

    init(container: AppContainer) {
        _viewModel = StateObject(
            wrappedValue: AnalyticsViewModel(analyticsRepository: container.analyticsRepository)
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Metrics.listSectionSpacing) {
                overviewHeader
                trendCard
                weakPointCard
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("学习分析")
        .appScreenChrome()
        .task {
            viewModel.load()
        }
        .refreshable {
            viewModel.load()
        }
    }

    private var overviewHeader: some View {
        PrimaryCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("数据会告诉你下一步该学什么")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("通过正确率和练习趋势，定位真正影响分数的薄弱知识点。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                HStack(spacing: 12) {
                    headerMetric(title: "趋势天数", value: "\(viewModel.trend.count)")
                    headerMetric(title: "知识点数", value: "\(viewModel.weakPoints.count)")
                }
            }
        }
    }

    @ViewBuilder
    private var trendCard: some View {
        if !viewModel.trend.isEmpty {
            PrimaryCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader("最近 14 天学习曲线", subtitle: "柱状图看练习量，折线看正确率")

                    Chart(viewModel.trend) { item in
                        BarMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("练习量", item.practicedCount)
                        )
                        .foregroundStyle(AppTheme.Colors.secondary.opacity(AppTheme.Metrics.chartBarOpacity))

                        LineMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("正确率", item.accuracy * 10)
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

                        PointMark(
                            x: .value("日期", item.date, unit: .day),
                            y: .value("正确率", item.accuracy * 10)
                        )
                        .foregroundStyle(AppTheme.Colors.secondary)
                        .symbolSize(AppTheme.Metrics.chartPointSize)
                    }
                    .frame(height: 240)
                }
            }
        } else if let errorMessage = viewModel.errorMessage {
            StatePanel(
                title: "学习曲线加载失败",
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
                title: "还没有趋势数据",
                message: "先进行练习，系统就会开始生成你的趋势图。",
                icon: "chart.line.uptrend.xyaxis"
            )
        }
    }

    @ViewBuilder
    private var weakPointCard: some View {
        if !viewModel.weakPoints.isEmpty {
            PrimaryCard(style: .subtle) {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader("薄弱知识点排行", subtitle: "优先处理正确率低且练习次数多的知识点")

                    ForEach(Array(viewModel.weakPoints.enumerated()), id: \.element.id) { index, item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                HStack(spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.white)
                                        .frame(width: 22, height: 22)
                                        .background(index < 3 ? AppTheme.Colors.textPrimary : AppTheme.Colors.secondary)
                                        .clipShape(Circle())

                                    Text(item.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                }

                                Spacer()

                                Text(item.accuracy.formatted(.percent.precision(.fractionLength(0))))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(weakPointColor(for: item.accuracy))
                            }

                            ProgressView(value: item.accuracy)
                                .tint(weakPointColor(for: item.accuracy))
                                .scaleEffect(x: 1, y: 1.15, anchor: .center)

                            Text("累计练习 \(item.practicedCount) 次")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                }
            }
        } else {
            StatePanel(
                title: "暂无薄弱点排行",
                message: "先去刷几题，系统会自动生成薄弱点分析。",
                icon: "list.number"
            )
        }
    }

    private func headerMetric(title: String, value: String) -> some View {
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

    private func weakPointColor(for accuracy: Double) -> Color {
        accuracy < 0.6 ? AppTheme.Colors.primary : AppTheme.Colors.secondary
    }
}
