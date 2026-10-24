import Foundation
import SwiftUI
import UIKit
import Vision
import LocalAuthentication
import UserNotifications

final class RuleStore {
    static let shared = RuleStore()
    let book: RuleBook
    let cards: [LearnCard]
    let engine: RulesEngine

    private init() {
        var loaded: RuleBook? = nil
        if let url = Bundle.main.url(forResource: "rules", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            loaded = try? RuleBook.load(from: data)
        }
        let b = loaded ?? RuleBook(lastChecked: "", sources: [], scenarios: [], evidence: [:])
        book = b
        engine = RulesEngine(book: b)
        if let url = Bundle.main.url(forResource: "cards", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let c = try? JSONDecoder().decode(CardBook.self, from: data) {
            cards = c.cards
        } else {
            cards = []
        }
    }
}

struct OCRResult {
    var date: String = ""
    var total: String = ""
    var store: String = ""
    var raw: String = ""
}

enum OCRService {
    static func recognize(_ image: UIImage, completion: @escaping (OCRResult) -> Void) {
        guard let cg = image.cgImage else { completion(OCRResult()); return }
        let request = VNRecognizeTextRequest { req, _ in
            let lines = (req.results as? [VNRecognizedTextObservation])?.compactMap { $0.topCandidates(1).first?.string } ?? []
            let result = parse(lines)
            DispatchQueue.main.async { completion(result) }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ar-SA", "en-US"]
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do { try handler.perform([request]) } catch {
                DispatchQueue.main.async { completion(OCRResult()) }
            }
        }
    }

    static func normalizeDigits(_ s: String) -> String {
        let map: [Character: Character] = ["٠":"0","١":"1","٢":"2","٣":"3","٤":"4","٥":"5","٦":"6","٧":"7","٨":"8","٩":"9"]
        return String(s.map { map[$0] ?? $0 })
    }

    static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let r = m.numberOfRanges > 1 ? m.range(at: 1) : m.range
        return ns.substring(with: r)
    }

    static func parse(_ lines: [String]) -> OCRResult {
        var r = OCRResult()
        let norm = lines.map { normalizeDigits($0) }
        r.raw = norm.joined(separator: "\n")
        r.store = norm.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
        r.date = firstMatch("(\\d{4}[-/.]\\d{1,2}[-/.]\\d{1,2}|\\d{1,2}[-/.]\\d{1,2}[-/.]\\d{2,4})", in: r.raw) ?? ""
        for line in norm {
            let low = line.lowercased()
            if low.contains("total") || line.contains("الإجمالي") || line.contains("المجموع") || line.contains("الاجمالي") {
                if let n = firstMatch("(\\d+[.,]?\\d*)", in: line) { r.total = n }
            }
        }
        return r
    }
}

enum Biometrics {
    static func authenticate(completion: @escaping (Bool) -> Void) {
        let ctx = LAContext()
        var err: NSError?
        let policy: LAPolicy = .deviceOwnerAuthentication
        guard ctx.canEvaluatePolicy(policy, error: &err) else { completion(true); return }
        ctx.evaluatePolicy(policy, localizedReason: "افتح «حقّي» لحماية قضاياك") { ok, _ in
            DispatchQueue.main.async { completion(ok) }
        }
    }
}

enum Notifier {
    static func requestAndSchedule(id: String, title: String, deadline: Date) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            center.removePendingNotificationRequests(withIdentifiers: [id + "-1", id + "-0"])
            for (suffix, daysBefore) in [("-1", 1), ("-0", 0)] {
                guard let fire = Calendar.current.date(byAdding: .day, value: -daysBefore, to: deadline),
                      fire > Date() else { continue }
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: fire)
                comps.hour = 10
                let content = UNMutableNotificationContent()
                content.title = "حقّي"
                content.body = daysBefore == 0 ? "اليوم آخر يوم: \(title)" : "باقي يوم واحد: \(title)"
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(identifier: id + suffix, content: content, trigger: trigger))
            }
        }
    }
}

enum PDFMaker {
    static let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)

    static func attributed(_ sections: [(String, String)]) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.alignment = .right; para.baseWritingDirection = .rightToLeft; para.lineSpacing = 6
        let h = UIFont(name: "IBMPlexSansArabic-Bold", size: 17) ?? .boldSystemFont(ofSize: 17)
        let b = UIFont(name: "IBMPlexSansArabic-Regular", size: 12) ?? .systemFont(ofSize: 12)
        let out = NSMutableAttributedString()
        for (title, body) in sections {
            out.append(NSAttributedString(string: title + "\n", attributes: [.font: h, .paragraphStyle: para, .foregroundColor: UIColor(red: 0.086, green: 0.204, blue: 0.471, alpha: 1)]))
            out.append(NSAttributedString(string: body + "\n\n", attributes: [.font: b, .paragraphStyle: para, .foregroundColor: UIColor.black]))
        }
        return out
    }

    static func drawText(_ text: NSAttributedString, in ctx: UIGraphicsPDFRendererContext) {
        let framesetter = CTFramesetterCreateWithAttributedString(text as CFAttributedString)
        var start = 0
        repeat {
            ctx.beginPage()
            let cg = ctx.cgContext
            cg.saveGState()
            cg.textMatrix = .identity
            cg.translateBy(x: 0, y: pageRect.height); cg.scaleBy(x: 1, y: -1)
            let path = CGPath(rect: pageRect.insetBy(dx: 40, dy: 50), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: start, length: 0), path, nil)
            CTFrameDraw(frame, cg)
            let visible = CTFrameGetVisibleStringRange(frame)
            start += visible.length
            cg.restoreGState()
            if visible.length == 0 { break }
        } while start < text.length
    }

    /// One PDF: summary + timeline + letter + balagh text + every evidence photo on its own page.
    static func caseFile(title: String, summary: String, timeline: String, letter: String, balagh: String, photos: [UIImage]) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Haqqi-Case-File.pdf")
        let text = attributed([(title, "تاريخ التصدير: " + Date().formatted(date: .long, time: .shortened)),
                               ("الخلاصة", summary), ("المسار الزمني", timeline.isEmpty ? "-" : timeline),
                               ("خطاب المطالبة", letter), ("نص البلاغ التجاري", balagh),
                               ("الأدلة", photos.isEmpty ? "ما فيه صور مرفقة." : "\(photos.count) صورة في الصفحات التالية."),
                               ("تنبيه", RulesEngine.disclaimer)])
        do {
            try UIGraphicsPDFRenderer(bounds: pageRect).writePDF(to: url) { ctx in
                drawText(text, in: ctx)
                for (i, img) in photos.enumerated() {
                    ctx.beginPage()
                    let cap = NSAttributedString(string: "دليل \(i + 1)", attributes: [.font: UIFont(name: "IBMPlexSansArabic-SemiBold", size: 14) ?? .systemFont(ofSize: 14)])
                    cap.draw(at: CGPoint(x: pageRect.width - 40 - cap.size().width, y: 30))
                    let box = pageRect.insetBy(dx: 40, dy: 70)
                    let s = min(box.width / img.size.width, box.height / img.size.height)
                    let size = CGSize(width: img.size.width * s, height: img.size.height * s)
                    img.draw(in: CGRect(x: box.midX - size.width / 2, y: box.midY - size.height / 2, width: size.width, height: size.height))
                }
            }
            return url
        } catch { return nil }
    }

    static func make(title: String, body: String, fileName: String) -> URL? {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let para = NSMutableParagraphStyle()
        para.alignment = .right
        para.baseWritingDirection = .rightToLeft
        para.lineSpacing = 6
        let titleFont = UIFont(name: "IBMPlexSansArabic-Bold", size: 20) ?? UIFont.boldSystemFont(ofSize: 20)
        let bodyFont = UIFont(name: "IBMPlexSansArabic-Regular", size: 13) ?? UIFont.systemFont(ofSize: 13)
        let full = NSMutableAttributedString(string: title + "\n\n", attributes: [.font: titleFont, .paragraphStyle: para])
        full.append(NSAttributedString(string: body + "\n\n" + RulesEngine.disclaimer, attributes: [.font: bodyFont, .paragraphStyle: para]))
        do {
            try renderer.writePDF(to: url) { ctx in
                let framesetter = CTFramesetterCreateWithAttributedString(full as CFAttributedString)
                var start = 0
                let total = full.length
                repeat {
                    ctx.beginPage()
                    let cg = ctx.cgContext
                    cg.saveGState()
                    cg.textMatrix = .identity
                    cg.translateBy(x: 0, y: page.height)
                    cg.scaleBy(x: 1, y: -1)
                    let path = CGPath(rect: page.insetBy(dx: 40, dy: 50), transform: nil)
                    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: start, length: 0), path, nil)
                    CTFrameDraw(frame, cg)
                    let visible = CTFrameGetVisibleStringRange(frame)
                    start += visible.length
                    cg.restoreGState()
                    if visible.length == 0 { break }
                } while start < total
            }
            return url
        } catch {
            return nil
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct CameraPicker: UIViewControllerRepresentable {
    var source: UIImagePickerController.SourceType
    var onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(source) ? source : .photoLibrary
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onPick(img) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

struct BackupCase: Codable {
    var id: UUID
    var scenarioID: String
    var title: String
    var createdAt: Date
    var eventDate: Date?
    var used: Bool
    var defective: Bool
    var delayDays: Int
    var storeName: String
    var product: String
    var invoiceDate: String
    var invoiceTotal: String
    var problem: String
    var stage: String
    var checkedEvidence: [String]
    var events: [BackupEvent]
    var photos: [Data]
}
struct BackupEvent: Codable { var date: Date; var stage: String; var note: String }
struct BackupFile: Codable { var version: Int; var exportedAt: Date; var cases: [BackupCase] }

enum Backup {
    static func export(_ cases: [CaseRecord]) -> URL? {
        let items = cases.map { c in
            BackupCase(id: c.id, scenarioID: c.scenarioID, title: c.title, createdAt: c.createdAt, eventDate: c.eventDate,
                       used: c.used, defective: c.defective, delayDays: c.delayDays, storeName: c.storeName, product: c.product,
                       invoiceDate: c.invoiceDate, invoiceTotal: c.invoiceTotal, problem: c.problem, stage: c.stageRaw,
                       checkedEvidence: c.checkedEvidence,
                       events: c.events.map { BackupEvent(date: $0.date, stage: $0.stageRaw, note: $0.note) },
                       photos: c.photos.map { $0.data })
        }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted]
        guard let data = try? enc.encode(BackupFile(version: 1, exportedAt: Date(), cases: items)) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Haqqi-Backup.json")
        do { try data.write(to: url); return url } catch { return nil }
    }

    static func decode(_ data: Data) -> BackupFile? {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(BackupFile.self, from: data)
    }
}
