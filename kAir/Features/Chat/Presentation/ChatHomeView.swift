//
//  ChatHomeView.swift
//  kAir
//
//  Primary all-in-one conversation surface for kAir.
//

import SwiftUI

struct ChatHomeView: View {
    let bootstrap: AppBootstrap

    @State private var store: ChatStore
    @State private var isReferencePickerPresented = false

    /// Composes `ChatStore` with the runtime + handoff wired by
    /// `AppBootstrap`.
    ///
    /// Per `Contracts/UX/feedback-runtime-v1.md` §5 + Main A.1 / A.2
    /// wiring, the feedback runtime, the completed-recommendation
    /// handoff, AND the telemetry emitter are owned by the
    /// composition root (`AppBootstrap`), not by `ChatStore`. The
    /// view threads them through at construction time.
    ///
    /// This `init` is the single composition seam between the
    /// `AppBootstrap` and `ChatStore`. Per Main B scope, the only
    /// addition here is the `telemetryEmitter:` argument; no view
    /// logic, no rendering, no new emit sites in this view.
    init(bootstrap: AppBootstrap) {
        self.bootstrap = bootstrap
        self._store = State(
            wrappedValue: ChatStore(
                feedbackRuntime: bootstrap.feedbackRuntime,
                completedRecommendationHandoff: bootstrap.completedRecommendationHandoff,
                telemetryEmitter: bootstrap.telemetryEmitter
            )
        )
    }

    private static let bottomAnchorID = "kair-chat-bottom"

    private var dashboard: HealthDashboard? {
        bootstrap.healthStore.dashboard
    }

    private var visibleMessages: [ConversationMessage] {
        store.session.messages.filter { $0.role != .system }
    }

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear
                            .frame(height: 10)

                        if visibleMessages.isEmpty {
                            EmptyConversationState(
                                prompts: store.suggestedPrompts,
                                onTapPrompt: { prompt in
                                    submit(prompt, scrollProxy: proxy)
                                }
                            )
                            .padding(.top, 40)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(visibleMessages.enumerated()), id: \.element.id) { index, message in
                                    ConversationInboxRow(
                                        message: message,
                                        badgeCount: badgeCount(for: message),
                                        onTap: {
                                            focus(message: message, scrollProxy: proxy)
                                        }
                                    )

                                    if index != visibleMessages.count - 1 {
                                        Divider()
                                            .padding(.leading, 84)
                                    }
                                }
                            }
                        }

                        // Layer 4: Recommended Next rail.
                        // Renders nothing when the slate is empty per
                        // mixed-recommendation-rail-visual-v1 §3.
                        // I3 wires onDismiss (✕ button) and onFeedback
                        // (⋯ menu) to ChatStore.dismissRecommendation;
                        // both produce same-frame removal per
                        // negative-feedback-affordance-visual-v1 §6.1.
                        // Accept / refresh wiring stay deferred to a
                        // later PR.
                        RecommendationRail(
                            objects: store.recommendedMatches,
                            onDismiss: { object in
                                store.dismissRecommendation(object, feedback: .dismiss)
                            },
                            onFeedback: { object, kind in
                                store.dismissRecommendation(object, feedback: kind)
                            }
                        )
                        .padding(.top, store.recommendedMatches.isEmpty ? 0 : 16)

                        Color.clear
                            .frame(height: 1)
                            .id(Self.bottomAnchorID)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 154)
                }
                .scrollIndicators(.hidden)
                .task(id: dashboard?.generatedAt) {
                    if let dashboard {
                        store.bootstrap(with: dashboard)
                    } else {
                        store.bootstrapWithoutDashboard(
                            supportsHealthData: bootstrap.healthStore.supportsHealthData
                        )
                    }
                }
                .onChange(of: store.session.messages.count) { _, newCount in
                    guard newCount > 1 else { return }
                    scrollToBottom(proxy)
                }
            }
        }
        .sheet(isPresented: $isReferencePickerPresented) {
            ReferencePickerSheet(
                onSelect: handleReference
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .safeAreaInset(edge: .bottom) {
            FloatingAskComposer(
                text: $store.draft,
                placeholder: "Ask me anything...",
                onSend: sendFromComposer,
                onUserTap: bootstrap.showProfile
            )
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(Color.white.opacity(0.001))
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func handleAccessory(_ accessory: ComposerAccessory) {
        switch accessory.id {
        case "health":
            bootstrap.openSurface(.health)
            store.recordHandoff(to: .health)
        case "ai":
            bootstrap.openSurface(.ai)
            store.recordHandoff(to: .ai)
        case "maps":
            bootstrap.openSurface(.maps)
            store.recordHandoff(to: .maps)
        case "store":
            bootstrap.openSurface(.store)
            store.recordHandoff(to: .store)
        default:
            break
        }
    }

    private func submit(_ prompt: String, scrollProxy: ScrollViewProxy) {
        let route = store.route(for: prompt)
        store.submitPrompt(prompt, using: dashboard)
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

    private func badgeCount(for message: ConversationMessage) -> Int? {
        guard message.role == .assistant else { return nil }

        if message.toolResults.isEmpty == false {
            return message.toolResults.count
        }

        if message.tags.contains("Maps") || message.tags.contains("Route") || message.tags.contains("路线") {
            return 1
        }

        return nil
    }

    private func sendFromComposer() {
        let prompt = store.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.isEmpty == false else { return }

        let route = store.route(for: prompt)
        store.sendDraft(using: dashboard)
        handleRoute(route)
    }

    private func handleRoute(_ route: AppSection?) {
        guard let route else { return }

        store.recordHandoff(to: route)

        if route == .maps {
            bootstrap.openMaps(with: store.consumeResolvedMapsSession())
        } else {
            bootstrap.openSurface(route)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.24)) {
            proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        }
    }

    private func focus(message _: ConversationMessage, scrollProxy: ScrollViewProxy) {
        scrollToBottom(scrollProxy)
    }
}

private struct ConversationInboxRow: View {
    let message: ConversationMessage
    let badgeCount: Int?
    let onTap: () -> Void

    private var title: String {
        switch message.role {
        case .assistant:
            if message.tags.contains("Maps") || message.tags.contains("Route") || message.tags.contains("路线") {
                return "Maps"
            }
            if message.tags.contains("Health") {
                return "Health"
            }
            if message.tags.contains("AI") {
                return "AI"
            }
            if message.tags.contains("Store") {
                return "Store"
            }
            return "kAir"
        case .user:
            return "User"
        case .system:
            return "System"
        }
    }

    private var avatarLabel: String {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let pieces = title.split(separator: " ")
        if pieces.count > 1 {
            return pieces.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        }
        return String(title.prefix(2)).uppercased()
    }

    private var timestamp: String {
        message.timestamp.formatted(date: .omitted, time: .shortened)
    }

    private var subtitle: String {
        let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Ready." : trimmed
    }

    var body: some View {
        if message.continuationEvent != nil {
            continuationLayout
        } else {
            Button(action: onTap) {
                standardLayout
            }
            .buttonStyle(.plain)
        }
    }

    private var avatar: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.74, green: 0.74, blue: 0.79),
                        Color(red: 0.62, green: 0.62, blue: 0.67)
                    ],
                    center: .topLeading,
                    startRadius: 2,
                    endRadius: 34
                )
            )
            .frame(width: 50, height: 50)
            .overlay(
                Text(avatarLabel)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.white)
            )
            .padding(.top, 2)
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.black)
                .lineLimit(1)

            Spacer(minLength: 10)

            Text(timestamp)
                .font(.title3.weight(.regular))
                .foregroundStyle(Color.black.opacity(0.88))
                .lineLimit(1)
        }
    }

    private var standardLayout: some View {
        HStack(alignment: .top, spacing: 14) {
            avatar
            VStack(alignment: .leading, spacing: 4) {
                headerRow
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(subtitle)
                        .font(.title3.weight(.regular))
                        .foregroundStyle(Color.black.opacity(0.92))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    if let badgeCount, badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 22, minHeight: 22)
                            .padding(.horizontal, 2)
                            .background(
                                Circle()
                                    .fill(Color(red: 0.90, green: 0.23, blue: 0.20))
                            )
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var continuationLayout: some View {
        if let event = message.continuationEvent {
            HStack(alignment: .top, spacing: 14) {
                avatar
                VStack(alignment: .leading, spacing: 8) {
                    headerRow
                    ContinuationBlockRenderer(event: event)
                }
            }
            .padding(.vertical, 14)
        }
    }
}

private struct EmptyConversationState: View {
    let prompts: [String]
    let onTapPrompt: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Ask me anything.")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.black)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(prompts, id: \.self) { prompt in
                        Button {
                            onTapPrompt(prompt)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(prompt)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.black)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)

                                Text("Start from intent")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(Color.black.opacity(0.45))
                            }
                            .frame(width: 180, alignment: .leading)
                            .padding(14)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 18,
                                    style: .continuous
                                )
                                .fill(Color.white)
                            )
                            .overlay(
                                RoundedRectangle(
                                    cornerRadius: 18,
                                    style: .continuous
                                )
                                .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 22, x: 0, y: 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct FloatingAskComposer: View {
    @Binding var text: String

    let placeholder: String
    let onSend: () -> Void
    let onUserTap: () -> Void

    private var canSend: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(1 ... 3)
                    .font(.title3.weight(.regular))
                    .foregroundStyle(Color.black)
                    .submitLabel(.send)
                    .onSubmit(onSend)

                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(canSend ? Color.white : Color.black.opacity(0.35))
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(canSend ? Color.black : Color.black.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .disabled(canSend == false)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.09), radius: 20, x: 0, y: 8)

            Button(action: onUserTap) {
                Text("User")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.09), radius: 20, x: 0, y: 8)
            }
            .buttonStyle(.plain)
        }
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
