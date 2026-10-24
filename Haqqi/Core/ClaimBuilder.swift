import Foundation

public struct ClaimDetails {
    public var customerName: String
    public var storeName: String
    public var product: String
    public var invoiceDate: String
    public var invoiceTotal: String
    public var problem: String
    public init(customerName: String = "", storeName: String = "", product: String = "", invoiceDate: String = "", invoiceTotal: String = "", problem: String = "") {
        self.customerName = customerName; self.storeName = storeName; self.product = product
        self.invoiceDate = invoiceDate; self.invoiceTotal = invoiceTotal; self.problem = problem
    }
}

public enum ClaimBuilder {
    static func citeLine(_ s: RuleSource) -> String {
        if let a = s.article { return "\(s.law) - \(a)" }
        return s.law
    }

    public static func merchantLetter(scenario: Scenario, verdict: Verdict, details: ClaimDetails) -> String {
        let cites = verdict.sources.map { "• " + citeLine($0) + "\n  " + $0.url }.joined(separator: "\n")
        let store = details.storeName.isEmpty ? "إدارة المتجر" : details.storeName
        return """
        السادة / \(store)            المحترمين
        السلام عليكم ورحمة الله وبركاته،

        الموضوع: \(scenario.title)

        اشتريت منكم \(details.product.isEmpty ? "منتجاً" : details.product) بتاريخ \(details.invoiceDate.isEmpty ? "—" : details.invoiceDate) بمبلغ \(details.invoiceTotal.isEmpty ? "—" : details.invoiceTotal) ريال.
        المشكلة: \(details.problem.isEmpty ? scenario.title : details.problem)

        وأستند في طلبي إلى ما يلي:
        \(cites)

        \(verdict.text)

        أرجو معالجة الطلب خلال مدة معقولة، وإلا سأضطر لتقديم بلاغ لوزارة التجارة عبر تطبيق «بلاغ تجاري».

        مقدّمه: \(details.customerName.isEmpty ? "—" : details.customerName)
        """
    }

    public static func balaghText(scenario: Scenario, verdict: Verdict, details: ClaimDetails) -> String {
        let cites = verdict.sources.map { citeLine($0) }.joined(separator: "، ")
        return "اشتريت \(details.product.isEmpty ? "منتجاً" : details.product) من \(details.storeName.isEmpty ? "المتجر" : details.storeName) بتاريخ \(details.invoiceDate.isEmpty ? "—" : details.invoiceDate) بمبلغ \(details.invoiceTotal.isEmpty ? "—" : details.invoiceTotal) ريال. المشكلة: \(details.problem.isEmpty ? scenario.title : details.problem). تواصلت مع المتجر ولم تُحل المشكلة. أطلب تطبيق: \(cites). مرفق الفاتورة والصور."
    }
}
