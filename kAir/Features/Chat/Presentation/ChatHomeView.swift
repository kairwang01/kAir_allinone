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

    /// I2 step 2 (chat-home §9): the staged direct-submit confirmation /
    /// clarification gate, or `nil` when no raw submit is awaiting the
    /// user's explicit accept. View-local and ephemeral — not part of the
    /// persisted `ChatStore` session.
    @State private var pendingGate: PendingGate?

    /// V1 (chat-home §3.3): the `RecommendedNextConsole` expand/collapse
    /// state. Expanded is the default for the first display; the choice
    /// then persists for this view session only.
    @State private var isRecommendedNextExpanded = true

    /// Composes `ChatStore` with the runtime + handoff wired by
    /// `AppBootstrap`.
    ///
    /// Per `Contracts/UX/feedback-runtime-v1.md` §5 + Main A.1 / A.2
    /// wiring, the recommendation provider, feedback runtime, the
    /// completed-recommendation handoff, the telemetry emitter, the
    /// capability registry, AND the provider-status source are owned by
    /// the composition root (`AppBootstrap`), not by `ChatStore`. The view
    /// threads them through at construction time.
    ///
    /// This `init` is the single composition seam between the
    /// `AppBootstrap` and `ChatStore`. Per Main C scope, the only
    /// addition here is the `capabilityRegistry:` argument; no view
    /// logic, no rendering, no new behavior in this view.
    init(bootstrap: AppBootstrap) {
        self.bootstrap = bootstrap
        self._store = State(
            wrappedValue: ChatStore(
                recommendationProvider: bootstrap.recommendationProvider,
                providerStatusProvider: bootstrap.providerStatusProvider,
                feedbackRuntime: bootstrap.feedbackRuntime,
                completedRecommendationHandoff: bootstrap.completedRecommendationHandoff,
                telemetryEmitter: bootstrap.telemetryEmitter,
                capabilityRegistry: bootstrap.capabilityRegistry,
                textGenerator: bootstrap.textGenerator,
                enabledSurfaces: bootstrap.enabledSurfaces
            )
        )
    }

    /// Whether the capability-routing chrome (search-availability strip,
    /// recommended-next console) is shown. Hidden in the local-first v1 where
    /// only Chat + Health ship, keeping the surface a clean conversation.
    private var showsCapabilityChrome: Bool {
        bootstrap.enabledSurfaces.contains(.maps)
            || bootstrap.enabledSurfaces.contains(.store)
            || bootstrap.enabledSurfaces.contains(.search)
            || bootstrap.enabledSurfaces.contains(.ai)
    }

    private static let bottomAnchorID = "kair-chat-bottom"

    /// Scroll-to-bottom uses the `.standard` motion tier per
    /// `design-system-v1.md` §3.6. The previous inline
    /// `.easeInOut(duration: 0.24)` was exactly this tier; this
    /// replaces it with the shared token. Exposed (internal) so the
    /// token-wiring test can assert `scrollMotion == AppTheme.Motion.standard`.
    static let scrollMotion = AppTheme.Motion.standard

    /// Elevation tier for the chat surfaces (assistant card, composer
    /// bar, adjacent capsule button) per `design-system-v1.md` §3.5.
    ///
    /// Tier 2 migration (audit §8.1 box 2): the three previous inline
    /// shadows here (α 0.08 / blur 22 / y 10 and α 0.09 / blur 20 /
    /// y 8 ×2) were off-grid AND un-enumerated by the contract §6
    /// note. Per §6's blanket ruling — "Off-grid shadows … reroute to
    /// `elevation.raised` on next touch" — all three resolve to
    /// `.raised`. Exposed (internal) for the token-wiring test.
    static let surfaceElevation = AppTheme.Elevation.raised

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
                            // I2 step 1 (de-inbox): the transcript renders as
                            // role-aware chat bubbles, not tappable inbox rows.
                            // `MessageBubble` handles user / assistant / tool
                            // results; messages carrying a `continuationEvent`
                            // project through `ContinuationBlockRenderer`.
                            LazyVStack(alignment: .leading, spacing: 20) {
                                ForEach(visibleMessages) { message in
                                    transcriptRow(message)
                                }
                            }
                        }

                        // I2 step 2 (chat-home §9): the direct-submit
                        // confirmation / clarification gate renders in the
                        // Layer-2 card stream. A raw submit stages it; only an
                        // explicit accept opens a surface.
                        if let gate = pendingGate {
                            DirectSubmitGate(
                                gate: gate,
                                onOpen: { section in acceptGate(section) },
                                onKeepChatting: { dismissGate() },
                                choices: [.health, .ai, .maps, .store].filter {
                                    bootstrap.enabledSurfaces.contains($0)
                                }
                            )
                            .padding(.top, 16)
                        }

                        // V1 (Layer-4): Recommended Next now renders as the
                        // `RecommendedNextConsole` in the bottom safe-area
                        // inset (above the composer) — see
                        // `.safeAreaInset(edge: .bottom)` — not inline in the
                        // Layer-2 scroll stream.

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
                .onAppear {
                    // Main D: install the transcript projection sink.
                    // `AppBootstrap.recordSurfaceReturn(_:)` calls this
                    // handler with the built `ChatContinuationEvent` when
                    // `renderEligible == true`. The chat store then
                    // appends the assistant message per
                    // `continuation-runtime-v1.md` §8.1 (option b).
                    //
                    // Installed in `onAppear` rather than `init` because
                    // `@State` initialization happens before SwiftUI has
                    // wired the view's identity; reinstalling on each
                    // appearance is idempotent (same closure, same store
                    // reference).
                    bootstrap.continuationHandler = { [weak store] event in
                        store?.recordContinuation(event)
                    }

                    // Main D.1: install the telemetry-identifier
                    // resolver. `AppBootstrap.recordSurfaceReturn(_:)`
                    // calls this to populate the §5.2 propagation
                    // matrix for `transcript.continuation.append` /
                    // `.silent`. Returns `(nil, nil)` if the chat
                    // store has been torn down (defensive); in that
                    // case the telemetry emit is silently skipped.
                    bootstrap.surfaceTelemetryIdentifiers = { [weak store] in
                        guard let store else { return (nil, nil) }
                        return (store.lastIssuedTraceID, store.telemetryThreadID)
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
                attachments: ReferenceAttachment.allCases.filter { reference in
                    switch reference {
                    case .health: return true
                    case .location: return bootstrap.enabledSurfaces.contains(.maps)
                    case .store: return bootstrap.enabledSurfaces.contains(.store)
                    case .photo: return false   // visual/file intake not implemented yet
                    }
                },
                onSelect: handleReference
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .safeAreaInset(edge: .bottom) {
            // V1: Layer-4 projection of Recommended Next. This is bottom
            // chrome, not a Layer-2 transcript/card-stream element.
            // The bottom inset owns both the recommendation console and
            // composer so neither overlays transcript content or competes
            // for safe-area space.
            VStack(spacing: 12) {
                if showsCapabilityChrome {
                    SearchAvailabilityIndicator(display: store.searchAvailabilityDisplay)

                    if store.recommendedMatches.isEmpty == false {
                        RecommendedNextConsole(
                            objects: store.recommendedMatches,
                            isExpanded: $isRecommendedNextExpanded,
                            providerStatus: { object in
                                store.providerStatusPresentation(for: object.id)
                            },
                            onAccept: { object in acceptRecommendation(object) },
                            onDismiss: { object in
                                store.dismissRecommendation(object, feedback: .dismiss)
                            },
                            onFeedback: { object, kind in
                                store.dismissRecommendation(object, feedback: kind)
                            }
                        )
                    }
                }

                FloatingAskComposer(
                    text: $store.draft,
                    placeholder: "Message kAir",
                    onSend: sendFromComposer,
                    onUserTap: bootstrap.showProfile
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(Color.white.opacity(0.001))
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func submit(_ prompt: String, scrollProxy: ScrollViewProxy) {
        // I2 step 2 (chat-home §9): a raw submit appends the user message
        // as today, then stages a confirmation / clarification gate. It does
        // NOT open a surface — only an explicit accept on the gate card
        // calls `handleRoute` (see `acceptGate`).
        let route = store.route(for: prompt)
        store.submitPrompt(prompt, using: dashboard)
        stageGateIfNeeded(prompt: prompt, route: route)
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
                detail: "Photo and file context is added to the conversation."
            )
        case .store:
            store.attachReference(
                "Store intent",
                detail: "The conversation can now bias toward curated product suggestions."
            )
        }
    }

    /// I2 step 1 (de-inbox): one transcript row per message. A message
    /// carrying a structured `continuationEvent` projects through
    /// `ContinuationBlockRenderer` (assistant-side, leading); everything
    /// else renders through the shared role-aware `MessageBubble`. No
    /// avatar, no timestamp header, no unread badge, no tap target — this
    /// is thread content, not an inbox row.
    @ViewBuilder
    private func transcriptRow(_ message: ConversationMessage) -> some View {
        if let event = message.continuationEvent {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    ContinuationBlockRenderer(event: event)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 52)
            }
        } else {
            MessageBubble(message: message)
        }
    }

    private func sendFromComposer() {
        let prompt = store.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.isEmpty == false else { return }

        // I2 step 2 (chat-home §9): stage the gate; do not open a surface
        // until the user accepts the gate card. See `acceptGate`.
        let route = store.route(for: prompt)
        store.sendDraft(using: dashboard)
        stageGateIfNeeded(prompt: prompt, route: route)
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

    /// I2 step 2: the user explicitly accepted a gate card for `section`.
    /// This is the single sanctioned bridge from a raw submit to a surface
    /// (chat-home §9.1): clear the gate, then route — preserving the Maps
    /// session consumption in `handleRoute`.
    private func acceptGate(_ section: AppSection) {
        pendingGate = nil
        handleRoute(section)
    }

    /// I2 step 2: do not stack the generic capability gate on top of the
    /// existing Maps-specific mode clarification. For prompts like
    /// "I want to go to Apple Store", `ChatStore` first captures the
    /// destination and asks for drive/walk; the explicit surface gate
    /// belongs after the user provides that mode and `route(for:)`
    /// resolves `.maps`.
    private func stageGateIfNeeded(prompt: String, route: AppSection?) {
        if route == nil, latestMessageIsPendingMapsClarification {
            pendingGate = nil
            return
        }
        pendingGate = PendingGate(prompt: prompt, route: route)
    }

    private var latestMessageIsPendingMapsClarification: Bool {
        store.session.messages.last?.toolResults.contains { result in
            result.id == "maps_route_pending"
        } == true
    }

    /// I2 step 2: "Keep chatting" / dismiss on a gate card. Clears the gate
    /// and opens nothing. It does NOT write a surface handoff or route into
    /// the recommendation-feedback path (chat-home §9.3 / §9.5).
    private func dismissGate() {
        pendingGate = nil
    }

    /// V1 step 2 (chat-home §3.5): the positive accept path for a
    /// Recommended Next card (the rail's primary CTA). The store removes the
    /// target and writes its activation prompt; if the route resolves, the
    /// view opens the surface — reusing `handleRoute`, which records the
    /// handoff. `prepareRecommendationForAccept` clears any raw Maps route
    /// context first, so this path cannot consume a stale composer Maps
    /// session. A non-resolvable route leaves the thread write as the only
    /// effect (no guessing). This is **not** the §9 raw-submit gate and emits
    /// no feedback event.
    private func acceptRecommendation(_ object: MatchingObject) {
        switch store.prepareRecommendationForAccept(object) {
        case .unknown, .threadOnly:
            break
        case .route(let section):
            handleRoute(section)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(Self.scrollMotion) {
            proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        }
    }
}

// MARK: - Search availability indicator

struct SearchAvailabilityIndicatorContent: Equatable {
    let systemImage: String
    let statusLine: String
    let accessibilityLabel: String
    let tone: ChatSearchAvailabilityDisplay.Tone
}

/// A41: non-interactive Search boundary copy for the Chat chrome. This view is
/// intentionally read-only: no tap, no button, no route, no prompt submit.
struct SearchAvailabilityIndicator: View {
    static let typography = AppTheme.Typography.chip
    static let borderWidth: CGFloat = 0.8

    let display: ChatSearchAvailabilityDisplay

    var body: some View {
        if let content = Self.content(for: display) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: content.systemImage)
                        .font(.caption.weight(.semibold))

                    Text(verbatim: content.statusLine)
                        .kAirTypography(Self.typography)
                        .lineLimit(1)
                }
                .foregroundStyle(Self.foregroundColor(for: content.tone))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(Self.backgroundColor(for: content.tone))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            Self.borderColor(for: content.tone),
                            lineWidth: Self.borderWidth
                        )
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(content.accessibilityLabel))
                .accessibilityIdentifier("chat-search-availability-indicator")

                Spacer(minLength: 0)
            }
        }
    }

    static func content(
        for display: ChatSearchAvailabilityDisplay
    ) -> SearchAvailabilityIndicatorContent? {
        guard display.isVisible else { return nil }

        return SearchAvailabilityIndicatorContent(
            systemImage: display.systemImage,
            statusLine: display.statusLine,
            accessibilityLabel: display.accessibilityLabel,
            tone: display.tone
        )
    }

    static func foregroundColor(
        for tone: ChatSearchAvailabilityDisplay.Tone
    ) -> Color {
        switch tone {
        case .neutral:
            return AppTheme.Palette.textMuted
        case .warning:
            return AppTheme.Palette.warning
        case .positive:
            return AppTheme.Palette.success
        }
    }

    static func backgroundColor(
        for tone: ChatSearchAvailabilityDisplay.Tone
    ) -> Color {
        foregroundColor(for: tone).opacity(0.10)
    }

    static func borderColor(
        for tone: ChatSearchAvailabilityDisplay.Tone
    ) -> Color {
        foregroundColor(for: tone).opacity(0.16)
    }
}

// `ConversationInboxRow` was removed in I2 step 1 (de-inbox). The
// transcript now renders role-aware chat bubbles via `MessageBubble`
// (user / assistant / tool-result) and `ContinuationBlockRenderer`
// (continuation events) — see `ChatHomeView.transcriptRow`.

// MARK: - Direct-submit confirmation / clarification gate (chat-home §9)

/// The staged result of a raw composer submit, awaiting the user's
/// explicit accept before any surface opens (chat-home §9.1). A non-nil
/// `route` is the high-confidence match; `nil` is the low-confidence /
/// ambiguous case that fans out to the closed-catalog clarification.
private struct PendingGate {
    let prompt: String
    let route: AppSection?
}

/// Renders the gate as Layer-2 `ActionCardShell`(s) (chat-home §9.2 / §9.3).
/// Because `ActionCardShell` exposes exactly one primary + one secondary
/// CTA, each capability is its own card — `Open {capability}` (primary) +
/// `Keep chatting` (secondary). High confidence shows one card for the
/// matched section; low confidence shows one card per closed-catalog
/// capability, in fixed order. Pure ActionCardShell syntax — no chips,
/// grid, or new container (§9.5).
private struct DirectSubmitGate: View {
    let gate: PendingGate
    let onOpen: (AppSection) -> Void
    let onKeepChatting: () -> Void

    /// The closed catalog offered when the route is ambiguous, in a fixed
    /// order (no re-sort, no grouping). The caller filters it to the surfaces
    /// enabled for this build.
    var choices: [AppSection] = [.health, .ai, .maps, .store]

    var body: some View {
        VStack(spacing: 16) {
            if let route = gate.route {
                card(for: route, highConfidence: true)
            } else {
                ForEach(choices) { section in
                    card(for: section, highConfidence: false)
                }
            }
        }
    }

    private func card(for section: AppSection, highConfidence: Bool) -> some View {
        ActionCardShell(
            object: Self.object(for: section, prompt: gate.prompt, highConfidence: highConfidence),
            onPrimaryTap: { onOpen(section) },
            onSecondaryTap: onKeepChatting,
            onDismiss: onKeepChatting,
            onFeedback: { _ in onKeepChatting() }
        )
    }

    private static func object(
        for section: AppSection,
        prompt: String,
        highConfidence: Bool
    ) -> MatchingObject {
        let name = section.title
        let preview = prompt.count > 80 ? String(prompt.prefix(79)) + "…" : prompt
        return MatchingObject(
            id: "direct-gate-\(section.rawValue)",
            kind: .toolEntry,
            title: highConfidence ? "Open \(name)?" : name,
            subtitleTokens: ["“\(preview)”"],
            reasonText: highConfidence
                ? "Confirm before opening."
                : "Not sure what you need — pick one or keep chatting.",
            primaryCTA: "Open \(name)",
            secondaryCTA: "Keep chatting"
        )
    }
}

// MARK: - Recommended Next console (Layer 4, chat-home §3)

/// V1: Layer-4 projection of Recommended Next. This is bottom chrome,
/// not a Layer-2 transcript/card-stream element. Rendered iff
/// `objects.isEmpty == false` (chat-home §3.1); the order is a 1:1 mirror
/// of `store.recommendedMatches` (§3.2 — no re-sort, no filter, no group).
/// Collapsed shows the count summary; expanded renders a compact horizontal
/// one-row tray (§3.3), not full `ActionCardShell` cards. Dismiss / feedback
/// route to `store.dismissRecommendation`; accept (the cell's primary CTA)
/// routes to `acceptRecommendation` → `store.prepareRecommendationForAccept`
/// (§3.4 / §3.5, V1 step 2). Refresh stays deferred.
private struct RecommendedNextConsole: View {
    let objects: [MatchingObject]
    @Binding var isExpanded: Bool
    let providerStatus: (MatchingObject) -> ProviderStatusPresentation?
    let onAccept: (MatchingObject) -> Void
    let onDismiss: (MatchingObject) -> Void
    let onFeedback: (MatchingObject, MatchingFeedbackKind) -> Void

    var body: some View {
        if objects.isEmpty == false {
            VStack(alignment: .leading, spacing: 12) {
                header

                if isExpanded {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(objects) { object in
                                RecommendedNextCell(
                                    object: object,
                                    providerStatus: ProviderStatusCompactCellDisplay.make(
                                        from: providerStatus(object)
                                    ),
                                    onAccept: { onAccept(object) },
                                    onDismiss: { onDismiss(object) },
                                    onFeedback: { kind in onFeedback(object, kind) }
                                )
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous)
                    .fill(AppTheme.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cardRadius, style: .continuous)
                    .strokeBorder(AppTheme.Palette.line, lineWidth: 0.8)
            )
            .kAirElevation(AppTheme.Elevation.raised)
        }
    }

    private var header: some View {
        Button {
            withAnimation(AppTheme.Motion.emphasized) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Text(isExpanded
                     ? "Recommended next"
                     : "\(objects.count) next-step suggestions ready")
                    .kAirTypography(AppTheme.Typography.chip)
                    .foregroundStyle(AppTheme.Palette.textMuted)

                Spacer(minLength: 8)

                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.textMuted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(isExpanded
            ? "Collapse recommended next"
            : "\(objects.count) next-step suggestions ready, expand"))
    }
}

/// Compact Layer-4 cell for one recommended object. This deliberately is not
/// `ActionCardShell`: full card rendering belongs to Layer 2. The cell keeps
/// the same feedback vocabulary and dismiss affordance as region (1) of the
/// card primitive; the primary CTA wires positive acceptance (V1 step 2,
/// chat-home §3.4 / §3.5).
private struct RecommendedNextCell: View {
    let object: MatchingObject
    let providerStatus: ProviderStatusCompactCellDisplay?
    let onAccept: () -> Void
    let onDismiss: () -> Void
    let onFeedback: (MatchingFeedbackKind) -> Void

    private static let width: CGFloat = 236

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: object.kind.headerGlyph)
                        .font(.caption.weight(.bold))
                    Text(verbatim: object.kind.headerLabel)
                        .kAirTypography(AppTheme.Typography.eyebrow)
                }
                .foregroundStyle(AppTheme.Palette.textMuted)

                Spacer(minLength: 8)

                feedbackMenu
                dismissButton
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: object.title)
                    .kAirTypography(AppTheme.Typography.heading)
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if object.subtitleTokens.isEmpty == false {
                    Text(verbatim: object.subtitleTokens.joined(separator: " · "))
                        .kAirTypography(AppTheme.Typography.meta)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .lineLimit(1)
                }

                if let reason = object.reasonText, reason.isEmpty == false {
                    Text(verbatim: reason)
                        .kAirTypography(AppTheme.Typography.micro)
                        .foregroundStyle(AppTheme.Palette.textMuted)
                        .lineLimit(1)
                }
            }

            providerStatusRegion

            Spacer(minLength: 0)

            // §3.4: positive acceptance is the primary CTA button.
            Button(action: onAccept) {
                Text(verbatim: object.primaryCTA)
                    .kAirTypography(AppTheme.Typography.actionLabel)
                    .foregroundStyle(AppTheme.Palette.textOnStrong)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                            .fill(AppTheme.Palette.accentStrong)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: Self.width, alignment: .topLeading)
        .frame(minHeight: 132, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .fill(AppTheme.Palette.backgroundInset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Metrics.compactRadius, style: .continuous)
                .strokeBorder(AppTheme.Palette.line, lineWidth: 0.8)
        )
    }

    @ViewBuilder
    private var providerStatusRegion: some View {
        if let providerStatus {
            VStack(alignment: .leading, spacing: 6) {
                if providerStatus.badges.isEmpty == false {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(providerStatus.badges) { badge in
                                providerStatusBadge(badge)
                            }
                        }
                    }
                }

                if providerStatus.statusLine.isEmpty == false {
                    Text(verbatim: providerStatus.statusLine)
                        .kAirTypography(AppTheme.Typography.micro)
                        .foregroundStyle(statusLineColor(for: providerStatus.treatment))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.top, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(providerStatus.accessibilityLabel))
        }
    }

    private func providerStatusBadge(_ badge: ProviderStatusBadgeModel) -> some View {
        HStack(spacing: 4) {
            Image(systemName: badge.systemImage)
                .font(.caption2.weight(.semibold))
            Text(verbatim: badge.label)
                .kAirTypography(AppTheme.Typography.micro)
                .lineLimit(1)
        }
        .foregroundStyle(ActionCardTrustPill.foregroundColor(for: badge.tone))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(ActionCardTrustPill.backgroundColor(for: badge.tone))
        )
    }

    private func statusLineColor(
        for treatment: ProviderStatusCompactCellTreatment
    ) -> Color {
        switch treatment {
        case .normal:
            return AppTheme.Palette.textMuted
        case .warning:
            return AppTheme.Palette.warning
        case .disabled:
            return AppTheme.Palette.danger
        }
    }

    private var feedbackMenu: some View {
        Menu {
            ForEach(MatchingFeedbackKind.allCases, id: \.self) { kind in
                Button {
                    onFeedback(kind)
                } label: {
                    Text(verbatim: kind.displayLabel)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textMuted)
                .padding(6)
                .contentShape(Rectangle())
        }
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textMuted)
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Dismiss \(object.title)"))
    }
}

private struct EmptyConversationState: View {
    let prompts: [String]
    let onTapPrompt: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Ask me anything")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.Palette.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(prompts, id: \.self) { prompt in
                        Button {
                            onTapPrompt(prompt)
                        } label: {
                            Text(prompt)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.Palette.textPrimary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .frame(width: 168, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(AppTheme.Palette.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(AppTheme.Palette.line, lineWidth: 1)
                                )
                                .kAirElevation(ChatHomeView.surfaceElevation)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(prompt)
                        .accessibilityHint("Starts a message from this suggestion")
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
                    .foregroundStyle(AppTheme.Palette.textPrimary)
                    .submitLabel(.send)
                    .onSubmit(onSend)
                    .accessibilityLabel("Message")
                    .accessibilityIdentifier("chat.composer")

                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(canSend ? AppTheme.Palette.textOnStrong : AppTheme.Palette.textMuted)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(canSend ? AppTheme.Palette.accentStrong : AppTheme.Palette.line)
                        )
                }
                .buttonStyle(.plain)
                .disabled(canSend == false)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.Palette.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(AppTheme.Palette.line, lineWidth: 1)
            )
            .kAirElevation(ChatHomeView.surfaceElevation)

            // V1 composer polish: the redundant "User" text button is replaced
            // by a compact profile avatar (icon-style, 44pt tap target). This
            // keeps the single composer + the profile entry while freeing
            // horizontal room for the TextField on narrow screens. It reuses
            // the "K" avatar the Execution Surfaces use — not a second text
            // button.
            Button(action: onUserTap) {
                Circle()
                    .fill(AppTheme.Palette.surfaceStrong)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(verbatim: "K")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.Palette.textOnStrong)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Profile"))
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

    var attachments: [ReferenceAttachment] = ReferenceAttachment.allCases
    let onSelect: (ReferenceAttachment) -> Void

    var body: some View {
        NavigationStack {
            List(attachments) { attachment in
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
