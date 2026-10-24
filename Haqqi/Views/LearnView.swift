import SwiftUI

struct LearnView: View {
    private let cards = RuleStore.shared.cards
    @State private var query = ""

    private var filtered: [LearnCard] {
        query.isEmpty ? cards : cards.filter { $0.title.contains(query) || $0.body.contains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if filtered.isEmpty {
                        EmptyStateView(symbol: "magnifyingglass", title: "ما لقينا شي", message: "جرّب كلمة ثانية.")
                            .frame(height: 400)
                    }
                    ForEach(filtered) { c in
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.gold.opacity(0.18))
                                Image(systemName: c.icon).font(.system(size: 22, weight: .semibold)).foregroundStyle(Theme.navy)
                            }.frame(width: 50, height: 50)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(c.title).font(.hHeadline)
                                Text(c.body).font(.hBody).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                if let u = URL(string: c.url) {
                                    Link(destination: u) { Label("المصدر", systemImage: "link").font(.hCaption) }
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .card()
                    }
                    DisclaimerBadge()
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("تعلّم حقوقك")
            .searchable(text: $query, prompt: "ابحث")
        }
    }
}
