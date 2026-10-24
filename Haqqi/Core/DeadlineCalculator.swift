import Foundation

public struct DeadlineItem: Equatable, Identifiable {
    public var id: String { key }
    public let key: String
    public let title: String
    public let date: Date
    public let daysLeft: Int
    public let sourceID: String
}

/// "احسب مهلتي": from purchase / delivery dates compute every relevant deadline.
public struct DeadlineCalculator {
    public let engine: RulesEngine
    public init(engine: RulesEngine) { self.engine = engine }

    public func compute(purchase: Date, delivery: Date?, online: Bool, electronic: Bool, now: Date = Date()) -> [DeadlineItem] {
        let cal = engine.calendar
        var items: [DeadlineItem] = []
        func add(_ key: String, _ title: String, _ d: Date?, _ src: String) {
            guard let d else { return }
            items.append(DeadlineItem(key: key, title: title, date: d, daysLeft: engine.daysBetween(now, d), sourceID: src))
        }
        if online {
            if let del = delivery {
                add("return7", "آخر يوم ترجّع بدون سبب (٧ أيام من الاستلام)", cal.date(byAdding: .day, value: 7, to: del), "ecom13")
            } else {
                add("cancel15", "من بعده تقدر تلغي وتسترد إذا ما وصل (١٥ يوم)", cal.date(byAdding: .day, value: 15, to: purchase), "ecom14")
            }
        }
        if electronic {
            add("warranty", "نهاية ضمان السنتين", cal.date(byAdding: .year, value: 2, to: purchase), "warranty")
        }
        return items.sorted { $0.date < $1.date }
    }
}
