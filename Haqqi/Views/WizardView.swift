import SwiftUI
import SwiftData

struct WizardView: View {
    let scenario: Scenario
    var autoVerdict: Bool = false
    @State private var share: ShareItem?
    @Environment(\.modelContext) private var context
    @State private var eventDate = Date()
    @State private var used = false
    @State private var defective = true
    @State private var delayDays = 0
    @State private var showVerdict = false
    @State private var savedCase: CaseRecord?

    private var engine: RulesEngine { RuleStore.shared.engine }
    private var input: CaseInput {
        CaseInput(scenarioID: scenario.id, eventDate: scenario.asks.contains("eventDate") ? eventDate : nil,
                  used: used, defective: defective, delayDays: delayDays)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Spacer()
                    SpotIllustration(symbol: scenario.icon, size: 150)
                    Spacer()
                }
                Text(scenario.title).font(.hTitle)

                if scenario.asks.contains("eventDate") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(scenario.eventLabel, systemImage: "calendar").font(.hHeadline)
                        DatePicker("", selection: $eventDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact).labelsHidden()
                    }.card()
                }
                if scenario.asks.contains("used") {
                    Toggle(isOn: $used) { Label("استخدمت المنتج؟", systemImage: "hand.tap").font(.hHeadline) }
                        .card()
                }
                if scenario.asks.contains("defective") {
                    Toggle(isOn: $defective) { Label("المنتج فيه عيب أو خراب؟", systemImage: "exclamationmark.triangle").font(.hHeadline) }
                        .card()
                }
                if scenario.asks.contains("delayDays") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("كم يوم تأخرت الصيانة أو القطع؟", systemImage: "hourglass").font(.hHeadline)
                        Stepper(value: $delayDays, in: 0...365) { Text("\(delayDays) يوم").font(.hBody) }
                    }.card()
                }

                Button {
                    Haptics.success()
                    withAnimation(.spring()) { showVerdict = true }
                } label: { Label("وش حقّي؟", systemImage: "scalemass.fill") }
                .buttonStyle(PrimaryButtonStyle())

                if showVerdict, let v = engine.evaluate(input) {
                    VerdictCard(verdict: v)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    Button { shareVerdict(v) } label: { Label("شارك النتيجة (صورة ونص)", systemImage: "square.and.arrow.up") }
                        .buttonStyle(PrimaryButtonStyle(color: Theme.gold.opacity(0.95)))
                    if let saved = savedCase {
                        NavigationLink { CaseDetailView(record: saved) } label: {
                            Label("افتح القضية", systemImage: "folder.fill")
                        }.buttonStyle(PrimaryButtonStyle(color: Theme.green))
                    } else {
                        Button { save(v) } label: { Label("احفظها كقضية وجهّز الخطاب", systemImage: "folder.badge.plus") }
                            .buttonStyle(PrimaryButtonStyle(color: Theme.green))
                    }
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: input) { _, _ in savedCase = nil }
        .sheet(item: $share) { s in ShareSheet(items: s.items) }
        .onAppear {
            if autoVerdict {
                eventDate = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
                showVerdict = true
            }
        }
    }

    @MainActor private func shareVerdict(_ v: Verdict) {
        let text = VerdictShare.text(scenario: scenario, verdict: v)
        var items: [Any] = [text]
        if let img = VerdictShare.image(scenario: scenario, verdict: v) { items.insert(img, at: 0) }
        share = ShareItem(items: items)
    }

    private func save(_ v: Verdict) {
        let r = CaseRecord(scenarioID: scenario.id, title: scenario.title)
        r.eventDate = input.eventDate
        r.used = used; r.defective = defective; r.delayDays = delayDays
        r.events.append(CaseEvent(stage: .open, note: v.title))
        context.insert(r)
        try? context.save()
        if let d = v.deadline { Notifier.requestAndSchedule(id: r.id.uuidString, title: scenario.title, deadline: d) }
        Haptics.success()
        savedCase = r
    }
}

struct VerdictCard: View {
    let verdict: Verdict

    var statusColor: Color {
        switch verdict.status {
        case .eligible: return Theme.green
        case .waiting: return Theme.orange
        case .expired: return verdict.deadlineLabel == "بعده تقدر تلغي وتسترد" ? Theme.green : Theme.red
        case .blocked: return Theme.orange
        }
    }
    var statusIcon: String {
        switch verdict.status {
        case .eligible: return "checkmark.shield.fill"
        case .waiting: return "hourglass"
        case .expired: return statusColor == Theme.green ? "checkmark.shield.fill" : "xmark.shield.fill"
        case .blocked: return "exclamationmark.shield.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: statusIcon).font(.system(size: 34)).foregroundStyle(statusColor)
                Text(verdict.title).font(.plex(22, .bold, relativeTo: .title2))
            }
            Text(verdict.text).font(.hBody).fixedSize(horizontal: false, vertical: true)

            if let left = verdict.daysLeft, let total = verdict.totalDays, let d = verdict.deadline {
                HStack(spacing: 16) {
                    CountdownRing(daysLeft: left, total: total, size: 120)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verdict.deadlineLabel ?? "").font(.hCaption).foregroundStyle(.secondary)
                        Text(d.formatted(date: .long, time: .omitted)).font(.hHeadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !verdict.exceptions.isEmpty {
                Label { Text(verdict.exceptions).font(.hCaption) } icon: { Image(systemName: "info.circle") }
                    .foregroundStyle(.secondary)
            }

            Divider()
            Text("المصدر").font(.hHeadline)
            ForEach(verdict.sources) { s in
                SourceRow(source: s)
            }
            Text("آخر مراجعة: \(verdict.lastChecked)").font(.hCaption).foregroundStyle(.secondary)

            Divider()
            Text("جهّز هذي الأدلة").font(.hHeadline)
            ForEach(verdict.evidence, id: \.self) { e in
                Label(e, systemImage: "checklist").font(.hBody)
            }
            DisclaimerBadge()
        }
        .card()
    }
}

struct SourceRow: View {
    let source: RuleSource
    var confidenceText: String {
        switch source.confidence {
        case "high": return "ثقة عالية"
        case "medium": return "ثقة متوسطة"
        default: return "ثقة منخفضة"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "building.columns.fill").foregroundStyle(Theme.navy)
                Text(source.law + (source.article.map { " - " + $0 } ?? "")).font(.plex(16, .semibold))
            }
            HStack {
                if !source.isVerified { PillTag(text: "غير متحقق منه", color: Theme.orange) }
                Text(confidenceText).font(.hCaption)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill((source.confidence == "high" ? Theme.green : Theme.orange).opacity(0.15)))
                if let url = URL(string: source.url) {
                    Link(destination: url) { Label("افتح المصدر", systemImage: "link").font(.hCaption) }
                }
            }
        }
    }
}

struct DisclaimerBadge: View {
    var body: some View {
        Label(RulesEngine.disclaimer, systemImage: "exclamationmark.bubble")
            .font(.hCaption)
            .foregroundStyle(Theme.orange)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.orange.opacity(0.12)))
    }
}
