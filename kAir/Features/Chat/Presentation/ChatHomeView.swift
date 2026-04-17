//
//  ChatHomeView.swift
//  kAir
//
//  Chat inbox plus focused conversation thread for kAir.
//

import SwiftUI

struct ChatHomeView: View {
    let bootstrap: AppBootstrap

    @State private var store = ChatStore()
    @State private var isConversationPresented = false

    private var dashboard: HealthDashboard? {
        bootstrap.healthStore.dashboard
    }

    private var latestMessage: ConversationMessage? {
        store.session.messages.last
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    ConversationInboxRow(
                        title: store.session.title,
                        preview: latestMessage?.text ?? store.contextSummary,
                        timestamp: latestMessage?.timestamp,
                        onTap: {
                            isConversationPresented = true
                        }
                    )
                    .padding(.top, 10)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 520, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .task(id: dashboard?.generatedAt) {
            if let dashboard {
                store.bootstrap(with: dashboard)
            } else {
                store.bootstrapWithoutDashboard(
                    supportsHealthData: bootstrap.healthStore.supportsHealthData
                )
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ChatInboxTopBar(
                onAddTap: {
                    isConversationPresented = true
                }
            )
        }
        .safeAreaInset(edge: .bottom) {
            FloatingAskComposer(
                text: $store.draft,
                isTemplateChat: $store.isTemplateChat,
                placeholder: "Ask me anything...",
                onSend: sendFromHomeComposer,
                onProfileTap: bootstrap.showProfile
            )
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(Color.white.opacity(0.001))
        }
        .navigationDestination(isPresented: $isConversationPresented) {
            ConversationThreadView(
                store: store,
                bootstrap: bootstrap
            )
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func sendFromHomeComposer() {
        let prompt = store.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.isEmpty == false else { return }

        let route = store.route(for: prompt)
        store.sendDraft(using: dashboard, target: route)
        isConversationPresented = true
        handleRoute(route)
    }

    private func handleRoute(_ route: ChatNavigationTarget?) {
        guard let route else { return }

        store.recordHandoff(to: route)

        switch route {
        case .section(.maps):
            bootstrap.openMaps(with: store.consumeResolvedMapsSession())
        case .section(.health):
            bootstrap.openHealth(with: store.consumeResolvedHealthSession())
        case .section(let section):
            bootstrap.openSurface(section)
        case .userProfile:
            bootstrap.showProfile()
        }
    }
}

private struct ConversationThreadView: View {
    let store: ChatStore
    let bootstrap: AppBootstrap

    @State private var isReferencePickerPresented = false
    @Environment(\.dismiss) private var dismiss

    private static let bottomAnchorID = "kair-chat-bottom"

    private var dashboard: HealthDashboard? {
        bootstrap.healthStore.dashboard
    }

    private var threadMessages: [ConversationMessage] {
        store.session.messages
    }

    var body: some View {
        @Bindable var store = store

        ZStack {
            Color(uiColor: .systemGray6)
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        if threadMessages.isEmpty {
                            EmptyConversationState(
                                prompts: store.suggestedPrompts,
                                onTapPrompt: { prompt in
                                    submit(prompt, scrollProxy: proxy)
                                }
                            )
                            .padding(.top, 24)
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(threadMessages) { message in
                                    MessageBubble(message: message)
                                }
                            }
                        }

                        if threadMessages.count <= 2 {
                            ConversationPromptTray(
                                prompts: store.suggestedPrompts,
                                onTapPrompt: { prompt in
                                    submit(prompt, scrollProxy: proxy)
                                }
                            )
                            .padding(.top, 6)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(Self.bottomAnchorID)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 108)
                }
                .scrollIndicators(.hidden)
                .onChange(of: store.session.messages.count) { _, newCount in
                    guard newCount > 1 else { return }
                    scrollToBottom(proxy)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ConversationThreadTopBar(
                title: store.session.title,
                onBackTap: dismiss.callAsFunction,
                onOptionsTap: {
                    isReferencePickerPresented = true
                }
            )
        }
        .sheet(isPresented: $isReferencePickerPresented) {
            ReferencePickerSheet(
                onSelect: handleReference
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .safeAreaInset(edge: .bottom) {
            ConversationThreadComposer(
                text: $store.draft,
                isTemplateChat: $store.isTemplateChat,
                onSend: sendFromComposer,
                onReferenceTap: {
                    isReferencePickerPresented = true
                }
            )
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color(uiColor: .systemGray6).opacity(0.96))
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func submit(_ prompt: String, scrollProxy: ScrollViewProxy) {
        let route = store.route(for: prompt)
        store.submitPrompt(prompt, using: dashboard, target: route)
        handleRoute(route)
        scrollToBottom(scrollProxy)
    }

    private func handleReference(_ reference: ReferenceAttachment) {
        switch reference {
        case .health:
            store.attachReference(
                "Apple Health",
                detail: "The latest local Apple Health snapshot is now part of the conversation context."
            )
        case .location:
            store.attachReference(
                "Current location",
                detail: "Nearby places can now be routed through Maps from inside chat."
            )
        case .photo:
            store.attachReference(
                "Photo or file",
                detail: "Visual and document intake is reserved for the next implementation pass."
            )
        case .store:
            store.attachReference(
                "Store intent",
                detail: "The conversation can now bias toward curated product suggestions."
            )
        }
    }

    private func sendFromComposer() {
        let prompt = store.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.isEmpty == false else { return }

        let route = store.route(for: prompt)
        store.sendDraft(using: dashboard, target: route)
        handleRoute(route)
    }

    private func handleRoute(_ route: ChatNavigationTarget?) {
        guard let route else { return }

        store.recordHandoff(to: route)

        switch route {
        case .section(.maps):
            bootstrap.openMaps(with: store.consumeResolvedMapsSession())
        case .section(.health):
            bootstrap.openHealth(with: store.consumeResolvedHealthSession())
        case .section(let section):
            bootstrap.openSurface(section)
        case .userProfile:
            bootstrap.showProfile()
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.24)) {
            proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        }
    }
}

private struct ChatInboxTopBar: View {
    let onAddTap: () -> Void

    var body: some View {
        HStack {
            Spacer()

            Button(action: onAddTap) {
                Image(systemName: "plus.circle")
                    .font(.title3.weight(.regular))
                    .foregroundStyle(Color.black.opacity(0.76))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            Color(uiColor: .systemBackground)
                .ignoresSafeArea(edges: .top)
        )
    }
}

private struct ConversationInboxRow: View {
    let title: String
    let preview: String
    let timestamp: Date?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.33, green: 0.43, blue: 0.56),
                                Color(red: 0.16, green: 0.20, blue: 0.27)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.regular))
                        .foregroundStyle(Color.black.opacity(0.82))

                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(Color.black.opacity(0.26))
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                if let timestamp {
                    Text(
                        timestamp.formatted(
                            .dateTime
                                .year()
                                .month()
                                .day()
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(Color.black.opacity(0.14))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 66)
        }
    }
}

private struct ConversationThreadTopBar: View {
    let title: String
    let onBackTap: () -> Void
    let onOptionsTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBackTap) {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.82))

                Spacer()

                Button(action: onOptionsTap) {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .background(
            Color(uiColor: .systemGray6)
                .ignoresSafeArea(edges: .top)
        )
    }
}

private struct ConversationPromptTray: View {
    let prompts: [String]
    let onTapPrompt: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try a prompt")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.28))
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(prompts.prefix(4), id: \.self) { prompt in
                        Button {
                            onTapPrompt(prompt)
                        } label: {
                            Text(prompt)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Color.black.opacity(0.78))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.white.opacity(0.92))
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct EmptyConversationState: View {
    let prompts: [String]
    let onTapPrompt: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("kAir is ready.")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.88))

            Text("Start with a direct request, then let the thread open Health, Maps, AI, or Store only when it needs to.")
                .font(.subheadline)
                .foregroundStyle(Color.black.opacity(0.44))

            ConversationPromptTray(
                prompts: prompts,
                onTapPrompt: onTapPrompt
            )
        }
    }
}

private struct ConversationThreadComposer: View {
    @Binding var text: String
    @Binding var isTemplateChat: Bool

    let onSend: () -> Void
    let onReferenceTap: () -> Void

    @FocusState private var isFocused: Bool

    private var canSend: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var showsTemplateToggle: Bool {
        isFocused || canSend || isTemplateChat
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsTemplateToggle {
                TemplateChatToggle(isOn: $isTemplateChat)
            }

            HStack(spacing: 10) {
                Button(action: {}) {
                    Image(systemName: "waveform.circle")
                        .font(.title2.weight(.regular))
                        .foregroundStyle(Color.black.opacity(0.68))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    TextField("", text: $text, prompt: Text("Message"))
                        .font(.body)
                        .foregroundStyle(Color.black.opacity(0.88))
                        .lineLimit(1 ... 4)
                        .submitLabel(.send)
                        .onSubmit(onSend)
                        .focused($isFocused)

                    Button(action: canSend ? onSend : {}) {
                        Image(systemName: canSend ? "arrow.up.circle.fill" : "mic")
                            .font(.headline.weight(.medium))
                            .foregroundStyle(canSend ? Color.black.opacity(0.82) : Color.black.opacity(0.38))
                    }
                    .buttonStyle(.plain)
                    .disabled(canSend == false)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white)
                )

                Button(action: {}) {
                    Image(systemName: "face.smiling")
                        .font(.title3.weight(.regular))
                        .foregroundStyle(Color.black.opacity(0.72))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Button(action: onReferenceTap) {
                    Image(systemName: "plus.circle")
                        .font(.title2.weight(.regular))
                        .foregroundStyle(Color.black.opacity(0.72))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct FloatingAskComposer: View {
    @Binding var text: String
    @Binding var isTemplateChat: Bool

    let placeholder: String
    let onSend: () -> Void
    let onProfileTap: () -> Void

    @FocusState private var isFocused: Bool

    private var canSend: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var showsSendButton: Bool {
        isFocused || canSend
    }

    private var showsTemplateToggle: Bool {
        isFocused || canSend || isTemplateChat
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsTemplateToggle {
                TemplateChatToggle(isOn: $isTemplateChat)
            }

            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    TextField(
                        "",
                        text: $text,
                        prompt: Text(placeholder)
                            .font(.title3.weight(.regular))
                            .foregroundStyle(Color.black.opacity(0.92))
                    )
                    .lineLimit(1 ... 2)
                    .font(.title3.weight(.regular))
                    .foregroundStyle(Color.black)
                    .submitLabel(.send)
                    .onSubmit(onSend)
                    .focused($isFocused)

                    if showsSendButton {
                        Button(action: onSend) {
                            Image(systemName: "arrow.up")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(canSend ? Color.white : Color.black.opacity(0.35))
                                .frame(width: 34, height: 34)
                                .background(
                                    Circle()
                                        .fill(canSend ? Color.black : Color.black.opacity(0.08))
                                )
                        }
                        .disabled(canSend == false)
                        .buttonStyle(.plain)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)

                Button(action: onProfileTap) {
                    Circle()
                        .fill(Color.white.opacity(0.36))
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.black.opacity(0.82), lineWidth: 1.6)
                        )
                        .overlay {
                            Text("K")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Color.black.opacity(0.88))
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showsSendButton)
    }
}

private struct TemplateChatToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.subheadline.weight(.semibold))

                Text("Template chat")
                    .font(.footnote.weight(.medium))
            }
            .foregroundStyle(Color.black.opacity(0.78))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private enum ReferenceAttachment: CaseIterable, Identifiable {
    case health
    case location
    case photo
    case store

    var id: Self { self }

    var title: String {
        switch self {
        case .health:
            return "Apple Health"
        case .location:
            return "Current location"
        case .photo:
            return "Photo or file"
        case .store:
            return "Store intent"
        }
    }

    var summary: String {
        switch self {
        case .health:
            return "Attach the latest local health snapshot."
        case .location:
            return "Help Maps route nearby actions from chat."
        case .photo:
            return "Reserve visual or file context."
        case .store:
            return "Bias the conversation toward curated products."
        }
    }

    var systemImage: String {
        switch self {
        case .health:
            return "heart.text.square"
        case .location:
            return "location"
        case .photo:
            return "paperclip"
        case .store:
            return "bag"
        }
    }
}

private struct ReferencePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (ReferenceAttachment) -> Void

    var body: some View {
        NavigationStack {
            List(ReferenceAttachment.allCases) { attachment in
                Button {
                    onSelect(attachment)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: attachment.systemImage)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(attachment.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            Text(attachment.summary)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Palette.textSecondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Add Reference")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
