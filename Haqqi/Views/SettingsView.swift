import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("faceIDEnabled") private var faceIDEnabled = false
    @AppStorage("onboarded") private var onboarded = true
    @Query private var cases: [CaseRecord]
    @Environment(\.modelContext) private var context
    @State private var share: ShareItem?
    @State private var importing = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        EmblemView(size: 56)
                        VStack(alignment: .leading) {
                            Text("حقّي").font(.hHeadline)
                            Text("يشتغل بدون إنترنت. بياناتك على جهازك فقط.").font(.hCaption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 6)
                }
                Section("الحماية") {
                    Toggle(isOn: $faceIDEnabled) { Label("قفل بـ Face ID", systemImage: "faceid").font(.hBody) }
                }
                Section("النسخة الاحتياطية") {
                    Button {
                        if let url = Backup.export(cases) { share = ShareItem(items: [url]) }
                    } label: { Label("صدّر نسخة (JSON)", systemImage: "square.and.arrow.up").font(.hBody) }
                    Button { importing = true } label: { Label("استرجع من نسخة", systemImage: "square.and.arrow.down").font(.hBody) }
                    if let m = message { Text(m).font(.hCaption).foregroundStyle(.secondary) }
                }
                Section("عن التطبيق") {
                    Button { onboarded = false } label: { Label("شوف الترحيب مرة ثانية", systemImage: "sparkles").font(.hBody) }
                    NavigationLink { SourcesView() } label: { Label("المصادر الرسمية", systemImage: "building.columns").font(.hBody) }
                    Label("آخر مراجعة للأنظمة: \(RuleStore.shared.book.lastChecked)", systemImage: "calendar.badge.checkmark").font(.hCaption)
                    Label(RulesEngine.disclaimer, systemImage: "exclamationmark.bubble").font(.hCaption).foregroundStyle(Theme.orange)
                    Label("الخط: IBM Plex Sans Arabic (OFL)", systemImage: "textformat").font(.hCaption)
                }
            }
            .navigationTitle("الإعدادات")
            .sheet(item: $share) { s in ShareSheet(items: s.items) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [UTType.json]) { result in
                if case .success(let url) = result { restore(url) }
            }
        }
    }

    private func restore(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let file = Backup.decode(data) else {
            message = "الملف غير صالح"; return
        }
        let existing = Set(cases.map { $0.id })
        var count = 0
        for b in file.cases where !existing.contains(b.id) {
            let r = CaseRecord(scenarioID: b.scenarioID, title: b.title)
            r.id = b.id; r.createdAt = b.createdAt; r.eventDate = b.eventDate
            r.used = b.used; r.defective = b.defective; r.delayDays = b.delayDays
            r.storeName = b.storeName; r.product = b.product; r.invoiceDate = b.invoiceDate
            r.invoiceTotal = b.invoiceTotal; r.problem = b.problem; r.stageRaw = b.stage
            r.checkedEvidence = b.checkedEvidence
            for e in b.events {
                let ev = CaseEvent(stage: CaseStage(rawValue: e.stage) ?? .open, note: e.note)
                ev.date = e.date
                r.events.append(ev)
            }
            for d in b.photos { r.photos.append(EvidencePhoto(data: d)) }
            context.insert(r)
            count += 1
        }
        try? context.save()
        message = "تم استرجاع \(count) قضية"
        Haptics.success()
    }
}
