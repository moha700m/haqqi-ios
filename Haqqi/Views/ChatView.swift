import SwiftUI
import SwiftData

struct ChatView: View {
    @Query(sort: \ChatMessage.date) private var messages: [ChatMessage]
    @Environment(\.modelContext) private var context
    @State private var draft = ""
    @State private var thinking = false
    @State private var confirmClear = false
    @FocusState private var focused: Bool
    private let status = HaqqiAI.status

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            header
                            ForEach(messages) { m in ChatBubble(message: m).id(m.id) }
                            if thinking {
                                HStack { TypingDots(); Spacer() }.padding(.horizontal, 4).id("typing")
                            }
                            if messages.isEmpty { suggestions }
                        }
                        .padding(16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: messages.count) { _, _ in
                        withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                    }
                    .onChange(of: thinking) { _, t in if t { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } } }
                }
                if !messages.isEmpty { chips }
                inputBar
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("اسأل حقّي")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) { confirmClear = true } label: { Image(systemName: "trash") }
                            .accessibilityLabel("امسح المحادثة")
                    }
                }
            }
            .confirmationDialog("تمسح المحادثة كلها؟", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("امسح", role: .destructive) { clear() }
            }
            .onAppear {
                if UserDefaults.standard.bool(forKey: "demoChat"), messages.isEmpty {
                    send(LocalAnswerer.suggestions[0])
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.heroGradient).frame(width: 84, height: 84)
                Image(systemName: "bubble.left.and.text.bubble.right.fill").font(.system(size: 34)).foregroundStyle(Theme.gold)
            }
            Text("اسألني عن حقّك").font(.hHeadline)
            Label(status.label, systemImage: status.onDevice ? "sparkles" : "lock.shield")
                .font(.hCaption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("أجاوب من مصادر رسمية موثقة فقط، وأقول لك إذا ما عندي معلومة.")
                .font(.hCaption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("جرّب تسأل:").font(.hHeadline)
            ForEach(LocalAnswerer.suggestions, id: \.self) { s in
                Button { send(s) } label: {
                    HStack {
                        Image(systemName: "sparkle").foregroundStyle(Theme.gold)
                        Text(s).font(.hBody).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LocalAnswerer.suggestions, id: \.self) { s in
                    Button { send(s) } label: {
                        Text(s).font(.hCaption).lineLimit(1)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Capsule().fill(Theme.navy.opacity(0.12)))
                    }.buttonStyle(.plain).disabled(thinking)
                }
            }.padding(.horizontal, 16).padding(.vertical, 6)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("اكتب سؤالك…", text: $draft, axis: .vertical)
                .font(.hBody).lineLimit(1...4).focused($focused)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
                .submitLabel(.send).onSubmit { send(draft) }
            Button { send(draft) } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 36))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespaces).isEmpty || thinking ? Color.secondary : Theme.navy)
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || thinking)
            .accessibilityLabel("أرسل")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.bar)
    }

    private func send(_ raw: String) {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !thinking else { return }
        draft = ""
        Haptics.tap()
        context.insert(ChatMessage(isUser: true, text: q))
        try? context.save()
        thinking = true
        Task {
            let (answer, engine) = await HaqqiAI.ask(q)
            await MainActor.run {
                context.insert(ChatMessage(isUser: false, text: answer, engine: engine))
                try? context.save()
                thinking = false
            }
        }
    }

    private func clear() {
        for m in messages { context.delete(m) }
        try? context.save()
        Haptics.warn()
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer(minLength: 48) }
            VStack(alignment: .leading, spacing: 6) {
                Text(message.text)
                    .font(.hBody)
                    .foregroundStyle(message.isUser ? Color.white : Color.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if !message.isUser {
                    Label(message.engine == "ai" ? "ذكاء Apple + مصادر حقّي" : "من قواعد حقّي",
                          systemImage: message.engine == "ai" ? "sparkles" : "books.vertical")
                        .font(.plex(12, .medium)).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(message.isUser ? AnyShapeStyle(Theme.heroGradient) : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)))
            )
            if !message.isUser { Spacer(minLength: 32) }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}

struct TypingDots: View {
    @State private var phase = 0.0
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle().fill(Color.secondary).frame(width: 8, height: 8)
                    .opacity(0.3 + 0.7 * abs(sin(phase + Double(i) * 0.6)))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(uiColor: .secondarySystemGroupedBackground)))
        .onAppear { withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = .pi } }
    }
}
