#!/usr/bin/env swift

import Foundation

struct ImportQuestionOption: Codable {
    let label: String
    let content: String
}

enum ImportQuestionType: String, Codable {
    case singleChoice
    case caseStudy
    case essay
}

struct ImportQuestion: Codable {
    let id: Int64
    let year: Int
    let stage: String
    let type: ImportQuestionType
    let category: String
    let knowledgePoints: [String]
    let stem: String
    let options: [ImportQuestionOption]
    let correctAnswers: [String]
    let analysis: String
    let score: Double
    let estimatedMinutes: Int
}

struct ImportQuestionRecord: Decodable {
    let id: Int64?
    let year: Int?
    let stage: String?
    let type: String?
    let category: String?
    let knowledgePoints: [String]?
    let knowledge_points: String?
    let stem: String?
    let options: [ImportQuestionOption]?
    let options_json: String?
    let option_a: String?
    let option_b: String?
    let option_c: String?
    let option_d: String?
    let option_e: String?
    let option_f: String?
    let correctAnswers: [String]?
    let correct_answers: String?
    let analysis: String?
    let score: Double?
    let estimatedMinutes: Int?
    let estimated_minutes: Int?
}

struct ImportQuestionWrapper: Decodable {
    let questions: [ImportQuestionRecord]
}

enum ImporterError: LocalizedError {
    case invalidArguments(String)
    case unsupportedInput(String)
    case malformedData(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let message),
             .unsupportedInput(let message),
             .malformedData(let message):
            return message
        }
    }
}

enum QuestionImporterCLI {
    static func run() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard !arguments.isEmpty else {
            throw ImporterError.invalidArguments(usage)
        }

        let configuration = try parseArguments(arguments)
        let questions = try loadQuestions(from: configuration.inputURL)
        try write(questions: questions, to: configuration.outputURL)

        print("✅ 已生成题库文件：\(configuration.outputURL.path)")
        print("📦 题目数量：\(questions.count)")
        let categories = Set(questions.map(\.category)).sorted()
        print("🧭 分类：\(categories.joined(separator: "、"))")
    }

    private static let usage = """
    用法：
      swift Tools/question_importer.swift --input <输入文件> --output <输出文件>

    支持输入：
      - CSV：适合从网页 / Excel 整理后导入
      - JSON：支持 questions 数组或 { \"questions\": [...] } 包装结构

    输出：
      - 规范化后的 JSON 题包，可直接放到 RuanKao/Resources/Seeds/Imports/
    """

    private static func parseArguments(_ arguments: [String]) throws -> (inputURL: URL, outputURL: URL) {
        var inputPath: String?
        var outputPath: String?

        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--input":
                inputPath = iterator.next()
            case "--output":
                outputPath = iterator.next()
            case "--help", "-h":
                throw ImporterError.invalidArguments(usage)
            default:
                throw ImporterError.invalidArguments("未知参数：\(argument)\n\n\(usage)")
            }
        }

        guard let inputPath, let outputPath else {
            throw ImporterError.invalidArguments(usage)
        }

        return (URL(fileURLWithPath: inputPath), URL(fileURLWithPath: outputPath))
    }

    private static func loadQuestions(from url: URL) throws -> [ImportQuestion] {
        switch url.pathExtension.lowercased() {
        case "csv":
            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = try CSVParser.parse(content)
            return try normalizeCSVRows(rows)
        case "json":
            let data = try Data(contentsOf: url)
            return try loadQuestionsFromJSON(data)
        default:
            throw ImporterError.unsupportedInput("暂不支持 \(url.pathExtension) 格式，请使用 CSV 或 JSON。")
        }
    }

    private static func loadQuestionsFromJSON(_ data: Data) throws -> [ImportQuestion] {
        let decoder = JSONDecoder()

        if let normalized = try? decoder.decode([ImportQuestion].self, from: data) {
            return try validateAndSort(normalized)
        }

        if let wrapper = try? decoder.decode(ImportQuestionWrapper.self, from: data) {
            return try validateAndSort(wrapper.questions.map(normalize(record:)))
        }

        if let rawRecords = try? decoder.decode([ImportQuestionRecord].self, from: data) {
            return try validateAndSort(rawRecords.map(normalize(record:)))
        }

        throw ImporterError.malformedData("JSON 结构无法识别，请参考模板文件。")
    }

    private static func normalizeCSVRows(_ rows: [[String]]) throws -> [ImportQuestion] {
        guard let header = rows.first else {
            throw ImporterError.malformedData("CSV 为空。")
        }

        let normalizedHeader = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let records = try rows.dropFirst().enumerated().compactMap { index, row -> ImportQuestion? in
            guard row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                return nil
            }

            var values: [String: String] = [:]
            for (columnIndex, key) in normalizedHeader.enumerated() where columnIndex < row.count {
                values[key] = row[columnIndex]
            }

            return try normalize(csvValues: values, lineNumber: index + 2)
        }

        return try validateAndSort(records)
    }

    private static func normalize(csvValues: [String: String], lineNumber: Int) throws -> ImportQuestion {
        let record = ImportQuestionRecord(
            id: Int64(csvValues["id"] ?? ""),
            year: Int(csvValues["year"] ?? ""),
            stage: csvValues["stage"],
            type: csvValues["type"],
            category: csvValues["category"],
            knowledgePoints: nil,
            knowledge_points: csvValues["knowledge_points"],
            stem: csvValues["stem"],
            options: nil,
            options_json: csvValues["options_json"],
            option_a: csvValues["option_a"],
            option_b: csvValues["option_b"],
            option_c: csvValues["option_c"],
            option_d: csvValues["option_d"],
            option_e: csvValues["option_e"],
            option_f: csvValues["option_f"],
            correctAnswers: nil,
            correct_answers: csvValues["correct_answers"],
            analysis: csvValues["analysis"],
            score: Double(csvValues["score"] ?? ""),
            estimatedMinutes: nil,
            estimated_minutes: Int(csvValues["estimated_minutes"] ?? "")
        )

        do {
            return try normalize(record: record)
        } catch {
            throw ImporterError.malformedData("CSV 第 \(lineNumber) 行有误：\(error.localizedDescription)")
        }
    }

    private static func normalize(record: ImportQuestionRecord) throws -> ImportQuestion {
        guard let year = record.year else {
            throw ImporterError.malformedData("缺少 year。")
        }
        guard let type = normalizeType(record.type) else {
            throw ImporterError.malformedData("type 无法识别。")
        }
        let stage = sanitized(record.stage) ?? defaultStage(for: type)
        let category = sanitized(record.category) ?? "未分类"
        guard let stem = sanitized(record.stem) else {
            throw ImporterError.malformedData("缺少 stem。")
        }

        let options = try normalizeOptions(record: record, type: type)
        let correctAnswers = try normalizeAnswers(record: record, type: type)
        let score = record.score ?? defaultScore(for: type)
        let estimatedMinutes = record.estimatedMinutes ?? record.estimated_minutes ?? defaultEstimatedMinutes(for: type)
        let knowledgePoints = normalizeKnowledgePoints(record)
        let analysis = sanitized(record.analysis) ?? "待补充解析。"
        let id = record.id ?? generatedID(year: year, stage: stage, type: type, stem: stem)

        if type == .singleChoice && options.isEmpty {
            throw ImporterError.malformedData("选择题至少需要一个选项。")
        }

        if type == .singleChoice && correctAnswers.isEmpty {
            throw ImporterError.malformedData("选择题至少需要一个正确答案。")
        }

        return ImportQuestion(
            id: id,
            year: year,
            stage: stage,
            type: type,
            category: category,
            knowledgePoints: knowledgePoints,
            stem: stem,
            options: options,
            correctAnswers: correctAnswers,
            analysis: analysis,
            score: score,
            estimatedMinutes: estimatedMinutes
        )
    }

    private static func normalizeOptions(record: ImportQuestionRecord, type: ImportQuestionType) throws -> [ImportQuestionOption] {
        if let options = record.options, !options.isEmpty {
            return options.map { ImportQuestionOption(label: $0.label.uppercased(), content: $0.content) }
        }

        if let optionsJSON = sanitized(record.options_json) {
            guard let data = optionsJSON.data(using: .utf8),
                  let options = try? JSONDecoder().decode([ImportQuestionOption].self, from: data) else {
                throw ImporterError.malformedData("options_json 不是合法 JSON。")
            }
            return options.map { ImportQuestionOption(label: $0.label.uppercased(), content: $0.content) }
        }

        guard type == .singleChoice else { return [] }

        let optionPairs = [
            ("A", record.option_a),
            ("B", record.option_b),
            ("C", record.option_c),
            ("D", record.option_d),
            ("E", record.option_e),
            ("F", record.option_f)
        ]

        return optionPairs.compactMap { label, rawValue in
            guard let content = sanitized(rawValue) else { return nil }
            return ImportQuestionOption(label: label, content: content)
        }
    }

    private static func normalizeAnswers(record: ImportQuestionRecord, type: ImportQuestionType) throws -> [String] {
        if let correctAnswers = record.correctAnswers, !correctAnswers.isEmpty {
            return correctAnswers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }

        let rawAnswer = sanitized(record.correct_answers)

        switch type {
        case .singleChoice:
            return split(rawAnswer, separators: ["|", "、", ",", "，", "/"]).map { $0.uppercased() }
        case .caseStudy, .essay:
            guard let rawAnswer else { return [] }
            return [rawAnswer]
        }
    }

    private static func normalizeKnowledgePoints(_ record: ImportQuestionRecord) -> [String] {
        if let knowledgePoints = record.knowledgePoints, !knowledgePoints.isEmpty {
            return unique(knowledgePoints.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        }

        return unique(split(record.knowledge_points, separators: ["|", "、", ",", "，", "/", ";", "；"]))
    }

    private static func validateAndSort(_ questions: [ImportQuestion]) throws -> [ImportQuestion] {
        var seen = Set<Int64>()
        for question in questions {
            if seen.contains(question.id) {
                throw ImporterError.malformedData("发现重复题目 id：\(question.id)")
            }
            seen.insert(question.id)
        }

        return questions.sorted {
            if $0.year == $1.year {
                return $0.id < $1.id
            }
            return $0.year > $1.year
        }
    }

    private static func write(questions: [ImportQuestion], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(questions)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try data.write(to: url)
    }

    private static func normalizeType(_ value: String?) -> ImportQuestionType? {
        switch sanitized(value)?.lowercased() {
        case "singlechoice", "single_choice", "choice", "选择题":
            return .singleChoice
        case "casestudy", "case_study", "案例题", "案例分析":
            return .caseStudy
        case "essay", "论文题", "论文":
            return .essay
        default:
            return nil
        }
    }

    private static func defaultStage(for type: ImportQuestionType) -> String {
        switch type {
        case .singleChoice:
            return "上午真题"
        case .caseStudy:
            return "下午案例"
        case .essay:
            return "论文题"
        }
    }

    private static func defaultScore(for type: ImportQuestionType) -> Double {
        switch type {
        case .singleChoice:
            return 1
        case .caseStudy:
            return 25
        case .essay:
            return 75
        }
    }

    private static func defaultEstimatedMinutes(for type: ImportQuestionType) -> Int {
        switch type {
        case .singleChoice:
            return 2
        case .caseStudy:
            return 20
        case .essay:
            return 45
        }
    }

    private static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func split(_ value: String?, separators: [String]) -> [String] {
        guard let value = sanitized(value) else { return [] }
        var fragments = [value]

        for separator in separators {
            fragments = fragments.flatMap { $0.components(separatedBy: separator) }
        }

        return fragments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func unique(_ values: [String]) -> [String] {
        var result: [String] = []
        var seen = Set<String>()

        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }

        return result
    }

    private static func generatedID(year: Int, stage: String, type: ImportQuestionType, stem: String) -> Int64 {
        let base = "\(year)|\(stage)|\(type.rawValue)|\(stem)"
        let hash = FNV1a64.hash(base)
        return Int64(hash & 0x7FFF_FFFF_FFFF_FFFF)
    }
}

enum CSVParser {
    static func parse(_ string: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false
        let characters = Array(string)
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if insideQuotes {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        insideQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    insideQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n":
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                case "\r":
                    break
                default:
                    field.append(character)
                }
            }

            index += 1
        }

        if insideQuotes {
            throw ImporterError.malformedData("CSV 引号没有正确闭合。")
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }
}

enum FNV1a64 {
    static func hash(_ string: String) -> UInt64 {
        let offsetBasis: UInt64 = 14695981039346656037
        let prime: UInt64 = 1099511628211

        return string.utf8.reduce(offsetBasis) { partial, byte in
            (partial ^ UInt64(byte)) &* prime
        }
    }
}

do {
    try QuestionImporterCLI.run()
} catch {
    fputs("❌ \(error.localizedDescription)\n", stderr)
    exit(1)
}
