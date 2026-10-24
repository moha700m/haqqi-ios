import Foundation

public struct RetrievedRule: Equatable {
    public let scenario: Scenario
    public let score: Double
    public let sources: [RuleSource]
}

/// Lightweight keyword retriever over bundled rules. Deterministic and unit-tested.
public struct RuleRetriever {
    public let book: RuleBook
    /// Hand-tuned concept tags per scenario (the "index").
    static let tags: [String: [String: Double]] = [
        "online_return": ["ارجاع": 3, "اونلاين": 2, "استخدام": 1, "استبدال": 1],
        "late_delivery": ["تاخير": 4, "اونلاين": 1, "ارجاع": 0.5],
        "device_fault": ["عيب": 3, "ضمان": 3],
        "spare_delay": ["قطع": 4, "تاخير": 1.5, "ضمان": 1],
        "store_refused": ["محل": 3, "ارجاع": 1.5, "استبدال": 1.5, "عيب": 1, "سياسه": 2],
        "wrong_item": ["غلط": 4, "استبدال": 1, "اونلاين": 0.5],
        "no_return_sign": ["لا ترد": 5, "سياسه": 1],
        "store_credit": ["قسيمه": 5, "ارجاع": 0.5],
        "repeat_fault": ["تكرر": 5, "عيب": 1, "ضمان": 1],
    ]

    public init(book: RuleBook) { self.book = book }

    public func retrieve(_ query: String, limit: Int = 3) -> [RetrievedRule] {
        let concepts = ArabicText.concepts(in: query)
        let qTokens = ArabicText.tokens(query)
        var results: [RetrievedRule] = []
        for sc in book.scenarios {
            var score = 0.0
            for (c, w) in RuleRetriever.tags[sc.id] ?? [:] where concepts.contains(c) { score += w }
            let docTokens = ArabicText.tokens(sc.title + " " + sc.okText)
            score += Double(qTokens.intersection(docTokens).count) * 0.4
            if score > 0.9 {
                results.append(RetrievedRule(scenario: sc, score: score, sources: sc.sources.compactMap { book.source($0) }))
            }
        }
        return Array(results.sorted { $0.score == $1.score ? $0.scenario.id < $1.scenario.id : $0.score > $1.score }.prefix(limit))
    }

    /// Text block given to the on-device model as grounding context.
    public func context(for rules: [RetrievedRule]) -> String {
        rules.enumerated().map { i, r in
            let src = r.sources.map { s in
                var line = "- " + s.law
                if s.isVerified, let a = s.article { line += " (" + a + ")" }
                line += s.isVerified ? " [متحقق منه]" : " [غير متحقق منه]"
                return line + " " + s.url
            }.joined(separator: "\n")
            return "قاعدة \(i + 1): \(r.scenario.title)\n\(r.scenario.okText)\nاستثناءات: \(r.scenario.exceptions)\nالمصادر:\n\(src)"
        }.joined(separator: "\n\n")
    }
}

/// Offline answer composer (fallback when Apple Intelligence is not available).
public enum LocalAnswerer {
    public static let notFound = "ما لقيت قاعدة عندي تنطبق على سؤالك بالضبط. جرّب تكتبه بكلمات ثانية (مثلاً: «أبغى أرجع جوال طلبته أونلاين»)، أو اتصل بوزارة التجارة على 1900."
    public static let suggestions = [
        "أبغى أرجع شي طلبته أونلاين",
        "طلبي متأخر وما وصل",
        "جهازي خربان وعليه ضمان؟",
        "المحل يبي يعطيني قسيمة بدل فلوسي",
        "مكتوب لا ترد ولا تستبدل",
        "الصيانة متأخرة في قطع الغيار",
    ]

    public static func answer(_ query: String, retriever: RuleRetriever) -> (text: String, rules: [RetrievedRule]) {
        let rules = retriever.retrieve(query)
        guard let top = rules.first else { return (notFound + "\n\n" + RulesEngine.disclaimer, []) }
        var parts: [String] = []
        parts.append("«\(top.scenario.okTitle)»")
        parts.append(top.scenario.okText)
        if !top.scenario.exceptions.isEmpty { parts.append("انتبه: " + top.scenario.exceptions) }
        let cites = top.sources.map { s -> String in
            var t = "• " + s.law
            if s.isVerified, let a = s.article { t += " - " + a }
            if !s.isVerified { t += " (غير متحقق منه)" }
            return t
        }
        parts.append("المصدر:\n" + cites.joined(separator: "\n"))
        if rules.count > 1 {
            parts.append("ممكن يهمك بعد: " + rules.dropFirst().map { $0.scenario.title }.joined(separator: "، "))
        }
        parts.append(RulesEngine.disclaimer)
        return (parts.joined(separator: "\n\n"), rules)
    }
}
