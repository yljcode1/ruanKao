import Foundation

final class MockAIStudyService: AIStudyServiceProtocol {
    func generateInsight(for question: Question, style: AIInsightStyle) async throws -> AIStudyInsight {
        try await Task.sleep(for: .milliseconds(450))

        switch style {
        case .explanation:
            return AIStudyInsight(
                title: "AI 讲解：\(question.category)",
                summary: "这题的关键不是背答案，而是先识别它考的是 \(question.knowledgePoints.first ?? question.category) 的核心判断标准。",
                highlights: [
                    "先看题干里的限定词，判断考察的是概念、场景还是设计原则。",
                    "把正确选项对应的知识点和常见干扰项对照记忆，能显著减少下次误判。",
                    question.analysis
                ],
                nextAction: "建议立刻再做 2~3 道同类别题，巩固同一知识点。",
                source: "本地智能模板"
            )
        case .similarQuestion:
            return AIStudyInsight(
                title: "AI 相似题练习",
                summary: "围绕 \(question.category) 给你生成一组同考点变体题，训练迁移能力。",
                highlights: [
                    "把题干场景改成“高并发 / 高可用 / 性能瓶颈”其中一个，再重新判断设计取舍。",
                    "把选项中的正确原则换成相近概念，例如把“无状态”换成“幂等性”，检验是否能区分。",
                    "尝试自己写一个错误选项，并解释它为什么错。"
                ],
                nextAction: "打开随机刷题模式，继续做 5 道同类题效果最好。",
                source: "本地智能模板"
            )
        case .essayOutline:
            return AIStudyInsight(
                title: "AI 论文题提纲",
                summary: "论文题建议固定成“背景 -> 问题 -> 方案 -> 收益 -> 反思”五段式，保证结构稳定。",
                highlights: [
                    "开头先交代项目背景、规模、角色和业务挑战。",
                    "中间用 3 个小节写核心设计：架构方案、关键技术、落地过程。",
                    "结尾必须写量化收益和复盘反思，这一段最容易拉开分差。"
                ],
                nextAction: "先按这个结构写 5 句提纲，再开始扩写正文。",
                source: "本地智能模板"
            )
        }
    }
}
