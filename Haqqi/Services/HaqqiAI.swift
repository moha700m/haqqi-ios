import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// "اسأل حقّي" brain: Apple on-device model when available, else local retrieval.
enum HaqqiAI {
    struct Status { let onDevice: Bool; let label: String }

    static let instructions = """
    أنت «حقّي»، مساعد سعودي يشرح حقوق المستهلك بلهجة سعودية بسيطة وجمل قصيرة.
    قواعد صارمة:
    ١) جاوب فقط من «القواعد المسترجعة» اللي تحت. لا تستخدم معلومات من عندك.
    ٢) لا تخترع أرقام مواد أو أنظمة أو مدد. اذكر رقم المادة فقط إذا كان مكتوب حرفياً في القواعد ومعلّم [متحقق منه].
    ٣) إذا القواعد ما تجاوب السؤال قل: «ما عندي معلومة موثقة عن هذا» وانصح بالتواصل مع وزارة التجارة 1900.
    ٤) اذكر اسم المصدر اللي اعتمدت عليه.
    ٥) لا تعطي رأي قانوني نهائي. خلك مختصر (أقل من ١٢٠ كلمة).
    """

    static var status: Status {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                let arabic = model.supportedLanguages.contains { $0.languageCode?.identifier == "ar" }
                return arabic ? Status(onDevice: true, label: "ذكاء Apple على جهازك")
                              : Status(onDevice: false, label: "ذكاء Apple ما يدعم العربي بعد، نجاوب من قواعدنا")
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible: return Status(onDevice: false, label: "جهازك ما يدعم ذكاء Apple، نجاوب من قواعدنا")
                case .appleIntelligenceNotEnabled: return Status(onDevice: false, label: "فعّل Apple Intelligence من الإعدادات، وحالياً نجاوب من قواعدنا")
                case .modelNotReady: return Status(onDevice: false, label: "النموذج يتحمّل، وحالياً نجاوب من قواعدنا")
                @unknown default: return Status(onDevice: false, label: "نجاوب من قواعدنا")
                }
            }
        }
        #endif
        return Status(onDevice: false, label: "يجاوب من قواعد حقّي بدون إنترنت")
    }

    /// Returns (answer, engineTag).
    static func ask(_ question: String, history: [(String, String)] = []) async -> (String, String) {
        let retriever = RuleRetriever(book: RuleStore.shared.book)
        let rules = retriever.retrieve(question)
        let local = LocalAnswerer.answer(question, retriever: retriever)
        guard !rules.isEmpty else { return (local.text, "local") }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), status.onDevice {
            do {
                let session = LanguageModelSession(instructions: instructions)
                let ctx = retriever.context(for: rules)
                let prompt = "القواعد المسترجعة:\n\(ctx)\n\nسؤال المستخدم: \(question)\n\nجاوب بالسعودي البسيط من القواعد فقط."
                let response = try await session.respond(to: prompt)
                var text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                // Guardrail: an article mention that isn't in the grounded context -> use the local answer.
                if text.isEmpty || (text.contains("المادة") && !articleMentionsGrounded(text, context: ctx)) {
                    return (local.text, "local")
                }
                let cites = rules.first!.sources.map { "• " + $0.law + ($0.isVerified ? "" : " (غير متحقق منه)") }
                text += "\n\nالمصدر:\n" + cites.joined(separator: "\n") + "\n\n" + RulesEngine.disclaimer
                return (text, "ai")
            } catch {
                return (local.text, "local")
            }
        }
        #endif
        return (local.text, "local")
    }

    static func articleMentionsGrounded(_ text: String, context: String) -> Bool {
        let ns = text as NSString
        guard let re = try? NSRegularExpression(pattern: "المادة\\s+\\S+(\\s+\\S+)?") else { return false }
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let phrase = ns.substring(with: m.range)
            let words = phrase.split(separator: " ")
            let two = words.prefix(2).joined(separator: " ")
            if !context.contains(two) { return false }
        }
        return true
    }
}
