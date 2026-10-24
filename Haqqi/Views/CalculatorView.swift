import SwiftUI

struct CalculatorView: View {
    @State private var purchase = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
    @State private var delivered = true
    @State private var delivery = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var online = true
    @State private var electronic = true
    @State private var scheduled = false

    private var engine: RulesEngine { RuleStore.shared.engine }
    private var items: [DeadlineItem] {
        DeadlineCalculator(engine: engine).compute(purchase: purchase, delivery: online && delivered ? delivery : nil,
                                                   online: online, electronic: electronic)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()
                    SpotIllustration(symbol: "calendar.badge.clock", tint: Theme.green, size: 130)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $online) { Label("اشتريت أونلاين", systemImage: "globe").font(.hBody) }
                    Toggle(isOn: $electronic) { Label("جهاز كهربائي أو إلكتروني", systemImage: "bolt.fill").font(.hBody) }
                }.card()
                VStack(alignment: .leading, spacing: 10) {
                    DatePicker(selection: $purchase, in: ...Date(), displayedComponents: .date) {
                        Label("تاريخ الشراء / الفاتورة", systemImage: "doc.text").font(.hBody)
                    }
                    if online {
                        Toggle(isOn: $delivered) { Label("استلمت الطلب؟", systemImage: "shippingbox").font(.hBody) }
                        if delivered {
                            DatePicker(selection: $delivery, in: purchase...Date(), displayedComponents: .date) {
                                Label("تاريخ الاستلام", systemImage: "calendar").font(.hBody)
                            }
                        }
                    }
                }.card()

                Text("مهلك").font(.hHeadline)
                if items.isEmpty {
                    Text("اختر نوع الشراء عشان نحسب.").font(.hBody).foregroundStyle(.secondary).card()
                }
                ForEach(items) { it in
                    HStack(spacing: 14) {
                        CountdownRing(daysLeft: it.daysLeft, total: max(1, it.key == "warranty" ? 730 : (it.key == "cancel15" ? 15 : 7)), size: 74)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(it.title).font(.plex(16, .semibold)).fixedSize(horizontal: false, vertical: true)
                            Text(it.date.formatted(date: .long, time: .omitted)).font(.hBody)
                            Text(statusText(it)).font(.hCaption).foregroundStyle(it.daysLeft < 0 ? Theme.red : .secondary)
                            if let s = RuleStore.shared.book.source(it.sourceID) {
                                Text("المصدر: " + s.law + (s.article.map { " - " + $0 } ?? "")).font(.plex(12)).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }.card()
                }
                Button {
                    for it in items where it.daysLeft >= 0 { Notifier.requestAndSchedule(id: "calc-" + it.key, title: it.title, deadline: it.date) }
                    scheduled = true; Haptics.success()
                } label: { Label(scheduled ? "تم، بننبهك قبلها" : "ذكّرني قبل كل مهلة", systemImage: scheduled ? "checkmark" : "bell.badge") }
                .buttonStyle(PrimaryButtonStyle(color: Theme.green))
                .disabled(items.allSatisfy { $0.daysLeft < 0 })
                Text("التنبيهات محلية على جهازك، ما نضيف شي لتقويمك.").font(.hCaption).foregroundStyle(.secondary)
                DisclaimerBadge()
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("احسب مهلتي")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statusText(_ it: DeadlineItem) -> String {
        if it.daysLeft < 0 { return "انتهت قبل \(-it.daysLeft) يوم" }
        if it.daysLeft == 0 { return "اليوم آخر يوم!" }
        return it.key == "cancel15" ? "باقي \(it.daysLeft) يوم وبعدها يحق لك تلغي" : "باقي \(it.daysLeft) يوم"
    }
}
