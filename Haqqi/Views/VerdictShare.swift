import SwiftUI
import UIKit

enum VerdictShare {
    static func text(scenario: Scenario, verdict: Verdict) -> String {
        var t = "⚖️ حقّي: \(scenario.title)\n\n\(verdict.title)\n\(verdict.text)"
        if let d = verdict.deadline, let l = verdict.deadlineLabel {
            t += "\n\n\(l): \(d.formatted(date: .long, time: .omitted))"
        }
        t += "\n\nالمصدر: " + verdict.sources.map { $0.law + ($0.article.map { " - " + $0 } ?? "") }.joined(separator: "، ")
        t += "\n\n" + verdict.disclaimer
        return t
    }

    @MainActor static func image(scenario: Scenario, verdict: Verdict) -> UIImage? {
        let card = ShareCardView(scenario: scenario, verdict: verdict)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar_SA"))
        let r = ImageRenderer(content: card)
        r.scale = 3
        return r.uiImage
    }
}

struct ShareCardView: View {
    let scenario: Scenario
    let verdict: Verdict
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                EmblemView(size: 54)
                VStack(alignment: .leading) {
                    Text("حقّي").font(.plex(22, .bold)).foregroundStyle(.white)
                    Text(scenario.title).font(.plex(14, .medium)).foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }
            Text(verdict.title).font(.plex(24, .bold)).foregroundStyle(Theme.gold)
            Text(verdict.text).font(.plex(16)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
            if let d = verdict.deadline, let l = verdict.deadlineLabel {
                Text("\(l): \(d.formatted(date: .long, time: .omitted))").font(.plex(15, .semibold)).foregroundStyle(.white)
                    .padding(10).background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.12)))
            }
            Text("المصدر: " + verdict.sources.map { $0.law }.joined(separator: "، ")).font(.plex(12)).foregroundStyle(.white.opacity(0.8))
            Text(verdict.disclaimer).font(.plex(12, .semibold)).foregroundStyle(Theme.gold)
        }
        .padding(24)
        .frame(width: 390)
        .background(Theme.heroGradient)
    }
}
