import SwiftUI

struct SourcesView: View {
    private let book = RuleStore.shared.book
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    SpotIllustration(symbol: "building.columns.fill", tint: Theme.navy, size: 90)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("الأنظمة والمصادر اللي نعتمد عليها").font(.hHeadline)
                        Text("كل قاعدة في التطبيق مربوطة بمصدرها. آخر مراجعة: \(book.lastChecked)")
                            .font(.hCaption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                ForEach(book.sources) { s in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Image(systemName: s.isVerified ? "checkmark.seal.fill" : "questionmark.diamond.fill")
                                .foregroundStyle(s.isVerified ? Theme.green : Theme.orange).font(.title3)
                            Text(s.law).font(.plex(16, .semibold)).fixedSize(horizontal: false, vertical: true)
                        }
                        if let a = s.article { Text(a).font(.hCaption).foregroundStyle(Theme.navy) }
                        if let n = s.note { Text(n).font(.hCaption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                        HStack(spacing: 8) {
                            PillTag(text: s.isVerified ? "متحقق منه" : "غير متحقق منه", color: s.isVerified ? Theme.green : Theme.orange)
                            PillTag(text: s.confidence == "high" ? "ثقة عالية" : "ثقة متوسطة", color: Theme.navy)
                            Spacer(minLength: 0)
                        }
                        HStack {
                            Text("تاريخ التحقق: \(s.checked ?? "-")").font(.plex(12)).foregroundStyle(.secondary)
                            Spacer()
                            if let u = URL(string: s.url) {
                                Button { openURL(u) } label: { Label("افتح في Safari", systemImage: "safari").font(.hCaption) }
                            }
                        }
                    }
                    .card()
                }
                DisclaimerBadge()
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("المصادر")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PillTag: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text).font(.plex(12, .semibold)).foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}
