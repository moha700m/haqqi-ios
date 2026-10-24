import SwiftUI
import SwiftData
import UIKit

struct ShareItem: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct CaseDetailView: View {
    @Bindable var record: CaseRecord
    @Environment(\.modelContext) private var context
    @State private var pickerSource: UIImagePickerController.SourceType?
    @State private var showPicker = false
    @State private var ocrRunning = false
    @State private var share: ShareItem?
    @State private var customerName = UserDefaults.standard.string(forKey: "customerName") ?? ""

    private var scenario: Scenario? { RuleStore.shared.book.scenario(record.scenarioID) }
    private var verdict: Verdict? { RuleStore.shared.engine.evaluate(record.input) }
    private var details: ClaimDetails {
        ClaimDetails(customerName: customerName, storeName: record.storeName, product: record.product,
                     invoiceDate: record.invoiceDate, invoiceTotal: record.invoiceTotal, problem: record.problem)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let v = verdict { VerdictCard(verdict: v) }
                timeline
                evidence
                detailsForm
                claimPack
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(record.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            CameraPicker(source: pickerSource ?? .photoLibrary) { img in addPhoto(img) }
                .ignoresSafeArea()
        }
        .sheet(item: $share) { s in ShareSheet(items: s.items) }
    }

    // MARK: Timeline
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("مسار القضية").font(.hHeadline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CaseStage.allCases, id: \.self) { st in
                        Button {
                            Haptics.tap()
                            record.stage = st
                            record.events.append(CaseEvent(stage: st))
                            try? context.save()
                        } label: {
                            Label(st.label, systemImage: st.icon)
                                .font(.hCaption)
                                .padding(.horizontal, 12).frame(minHeight: 44)
                                .background(Capsule().fill(record.stage == st ? Theme.navy : Theme.navy.opacity(0.1)))
                                .foregroundStyle(record.stage == st ? Color.white : Theme.navy)
                        }
                    }
                }
            }
            ForEach(record.events.sorted { $0.date > $1.date }) { e in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: e.stage.icon).foregroundStyle(Theme.navy).frame(width: 24)
                    VStack(alignment: .leading) {
                        Text(e.stage.label).font(.plex(16, .semibold))
                        Text(e.date.formatted(date: .abbreviated, time: .shortened)).font(.hCaption).foregroundStyle(.secondary)
                        if !e.note.isEmpty { Text(e.note).font(.hCaption) }
                    }
                }
            }
        }
        .card()
    }

    // MARK: Evidence
    private var evidence: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("قائمة الأدلة").font(.hHeadline)
            ForEach(scenario?.evidence ?? [], id: \.self) { key in
                let label = RuleStore.shared.book.evidence[key] ?? key
                let on = record.checkedEvidence.contains(key)
                Button {
                    Haptics.tap()
                    if on { record.checkedEvidence.removeAll { $0 == key } } else { record.checkedEvidence.append(key) }
                } label: {
                    HStack {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(on ? Theme.green : Color.secondary).font(.title3)
                        Text(label).font(.hBody).foregroundStyle(.primary)
                        Spacer()
                    }.frame(minHeight: 44)
                }
            }
            HStack(spacing: 12) {
                Button { pickerSource = .camera; showPicker = true } label: { Label("صوّر", systemImage: "camera.fill") }
                    .buttonStyle(PrimaryButtonStyle())
                Button { pickerSource = .photoLibrary; showPicker = true } label: { Label("من الصور", systemImage: "photo.on.rectangle") }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.navy.opacity(0.8)))
            }
            if ocrRunning { ProgressView("نقرأ الفاتورة…").font(.hCaption) }
            if !record.photos.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(record.photos) { p in
                            if let img = UIImage(data: p.data) {
                                Image(uiImage: img).resizable().scaledToFill()
                                    .frame(width: 90, height: 90).clipShape(RoundedRectangle(cornerRadius: 12))
                                    .contextMenu {
                                        Button("اقرأ كفاتورة") { runOCR(img) }
                                        Button("احذف", role: .destructive) {
                                            record.photos.removeAll { $0.id == p.id }
                                            context.delete(p)
                                        }
                                    }
                            }
                        }
                    }
                }
                Text("اضغط مطولاً على الصورة لقراءتها كفاتورة.").font(.hCaption).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func addPhoto(_ img: UIImage) {
        let data = img.jpegData(compressionQuality: 0.6) ?? Data()
        let p = EvidencePhoto(data: data)
        record.photos.append(p)
        try? context.save()
        if !record.checkedEvidence.contains("photos") { record.checkedEvidence.append("photos") }
        runOCR(img)
    }

    private func runOCR(_ img: UIImage) {
        ocrRunning = true
        OCRService.recognize(img) { r in
            ocrRunning = false
            if record.invoiceDate.isEmpty && !r.date.isEmpty { record.invoiceDate = r.date }
            if record.invoiceTotal.isEmpty && !r.total.isEmpty { record.invoiceTotal = r.total }
            if record.storeName.isEmpty && !r.store.isEmpty { record.storeName = r.store }
            if !r.date.isEmpty || !r.total.isEmpty { Haptics.success() }
        }
    }

    // MARK: Details
    private var detailsForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("بيانات الفاتورة (تقدر تعدّلها)").font(.hHeadline)
            field("اسمك", text: $customerName, icon: "person")
            field("اسم المتجر", text: $record.storeName, icon: "storefront")
            field("المنتج", text: $record.product, icon: "shippingbox")
            field("تاريخ الفاتورة", text: $record.invoiceDate, icon: "calendar")
            field("المبلغ (ريال)", text: $record.invoiceTotal, icon: "banknote")
            field("وش المشكلة باختصار", text: $record.problem, icon: "text.bubble")
        }
        .card()
        .onChange(of: customerName) { _, v in UserDefaults.standard.set(v, forKey: "customerName") }
    }

    private func field(_ title: String, text: Binding<String>, icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(Theme.navy).frame(width: 24)
            TextField(title, text: text).font(.hBody).frame(minHeight: 44)
        }
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .tertiarySystemFill)))
    }

    // MARK: Claim pack
    private var claimPack: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.richtext.fill").font(.title2).foregroundStyle(Theme.gold)
                Text("ملف المطالبة").font(.hHeadline)
            }
            if let sc = scenario, let v = verdict {
                let letter = ClaimBuilder.merchantLetter(scenario: sc, verdict: v, details: details)
                let balagh = ClaimBuilder.balaghText(scenario: sc, verdict: v, details: details)
                Text(letter).font(.hCaption).padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .tertiarySystemFill)))
                Button {
                    if let url = PDFMaker.make(title: "خطاب مطالبة", body: letter, fileName: "Haqqi-Letter.pdf") {
                        share = ShareItem(items: [url])
                    }
                    markSent()
                } label: { Label("شارك الخطاب PDF", systemImage: "square.and.arrow.up") }
                .buttonStyle(PrimaryButtonStyle())
                Button {
                    UIPasteboard.general.string = balagh
                    Haptics.success()
                    share = ShareItem(items: [balagh])
                } label: { Label("نص البلاغ التجاري", systemImage: "megaphone.fill") }
                .buttonStyle(PrimaryButtonStyle(color: Theme.orange))
                Text("انسخ النص والصقه في تطبيق «بلاغ تجاري» من وزارة التجارة.").font(.hCaption).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func markSent() {
        if record.stage == .open {
            record.stage = .sent
            record.events.append(CaseEvent(stage: .sent))
            try? context.save()
        }
    }
}
