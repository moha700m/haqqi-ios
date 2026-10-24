import XCTest

final class RetrievalTests: XCTestCase {
    var retriever: RuleRetriever!
    var engine: RulesEngine!

    override func setUpWithError() throws {
        let url = try XCTUnwrap(Bundle(for: RetrievalTests.self).url(forResource: "rules", withExtension: "json"))
        let book = try RuleBook.load(from: Data(contentsOf: url))
        retriever = RuleRetriever(book: book)
        engine = RulesEngine(book: book)
    }

    func top(_ q: String) -> String? { retriever.retrieve(q).first?.scenario.id }

    func testNormalization() {
        XCTAssertEqual(ArabicText.normalize("إرْجَاعُ"), "ارجاع")
        XCTAssertEqual(ArabicText.normalize("فاتورة مستشفى"), "فاتوره مستشفي")
        XCTAssertEqual(ArabicText.normalize("١٥ يوم"), "15 يوم")
        XCTAssertEqual(ArabicText.normalize("أأ ـــ آ"), "اا ا")
    }

    func testSynonyms() {
        XCTAssertTrue(ArabicText.concepts(in: "أبي أرجّع الجوال").contains("ارجاع"))
        XCTAssertTrue(ArabicText.concepts(in: "استرجاع المبلغ").contains("ارجاع"))
        XCTAssertTrue(ArabicText.concepts(in: "الشاشة خربانة").contains("عيب"))
        XCTAssertTrue(ArabicText.concepts(in: "الجهاز مكسور").contains("عيب"))
        XCTAssertTrue(ArabicText.concepts(in: "الطلب ما وصل").contains("تاخير"))
        XCTAssertTrue(ArabicText.concepts(in: "الشحنة متأخرة").contains("تاخير"))
    }

    func testRetrievalTopMatches() {
        XCTAssertEqual(top("أبغى أرجع شي طلبته أونلاين"), "online_return")
        XCTAssertEqual(top("طلبي متأخر وما وصل من أسبوعين"), "late_delivery")
        XCTAssertEqual(top("المحل يبي يعطيني قسيمة بدل فلوسي"), "store_credit")
        XCTAssertEqual(top("مكتوب على الفاتورة البضاعة لا ترد ولا تستبدل"), "no_return_sign")
        XCTAssertEqual(top("الصيانة متأخرة وقطع الغيار ما جت"), "spare_delay")
        XCTAssertEqual(top("نفس العطل تكرر ثالث مرة"), "repeat_fault")
        XCTAssertEqual(top("وصلني لون ثاني غير اللي طلبته"), "wrong_item")
        let d = top("جهازي خربان وعليه ضمان؟")
        XCTAssertEqual(d, "device_fault")
    }

    func testNoMatchGivesHonestFallback() {
        XCTAssertTrue(retriever.retrieve("كم سعر الذهب اليوم").isEmpty)
        let a = LocalAnswerer.answer("كم سعر الذهب اليوم", retriever: retriever)
        XCTAssertTrue(a.text.contains("ما لقيت"))
        XCTAssertTrue(a.text.contains(RulesEngine.disclaimer))
    }

    func testAnswerCitesSourcesAndDisclaimer() {
        let a = LocalAnswerer.answer("ابي ارجع طلب اونلاين", retriever: retriever)
        XCTAssertTrue(a.text.contains("المادة الثالثة عشرة"))
        XCTAssertTrue(a.text.contains(RulesEngine.disclaimer))
        let c = LocalAnswerer.answer("قسيمة بدل الفلوس", retriever: retriever)
        XCTAssertTrue(c.text.contains("غير متحقق"))
    }

    func testContextOnlyHasVerifiedArticles() {
        let ctx = retriever.context(for: retriever.retrieve("قسيمة بدل فلوسي", limit: 1))
        XCTAssertFalse(ctx.contains("المادة"))
        XCTAssertTrue(ctx.contains("غير متحقق منه"))
    }

    func testDeadlineCalculator() {
        var c = DateComponents(); c.year = 2026; c.month = 1; c.day = 1; c.hour = 12
        let p = engine.calendar.date(from: c)!
        let del = engine.calendar.date(byAdding: .day, value: 3, to: p)!
        let items = DeadlineCalculator(engine: engine).compute(purchase: p, delivery: del, online: true, electronic: true, now: p)
        XCTAssertEqual(items.map { $0.key }, ["return7", "warranty"])
        XCTAssertEqual(items[0].daysLeft, 10)
        let notDelivered = DeadlineCalculator(engine: engine).compute(purchase: p, delivery: nil, online: true, electronic: false, now: p)
        XCTAssertEqual(notDelivered.first?.key, "cancel15")
        XCTAssertEqual(notDelivered.first?.daysLeft, 15)
    }
}
