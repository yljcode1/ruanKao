import Foundation

enum AppConfiguration {
    private static let aiServiceEndpointKey = "ai_service_endpoint"
    private static let aiServiceTokenKey = "ai_service_token"
    private static let aiServiceModelKey = "ai_service_model"
    private static let keychain = KeychainStore(
        service: Bundle.main.bundleIdentifier ?? "com.codexdemo.ruankao"
    )

    static var aiServiceEndpointString: String {
        if let customValue = sanitized(UserDefaults.standard.string(forKey: aiServiceEndpointKey)) {
            return customValue
        }
        return sanitized(Bundle.main.object(forInfoDictionaryKey: "AIServiceEndpoint") as? String) ?? ""
    }

    static var aiServiceEndpoint: URL? {
        guard let string = sanitized(aiServiceEndpointString) else { return nil }
        return URL(string: string)
    }

    static var aiServiceToken: String? {
        if let customValue = sanitized(try? keychain.string(forKey: aiServiceTokenKey)) {
            return customValue
        }
        return sanitized(Bundle.main.object(forInfoDictionaryKey: "AIServiceToken") as? String)
    }

    static var aiServiceModel: String? {
        if let customValue = sanitized(UserDefaults.standard.string(forKey: aiServiceModelKey)) {
            return customValue
        }
        return sanitized(Bundle.main.object(forInfoDictionaryKey: "AIServiceModel") as? String)
    }

    static var isRemoteAIEnabled: Bool {
        aiServiceEndpoint != nil
    }

    static func saveAIService(endpoint: String, token: String, model: String) throws {
        let sanitizedEndpoint = sanitized(endpoint)
        let sanitizedToken = sanitized(token)
        let sanitizedModel = sanitized(model)

        if let sanitizedEndpoint {
            UserDefaults.standard.set(sanitizedEndpoint, forKey: aiServiceEndpointKey)
        } else {
            UserDefaults.standard.removeObject(forKey: aiServiceEndpointKey)
        }

        if let sanitizedToken {
            try keychain.set(sanitizedToken, forKey: aiServiceTokenKey)
        } else {
            try keychain.removeValue(forKey: aiServiceTokenKey)
        }

        if let sanitizedModel {
            UserDefaults.standard.set(sanitizedModel, forKey: aiServiceModelKey)
        } else {
            UserDefaults.standard.removeObject(forKey: aiServiceModelKey)
        }
    }

    static func resetAIServiceOverrides() throws {
        UserDefaults.standard.removeObject(forKey: aiServiceEndpointKey)
        UserDefaults.standard.removeObject(forKey: aiServiceModelKey)
        try keychain.removeValue(forKey: aiServiceTokenKey)
    }

    static func maskedTokenDescription(for token: String?) -> String {
        guard let token = sanitized(token) else {
            return "未设置"
        }

        let suffix = String(token.suffix(min(4, token.count)))
        return "已设置 ••••\(suffix)"
    }

    private static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
