import SwiftUI

enum HomeRoute: Hashable { case sources, calculator }

struct HomeView: View {
    var openChat: () -> Void = {}
    private let book = RuleStore.shared.book
    @State private var path = NavigationPath()
    private let tints: [Color] = [Theme.navy, Theme.orange, Theme.red, Color.purple, Theme.green, Color.teal, Color.pink, Color.indigo]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    quickActions
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
            .navigationDestination(for: Scenario.self) { sc in
                WizardView(scenario: sc, autoVerdict: UserDefaults.standard.string(forKey: "screen") == "verdict")
            }
            .navigationDestination(for: HomeRoute.self) { r in
                switch r {
                case .sources: SourcesView()
                case .calculator: CalculatorView()
                }
            }
            .onAppear(perform: routeForScreenshots)
        }
    }

    private func routeForScreenshots() {
        guard path.isEmpty else { return }
        switch UserDefaults.standard.string(forKey: "screen") ?? "" {
        case "sources": path.append(HomeRoute.sources)
        case "calculator": path.append(HomeRoute.calculator)
        case "verdict": if let sc = book.scenario("online_return") { path.append(sc) }
        default: break
        }
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            QuickAction(title: "اسأل حقّي", symbol: "bubble.left.and.text.bubble.right.fill", tint: Theme.navy) { openChat() }
            QuickAction(title: "احسب مهلتي", symbol: "calendar.badge.clock", tint: Theme.green) { path.append(HomeRoute.calculator) }
            QuickAction(title: "المصادر", symbol: "building.columns.fill", tint: Theme.gold) { path.append(HomeRoute.sources) }
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

struct QuickAction: View {
    let title: String
    let symbol: String
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button { Haptics.tap(); action() } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 22, weight: .semibold)).foregroundStyle(tint)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(tint.opacity(0.15)))
                Text(title).font(.plex(14, .semibold)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
    }
}
