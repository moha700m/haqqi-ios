import SwiftUI
import SwiftData

@main
struct HaqqiApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar_SA"))
                .tint(Theme.navy)
        }
        .modelContainer(for: [CaseRecord.self, CaseEvent.self, EvidencePhoto.self, ChatMessage.self])
    }
}

struct RootView: View {
    @AppStorage("onboarded") private var onboarded = false
    @AppStorage("faceIDEnabled") private var faceIDEnabled = false
    @State private var unlocked = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !onboarded {
                OnboardingView { withAnimation { onboarded = true } }
            } else if faceIDEnabled && !unlocked {
                LockView { unlocked = true }
            } else {
                MainTabs()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && faceIDEnabled { unlocked = false }
        }
    }
}

struct MainTabs: View {
    @State private var tab: String = {
        switch UserDefaults.standard.string(forKey: "screen") ?? "" {
        case "chat": return "chat"
        case "cases": return "cases"
        case "learn": return "learn"
        case "settings": return "settings"
        default: return "home"
        }
    }()
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView(selection: $tab) {
            HomeView(openChat: { tab = "chat" }).tabItem { Label("حقّي", systemImage: "scalemass") }.tag("home")
            ChatView().tabItem { Label("اسأل", systemImage: "bubble.left.and.text.bubble.right") }.tag("chat")
            CasesView().tabItem { Label("قضاياي", systemImage: "folder") }.tag("cases")
            LearnView().tabItem { Label("تعلّم", systemImage: "book") }.tag("learn")
            SettingsView().tabItem { Label("الإعدادات", systemImage: "gearshape") }.tag("settings")
        }
        .onAppear { DemoSeed.runIfRequested(context) }
    }
}

/// Only used by CI screenshots (launch argument -seedDemo YES).
enum DemoSeed {
    static func runIfRequested(_ context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "seedDemo") else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<CaseRecord>())) ?? 0
        guard existing == 0 else { return }
        let a = CaseRecord(scenarioID: "online_return", title: "أبغى أرجّع شي اشتريته أونلاين")
        a.eventDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())
        a.storeName = "متجر نون"; a.product = "سماعة لاسلكية"
        a.events.append(CaseEvent(stage: .open, note: "تقدر ترجّعه"))
        let b = CaseRecord(scenarioID: "device_fault", title: "جهازي خرب (كهربائي/إلكتروني)")
        b.eventDate = Calendar.current.date(byAdding: .month, value: -8, to: Date())
        b.stage = .sent
        b.events.append(CaseEvent(stage: .open)); b.events.append(CaseEvent(stage: .sent))
        context.insert(a); context.insert(b)
        try? context.save()
    }
}

struct LockView: View {
    var onUnlock: () -> Void
    var body: some View {
        ZStack {
            Theme.heroGradient.ignoresSafeArea()
            VStack(spacing: 24) {
                EmblemView(size: 120)
                Text("حقّي مقفل").font(.hTitle).foregroundStyle(.white)
                Button { Biometrics.authenticate { ok in if ok { Haptics.success(); onUnlock() } } } label: {
                    Label("افتح بـ Face ID", systemImage: "faceid")
                }
                .buttonStyle(PrimaryButtonStyle(color: Theme.gold.opacity(0.9)))
                .padding(.horizontal, 40)
            }
        }
        .onAppear { Biometrics.authenticate { ok in if ok { onUnlock() } } }
    }
}

struct OnboardingView: View {
    var onDone: () -> Void
    @State private var page = 0
    private let pages: [(String, String, String, Color)] = [
        ("scalemass.fill", "اعرف حقّك بسهولة", "قل لنا وش صار، ونقول لك حقّك بكلام بسيط، مع المصدر من النظام.", Theme.navy),
        ("clock.badge.checkmark.fill", "لا تفوتك المهلة", "نعدّ لك الأيام الباقية وننبهك قبل آخر يوم.", Theme.green),
        ("doc.text.fill", "خطاب جاهز في ثواني", "صوّر الفاتورة، ونجهّز لك خطاب للتاجر ونص للبلاغ التجاري.", Theme.orange)
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(0..<pages.count, id: \.self) { i in
                    VStack(spacing: 28) {
                        Spacer()
                        if i == 0 { EmblemView(size: 150) } else { SpotIllustration(symbol: pages[i].0, tint: pages[i].3, size: 220) }
                        Text(pages[i].1).font(.hTitle).multilineTextAlignment(.center)
                        Text(pages[i].2).font(.hBody).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                        Spacer()
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page == pages.count - 1 ? "يلا نبدأ" : "التالي") {
                Haptics.tap()
                if page < pages.count - 1 { withAnimation { page += 1 } } else { onDone() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            Text(RulesEngine.disclaimer).font(.hCaption).foregroundStyle(.secondary).padding(.bottom, 8)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    }
}
