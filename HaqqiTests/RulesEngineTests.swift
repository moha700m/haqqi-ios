import XCTest

final class RulesEngineTests: XCTestCase {
    var engine: RulesEngine!

    override func setUpWithError() throws {
        let bundle = Bundle(for: RulesEngineTests.self)
        let url = try XCTUnwrap(bundle.url(forResource: "rules", withExtension: "json"))
        let book = try RuleBook.load(from: Data(contentsOf: url))
        engine = RulesEngine(book: book)
    }

    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 12
        return engine.calendar.date(from: c)!
    }

    func testAllScenariosLoadAndHaveSources() {
        XCTAssertEqual(engine.book.scenarios.count, 8)
        for s in engine.book.scenarios {
            XCTAssertFalse(s.sources.isEmpty, s.id)
            for id in s.sources { XCTAssertNotNil(engine.book.source(id), id) }
        }
    }

    func testOnlineReturnWithinSevenDays() {
        let v = engine.evaluate(CaseInput(scenarioID: "online_return", eventDate: date(2026, 1, 1)), now: date(2026, 1, 5))!
        XCTAssertEqual(v.status, .eligible)
        XCTAssertEqual(v.daysLeft, 3)
        XCTAssertEqual(v.disclaimer, "إرشاد وليس استشارة قانونية")
    }

    func testOnlineReturnLastDayStillEligible() {
        let v = engine.evaluate(CaseInput(scenarioID: "online_return", eventDate: date(2026, 1, 1)), now: date(2026, 1, 8))!
        XCTAssertEqual(v.status, .eligible)
        XCTAssertEqual(v.daysLeft, 0)
    }

    func testOnlineReturnExpired() {
        let v = engine.evaluate(CaseInput(scenarioID: "online_return", eventDate: date(2026, 1, 1)), now: date(2026, 1, 20))!
        XCTAssertEqual(v.status, .expired)
    }

    func testOnlineReturnUsedBlocked() {
        let v = engine.evaluate(CaseInput(scenarioID: "online_return", eventDate: date(2026, 1, 1), used: true), now: date(2026, 1, 2))!
        XCTAssertEqual(v.status, .blocked)
    }

    func testLateDeliveryWaitingThenCancel() {
        let w = engine.evaluate(CaseInput(scenarioID: "late_delivery", eventDate: date(2026, 3, 1)), now: date(2026, 3, 10))!
        XCTAssertEqual(w.status, .waiting)
        let e = engine.evaluate(CaseInput(scenarioID: "late_delivery", eventDate: date(2026, 3, 1)), now: date(2026, 3, 20))!
        XCTAssertEqual(e.status, .expired)
    }

    func testWarrantyTwoYearsAndExtension() {
        let v = engine.evaluate(CaseInput(scenarioID: "device_fault", eventDate: date(2024, 6, 1), delayDays: 30), now: date(2026, 6, 15))!
        XCTAssertEqual(v.status, .eligible)
        let x = engine.evaluate(CaseInput(scenarioID: "device_fault", eventDate: date(2024, 6, 1)), now: date(2026, 6, 15))!
        XCTAssertEqual(x.status, .expired)
    }

    func testStoreRefusedDefective() {
        let d = engine.evaluate(CaseInput(scenarioID: "store_refused", defective: true))!
        XCTAssertEqual(d.status, .eligible)
        let n = engine.evaluate(CaseInput(scenarioID: "store_refused", defective: false))!
        XCTAssertEqual(n.status, .blocked)
    }

    func testNoArticleNumbersInvented() {
        for s in engine.book.sources where s.article != nil {
            XCTAssertTrue(s.id.hasPrefix("ecom"), "Only E-Commerce Law articles are verified: \(s.id)")
        }
    }

    func testClaimLetterContainsCitation() {
        let sc = engine.book.scenario("online_return")!
        let v = engine.evaluate(CaseInput(scenarioID: "online_return", eventDate: Date()))!
        let letter = ClaimBuilder.merchantLetter(scenario: sc, verdict: v, details: ClaimDetails(storeName: "متجر"))
        XCTAssertTrue(letter.contains("المادة الثالثة عشرة"))
        XCTAssertTrue(ClaimBuilder.balaghText(scenario: sc, verdict: v, details: ClaimDetails()).contains("نظام التجارة الإلكترونية"))
    }

    func testCardsLoad() throws {
        let url = try XCTUnwrap(Bundle(for: RulesEngineTests.self).url(forResource: "cards", withExtension: "json"))
        let cards = try JSONDecoder().decode(CardBook.self, from: Data(contentsOf: url))
        XCTAssertEqual(cards.cards.count, 20)
    }
}
