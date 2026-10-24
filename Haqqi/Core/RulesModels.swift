import Foundation

public struct RuleSource: Codable, Hashable, Identifiable {
    public let id: String
    public let law: String
    public let article: String?
    public let url: String
    public let confidence: String
    public let verified: Bool?
    public let checked: String?
    public let note: String?
    public var isVerified: Bool { verified ?? false }
}

public struct Scenario: Codable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let icon: String
    public let asks: [String]
    public let eventLabel: String
    public let deadline: String
    public let okTitle: String
    public let okText: String
    public let expiredTitle: String
    public let expiredText: String
    public let blockedTitle: String
    public let blockedText: String
    public let exceptions: String
    public let sources: [String]
    public let evidence: [String]
    public let letter: String
}

public struct RuleBook: Codable {
    public let lastChecked: String
    public let sources: [RuleSource]
    public let scenarios: [Scenario]
    public let evidence: [String: String]

    public static func load(from data: Data) throws -> RuleBook {
        return try JSONDecoder().decode(RuleBook.self, from: data)
    }

    public func source(_ id: String) -> RuleSource? {
        return sources.first { $0.id == id }
    }

    public func scenario(_ id: String) -> Scenario? {
        return scenarios.first { $0.id == id }
    }
}

public struct LearnCard: Codable, Hashable, Identifiable {
    public let id: Int
    public let title: String
    public let body: String
    public let icon: String
    public let url: String
}

public struct CardBook: Codable {
    public let cards: [LearnCard]
}
