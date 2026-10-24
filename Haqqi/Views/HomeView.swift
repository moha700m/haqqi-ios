import SwiftUI

struct HomeView: View {
    private let book = RuleStore.shared.book
    private let tints: [Color] = [Theme.navy, Theme.orange, Theme.red, Color.purple, Theme.green, Color.teal, Color.pink, Color.indigo]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    Text("وش صار معك؟").font(.hHeadline).padding(.horizontal, 4)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Array(book.scenarios.enumerated()), id: \.element.id) { idx, sc in
                            NavigationLink(value: sc) {
                                ScenarioTile(scenario: sc, tint: tints[idx % tints.count])
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("حقّي")
            .navigationDestination(for: Scenario.self) { sc in WizardView(scenario: sc) }
        }
    }

    private var hero: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("حقّك واضح").font(.plex(26, .bold, relativeTo: .title)).foregroundStyle(.white)
                Text("اختر مشكلتك ونقول لك حقّك ومصدره.").font(.hBody).foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
            EmblemView(size: 80)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.heroGradient))
    }
}

struct ScenarioTile: View {
    let scenario: Scenario
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint.opacity(0.14))
                Image(systemName: scenario.icon).font(.system(size: 26, weight: .semibold)).foregroundStyle(tint)
            }
            .frame(width: 54, height: 54)
            Text(scenario.title).font(.plex(16, .semibold, relativeTo: .headline))
                .foregroundStyle(.primary).multilineTextAlignment(.leading)
                .lineLimit(3).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
