//
//  ChatHomeView.swift
//  kAir
//
//  Direct chat home plus focused conversation thread for kAir.
//

import SwiftUI

struct ChatHomeView: View {
    let bootstrap: AppBootstrap

    @State private var storeHolder = ChatStoreHolder()
    @State private var isConversationPresented = false
    @State private var isReferencePickerPresented = false
    @State private var isRecommendedNextExpanded = true

    private var dashboard: HealthDashboard? {
        bootstrap.healthStore.dashboard
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { store.draft },
            set: { store.draft = $0 }
        )
    }

    private var templateChatBinding: Binding<Bool> {
        Binding(
            get: { store.isTemplateChat },
            set: { store.isTemplateChat = $0 }
        )
    }

    private var store: ChatStore {
        if let existingStore = storeHolder.store {
            return existingStore
        }

        let createdStore = ChatStore(replayLab: bootstrap.matchingReplayLab)
        storeHolder.store = createdStore
        return createdStore
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 16) {
                    ChatHomeHero(
                        sessionTitle: store.session.title,
                        summary: store.contextSummary,
                        contextItems: store.homeContextItems
                    )

                    if store.canResumeThread {
                        ContinueThreadCard(
                            preview: store.latestMessagePreview,
                            timestamp: store.latestActivityDate,
                            onTap: {
                                isConversationPresented = true
                            }
                        )
                    }

                    if store.recommendedMatches.isEmpty == false {
                        LazyVStack(spacing: 16) {
                            ForEach(store.recommendedMatches) { recommendation in
                                if let mapCard = mapActionCardModel(for: recommendation) {
                                    MapActionCardView(
                                        model: mapCard,
                                        trustPills: mapCardTrustPills(for: mapCard),
                                        onImpression: { },
                                        onTap: {
                                            recordRecommendationClick(recommendation)
                                        },
                                        onAccept: {
                                            acceptHomeRecommendation(recommendation)
                                        },
                                        onDismiss: { feedback in
                                            store.dismissRecommendation(
                                                recommendation,
                                                feedback: feedback
                                            )
                                        }
                                    )
                                } else {
                                    UnifiedActionCard(
                                        candidate: recommendation.candidate,
                                        reasonText: recommendation.breakdown.reasonCodes.first?.userFacingText,
                                        primaryActionTitle: recommendation.package.ctaTitle,
                                        onPrimaryAction: {
                                            acceptHomeRecommendation(recommendation)
                                        },
                                        onCardTap: {
                                            recordRecommendationClick(recommendation)
                                        },
                                        onFeedback: { feedback in
                                            store.dismissRecommendation(
                                                recommendation,
                                                feedback: feedback
                                            )
                                        }
                                    )
                                }
                            }
                        }
                    }

                    Spacer(minLength: 220)
                }
                .padding(.horizontal, AppTheme.Metrics.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 140)
                .frame(maxWidth: .infinity, alignment: .top)
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
            bootstrap.mapsRuntime.registerThreadReturnHandler { task in
                store.recordMapReturn(from: task)
            }
            bootstrap.registerSurfaceReturnHandler { context in
                store.recordSurfaceReturn(
                    from: context,
                    dashboard: bootstrap.healthStore.dashboard,
                    healthSession: bootstrap.activeHealthSession
                )
            }
            bootstrap.registerSurfaceSilentExitHandler { section in
                store.recordSilentSurfaceExit(section)
            }
            bootstrap.registerSurfaceEntryEventHandler { phase, request in
                store.handleSurfaceEntryEvent(phase: phase, request: request)
            }
            bootstrap.registerSurfaceEntryRequestProvider { section in
                store.pendingSurfaceEntryRequest(for: section)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ChatHomeTopBar(
                onAddTap: {
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
            VStack(spacing: 0) {
                if store.recommendedMatches.isEmpty == false {
                    RecommendedNextConsole(
                        recommendations: store.recommendedMatches,
                        isExpanded: isRecommendedNextExpanded,
                        onToggle: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isRecommendedNextExpanded.toggle()
                            }
                        },
                        onRecommendationTap: recordRecommendationClick,
                        onRecommendationAccept: acceptHomeRecommendation,
                        onRecommendationFeedback: { recommendation, feedback in
                            store.dismissRecommendation(
                                recommendation,
                                feedback: feedback
                            )
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if store.suggestedPrompts.isEmpty == false && store.recommendedMatches.isEmpty {
                    ConversationPromptTray(
                        prompts: store.suggestedPrompts,
                        onTapPrompt: submitHomePrompt
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                }

                FloatingAskComposer(
                    text: draftBinding,
                    isTemplateChat: templateChatBinding,
                    placeholder: "Talk to kAir",
                    onSend: sendFromHomeComposer,
                    onReferenceTap: {
                        isReferencePickerPresented = true
                    },
                    onProfileTap: bootstrap.showProfile
                )
                .padding(.horizontal, 18)
                .padding(.top, store.recommendedMatches.isEmpty ? 4 : 0)
                .padding(.bottom, 12)
            }
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.001), Color.white.opacity(0.8), .white, .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )
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

        Task {
            let route = await store.sendDraft(
                using: dashboard,
                mapsRuntime: bootstrap.mapsRuntime
            )
            isConversationPresented = true
            handleRoute(route)
        }
    }

    private func submitHomePrompt(_ prompt: String) {
        Task {
            let route = await store.submitPrompt(
                prompt,
                using: dashboard,
                mapsRuntime: bootstrap.mapsRuntime
            )
            isConversationPresented = true
            handleRoute(route)
        }
    }

    private func recordRecommendationClick(_ recommendation: UnifiedMatchRecommendation) {
        store.recordRecommendationTap(recommendation)
    }

    private func acceptHomeRecommendation(_ recommendation: UnifiedMatchRecommendation) {
        store.prepareRecommendationForAccept(recommendation)
        submitHomePrompt(recommendation.candidate.activationPrompt)
    }

    private func handleReference(_ reference: ReferenceAttachment) {
        store.attachReference(
            reference.title,
            detail: reference.selectionDetail
        )
        isConversationPresented = true
    }

    private func handleRoute(_ route: ConversationRoute?) {
        guard let route else { return }

        if store.shouldRecordGenericHandoff(for: route) {
            store.recordHandoff(for: route)
        }

        switch route.destination {
        case .surface(.maps):
            bootstrap.openMaps(with: store.consumeResolvedMapTask())
        case .surface(.health):
            bootstrap.openHealth(with: store.consumeResolvedHealthSession())
        case .surface(.music):
            bootstrap.openMusic(with: store.consumeResolvedMusicSession())
        case .surface(.video):
            bootstrap.openVideo(with: store.consumeResolvedVideoSession())
        case .surface(let section):
            bootstrap.openSurface(section)
        case .persistentPlayer:
            if let session = store.consumeResolvedMusicSession() {
                bootstrap.startMusic(with: session)
            }
        case .userProfile:
            bootstrap.showProfile()
        }
    }

    private func mapActionCardModel(
        for recommendation: UnifiedMatchRecommendation
    ) -> MapActionCardModel? {
        guard recommendation.candidate.preferredSection == .maps else { return nil }
        let language = store.preferredMapsLanguage
        let recommendationId = store.currentRecommendationId
        return MapActionCardModel.fromRecommendation(
            recommendation,
            recommendationId: recommendationId,
            threadId: store.session.id,
            language: language
        )
    }

    private func mapCardTrustPills(for card: MapActionCardModel) -> [ActionCardTrustPillKind] {
        let permission = bootstrap.mapsRuntime.permissionState
        let metadata = MapActionCardTrustMetadata(
            placeResolution: .estimated,
            etaConfidence: card.taskKind == .nearbySearch ? .unavailable : .estimated,
            distanceConfidence: .estimated,
            partnerState: .pending,
            permissionState: permission
        )
        return metadata.pills
    }
}

private final class ChatStoreHolder {
    var store: ChatStore?
}

private struct RecommendedNextConsole: View {
    let recommendations: [UnifiedMatchRecommendation]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onRecommendationTap: (UnifiedMatchRecommendation) -> Void
    let onRecommendationAccept: (UnifiedMatchRecommendation) -> Void
    let onRecommendationFeedback: (UnifiedMatchRecommendation, MatchingFeedbackKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.black.opacity(0.8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recommended Next")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.82))

                        Text("\(recommendations.count) next-step suggestions ready")
                            .font(.caption)
                            .foregroundStyle(Color.black.opacity(0.48))
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                        .foregroundStyle(Color.black.opacity(0.2))
                        .font(.title3)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recommendations) { recommendation in
                            RecommendedNextCell(
                                recommendation: recommendation,
                                onTap: {
                                    onRecommendationTap(recommendation)
                                },
                                onPrimaryAction: {
                                    onRecommendationAccept(recommendation)
                                },
                                onFeedback: { feedback in
                                    onRecommendationFeedback(recommendation, feedback)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    )
                )
            }
        }
        .background(
            Color.white.opacity(0.85)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.06), radius: 24, x: 0, y: -8)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white, lineWidth: 1)
                )
        )
    }
}

private struct RecommendedNextCell: View {
    let recommendation: UnifiedMatchRecommendation
    let onTap: () -> Void
    let onPrimaryAction: () -> Void
    let onFeedback: (MatchingFeedbackKind) -> Void

    private var reasonText: String {
        recommendation.breakdown.reasonCodes.first?.userFacingText ?? recommendation.candidate.summary
    }

    private var constraintLabel: String {
        if let section = recommendation.candidate.preferredSection {
            return section.title
        }
        return recommendation.candidate.objectKind.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onTap) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            recommendation.candidate.objectKind.title,
                            systemImage: recommendation.candidate.objectKind.systemImage
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.56))

                        Text(recommendation.candidate.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.84))
                            .lineLimit(2)

                        Text(reasonText)
                            .font(.caption)
                            .foregroundStyle(Color.black.opacity(0.48))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Menu {
                    ForEach(MatchingFeedbackKind.allCases, id: \.self) { feedback in
                        Button {
                            onFeedback(feedback)
                        } label: {
                            Label(feedback.title, systemImage: feedback.systemImage)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.headline)
                        .foregroundStyle(Color.black.opacity(0.38))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Text(constraintLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.black.opacity(0.56))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.05))
                    )

                Spacer()

                Button(action: onPrimaryAction) {
                    Label("Go", systemImage: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.82))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 230, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
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
            AppBackground()

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
                                    MessageBubble(
                                        message: message,
                                        onAction: { action in
                                            handleConversationAction(action, scrollProxy: proxy)
                                        }
                                    )
                                }
                            }
                        }



                        if store.recommendedMatches.isEmpty == false {
                            LazyVStack(spacing: 16) {
                                ForEach(store.recommendedMatches) { recommendation in
                                    UnifiedActionCard(
                                        candidate: recommendation.candidate,
                                        reasonText: recommendation.breakdown.reasonCodes.first?.userFacingText,
                                        primaryActionTitle: recommendation.package.ctaTitle,
                                        onPrimaryAction: {
                                            store.prepareRecommendationForAccept(recommendation)
                                            submit(recommendation.candidate.activationPrompt, scrollProxy: proxy)
                                        },
                                        onCardTap: {
                                            store.recordRecommendationTap(recommendation)
                                        },
                                        onFeedback: { feedback in
                                            store.dismissRecommendation(
                                                recommendation,
                                                feedback: feedback
                                            )
                                        }
                                    )
                                }
                            }
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
                .onAppear {
                    guard threadMessages.isEmpty == false else { return }
                    DispatchQueue.main.async {
                        scrollToBottom(proxy)
                    }
                }
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
                onAddTap: {
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
            VStack(spacing: 0) {
                if store.suggestedPrompts.isEmpty == false {
                    ConversationPromptTray(
                        prompts: store.suggestedPrompts,
                        onTapPrompt: { prompt in
                            submit(prompt, scrollProxy: nil)
                        }
                    )
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }

                ConversationThreadComposer(
                    text: $store.draft,
                    isTemplateChat: $store.isTemplateChat,
                    onSend: sendFromComposer,
                    onReferenceTap: {
                        isReferencePickerPresented = true
                    }
                )
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
            .background(AppTheme.Palette.backgroundInset.opacity(0.96))
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func submit(_ prompt: String, scrollProxy: ScrollViewProxy?) {
        Task {
            let route = await store.submitPrompt(
                prompt,
                using: dashboard,
                mapsRuntime: bootstrap.mapsRuntime
            )
            handleRoute(route)
            if let proxy = scrollProxy {
                scrollToBottom(proxy)
            }
        }
    }

    private func handleReference(_ reference: ReferenceAttachment) {
        store.attachReference(
            reference.title,
            detail: reference.selectionDetail
        )
    }

    private func sendFromComposer() {
        let prompt = store.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.isEmpty == false else { return }

        Task {
            let route = await store.sendDraft(
                using: dashboard,
                mapsRuntime: bootstrap.mapsRuntime
            )
            handleRoute(route)
        }
    }

    private func handleRoute(_ route: ConversationRoute?) {
        guard let route else { return }

        if store.shouldRecordGenericHandoff(for: route) {
            store.recordHandoff(for: route)
        }

        switch route.destination {
        case .surface(.maps):
            bootstrap.openMaps(with: store.consumeResolvedMapTask())
        case .surface(.health):
            bootstrap.openHealth(with: store.consumeResolvedHealthSession())
        case .surface(.music):
            bootstrap.openMusic(with: store.consumeResolvedMusicSession())
        case .surface(.video):
            bootstrap.openVideo(with: store.consumeResolvedVideoSession())
        case .surface(let section):
            bootstrap.openSurface(section)
        case .persistentPlayer:
            if let session = store.consumeResolvedMusicSession() {
                bootstrap.startMusic(with: session)
            }
        case .userProfile:
            bootstrap.showProfile()
        }
    }

    private func handleConversationAction(
        _ action: ConversationToolAction,
        scrollProxy: ScrollViewProxy
    ) {
        Task {
            let route = await store.handleConversationAction(
                action,
                using: dashboard,
                mapsRuntime: bootstrap.mapsRuntime
            )
            handleRoute(route)
            scrollToBottom(scrollProxy)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.24)) {
            proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        }
    }
}

private struct ChatHomeTopBar: View {
    let onAddTap: () -> Void

    var body: some View {
        HStack {
            Text("kAir")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            Spacer()

            Button(action: onAddTap) {
                Label("Add", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.9))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(AppTheme.Palette.line, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.Metrics.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            AppTheme.Palette.backgroundStart
                .ignoresSafeArea(edges: .top)
        )
    }
}

private struct ChatHomeHero: View {
    let sessionTitle: String
    let summary: String
    let contextItems: [ConversationContextItem]

    var body: some View {
        KAirSurface(style: .hero) {
            VStack(alignment: .leading, spacing: 16) {
                KAirPageHeader(
                    title: "Talk to \(sessionTitle)",
                    summary: "This is the main place to talk to kAir. Start with a direct request, then let the thread open Health, Maps, Music, Video, AI, or Store only when it needs a deeper surface.",
                    badges: [
                        KAirHeaderBadge(title: "Direct chat", systemImage: "bubble.left.and.bubble.right", tint: AppTheme.Palette.accentStrong),
                        KAirHeaderBadge(title: "Same thread", systemImage: "arrow.triangle.branch", tint: AppTheme.Palette.sky),
                        KAirHeaderBadge(title: "Add references", systemImage: "plus.circle", tint: AppTheme.Palette.warning)
                    ]
                )

                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 120), spacing: 10)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(contextItems) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(item.title, systemImage: item.systemImage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.textMuted)

                            Text(item.value)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.Palette.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(
                                cornerRadius: AppTheme.Metrics.compactRadius,
                                style: .continuous
                            )
                            .fill(AppTheme.Palette.surface)
                        )
                    }
                }
            }
        }
    }
}

private struct ContinueThreadCard: View {
    let preview: String
    let timestamp: Date?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Continue last thread")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text(preview)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 8) {
                    if let timestamp {
                        Text(
                            timestamp.formatted(
                                .dateTime
                                    .month()
                                    .day()
                                    .hour()
                                    .minute()
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.textMuted)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Palette.textMuted)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(
                    cornerRadius: AppTheme.Metrics.cardRadius,
                    style: .continuous
                )
                .fill(Color.white.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: AppTheme.Metrics.cardRadius,
                    style: .continuous
                )
                .strokeBorder(AppTheme.Palette.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ConversationThreadTopBar: View {
    let title: String
    let onBackTap: () -> Void
    let onAddTap: () -> Void

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

                Button(action: onAddTap) {
                    Label("Add", systemImage: "plus")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.9))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(AppTheme.Palette.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .background(
            AppTheme.Palette.backgroundStart
                .ignoresSafeArea(edges: .top)
        )
    }
}

private struct ConversationPromptTray: View {
    let prompts: [String]
    let onTapPrompt: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

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

            Text("Start with a direct request, then let the thread open Health, Maps, Music, Video, AI, or Store only when it needs to.")
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
    let onReferenceTap: (() -> Void)?
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
                    if let onReferenceTap {
                        Button(action: onReferenceTap) {
                            Image(systemName: "plus.circle")
                                .font(.title3.weight(.regular))
                                .foregroundStyle(Color.black.opacity(0.72))
                        }
                        .buttonStyle(.plain)
                    }

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
            return "Reserved for a later pass; media is not attached yet."
        case .store:
            return "Reserved for a later pass; no commerce context is attached yet."
        }
    }

    var selectionDetail: String {
        switch self {
        case .health:
            return "The latest local Apple Health snapshot is now part of this same thread."
        case .location:
            return "Current location is now part of this thread for nearby and route work."
        case .photo:
            return "Photo and file intake is still reserved. This thread keeps only a placeholder note for now."
        case .store:
            return "Store intent is still reserved. This thread keeps only a shopping hint for now."
        }
    }

    var statusTitle: String {
        switch self {
        case .health, .location:
            return "Ready"
        case .photo, .store:
            return "Planned"
        }
    }

    var statusTint: Color {
        switch self {
        case .health:
            return AppTheme.Palette.success
        case .location:
            return AppTheme.Palette.sky
        case .photo, .store:
            return AppTheme.Palette.warning
        }
    }

    var statusSystemImage: String {
        switch self {
        case .health, .location:
            return "checkmark.circle.fill"
        case .photo, .store:
            return "clock"
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
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: attachment.systemImage)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(attachment.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.Palette.textPrimary)

                                Spacer(minLength: 8)

                                KAirStatusPill(
                                    title: attachment.statusTitle,
                                    systemImage: attachment.statusSystemImage,
                                    tint: attachment.statusTint
                                )
                            }

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
