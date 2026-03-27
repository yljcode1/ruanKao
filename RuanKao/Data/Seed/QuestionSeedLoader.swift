import Foundation

enum QuestionSeedLoader {
    struct SeedBundle {
        let manifest: String
        let questions: [Question]
    }

    static func load() -> [Question] {
        loadSeedBundle().questions
    }

    static func loadSeedBundle() -> SeedBundle {
        if let bundledBundle = loadBundledSeedBundle() {
            return bundledBundle
        }

        return SeedBundle(manifest: fallbackManifest, questions: fallbackQuestions)
    }

    static func currentManifest() -> String {
        bundledManifest() ?? fallbackManifest
    }

    private static func loadBundledSeedBundle() -> SeedBundle? {
        guard let manifest = bundledManifest() else {
            return nil
        }

        let questions = loadBundledSeedQuestions()
        guard !questions.isEmpty else {
            return nil
        }

        return SeedBundle(manifest: manifest, questions: questions)
    }

    private static func bundledManifest() -> String? {
        guard let resourceURL = Bundle.main.resourceURL else {
            return nil
        }

        let urls = seedURLs(at: resourceURL)
        guard !urls.isEmpty else {
            return nil
        }

        let components = urls.map { url -> String in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let fileSize = values?.fileSize ?? 0
            let modifiedAt = Int(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)
            return "\(url.lastPathComponent)#\(fileSize)#\(modifiedAt)"
        }

        return components.joined(separator: "|")
    }

    private static func loadBundledSeedQuestions() -> [Question] {
        guard let resourceURL = Bundle.main.resourceURL else {
            return []
        }

        let decoder = JSONDecoder()
        let urls = seedURLs(at: resourceURL)

        var questionsByID: [Int64: Question] = [:]

        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let questions = try? decoder.decode([Question].self, from: data)
            else {
                continue
            }

            for question in questions {
                questionsByID[question.id] = question
            }
        }

        return questionsByID.values.sorted {
            if $0.year == $1.year {
                return $0.id < $1.id
            }
            return $0.year > $1.year
        }
    }

    private static func seedURLs(at resourceURL: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: resourceURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator
            .compactMap { $0 as? URL }
            .filter {
                $0.pathExtension.lowercased() == "json"
                    && $0.lastPathComponent.lowercased().contains("question")
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static let fallbackManifest = "fallback_questions_v1"

    private static let fallbackQuestions: [Question] = [
        Question(
            id: 1001,
            year: 2024,
            stage: "上午真题",
            type: .singleChoice,
            category: "架构设计",
            knowledgePoints: ["架构风格", "高可用设计"],
            stem: "在微服务架构中，若希望多个服务实例之间无共享状态，并通过负载均衡横向扩展，最关键的设计原则是什么？",
            options: [
                QuestionOption(label: "A", content: "服务端保持会话状态，便于链路跟踪"),
                QuestionOption(label: "B", content: "服务设计为无状态，状态外置到缓存或数据库"),
                QuestionOption(label: "C", content: "将所有服务合并为统一部署单元"),
                QuestionOption(label: "D", content: "每个服务实例使用独立数据库且不共享数据")
            ],
            correctAnswers: ["B"],
            analysis: "无状态化是微服务可扩展的基础。用户会话、流程状态应外置到 Redis、数据库或 Token 中，实例才能被自由替换和弹性扩容。",
            score: 1,
            estimatedMinutes: 2
        ),
        Question(
            id: 1002,
            year: 2024,
            stage: "上午真题",
            type: .singleChoice,
            category: "数据库",
            knowledgePoints: ["事务", "并发控制"],
            stem: "下列关于数据库事务隔离级别的说法中，最能避免幻读的是哪一项？",
            options: [
                QuestionOption(label: "A", content: "Read Uncommitted"),
                QuestionOption(label: "B", content: "Read Committed"),
                QuestionOption(label: "C", content: "Repeatable Read"),
                QuestionOption(label: "D", content: "Serializable")
            ],
            correctAnswers: ["D"],
            analysis: "Serializable 是最高隔离级别，通过串行化执行避免脏读、不可重复读和幻读，但并发能力最低。",
            score: 1,
            estimatedMinutes: 2
        ),
        Question(
            id: 2001,
            year: 2023,
            stage: "下午案例",
            type: .caseStudy,
            category: "系统设计",
            knowledgePoints: ["性能优化", "缓存设计"],
            stem: "某电商平台在大促期间出现首页查询响应时间陡增。请从架构层面分析可能原因，并给出三项优化建议。",
            options: [],
            correctAnswers: ["可从缓存击穿、数据库热点、服务雪崩、消息削峰等方向展开。"],
            analysis: "案例题建议按“问题识别 -> 根因定位 -> 方案分层”回答。优先从 CDN、缓存、限流降级、读写分离、异步削峰五个层面组织答案。",
            score: 25,
            estimatedMinutes: 18
        ),
        Question(
            id: 3001,
            year: 2023,
            stage: "论文题",
            type: .essay,
            category: "软件架构",
            knowledgePoints: ["论文写作", "领域驱动设计"],
            stem: "请结合实际项目，论述领域驱动设计在大型复杂系统中的价值、实施难点以及落地策略。",
            options: [],
            correctAnswers: ["建议从背景、问题、DDD 分层、统一语言、聚合划分、收益与反思展开。"],
            analysis: "论文题答题模板建议固定为：项目背景 -> 面临挑战 -> 架构设计 -> 关键技术措施 -> 成果与反思。AI 能力后续可以在此页生成论文提纲和点评。",
            score: 75,
            estimatedMinutes: 45
        ),
        Question(
            id: 1003,
            year: 2022,
            stage: "上午真题",
            type: .singleChoice,
            category: "网络",
            knowledgePoints: ["负载均衡", "高可用设计"],
            stem: "在四层负载均衡与七层负载均衡的对比中，下列说法正确的是？",
            options: [
                QuestionOption(label: "A", content: "四层负载均衡可以基于 URL 进行路由"),
                QuestionOption(label: "B", content: "七层负载均衡无法感知应用协议内容"),
                QuestionOption(label: "C", content: "四层负载均衡通常性能更高，七层负载均衡策略更灵活"),
                QuestionOption(label: "D", content: "两者都只能工作在 TCP 协议之上")
            ],
            correctAnswers: ["C"],
            analysis: "四层负载均衡基于 IP 和端口转发，性能高；七层可解析 HTTP 等应用层信息，实现更细粒度的转发与治理。",
            score: 1,
            estimatedMinutes: 2
        ),
        Question(
            id: 1004,
            year: 2022,
            stage: "上午真题",
            type: .singleChoice,
            category: "操作系统",
            knowledgePoints: ["进程管理", "死锁"],
            stem: "避免系统发生死锁的银行家算法，其核心思想是：",
            options: [
                QuestionOption(label: "A", content: "允许系统进入不安全状态，再逐步回滚"),
                QuestionOption(label: "B", content: "动态判断资源分配后是否仍处于安全状态"),
                QuestionOption(label: "C", content: "一旦检测到死锁立即重启系统"),
                QuestionOption(label: "D", content: "要求所有进程一次性申请全部资源")
            ],
            correctAnswers: ["B"],
            analysis: "银行家算法通过试探分配并检查安全序列，确保系统始终停留在安全状态，从而避免死锁。",
            score: 1,
            estimatedMinutes: 2
        )
    ]
}
