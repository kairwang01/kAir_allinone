//
//  ChatHomeView.swift
//  Kair Health
//
//  Primary all-in-one conversation surface for kAir.
//

import SwiftUI

struct ChatHomeView: View {
    let bootstrap: AppBootstrap

    @State private var store = ChatStore()
    @State private var isReferencePickerPresented = false

    private static let bottomAnchorID = "kair-chat-bottom"

    private var dashboard: HealthDashboard? {
        bootstrap.healthStore.dashboard
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ConversationHeader(
                            summary: dashboard?.hero.summary ?? "All of kAir starts from one calm, continuous conversation.",
                            refreshedAt: dashboard?.generatedAt,
                            onAddReference: {
                                isReferencePickerPresented = true
                            },
                            onProfile: bootstrap.showProfile
                        )

                        if store.suggestedPrompts.isEmpty == false {
                            PromptRail(
                                prompts: store.suggestedPrompts,
                                onTap: { prompt in
                                    submit(prompt, scrollProxy: proxy)
                                }
                            )
                        }

                        VStack(spacing: 24) {
                            ForEach(store.session.messages) { message in
                                MessageBubble(message: message)
                            }

                            Color.clear
                                .frame(height: 1)
                                .id(Self.bottomAnchorID)
                        }
                    }
                    .padding(.horizontal, AppTheme.Metrics.screenPadding)
                    .padding(.top, 10)
                    .padding(.bottom, 152)
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
            ComposerBar(
                text: $store.draft,
                placeholder: "Ask about health, AI, nearby places, or what to buy…",
                contextSummary: store.contextSummary,
                modes: store.modes,
                selectedModeID: store.selectedModeID,
                accessories: store.accessories,
                onSelectMode: store.selectMode,
                onAccessoryTap: handleAccessory,
                onSend: sendFromComposer
            )
            .padding(.horizontal, AppTheme.Metrics.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(bottomOverlay)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var bottomOverlay: some View {
        LinearGradient(
            colors: [
                Color.clear,
                AppTheme.Palette.backgroundEnd.opacity(0.88),
                AppTheme.Palette.backgroundEnd
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
        if let route {
            store.recordHandoff(to: route)
            bootstrap.openSurface(route)
        }
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
        store.sendDraft(using: dashboard)

        if let route {
            store.recordHandoff(to: route)
            bootstrap.openSurface(route)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.snappy(duration: 0.28)) {
            proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        }
    }
}

private struct ConversationHeader: View {
    let summary: String
    let refreshedAt: Date?
    let onAddReference: () -> Void
    let onProfile: () -> Void

    var body: some View {
        KairSurface(style: .hero, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("kAir")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Chat is the home. Everything else is invoked.")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.Palette.textMuted)
                    }

                    Spacer(minLength: 12)

                    HStack(spacing: 10) {
                        Button(action: onProfile) {
                            Circle()
                                .fill(AppTheme.Palette.surfaceStrong)
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Text("K")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppTheme.Palette.textOnStrong)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open profile and settings")

                        Button(action: onAddReference) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.74))
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(AppTheme.Palette.textPrimary)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add reference")
                    }
                }

                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                HStack(spacing: 8) {
                    KairStatusPill(
                        title: "Local-first",
                        systemImage: "lock.shield",
                        tint: AppTheme.Palette.success
                    )

                    if let refreshedAt {
                        KairStatusPill(
                            title: refreshedAt.formatted(.dateTime.hour().minute()),
                            systemImage: "clock",
                            tint: AppTheme.Palette.sky
                        )
                    }

                    KairStatusPill(
                        title: "Chat Home",
                        systemImage: "bubble.left.and.bubble.right",
                        tint: AppTheme.Palette.accent
                    )
                }
            }
        }
    }
}

private struct PromptRail: View {
    let prompts: [String]
    let onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick starts")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textMuted)
                .tracking(0.8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(prompts, id: \.self) { prompt in
                        Button {
                            onTap(prompt)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(prompt)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppTheme.Palette.textPrimary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)

                                Text("Start from intent")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(AppTheme.Palette.textMuted)
                            }
                            .frame(width: 180, alignment: .leading)
                            .padding(14)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: AppTheme.Metrics.compactRadius + 2,
                                    style: .continuous
                                )
                                .fill(Color.white.opacity(0.66))
                            )
                            .overlay(
                                RoundedRectangle(
                                    cornerRadius: AppTheme.Metrics.compactRadius + 2,
                                    style: .continuous
                                )
                                .strokeBorder(AppTheme.Palette.line, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
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
