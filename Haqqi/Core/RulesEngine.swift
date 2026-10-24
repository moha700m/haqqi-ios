import Foundation

public struct CaseInput: Equatable {
    public var scenarioID: String
    public var eventDate: Date?
    public var used: Bool
    public var defective: Bool
    public var delayDays: Int

    public init(scenarioID: String, eventDate: Date? = nil, used: Bool = false, defective: Bool = false, delayDays: Int = 0) {
        self.scenarioID = scenarioID
        self.eventDate = eventDate
        self.used = used
        self.defective = defective
        self.delayDays = delayDays
    }
}

public enum VerdictStatus: String, Codable {
    case eligible
    case expired
    case blocked
    case waiting
}

public struct Verdict: Equatable {
    public let status: VerdictStatus
    public let title: String
    public let text: String
    public let exceptions: String
    public let deadline: Date?
    public let deadlineLabel: String?
    public let daysLeft: Int?
    public let totalDays: Int?
    public let sources: [RuleSource]
    public let evidence: [String]
    public let lastChecked: String
    public let disclaimer: String
}

public struct RulesEngine {
    public static let disclaimer = "إرشاد وليس استشارة قانونية"
    public let book: RuleBook
    public var calendar: Calendar

    public init(book: RuleBook) {
        self.book = book
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Riyadh") ?? TimeZone.current
        self.calendar = cal
    }

    /// Number of whole days between two dates (start of day based).
    public func daysBetween(_ a: Date, _ b: Date) -> Int {
        let s = calendar.startOfDay(for: a)
        let e = calendar.startOfDay(for: b)
        return calendar.dateComponents([.day], from: s, to: e).day ?? 0
    }

    public func deadline(for scenario: Scenario, input: CaseInput) -> (Date, String, Int)? {
        guard let start = input.eventDate else { return nil }
        switch scenario.deadline {
        case "days7":
            guard let d = calendar.date(byAdding: .day, value: 7, to: start) else { return nil }
            return (d, "آخر يوم للإرجاع", 7)
        case "delay15":
            guard let d = calendar.date(byAdding: .day, value: 15, to: start) else { return nil }
            return (d, "بعده تقدر تلغي وتسترد", 15)
        case "warranty2y":
            guard let base = calendar.date(byAdding: .year, value: 2, to: start) else { return nil }
            let extra = max(0, input.delayDays)
            guard let d = calendar.date(byAdding: .day, value: extra, to: base) else { return nil }
            return (d, "نهاية الضمان (مع التمديد)", daysBetween(start, d))
        default:
            return nil
        }
    }

    public func evaluate(_ input: CaseInput, now: Date = Date()) -> Verdict? {
        guard let sc = book.scenario(input.scenarioID) else { return nil }
        let srcs = sc.sources.compactMap { book.source($0) }
        let dl = deadline(for: sc, input: input)
        var status: VerdictStatus = .eligible
        var daysLeft: Int? = nil
        if let dl = dl {
            daysLeft = daysBetween(now, dl.0)
        }

        if sc.asks.contains("used") && input.used && !input.defective {
            status = .blocked
        } else if sc.asks.contains("defective") && !input.defective {
            status = .blocked
        } else if let left = daysLeft {
            if sc.deadline == "delay15" {
                status = left >= 0 ? .waiting : .expired
            } else if left < 0 {
                status = .expired
            }
        }

        var title = sc.okTitle
        var text = sc.okText
        switch status {
        case .expired:
            if !sc.expiredTitle.isEmpty { title = sc.expiredTitle; text = sc.expiredText }
        case .blocked:
            if !sc.blockedTitle.isEmpty { title = sc.blockedTitle; text = sc.blockedText }
        case .eligible, .waiting:
            break
        }

        return Verdict(status: status, title: title, text: text, exceptions: sc.exceptions,
                       deadline: dl?.0, deadlineLabel: dl?.1, daysLeft: daysLeft, totalDays: dl?.2,
                       sources: srcs, evidence: sc.evidence.map { book.evidence[$0] ?? $0 },
                       lastChecked: book.lastChecked, disclaimer: RulesEngine.disclaimer)
    }
}
