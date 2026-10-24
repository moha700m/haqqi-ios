import SwiftUI
import SwiftData

struct CasesView: View {
    @Query(sort: \CaseRecord.createdAt, order: .reverse) private var cases: [CaseRecord]
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Group {
                if cases.isEmpty {
                    EmptyStateView(symbol: "folder.badge.questionmark", title: "ما عندك قضايا", message: "من صفحة «حقّي» اختر مشكلتك واحفظها هنا عشان نتابعها معك.")
                } else {
                    List {
                        ForEach(cases) { c in
                            NavigationLink { CaseDetailView(record: c) } label: { CaseRow(record: c) }
                        }
                        .onDelete { idx in
                            for i in idx { context.delete(cases[i]) }
                            try? context.save()
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("قضاياي")
        }
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            SpotIllustration(symbol: symbol, size: 200)
            Text(title).font(.hTitle)
            Text(message).font(.hBody).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CaseRow: View {
    let record: CaseRecord
    var body: some View {
        HStack(spacing: 12) {
            let sc = RuleStore.shared.book.scenario(record.scenarioID)
            ZStack {
                Circle().fill(Theme.navy.opacity(0.12))
                Image(systemName: sc?.icon ?? "folder").foregroundStyle(Theme.navy)
            }.frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title).font(.plex(17, .semibold)).lineLimit(2)
                Label(record.stage.label, systemImage: record.stage.icon).font(.hCaption).foregroundStyle(.secondary)
            }
            Spacer()
            if let v = RuleStore.shared.engine.evaluate(record.input), let left = v.daysLeft, record.stage != .solved {
                Text(left < 0 ? "انتهت" : "\(left) يوم")
                    .font(.hCaption).padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill((left < 0 ? Theme.red : (left <= 2 ? Theme.orange : Theme.green)).opacity(0.15)))
            }
        }
        .padding(.vertical, 4)
    }
}
