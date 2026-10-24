import Foundation
import SwiftData

enum CaseStage: String, CaseIterable, Codable {
    case open, sent, replied, escalated, solved
    var label: String {
        switch self {
        case .open: return "مفتوحة"
        case .sent: return "أرسلت للتاجر"
        case .replied: return "ردّ التاجر"
        case .escalated: return "بلاغ تجاري"
        case .solved: return "انحلّت"
        }
    }
    var icon: String {
        switch self {
        case .open: return "folder"
        case .sent: return "paperplane"
        case .replied: return "bubble.left.and.bubble.right"
        case .escalated: return "megaphone"
        case .solved: return "checkmark.seal"
        }
    }
}

@Model
final class CaseRecord {
    var id: UUID = UUID()
    var scenarioID: String = ""
    var title: String = ""
    var createdAt: Date = Date()
    var eventDate: Date?
    var used: Bool = false
    var defective: Bool = false
    var delayDays: Int = 0
    var storeName: String = ""
    var product: String = ""
    var invoiceDate: String = ""
    var invoiceTotal: String = ""
    var problem: String = ""
    var stageRaw: String = CaseStage.open.rawValue
    var checkedEvidence: [String] = []
    @Relationship(deleteRule: .cascade) var events: [CaseEvent] = []
    @Relationship(deleteRule: .cascade) var photos: [EvidencePhoto] = []

    init(scenarioID: String, title: String) {
        self.id = UUID()
        self.scenarioID = scenarioID
        self.title = title
        self.createdAt = Date()
    }

    var stage: CaseStage {
        get { CaseStage(rawValue: stageRaw) ?? .open }
        set { stageRaw = newValue.rawValue }
    }

    var input: CaseInput {
        CaseInput(scenarioID: scenarioID, eventDate: eventDate, used: used, defective: defective, delayDays: delayDays)
    }
}

@Model
final class CaseEvent {
    var date: Date = Date()
    var stageRaw: String = CaseStage.open.rawValue
    var note: String = ""
    init(stage: CaseStage, note: String = "") {
        self.date = Date()
        self.stageRaw = stage.rawValue
        self.note = note
    }
    var stage: CaseStage { CaseStage(rawValue: stageRaw) ?? .open }
}

@Model
final class EvidencePhoto {
    var createdAt: Date = Date()
    @Attribute(.externalStorage) var data: Data = Data()
    init(data: Data) {
        self.createdAt = Date()
        self.data = data
    }
}
