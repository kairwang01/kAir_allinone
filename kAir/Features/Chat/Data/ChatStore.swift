//
//  ChatStore.swift
//  kAir
//
//  Local orchestration for the kAir conversation surface.
//

import Foundation
import Observation

@MainActor
@Observable
final class ChatStore {
    let modes: [ComposerMode] = [
        ComposerMode(id: "ask", title: "Ask", systemImage: "bubble.left"),
        ComposerMode(id: "coach", title: "Coach", systemImage: "waveform.path.ecg"),
        ComposerMode(id: "route", title: "Route", systemImage: "arrow.triangle.branch"),
        ComposerMode(id: "shop", title: "Shop", systemImage: "bag"),
    ]

    let accessories: [ComposerAccessory] = [
        ComposerAccessory(id: "health", title: "Health", systemImage: "heart.text.square"),
        ComposerAccessory(id: "ai", title: "AI", systemImage: "cpu"),
        ComposerAccessory(id: "maps", title: "Maps", systemImage: "map"),
        ComposerAccessory(id: "music", title: "Music", systemImage: "music.note"),
        ComposerAccessory(id: "video", title: "Video", systemImage: "play.rectangle"),
        ComposerAccessory(id: "store", title: "Store", systemImage: "bag"),
    ]

    var session = ChatSession(title: "kAir", messages: [])
    var draft = ""
    var isTemplateChat = false {
        didSet {
            handleTemplateChatChange()
        }
    }
    var selectedModeID = "ask"
    var contextSummary = "One thread across AI, Maps, Music, Video, Store, and optional Health"
    var recommendedMatches: [UnifiedMatchRecommendation] = []
    var suggestedPrompts: [String] = [
        "我想去超市",
        "播放一些专注音乐",
        "Show me a yoga stretch video",
        "Which model is active?",
        "Find a nearby pharmacy"
    ]

    private var lastRefreshDate: Date?
    private var supportsHealthData = true
    private var healthAvailability: MatchingHealthAvailability = .availableLater
    private var locationState: MatchingLocationState = .unknown
    private var motionContext: MatchingMotionContext = .stationary
    private var pendingMapTask: MapTask?
    private var resolvedMapTask: MapTask?
    private var resolvedHealthSession: HealthRouteSession?
    private var resolvedMusicSession: MusicPlaybackSession?
    private var resolvedVideoSession: VideoPlaybackSession?
    private var behaviorLog: [MatchingBehaviorEvent] = []
    private var lastImpressedRecommendationIDs: [String] = []
    private var pendingAcceptedRecommendation: UnifiedMatchRecommendation?
    private var activeRecommendationBySection: [AppSection: UnifiedMatchRecommendation] = [:]
    private var pendingReturnContextState: ExecutionReturnContextState?
    private var pendingSurfaceEntryRequests: [AppSection: SurfaceEntryRequest] = [:]
    private var activeSurfaceEntryRequests: [AppSection: SurfaceEntryRequest] = [:]
    private let matchingEngine: UnifiedMatchingEngine
    private let replayLab: MatchingReplayLab
    private let persistence = ChatSessionPersistence()
    private let eventRecorder: MatchingEventRecorder
    private var activeDecision: RecommendationDecision?
    private var executionStartDates: [AppSection: Date] = [:]
    var replayFrames: [MatchingReplayFrame] = []
    var lastExportedSession: ReplayExportedSession?

    var currentRecommendationId: String? {
        activeDecision?.recommendationId
    }

    var preferredMapsLanguage: MapsConversationLanguage {
        if let task = resolvedMapTask { return task.language }
        if let task = pendingMapTask { return task.language }
        return .english
    }

    init(
        replayLab: MatchingReplayLab,
        autostartLifecycle: Bool = true
    ) {
        self.matchingEngine = UnifiedMatchingEngine()
        self.eventRecorder = MatchingEventRecorder()
        self.replayLab = replayLab
        Self.wireReplayFeed(recorder: eventRecorder, lab: replayLab)
        if let restoredSession = persistence.load() {
            session = restoredSession
        }
        if autostartLifecycle {
            refreshRecommendedMatches()
        }
    }

    init(
        replayLab: MatchingReplayLab,
        matchingEngine: UnifiedMatchingEngine,
        eventRecorder: MatchingEventRecorder,
        autostartLifecycle: Bool = true
    ) {
        self.matchingEngine = matchingEngine
        self.eventRecorder = eventRecorder
        self.replayLab = replayLab
        Self.wireReplayFeed(recorder: eventRecorder, lab: replayLab)
        if let restoredSession = persistence.load() {
            session = restoredSession
        }
        if autostartLifecycle {
            refreshRecommendedMatches()
        }
    }

    private static func wireReplayFeed(
        recorder: MatchingEventRecorder,
        lab: MatchingReplayLab
    ) {
        recorder.onEventAppended = { [weak lab] event in
            lab?.submitSurfaceEntryEvent(event)
        }
        recorder.onSurfaceEntryRequestRetained = { [weak lab] request in
            lab?.retainSurfaceEntryRequest(request)
        }
        recorder.onExecutionReturnPayloadRetained = { [weak lab] payload in
            lab?.retainSurfaceEntryReturnPayload(payload)
        }
    }

    var latestMessagePreview: String {
        session.messages
            .last(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false })?
            .text ?? contextSummary
    }

    var latestActivityDate: Date? {
        session.messages.last?.timestamp
    }

    var canResumeThread: Bool {
        session.messages.contains(where: { $0.role == .user }) || session.messages.count > 1
    }

    var homeContextItems: [ConversationContextItem] {
        [
            ConversationContextItem(
                id: "default-thread",
                title: "Thread",
                value: "Same default session",
                systemImage: "bubble.left.and.bubble.right"
            ),
            ConversationContextItem(
                id: "add-reference",
                title: "Add",
                value: "References first",
                systemImage: "plus.circle"
            ),
            ConversationContextItem(
                id: "focused-surfaces",
                title: "Surfaces",
                value: supportsHealthData ? "Health on-demand" : "Health unavailable",
                systemImage: "square.stack.3d.up"
            ),
            ConversationContextItem(
                id: "matcher",
                title: "Matcher",
                value: recommendedMatches.isEmpty ? "Warming up" : "Next step ready",
                systemImage: "point.3.connected.trianglepath.dotted"
            )
        ]
    }

    func bootstrap(with dashboard: HealthDashboard) {
        supportsHealthData = true
        healthAvailability = .ready
        contextSummary = "AI, Maps, Music, Video, and Store are live. Apple Health is available on-device only when you ask for it."
        suggestedPrompts = Self.suggestedPrompts(for: dashboard)

        guard lastRefreshDate != dashboard.generatedAt else { return }

        if session.messages.isEmpty {
            session.messages = [
                .assistant(
                    text: Self.welcomeMessage(for: dashboard),
                    timestamp: dashboard.generatedAt,
                    tags: ["All-in-one", "Local-first"],
                    toolResults: [Self.runtimeShellResult(healthReady: true)]
                ),
            ]
            persistIfNeeded()
        }

        lastRefreshDate = dashboard.generatedAt
        refreshRecommendedMatches()
    }

    func bootstrapWithoutDashboard(supportsHealthData: Bool) {
        self.supportsHealthData = supportsHealthData
        healthAvailability = supportsHealthData ? .availableLater : .unavailable
        contextSummary = supportsHealthData
            ? "Chat-first shell · AI, Maps, Music, Video, and Store are ready; Health stays on-demand"
            : "HealthKit unavailable · AI, Maps, Music, Video, and Store remain available"
        suggestedPrompts = Self.fallbackSuggestedPrompts(supportsHealthData: supportsHealthData)

        guard session.messages.isEmpty else { return }

        session.messages = [
            .assistant(
                text: Self.welcomeMessageWithoutDashboard(supportsHealthData: supportsHealthData),
                tags: ["Chat-first", "Local-first"],
                toolResults: [Self.runtimeShellResult(healthReady: false, supportsHealthData: supportsHealthData)]
            ),
        ]
        persistIfNeeded()
        refreshRecommendedMatches()
    }

    func selectMode(_ mode: ComposerMode) {
        selectedModeID = mode.id
    }

    func sendDraft(
        using dashboard: HealthDashboard?,
        mapsRuntime: MapsRuntime
    ) async -> ConversationRoute? {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        draft = ""
        return await submit(prompt: trimmed, using: dashboard, mapsRuntime: mapsRuntime)
    }

    func submitPrompt(
        _ prompt: String,
        using dashboard: HealthDashboard?,
        mapsRuntime: MapsRuntime
    ) async -> ConversationRoute? {
        await submit(prompt: prompt, using: dashboard, mapsRuntime: mapsRuntime)
    }

    func shouldRecordGenericHandoff(for route: ConversationRoute) -> Bool {
        route.shouldRecordSystemNote
    }

    func recordHandoff(for route: ConversationRoute) {
        let destination = route.destination.title
        let reason = route.handoffReason
        let text = "Entering \(destination) \(reason). This thread stays here."

        session.messages.append(
            .system(
                text: text,
                tags: ["\(destination) handoff"]
            )
        )
        recordEvent(
            stage: .accept,
            subject: .route,
            surface: routeSection(for: route.destination),
            rawText: text,
            tags: matchingTags(from: text),
            outcome: MatchingOutcomeMetrics(
                downstreamValue: 0.45,
                completionScore: 0.2,
                wasSuccessful: true
            )
        )
        persistIfNeeded()
    }

    func attachReference(_ title: String, detail: String) {
        session.messages.append(
            .system(
                text: "\(title) added. \(detail)",
                tags: ["Reference"]
            )
        )
        recordEvent(
            stage: .accept,
            subject: .reference,
            rawText: "\(title) \(detail)",
            tags: matchingTags(from: "\(title) \(detail)"),
            outcome: MatchingOutcomeMetrics(
                downstreamValue: 0.32,
                completionScore: 0.28,
                wasSuccessful: true
            )
        )
        persistIfNeeded()
        refreshRecommendedMatches(
            seedPrompt: detail,
            replaceActiveLifecycle: true
        )
    }

    func recordRecommendationTap(_ recommendation: UnifiedMatchRecommendation) {
        pendingAcceptedRecommendation = recommendation
        recordEvent(
            stage: .click,
            subject: .recommendation,
            candidateID: recommendation.candidate.id,
            objectKind: recommendation.candidate.objectKind,
            surface: recommendation.candidate.preferredSection,
            rawText: recommendation.candidate.activationPrompt,
            tags: recommendation.candidate.tags,
            outcome: MatchingOutcomeMetrics(
                downstreamValue: 0.2,
                completionScore: 0,
                wasSuccessful: true
            )
        )
        eventRecorder.recordClick(candidate: recommendation)
    }

    func prepareRecommendationForAccept(_ recommendation: UnifiedMatchRecommendation) {
        pendingAcceptedRecommendation = recommendation
    }

    func dismissRecommendation(
        _ recommendation: UnifiedMatchRecommendation,
        feedback: MatchingFeedbackKind
    ) {
        if pendingAcceptedRecommendation?.id == recommendation.id {
            pendingAcceptedRecommendation = nil
        }

        let stage: MatchingBehaviorEvent.Stage = feedback == .alreadyDone ? .completion : .dismiss
        recordEvent(
            stage: stage,
            subject: .recommendation,
            candidateID: recommendation.candidate.id,
            objectKind: recommendation.candidate.objectKind,
            surface: recommendation.candidate.preferredSection,
            rawText: recommendation.candidate.activationPrompt,
            tags: recommendation.candidate.tags,
            feedback: feedback,
            outcome: outcomeMetrics(for: feedback)
        )
        eventRecorder.recordDismiss(
            candidate: recommendation,
            feedback: FeedbackOption(from: feedback)
        )
        syncClosedLifecycleArtifacts()

        recommendedMatches.removeAll { $0.id == recommendation.id }
        activeRecommendationBySection = activeRecommendationBySection.filter { _, value in
            value.id != recommendation.id
        }
        refreshRecommendedMatches()
    }

    func recordSurfaceReturn(
        from context: AppSurfaceReturnContext,
        dashboard: HealthDashboard?,
        healthSession: HealthRouteSession?
    ) {
        let linkedRecommendation = activeRecommendationBySection.removeValue(forKey: context.section)

        switch context.section {
        case .health:
            guard
                let dashboard,
                let healthSession,
                let message = healthReturnMessage(for: healthSession, dashboard: dashboard)
            else {
                return
            }
            session.messages.append(message)
        case .ai:
            session.messages.append(aiReturnMessage(dashboard: dashboard))
        case .music:
            session.messages.append(musicReturnMessage(session: context.musicSession))
        case .store:
            session.messages.append(storeReturnMessage())
        case .video:
            session.messages.append(videoReturnMessage(session: context.videoSession))
        case .chat, .maps:
            return
        }

        let returnStage = surfaceReturnStage(for: context)
        let metrics = outcomeMetrics(
            for: context,
            healthSession: healthSession
        )
        recordEvent(
            stage: returnStage,
            subject: .surface,
            candidateID: linkedRecommendation?.candidate.id,
            objectKind: linkedRecommendation?.candidate.objectKind,
            surface: context.section,
            rawText: context.section.title,
            tags: linkedRecommendation?.candidate.tags ?? matchingTags(from: context.section.title),
            outcome: metrics
        )
        let payload = executionReturnPayload(
            for: context.section,
            candidate: linkedRecommendation,
            stage: returnStage,
            metrics: metrics
        )
        eventRecorder.recordExecutionReturn(
            payload: payload,
            candidate: linkedRecommendation
        )
        applyExecutionReturnPayload(payload)
        syncClosedLifecycleArtifacts()
        executionStartDates[context.section] = nil
        persistIfNeeded()
        refreshRecommendedMatches(seedPrompt: context.section.title)
    }

    func recordMapReturn(from task: MapTask) {
        pendingMapTask = nil
        resolvedMapTask = nil
        syncSpatialContext(from: task)

        session.messages.append(
            .assistant(
                text: task.summaryForChatReturn(),
                tags: ["Maps", task.language.usesChineseCopy ? "返回聊天" : "Back in chat"],
                toolResults: [
                    ConversationToolResult(
                        id: "maps-return-summary",
                        title: task.language.usesChineseCopy ? "Maps 已回写线程" : "Maps wrote back into the thread",
                        summary: task.summaryForChatReturn(),
                        state: .ready,
                        metrics: [
                            .init(key: task.language.usesChineseCopy ? "任务" : "Task", value: task.taskType.title(for: task.language)),
                            .init(key: task.language.usesChineseCopy ? "线程" : "Thread", value: task.language.usesChineseCopy ? "原会话已保留" : "Original thread kept"),
                            .init(key: task.language.usesChineseCopy ? "返回" : "Return", value: task.language.usesChineseCopy ? "已完成" : "Complete")
                        ],
                        footer: task.language.usesChineseCopy
                            ? "Maps 退出后不会新开会话，也不会丢失上下文。"
                            : "Leaving Maps does not start a new session or lose context."
                    )
                ]
            )
        )
        let linkedRecommendation = activeRecommendationBySection.removeValue(forKey: .maps)
        let mapStage = mapReturnStage(for: task)
        let mapMetrics = outcomeMetrics(for: task)
        recordEvent(
            stage: mapStage,
            subject: .surface,
            candidateID: linkedRecommendation?.candidate.id,
            objectKind: linkedRecommendation?.candidate.objectKind ?? mapObjectKind(for: task),
            surface: .maps,
            rawText: task.summaryForChatReturn(),
            tags: linkedRecommendation?.candidate.tags ?? matchingTags(from: task.query),
            outcome: mapMetrics
        )
        let payload = executionReturnPayload(
            for: .maps,
            candidate: linkedRecommendation,
            stage: mapStage,
            metrics: mapMetrics
        )
        eventRecorder.recordExecutionReturn(
            payload: payload,
            candidate: linkedRecommendation
        )
        applyExecutionReturnPayload(payload)
        syncClosedLifecycleArtifacts()
        executionStartDates[.maps] = nil
        persistIfNeeded()
        refreshRecommendedMatches(seedPrompt: task.summaryForChatReturn())
    }

    func recordSilentSurfaceExit(_ section: AppSection) {
        let linkedRecommendation = activeRecommendationBySection.removeValue(forKey: section)
        recordEvent(
            stage: .abandon,
            subject: .surface,
            candidateID: linkedRecommendation?.candidate.id,
            objectKind: linkedRecommendation?.candidate.objectKind,
            surface: section,
            rawText: "\(section.title) closed",
            tags: linkedRecommendation?.candidate.tags ?? matchingTags(from: section.title),
            outcome: .neutral
        )
        eventRecorder.recordAbandon(
            candidate: linkedRecommendation,
            surface: section
        )
        executionStartDates[section] = nil
        syncClosedLifecycleArtifacts()
    }

    func consumeResolvedMapTask() -> MapTask? {
        let task = resolvedMapTask
        resolvedMapTask = nil
        return task
    }

    func consumeResolvedHealthSession() -> HealthRouteSession? {
        let session = resolvedHealthSession
        resolvedHealthSession = nil
        return session
    }

    func consumeResolvedMusicSession() -> MusicPlaybackSession? {
        let session = resolvedMusicSession
        resolvedMusicSession = nil
        return session
    }

    func consumeResolvedVideoSession() -> VideoPlaybackSession? {
        let session = resolvedVideoSession
        resolvedVideoSession = nil
        return session
    }

    func handleConversationAction(
        _ action: ConversationToolAction,
        using dashboard: HealthDashboard?,
        mapsRuntime: MapsRuntime
    ) async -> ConversationRoute? {
        if let resolution = await ConversationIntentEngine.handleAction(
            action,
            pendingMapTask: pendingMapTask,
            runtime: mapsRuntime
        ) {
            pendingMapTask = resolution.pendingMapTask
            resolvedMapTask = resolution.resolvedMapTask

            if let message = resolution.message {
                session.messages.append(message)
            }
            recordEvent(
                stage: .click,
                subject: .tool,
                surface: routeSection(for: resolution.route?.destination),
                rawText: action.title,
                tags: matchingTags(from: action.title),
                outcome: MatchingOutcomeMetrics(
                    downstreamValue: 0.3,
                    completionScore: resolution.route == nil ? 0.45 : 0.15,
                    wasSuccessful: true
                )
            )
            persistIfNeeded()
            if resolution.route == nil {
                refreshRecommendedMatches(
                    seedPrompt: action.title,
                    replaceActiveLifecycle: true
                )
            }
            return resolution.route
        }

        return nil
    }

    private func legacyRoute(for prompt: String) -> ConversationRoute? {
        resolvedHealthSession = nil

        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()

        if isUserCommand(normalized, prompt: trimmed) {
            return ConversationRoute(
                destination: .userProfile,
                handoffReason: "to open settings",
                shouldRecordSystemNote: true
            )
        }

        if let healthSession = exactHealthCommand(normalized: normalized, prompt: trimmed) {
            resolvedHealthSession = healthSession
            return ConversationRoute(
                destination: .surface(.health),
                handoffReason: "for grounded health context",
                shouldRecordSystemNote: false
            )
        }

        if isMapsCommand(normalized, prompt: trimmed) {
            return ConversationRoute(
                destination: .surface(.maps),
                handoffReason: "for location and route work",
                shouldRecordSystemNote: true
            )
        }

        if Self.isGenericMapsPrompt(normalized, prompt: prompt) {
            return ConversationRoute(
                destination: .surface(.maps),
                handoffReason: "for location and route work",
                shouldRecordSystemNote: true
            )
        }

        if isMusicCommand(normalized, prompt: trimmed) {
            return ConversationRoute(
                destination: .surface(.music),
                handoffReason: "to adjust the current player",
                shouldRecordSystemNote: true
            )
        }

        if isVideoCommand(normalized, prompt: trimmed) {
            return ConversationRoute(
                destination: .surface(.video),
                handoffReason: "for a focused video response",
                shouldRecordSystemNote: true
            )
        }

        if normalized.contains("buy") ||
            normalized.contains("shop") ||
            normalized.contains("order") ||
            normalized.contains("supplement") ||
            normalized.contains("device") ||
            normalized.contains("bundle")
        {
            return ConversationRoute(
                destination: .surface(.store),
                handoffReason: "for curated product suggestions",
                shouldRecordSystemNote: true
            )
        }

        if normalized.contains("model") || normalized.contains("ai") {
            return ConversationRoute(
                destination: .surface(.ai),
                handoffReason: "for deeper AI context",
                shouldRecordSystemNote: true
            )
        }

        if let healthSession = explicitHealthIntent(from: prompt) {
            resolvedHealthSession = healthSession
            return ConversationRoute(
                destination: .surface(.health),
                handoffReason: "for grounded health context",
                shouldRecordSystemNote: false
            )
        }

        return nil
    }

    private func submit(
        prompt: String,
        using dashboard: HealthDashboard?,
        mapsRuntime: MapsRuntime
    ) async -> ConversationRoute? {
        let acceptedRecommendation = consumeAcceptedRecommendation(for: prompt)
        session.messages.append(
            .user(
                text: prompt,
                tags: selectedModeID == "ask" ? [] : [selectedMode.title]
            )
        )
        recordEvent(
            stage: .accept,
            subject: .prompt,
            rawText: prompt,
            tags: matchingTags(from: prompt),
            outcome: MatchingOutcomeMetrics(
                downstreamValue: 0.3,
                completionScore: 0.18,
                wasSuccessful: true
            )
        )

        if let acceptedRecommendation {
            recordEvent(
                stage: .accept,
                subject: .recommendation,
                candidateID: acceptedRecommendation.candidate.id,
                objectKind: acceptedRecommendation.candidate.objectKind,
                surface: acceptedRecommendation.candidate.preferredSection,
                rawText: acceptedRecommendation.candidate.activationPrompt,
                tags: acceptedRecommendation.candidate.tags,
                outcome: MatchingOutcomeMetrics(
                    downstreamValue: 0.42,
                    completionScore: 0.24,
                    wasSuccessful: true
                )
            )
            eventRecorder.recordAccept(candidate: acceptedRecommendation)
        }

        if let resolution = await ConversationIntentEngine.handlePrompt(
            prompt,
            threadId: session.id,
            pendingMapTask: pendingMapTask,
            runtime: mapsRuntime
        ) {
            pendingMapTask = resolution.pendingMapTask
            resolvedMapTask = resolution.resolvedMapTask
            resolvedMusicSession = resolution.resolvedMusicSession
            resolvedVideoSession = resolution.resolvedVideoSession

            if let message = resolution.message {
                session.messages.append(message)
            }
            registerAcceptedRecommendation(
                acceptedRecommendation,
                for: resolution.route
            )
            persistIfNeeded()
            if resolution.route != nil {
                return resolution.route
            }
            refreshRecommendedMatches(
                seedPrompt: prompt,
                replaceActiveLifecycle: true
            )
            return resolution.route
        }

        let route = legacyRoute(for: prompt)
        registerAcceptedRecommendation(acceptedRecommendation, for: route)

        if case .surface(.health) = route?.destination, let healthSession = resolvedHealthSession {
            session.messages.append(
                .system(
                    text: healthHandoffText(for: healthSession, dashboard: dashboard),
                    toolResults: [healthHandoffResult(for: healthSession, dashboard: dashboard)]
                )
            )
            persistIfNeeded()
            return route
        }

        if case .userProfile = route?.destination {
            session.messages.append(
                .assistant(
                    text: "Opening User settings while keeping this thread intact.",
                    tags: ["User", "Focused surface"],
                    toolResults: [userProfileResult()]
                )
            )
            persistIfNeeded()
            return route
        }

        session.messages.append(
            .assistant(
                text: dashboard.map {
                    Self.reply(to: prompt, modeID: selectedModeID, dashboard: $0)
                } ?? Self.replyWithoutDashboard(
                    to: prompt,
                    modeID: selectedModeID,
                    supportsHealthData: supportsHealthData
                ),
                tags: dashboard.map {
                    Self.replyTags(for: prompt, modeID: selectedModeID, dashboard: $0)
                } ?? Self.replyTagsWithoutDashboard(
                    for: prompt,
                    modeID: selectedModeID,
                    supportsHealthData: supportsHealthData
                ),
                toolResults: dashboard.map {
                    Self.toolResults(for: prompt, dashboard: $0)
                } ?? Self.toolResultsWithoutDashboard(
                    for: prompt,
                    supportsHealthData: supportsHealthData
                )
            )
        )
        if let acceptedRecommendation {
            let completionMetrics = MatchingOutcomeMetrics(
                downstreamValue: 0.55,
                completionScore: 0.58,
                wasSuccessful: true
            )
            recordEvent(
                stage: .completion,
                subject: .recommendation,
                candidateID: acceptedRecommendation.candidate.id,
                objectKind: acceptedRecommendation.candidate.objectKind,
                surface: acceptedRecommendation.candidate.preferredSection,
                rawText: acceptedRecommendation.candidate.activationPrompt,
                tags: acceptedRecommendation.candidate.tags,
                outcome: completionMetrics
            )
            let payload = executionReturnPayload(
                for: .chat,
                candidate: acceptedRecommendation,
                stage: .completion,
                metrics: completionMetrics
            )
            eventRecorder.recordExecutionReturn(
                payload: payload,
                candidate: acceptedRecommendation
            )
            applyExecutionReturnPayload(payload)
            syncClosedLifecycleArtifacts()
        }
        persistIfNeeded()
        refreshRecommendedMatches(
            seedPrompt: prompt,
            replaceActiveLifecycle: true
        )
        return route
    }

    private var selectedMode: ComposerMode {
        modes.first(where: { $0.id == selectedModeID }) ?? modes[0]
    }

    private static func suggestedPrompts(for _: HealthDashboard) -> [String] {
        [
            "I want to go to Apple Store",
            "Play focus music",
            "Show me a yoga stretch video",
            "Which model should answer a health question?",
            "Find a nearby pharmacy"
        ]
    }

    private static func fallbackSuggestedPrompts(supportsHealthData: Bool) -> [String] {
        if supportsHealthData {
            [
                "I want to go to Apple Store",
                "Play focus music",
                "Show me a nearby pharmacy",
                "Which model is active?",
                "Show me a workout video"
            ]
        } else {
            [
                "I want to go to Apple Store",
                "播放一些专注音乐",
                "Show me a nearby pharmacy",
                "Which model is active?",
                "Show me a workout video"
            ]
        }
    }

    private static func welcomeMessage(for _: HealthDashboard) -> String {
        "You are in kAir. Chat is the main surface. I can route into AI, Maps, Music, Video, and Store from this thread, and Apple Health stays available as an on-device tool only when you ask for it."
    }

    private static func welcomeMessageWithoutDashboard(supportsHealthData: Bool) -> String {
        if supportsHealthData {
            return "You are in kAir. Chat is already live, and AI, Maps, Music, Video, and Store can open from this thread immediately. Apple Health stays optional until you explicitly ask for health context."
        }
        return "You are in kAir. This device cannot attach Apple Health right now, but the chat, AI, Maps, Music, Video, and Store surfaces still live in one thread."
    }

    private static func reply(to prompt: String, modeID: String, dashboard: HealthDashboard) -> String {
        let normalized = prompt.lowercased()

        if normalized.contains("sleep") {
            return "Sleep averaged \(dashboard.sleepSummary.averageHours.formattedOneDecimal) h/night across \(dashboard.sleepSummary.nightsTracked) nights. The latest night was \(dashboard.sleepSummary.latestHours.formattedOneDecimal) h. \(dashboard.sleepSummary.summary)"
        }

        if normalized.contains("recovery") || normalized.contains("hrv") || normalized.contains("health") {
            if let recovery = dashboard.insights.first(where: { $0.id == "recovery" }) {
                return "\(recovery.summary) I would read that alongside resting heart rate, sleep regularity, and the model watchpoints before deciding what deserves attention."
            }
        }

        if normalized.contains("activity") || normalized.contains("steps") || normalized.contains("workout") {
            let newestWorkout = dashboard.workouts.first?.activity ?? "No recent workout"
            return "The recent activity picture is anchored by \(dashboard.workouts.count) workouts, with \(newestWorkout) as the newest session. \(dashboard.insights.first(where: { $0.id == "activity" })?.summary ?? "Movement data is available in Health.")"
        }

        if isGenericMapsPrompt(normalized, prompt: prompt) {
            return "Maps should stay quiet and utilitarian inside kAir: nearby clinics, pharmacies, gyms, and walking routes, surfaced as task-ready places instead of a noisy standalone map first."
        }

        if isMusicPrompt(normalized, prompt: prompt) {
            return "Music should remain a quiet capability layer. It can start from chat, collapse into a persistent player, and keep the thread as the primary surface."
        }

        if isVideoPrompt(normalized, prompt: prompt) {
            return "Video should open only when the request needs a visual explanation or guided session. It is a focused surface, then it returns to the same thread."
        }

        if normalized.contains("model") || normalized.contains("ai") || modeID == "route" {
            if let prediction = dashboard.predictions.first {
                return "The active AI posture is local-first. One orchestrator keeps the thread intact, decides which surface to open next, and only reaches for specialized health reasoning when you explicitly ask for health context. \(prediction.title) remains available as an on-device specialist."
            }
            return "The AI layer is designed as a routing surface: one general model for conversation, one planner for opening Maps, Music, Video, or Store, and an optional on-device health explainer only when the thread calls for it."
        }

        if normalized.contains("buy") || normalized.contains("store") || normalized.contains("supplement") || normalized.contains("device") || modeID == "shop" {
            return "Store should feel curated, not loud. I would prioritize sleep and recovery tools first, then wearables, then lightweight nutrition suggestions, all anchored to what your health data actually suggests is worth watching."
        }

        if normalized.contains("privacy") || normalized.contains("local") {
            return "kAir stays local-first. The shell keeps chat, AI, Maps, Music, Video, and Store together, while Health remains an on-device capability that only comes into play when you explicitly ask for it."
        }

        return "kAir is set up as one conversation that can open deeper tools only when needed. I can stage nearby routes, start music, open a video surface, explain the AI runtime, prepare store suggestions, or bring in Health only if you want that context."
    }

    private static func replyWithoutDashboard(
        to prompt: String,
        modeID: String,
        supportsHealthData: Bool
    ) -> String {
        let normalized = prompt.lowercased()

        if normalized.contains("connect") || normalized.contains("health") || normalized.contains("sleep") || normalized.contains("heart") {
            if supportsHealthData {
                return "Health is available on this device, but it is not attached yet. Open the Health surface or use the profile controls to grant Apple Health access, then this thread can answer with grounded local data."
            }
            return "This device cannot attach Apple Health right now, so health answers cannot be grounded locally here."
        }

        if isGenericMapsPrompt(normalized, prompt: prompt) || modeID == "route" {
            return "Maps can still be invoked immediately from chat. I will preserve this thread, then hand off into a focused navigation surface."
        }

        if isMusicPrompt(normalized, prompt: prompt) {
            return "Music can start directly from chat and stay attached as a persistent player while the conversation continues."
        }

        if isVideoPrompt(normalized, prompt: prompt) {
            return "Video can open as a focused surface from chat, then return a compact summary into the same thread."
        }

        if normalized.contains("buy") || normalized.contains("store") || normalized.contains("shop") || modeID == "shop" {
            return "Store can still open from the conversation, but curation will be broader until Apple Health is attached."
        }

        if normalized.contains("model") || normalized.contains("ai") {
            return "The AI layer is already live. One orchestrator handles the thread, then opens deeper surfaces only when the task needs them."
        }

        return supportsHealthData
            ? "kAir is already chat-first. AI, Maps, Music, Video, and Store are available now, and Health remains optional until you explicitly ask for it."
            : "kAir is already chat-first. AI, Maps, Music, Video, and Store are available now, but Health grounding is unavailable on this device."
    }

    private static func replyTags(for prompt: String, modeID: String, dashboard: HealthDashboard) -> [String] {
        let normalized = prompt.lowercased()
        var tags = ["Local-first"]

        if modeID != "ask" {
            tags.append(modeID.capitalized)
        }

        if isGenericMapsPrompt(normalized, prompt: prompt) {
            tags.append("Maps")
        } else if isMusicPrompt(normalized, prompt: prompt) {
            tags.append("Music")
        } else if isVideoPrompt(normalized, prompt: prompt) {
            tags.append("Video")
        } else if normalized.contains("store") || normalized.contains("buy") || normalized.contains("supplement") {
            tags.append("Store")
        } else if normalized.contains("model") || normalized.contains("ai") {
            tags.append("AI")
        } else if isHealthPrompt(normalized) {
            tags.append("Health")
        } else {
            tags.append("General")
        }

        if let prediction = dashboard.predictions.first {
            tags.append(prediction.title)
        }

        return tags
    }

    private static func replyTagsWithoutDashboard(
        for prompt: String,
        modeID: String,
        supportsHealthData: Bool
    ) -> [String] {
        let normalized = prompt.lowercased()
        var tags = ["Chat-first"]

        if modeID != "ask" {
            tags.append(modeID.capitalized)
        }

        if normalized.contains("map") || normalized.contains("route") || normalized.contains("nearby") {
            tags.append("Maps")
        } else if isMusicPrompt(normalized, prompt: prompt) {
            tags.append("Music")
        } else if isVideoPrompt(normalized, prompt: prompt) {
            tags.append("Video")
        } else if normalized.contains("store") || normalized.contains("buy") || normalized.contains("shop") {
            tags.append("Store")
        } else if normalized.contains("model") || normalized.contains("ai") {
            tags.append("AI")
        } else if isHealthPrompt(normalized) {
            tags.append(supportsHealthData ? "Health" : "Health unavailable")
        } else {
            tags.append("General")
        }

        return tags
    }

    private static func toolResults(for prompt: String, dashboard: HealthDashboard) -> [ConversationToolResult] {
        let normalized = prompt.lowercased()

        if isGenericMapsPrompt(normalized, prompt: prompt) {
            return [mapsResult()]
        }

        if isMusicPrompt(normalized, prompt: prompt) {
            return [musicSurfaceResult()]
        }

        if isVideoPrompt(normalized, prompt: prompt) {
            return [videoSurfaceResult()]
        }

        if normalized.contains("model") || normalized.contains("ai") {
            return [aiRuntimeResult(for: dashboard)]
        }

        if normalized.contains("store") || normalized.contains("buy") || normalized.contains("supplement") || normalized.contains("device") {
            return [storeResult()]
        }

        if normalized.contains("sleep") {
            return [sleepResult(for: dashboard)]
        }

        if isHealthPrompt(normalized) {
            return [healthSnapshotResult(for: dashboard)]
        }

        return [runtimeShellResult(healthReady: true)]
    }

    private static func toolResultsWithoutDashboard(
        for prompt: String,
        supportsHealthData: Bool
    ) -> [ConversationToolResult] {
        let normalized = prompt.lowercased()

        if isGenericMapsPrompt(normalized, prompt: prompt) {
            return [mapsResult()]
        }

        if isMusicPrompt(normalized, prompt: prompt) {
            return [musicSurfaceResult()]
        }

        if isVideoPrompt(normalized, prompt: prompt) {
            return [videoSurfaceResult()]
        }

        if normalized.contains("model") || normalized.contains("ai") {
            return [ungroundedAIResult()]
        }

        if normalized.contains("store") || normalized.contains("buy") || normalized.contains("shop") {
            return [storeResult()]
        }

        if isHealthPrompt(normalized) {
            return [healthAccessResult(supportsHealthData: supportsHealthData)]
        }

        return [runtimeShellResult(healthReady: false, supportsHealthData: supportsHealthData)]
    }

    private static func runtimeShellResult(
        healthReady: Bool,
        supportsHealthData: Bool = true
    ) -> ConversationToolResult {
        ConversationToolResult(
            id: healthReady ? "runtime_shell_ready" : "runtime_shell_base",
            title: "kAir Runtime",
            summary: "The app is chat-first. A unified matching layer decides which content, tool, or surface should come next.",
            state: .ready,
            metrics: [
                .init(key: "Chat", value: "Primary"),
                .init(key: "Matcher", value: "Live"),
                .init(key: "Maps", value: "Ready"),
                .init(key: "Music", value: "Player ready"),
                .init(key: "Video", value: "Surface ready"),
                .init(key: "Store", value: "Ready"),
                .init(key: "Health", value: healthReady ? "On-demand" : (supportsHealthData ? "Available later" : "Unavailable"))
            ],
            footer: healthReady
                ? "Apple Health is available locally, but the matcher keeps it dormant until the thread explicitly asks for grounded context."
                : "Health stays dormant until the thread explicitly asks for it."
        )
    }

    private static func healthSnapshotResult(for dashboard: HealthDashboard) -> ConversationToolResult {
        ConversationToolResult(
            id: "health_snapshot",
            title: "Health Snapshot",
            summary: dashboard.hero.summary,
            state: dashboard.hero.band.lowercased() == "guarded" ? .warning : .ready,
            metrics: [
                .init(key: "Band", value: dashboard.hero.band),
                .init(key: "Confidence", value: dashboard.hero.confidence.formattedPercent0),
                .init(key: "Refreshed", value: dashboard.generatedAt.formatted(.dateTime.hour().minute()))
            ],
            footer: "Local Apple Health only."
        )
    }

    private static func sleepResult(for dashboard: HealthDashboard) -> ConversationToolResult {
        ConversationToolResult(
            id: "sleep_summary",
            title: "Sleep Summary",
            summary: dashboard.sleepSummary.summary,
            state: .ready,
            metrics: [
                .init(key: "Average", value: "\(dashboard.sleepSummary.averageHours.formattedOneDecimal) h"),
                .init(key: "Latest", value: "\(dashboard.sleepSummary.latestHours.formattedOneDecimal) h"),
                .init(key: "Debt", value: "\(dashboard.sleepSummary.debtHours.formattedOneDecimal) h")
            ],
            footer: "Computed from recent Apple Health sleep segments."
        )
    }

    private static func aiRuntimeResult(for dashboard: HealthDashboard) -> ConversationToolResult {
        ConversationToolResult(
            id: "ai_runtime",
            title: "AI Runtime",
            summary: "The AI layer uses one conversation surface and opens deeper tools only when the task needs it.",
            state: .ready,
            metrics: [
                .init(key: "Primary", value: dashboard.modelSummary?.engine ?? "Local-first"),
                .init(key: "Health", value: "Grounded"),
                .init(key: "Cloud", value: "Off by default")
            ],
            footer: "Use AI for routing and explanation, not for replacing the health data source."
        )
    }

    private static func ungroundedAIResult() -> ConversationToolResult {
        ConversationToolResult(
            id: "ai_runtime_base",
            title: "AI Runtime",
            summary: "The conversation layer is live even before Health is attached.",
            state: .ready,
            metrics: [
                .init(key: "Primary", value: "kAir Orchestrator"),
                .init(key: "Health", value: "Attach later"),
                .init(key: "Cloud", value: "Off by default")
            ],
            footer: "Attach Apple Health when you want evidence-backed health answers."
        )
    }

    private static func mapsResult() -> ConversationToolResult {
        ConversationToolResult(
            id: "maps_surface",
            title: "Maps Surface",
            summary: "Prepared nearby places, live route context, and in-app navigation inside the shell.",
            state: .ready,
            metrics: [
                .init(key: "Places", value: "Clinics · Pharmacy · Gym"),
                .init(key: "Mode", value: "Task-first"),
                .init(key: "Route", value: "In-app"),
                .init(key: "CarPlay", value: "Ready")
            ],
            footer: "Chat can hand off into live map search, navigation, and route return without breaking the thread."
        )
    }

    private static func musicSurfaceResult() -> ConversationToolResult {
        ConversationToolResult(
            id: "music_surface",
            title: "Music Layer",
            summary: "Prepared a persistent music player that keeps playback live while chat stays primary.",
            state: .ready,
            metrics: [
                .init(key: "Player", value: "Persistent"),
                .init(key: "Entry", value: "Intent-driven"),
                .init(key: "Thread", value: "Unchanged")
            ],
            footer: "Music is not a permanent tab. It hangs off the shell while the conversation keeps going."
        )
    }

    private static func videoSurfaceResult() -> ConversationToolResult {
        ConversationToolResult(
            id: "video_surface",
            title: "Video Layer",
            summary: "Prepared a focused video surface for visual answers, demos, and guided sessions.",
            state: .ready,
            metrics: [
                .init(key: "Surface", value: "Focused"),
                .init(key: "Return", value: "Summary only"),
                .init(key: "Thread", value: "Preserved")
            ],
            footer: "Video opens only when the answer needs a visual surface instead of a long chat reply."
        )
    }

    private static func storeResult() -> ConversationToolResult {
        ConversationToolResult(
            id: "store_surface",
            title: "Store Curation",
            summary: "Prepared a curated store layer for recovery, wearables, and nutrition.",
            state: .working,
            metrics: [
                .init(key: "Focus", value: "Sleep + Recovery"),
                .init(key: "Style", value: "Curated"),
                .init(key: "Checkout", value: "Not wired")
            ],
            footer: "Commerce and checkout are intentionally out of scope for the current rebuild."
        )
    }

    private static func healthAccessResult(supportsHealthData: Bool) -> ConversationToolResult {
        ConversationToolResult(
            id: "health_access",
            title: supportsHealthData ? "Apple Health Access" : "HealthKit Unavailable",
            summary: supportsHealthData
                ? "Chat is live now. Attach Apple Health whenever you want local health grounding."
                : "This device cannot provide Apple Health grounding.",
            state: supportsHealthData ? .working : .warning,
            metrics: [
                .init(key: "Chat", value: "Ready"),
                .init(key: "Health", value: supportsHealthData ? "Connect" : "Unavailable"),
                .init(key: "Maps", value: "Ready"),
                .init(key: "Music", value: "Ready")
            ],
            footer: supportsHealthData
                ? "Open the Health surface to grant Apple Health access."
                : "Use AI, Maps, Music, Video, and Store without local Apple Health."
        )
    }

    private func userProfileResult() -> ConversationToolResult {
        ConversationToolResult(
            id: "user_profile_surface",
            title: "User",
            summary: "Prepared the user settings sheet from inside the current thread.",
            state: .ready,
            metrics: [
                .init(key: "Surface", value: "Profile sheet"),
                .init(key: "Thread", value: "Same conversation"),
                .init(key: "Storage", value: isTemplateChat ? "Template only" : "Saved locally")
            ],
            footer: "Use this testing route to jump into the user interface from chat."
        )
    }

    private func healthReturnMessage(
        for session: HealthRouteSession,
        dashboard: HealthDashboard
    ) -> ConversationMessage? {
        let summary = healthReturnSummary(for: session, dashboard: dashboard)
        let title = session.language == .chinese ? "Health 已回写线程" : "Health wrote back to chat"
        let text = session.language == .chinese
            ? "已回到聊天。Health 保留了原线程，并把本地摘要写回这里。"
            : "Back in chat. Health kept the same thread and wrote the local summary below."

        return .assistant(
            text: text,
            tags: [
                "Health",
                session.language == .chinese ? "返回聊天" : "Back in chat"
            ],
            toolResults: [
                ConversationToolResult(
                    id: "health-return-\(session.topic.rawValue)",
                    title: title,
                    summary: summary,
                    state: .ready,
                    metrics: [
                        .init(
                            key: session.language == .chinese ? "主题" : "Topic",
                            value: session.topic.title(for: session.language)
                        ),
                        .init(
                            key: session.language == .chinese ? "数据" : "Data",
                            value: session.language == .chinese ? "本地 Apple Health" : "Local Apple Health"
                        ),
                        .init(
                            key: session.language == .chinese ? "线程" : "Thread",
                            value: session.language == .chinese ? "原会话保留" : "Original thread kept"
                        )
                    ],
                    footer: session.language == .chinese
                        ? "回到聊天后只保留摘要，不回写原始健康数据。"
                        : "Only summarized output returns to chat, not raw Health data."
                )
            ]
        )
    }

    private func healthReturnSummary(
        for session: HealthRouteSession,
        dashboard: HealthDashboard
    ) -> String {
        switch (session.topic, session.language) {
        case (.sleep, .chinese):
            return "最近 \(dashboard.sleepSummary.nightsTracked) 晚平均睡眠 \(dashboard.sleepSummary.averageHours.formattedOneDecimal) 小时，最新一晚 \(dashboard.sleepSummary.latestHours.formattedOneDecimal) 小时。"
        case (.sleep, .english):
            return "Sleep averaged \(dashboard.sleepSummary.averageHours.formattedOneDecimal) h/night across \(dashboard.sleepSummary.nightsTracked) nights. The latest night was \(dashboard.sleepSummary.latestHours.formattedOneDecimal) h."
        case (.activity, .chinese):
            return "最近分析窗口内记录了 \(dashboard.workouts.count) 次运动，最新一次是 \(dashboard.workouts.first?.activity ?? "最新活动")。"
        case (.activity, .english):
            return "The current window includes \(dashboard.workouts.count) workouts, with \(dashboard.workouts.first?.activity ?? "the latest activity") as the newest session."
        case (.heart, .chinese):
            if let signal = heartSignal(in: dashboard) {
                return "心率相关信号提示：\(signal.highlight)"
            }
            return dashboard.hero.summary
        case (.heart, .english):
            if let signal = heartSignal(in: dashboard) {
                return "Heart-rate signal update: \(signal.highlight)"
            }
            return dashboard.hero.summary
        case (.ecg, .chinese):
            if let latestReading = dashboard.ecgReadings.first {
                return "最近 ECG 记录为“\(latestReading.classification)”，当前窗口共 \(dashboard.ecgReadings.count) 条。"
            }
            return "当前窗口没有可回写的 ECG 记录。"
        case (.ecg, .english):
            if let latestReading = dashboard.ecgReadings.first {
                return "The latest ECG reading is “\(latestReading.classification),” with \(dashboard.ecgReadings.count) readings in the current window."
            }
            return "There are no ECG readings available to write back in the current window."
        case (.recovery, .chinese), (.overall, .chinese):
            return Self.leadingInsight(in: dashboard)?.summary ?? dashboard.hero.summary
        case (.recovery, .english), (.overall, .english):
            return Self.leadingInsight(in: dashboard)?.summary ?? dashboard.hero.summary
        }
    }

    private func aiReturnMessage(dashboard: HealthDashboard?) -> ConversationMessage {
        let summary: String
        let primaryRuntime: String
        let healthState: String

        if let dashboard {
            summary = "AI surfaced the current runtime: one local-first orchestrator stays primary, Health grounding remains on-demand, and cloud fallback stays off by default."
            primaryRuntime = dashboard.modelSummary?.engine ?? "Local-first"
            healthState = "Grounded on demand"
        } else {
            summary = "AI surfaced the current runtime: the conversation layer is live, Health grounding can be attached later, and cloud fallback stays off by default."
            primaryRuntime = "kAir Orchestrator"
            healthState = supportsHealthData ? "Attach later" : "Unavailable"
        }

        return .assistant(
            text: "Back in chat. AI returned the runtime summary below.",
            tags: ["AI", "Back in chat"],
            toolResults: [
                ConversationToolResult(
                    id: "ai-return",
                    title: "AI wrote back to chat",
                    summary: summary,
                    state: .ready,
                    metrics: [
                        .init(key: "Primary", value: primaryRuntime),
                        .init(key: "Health", value: healthState),
                        .init(key: "Thread", value: "Original thread kept")
                    ],
                    footer: "The AI page stays a focused surface while chat remains the default entry."
                )
            ]
        )
    }

    private func storeReturnMessage() -> ConversationMessage {
        .assistant(
            text: "Back in chat. Store returned the curation summary below.",
            tags: ["Store", "Back in chat"],
            toolResults: [
                ConversationToolResult(
                    id: "store-return",
                    title: "Store wrote back to chat",
                    summary: "Store kept the same thread and returned curated directions around recovery, wearables, and nutrition. Checkout remains intentionally unwired.",
                    state: .ready,
                    metrics: [
                        .init(key: "Focus", value: "Recovery first"),
                        .init(key: "Catalog", value: "Curated"),
                        .init(key: "Thread", value: "Original thread kept")
                    ],
                    footer: "The commerce layer is still a focused surface, not a separate conversation."
                )
            ]
        )
    }

    private func musicReturnMessage(session: MusicPlaybackSession?) -> ConversationMessage {
        let title = session?.title ?? "Music"
        let mood = session?.mood.title ?? "Playback"

        return .assistant(
            text: "Back in chat. Music kept the player alive below and returned the current playback summary.",
            tags: ["Music", "Back in chat"],
            toolResults: [
                ConversationToolResult(
                    id: "music-return",
                    title: "Music wrote back to chat",
                    summary: "\(title) is still active in the persistent player while the conversation remains the main surface.",
                    state: .ready,
                    metrics: [
                        .init(key: "Track", value: title),
                        .init(key: "Mode", value: mood),
                        .init(key: "Thread", value: "Original thread kept")
                    ],
                    footer: "Leaving Music does not stop playback unless the user explicitly stops it."
                )
            ]
        )
    }

    private func videoReturnMessage(session: VideoPlaybackSession?) -> ConversationMessage {
        let title = session?.title ?? "Video"
        let category = session?.category.title ?? "Visual response"

        return .assistant(
            text: "Back in chat. Video returned the compact summary below.",
            tags: ["Video", "Back in chat"],
            toolResults: [
                ConversationToolResult(
                    id: "video-return",
                    title: "Video wrote back to chat",
                    summary: "\(title) finished as a focused surface and returned control to the original thread.",
                    state: .ready,
                    metrics: [
                        .init(key: "Title", value: title),
                        .init(key: "Category", value: category),
                        .init(key: "Thread", value: "Original thread kept")
                    ],
                    footer: "Video stays an invoked surface instead of becoming a second home."
                )
            ]
        )
    }

    private func heartSignal(in dashboard: HealthDashboard) -> SignalSeries? {
        dashboard.signals.first { signal in
            let label = signal.label.lowercased()
            return label.contains("heart") || signal.id.contains("heart")
        }
    }

    private static func leadingInsight(in dashboard: HealthDashboard) -> InsightCard? {
        dashboard.insights.max(by: { $0.score < $1.score })
    }

    private static func isHealthPrompt(_ normalized: String) -> Bool {
        normalized.contains("sleep") ||
            normalized.contains("recovery") ||
            normalized.contains("health") ||
            normalized.contains("heart") ||
            normalized.contains("hrv") ||
            normalized.contains("ecg")
    }

    private func healthHandoffText(
        for session: HealthRouteSession,
        dashboard: HealthDashboard?
    ) -> String {
        let topic = session.topic.title(for: session.language)

        switch session.language {
        case .chinese:
            if dashboard != nil {
                return "进入 Health 继续这个\(topic)查询。原线程保留，返回后只回写摘要。"
            }

            if supportsHealthData {
                return "进入 Health 处理这个\(topic)查询。若这台设备还没授权，页面会先说明所需权限。"
            }

            return "进入 Health 查看这个\(topic)查询，但这台设备当前不能提供本地 Apple Health 数据。"
        case .english:
            if dashboard != nil {
                return "Entering Health for this \(topic.lowercased()) check. The original thread stays here and only the summary writes back."
            }

            if supportsHealthData {
                return "Entering Health for this \(topic.lowercased()) check. The page will explain Apple Health access first if this device is not authorized yet."
            }

            return "Entering Health for this \(topic.lowercased()) check, but this device cannot provide local Apple Health data right now."
        }
    }

    private func healthHandoffResult(
        for session: HealthRouteSession,
        dashboard: HealthDashboard?
    ) -> ConversationToolResult {
        switch session.language {
        case .chinese:
            if dashboard != nil {
                return ConversationToolResult(
                    id: "health_handoff_ready",
                    title: "Health 已接管",
                    summary: "聊天已把这次查询切到 Health 页面，由本地数据完成结论、证据和限制说明。",
                    state: .ready,
                    metrics: [
                        .init(key: "主题", value: session.topic.title(for: .chinese)),
                        .init(key: "数据", value: "本地 Apple Health"),
                        .init(key: "线程", value: "保持同一会话")
                    ],
                    footer: "聊天层只保留摘要与 handoff 记录，不暴露原始 Health 数据。"
                )
            }

            if supportsHealthData {
                return ConversationToolResult(
                    id: "health_handoff_auth",
                    title: "Health 等待授权",
                    summary: "Health 页面会先解释权限用途，再继续本地分析。",
                    state: .working,
                    metrics: [
                        .init(key: "主题", value: session.topic.title(for: .chinese)),
                        .init(key: "下一步", value: "授权 Apple Health"),
                        .init(key: "线程", value: "保持同一会话")
                    ],
                    footer: "权限是 just-in-time 触发，不会在聊天首页强行索取。"
                )
            }

            return ConversationToolResult(
                id: "health_handoff_unavailable",
                title: "Health 不可用",
                summary: "这台设备当前不能提供本地 Apple Health 证据。",
                state: .warning,
                metrics: [
                    .init(key: "主题", value: session.topic.title(for: .chinese)),
                    .init(key: "Health", value: "不可用"),
                    .init(key: "线程", value: "保持同一会话")
                ],
                footer: "聊天仍可继续，但这里不能给出本地健康结论。"
            )
        case .english:
            if dashboard != nil {
                return ConversationToolResult(
                    id: "health_handoff_ready",
                    title: "Health Focused Surface",
                    summary: "The chat thread handed this request to Health, where the conclusion, evidence, and limitations stay grounded locally.",
                    state: .ready,
                    metrics: [
                        .init(key: "Topic", value: session.topic.title(for: .english)),
                        .init(key: "Data", value: "Local Apple Health"),
                        .init(key: "Thread", value: "Same conversation")
                    ],
                    footer: "Chat receives only summarized output and the handoff record, not raw Health data."
                )
            }

            if supportsHealthData {
                return ConversationToolResult(
                    id: "health_handoff_auth",
                    title: "Health Authorization",
                    summary: "Health will explain the permission step first, then continue the local analysis flow.",
                    state: .working,
                    metrics: [
                        .init(key: "Topic", value: session.topic.title(for: .english)),
                        .init(key: "Next", value: "Authorize Apple Health"),
                        .init(key: "Thread", value: "Same conversation")
                    ],
                    footer: "The permission request is just-in-time. It does not interrupt chat unless the user asks for Health."
                )
            }

            return ConversationToolResult(
                id: "health_handoff_unavailable",
                title: "Health Unavailable",
                summary: "This device cannot provide local Apple Health evidence for the requested health check.",
                state: .warning,
                metrics: [
                    .init(key: "Topic", value: session.topic.title(for: .english)),
                    .init(key: "Health", value: "Unavailable"),
                    .init(key: "Thread", value: "Same conversation")
                ],
                footer: "The conversation can continue, but this request cannot be grounded in local Health data here."
            )
        }
    }

    private func healthHandoffTags(for session: HealthRouteSession) -> [String] {
        switch session.language {
        case .chinese:
            return ["Health", session.topic.title(for: .chinese), "Focused surface"]
        case .english:
            return ["Health", session.topic.title(for: .english), "Focused surface"]
        }
    }

    private func explicitHealthIntent(from prompt: String) -> HealthRouteSession? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let normalized = trimmed.lowercased()
        guard shouldHandoffToHealth(normalized: normalized, prompt: trimmed) else {
            return nil
        }

        let language: HealthConversationLanguage = Self.containsChinese(in: trimmed) ? .chinese : .english
        let topic = healthTopic(normalized: normalized, prompt: trimmed)

        return HealthRouteSession(
            topic: topic,
            language: language,
            originalPrompt: prompt
        )
    }

    private func shouldHandoffToHealth(normalized: String, prompt: String) -> Bool {
        guard containsHealthTopic(normalized: normalized, prompt: prompt) else {
            return false
        }

        if isDirectHealthOpenRequest(normalized: normalized, prompt: prompt) {
            return true
        }

        if containsNonHealthProductContext(normalized: normalized, prompt: prompt) {
            return false
        }

        return isHealthStatusQuery(normalized: normalized, prompt: prompt)
    }

    private func healthTopic(normalized: String, prompt: String) -> HealthFocusedTopic {
        if normalized.contains("ecg") || normalized.contains("electrocardiogram") || prompt.contains("心电") {
            return .ecg
        }

        if normalized.contains("sleep") || normalized.contains("slept") || normalized.contains("bed") || prompt.contains("睡") {
            return .sleep
        }

        if normalized.contains("recovery") || normalized.contains("recover") || normalized.contains("readiness") || prompt.contains("恢复") || prompt.contains("疲劳") {
            return .recovery
        }

        if normalized.contains("step") ||
            normalized.contains("walking") ||
            normalized.contains("walked") ||
            normalized.contains("workout") ||
            normalized.contains("activity") ||
            prompt.contains("步数") ||
            prompt.contains("运动") ||
            prompt.contains("锻炼")
        {
            return .activity
        }

        if normalized.contains("heart rate") ||
            normalized.contains("resting heart") ||
            normalized.contains("pulse") ||
            normalized.contains("bpm") ||
            normalized.contains("hrv") ||
            prompt.contains("心率") ||
            prompt.contains("心跳")
        {
            return .heart
        }

        return .overall
    }

    private func containsHealthTopic(normalized: String, prompt: String) -> Bool {
        let englishTokens = [
            "sleep",
            "slept",
            "recovery",
            "recover",
            "health",
            "wellness",
            "heart",
            "hrv",
            "bpm",
            "pulse",
            "step",
            "steps",
            "workout",
            "activity",
            "ecg",
            "electrocardiogram",
        ]
        let chineseTokens = [
            "健康",
            "睡",
            "恢复",
            "心率",
            "心跳",
            "步数",
            "运动",
            "锻炼",
            "心电",
        ]

        if englishTokens.contains(where: normalized.contains) {
            return true
        }

        return chineseTokens.contains(where: prompt.contains)
    }

    private func containsNonHealthProductContext(normalized: String, prompt: String) -> Bool {
        let englishTokens = [
            "healthkit",
            "permission",
            "privacy",
            "policy",
            "feature",
            "tool",
            "route",
            "page",
            "surface",
            "design",
            "sdk",
            "api",
            "integration",
            "import",
            "export",
            "chat",
        ]
        let chineseTokens = [
            "权限",
            "隐私",
            "设计",
            "页面",
            "入口",
            "工具",
            "路由",
            "功能",
            "接口",
            "导入",
            "导出",
            "聊天",
        ]

        if englishTokens.contains(where: normalized.contains) {
            return true
        }

        return chineseTokens.contains(where: prompt.contains)
    }

    private func isDirectHealthOpenRequest(normalized: String, prompt: String) -> Bool {
        let englishPhrases = [
            "open health",
            "open health page",
            "show health",
            "show me health",
            "take me to health",
            "go to health",
        ]
        let chinesePhrases = [
            "打开健康",
            "打开健康页面",
            "进入健康",
            "去健康页",
            "看健康页",
        ]

        if englishPhrases.contains(where: normalized.contains) {
            return true
        }

        return chinesePhrases.contains(where: prompt.contains)
    }

    private func isHealthStatusQuery(normalized: String, prompt: String) -> Bool {
        let englishPhrases = [
            "how is",
            "how's",
            "how am",
            "what is",
            "what's",
            "did i",
            "am i",
            "show me",
            "check my",
            "review my",
            "analyze my",
            "analyse my",
            "tell me",
            "today",
            "tonight",
            "last night",
            "recent",
            "lately",
            "trend",
            "status",
            "overview",
        ]
        let chinesePhrases = [
            "怎么样",
            "如何",
            "好吗",
            "睡得",
            "情况",
            "状态",
            "趋势",
            "最近",
            "昨晚",
            "今天",
            "看下",
            "看看",
            "查下",
            "查一下",
            "分析",
            "评估",
        ]

        if normalized.contains("?") || prompt.contains("？") {
            return true
        }

        if englishPhrases.contains(where: normalized.contains) {
            return true
        }

        return chinesePhrases.contains(where: prompt.contains)
    }

    private func exactHealthCommand(
        normalized: String,
        prompt: String
    ) -> HealthRouteSession? {
        let englishCommands = ["health", "open health", "health page"]
        let chineseCommands = ["健康", "打开健康", "健康页"]

        guard englishCommands.contains(normalized) || chineseCommands.contains(prompt) else {
            return nil
        }

        let language: HealthConversationLanguage = Self.containsChinese(in: prompt) ? .chinese : .english
        return HealthRouteSession(
            topic: .overall,
            language: language,
            originalPrompt: prompt
        )
    }

    private func isMapsCommand(_ normalized: String, prompt: String) -> Bool {
        let englishCommands = ["map", "maps", "open maps"]
        let chineseCommands = ["地图", "打开地图", "maps"]
        return englishCommands.contains(normalized) || chineseCommands.contains(prompt)
    }

    private func isMusicCommand(_ normalized: String, prompt: String) -> Bool {
        let englishCommands = ["music", "open music", "music player"]
        let chineseCommands = ["音乐", "打开音乐", "音乐播放器"]
        return englishCommands.contains(normalized) || chineseCommands.contains(prompt)
    }

    private func isVideoCommand(_ normalized: String, prompt: String) -> Bool {
        let englishCommands = ["video", "open video", "video player"]
        let chineseCommands = ["视频", "打开视频", "视频播放器"]
        return englishCommands.contains(normalized) || chineseCommands.contains(prompt)
    }

    private func isUserCommand(_ normalized: String, prompt: String) -> Bool {
        let englishCommands = ["user", "profile", "me", "open user"]
        let chineseCommands = ["用户", "个人资料", "设置", "我的"]
        return englishCommands.contains(normalized) || chineseCommands.contains(prompt)
    }

    private func handleTemplateChatChange() {
        if isTemplateChat {
            persistence.remove()
        } else {
            persistIfNeeded()
        }
    }

    private func recordEvent(
        stage: MatchingBehaviorEvent.Stage,
        subject: MatchingBehaviorEvent.Subject,
        candidateID: String? = nil,
        objectKind: MatchingObjectKind? = nil,
        surface: AppSection? = nil,
        rawText: String? = nil,
        tags: Set<MatchingIntentTag>,
        feedback: MatchingFeedbackKind? = nil,
        outcome: MatchingOutcomeMetrics = MatchingOutcomeMetrics()
    ) {
        let event = MatchingBehaviorEvent(
            stage: stage,
            subject: subject,
            candidateID: candidateID,
            objectKind: objectKind,
            surface: surface,
            rawText: rawText,
            tags: tags,
            feedback: feedback,
            outcome: outcome
        )
        
        print("[ChatStore] Event: stage=\(stage.rawValue), subject=\(subject.rawValue), id=\(candidateID ?? "nil"), kind=\(objectKind?.rawValue ?? "nil"), feedback=\(feedback?.rawValue ?? "nil")")
        
        behaviorLog.append(event)
        replayLab.recordOutcomeEvent(event)

        if behaviorLog.count > 64 {
            behaviorLog.removeFirst(behaviorLog.count - 64)
        }
    }

    private func refreshRecommendedMatches(
        seedPrompt: String? = nil,
        replaceActiveLifecycle: Bool = false
    ) {
        if replaceActiveLifecycle {
            _ = eventRecorder.abandonActiveLifecycleIfNeeded(surface: .chat)
            syncClosedLifecycleArtifacts()
        }

        let snapshot = matchingSnapshot(
            label: "Current thread",
            recentPrompt: seedPrompt
        )
        replayFrames = [
            replayLab.beginScenario(
                snapshot: snapshot,
                recentEventsWindow: Array(behaviorLog.suffix(8))
            ),
        ]
        recommendedMatches = replayFrames.first?.recommendations ?? []
        beginDecisionLifecycle(seedPrompt: seedPrompt)
        recordRecommendationImpressions(for: recommendedMatches)
    }

    private func beginDecisionLifecycle(seedPrompt: String?) {
        let returnContextState = pendingReturnContextState
        let bundle = matchingEngine.decideWithSnapshot(
            recentPrompt: seedPrompt,
            session: session,
            healthAvailability: healthAvailability,
            locationState: locationState,
            motionContext: motionContext,
            behaviorLog: behaviorLog,
            returnContextState: returnContextState,
            activeSurface: .chat
        )
        eventRecorder.beginLifecycle(
            context: bundle.contextSnapshot,
            decision: bundle.decision
        )
        activeDecision = bundle.decision
        pendingReturnContextState = nil
    }

    private func matchingTags(from text: String) -> Set<MatchingIntentTag> {
        matchingEngine.intentTags(for: text)
    }

    var debugPendingReturnContextState: ExecutionReturnContextState? {
        pendingReturnContextState
    }

    func debugApplyExecutionReturnPayload(_ payload: ExecutionReturnPayload) {
        applyExecutionReturnPayload(payload)
    }

    func scenarioPrimeRecommendations(seedPrompt: String?) {
        refreshRecommendedMatches(
            seedPrompt: seedPrompt,
            replaceActiveLifecycle: false
        )
    }

    private func applyExecutionReturnPayload(_ payload: ExecutionReturnPayload) {
        let foldback = ExecutionReturnContextState.from(payload: payload)
        if let pendingReturnContextState {
            self.pendingReturnContextState = pendingReturnContextState.merged(with: foldback)
        } else {
            pendingReturnContextState = foldback
        }
    }

    private func syncClosedLifecycleArtifacts() {
        if let export = eventRecorder.lastPersistedExport {
            lastExportedSession = export
        }
        replayLab.finalizePendingScenario()
    }

    private func recordRecommendationImpressions(for recommendations: [UnifiedMatchRecommendation]) {
        let visibleRecommendations = Array(recommendations.prefix(4))
        let visibleIDs = visibleRecommendations.map(\.id)
        guard visibleIDs != lastImpressedRecommendationIDs else { return }

        lastImpressedRecommendationIDs = visibleIDs

        for recommendation in visibleRecommendations {
            recordEvent(
                stage: .impression,
                subject: .recommendation,
                candidateID: recommendation.candidate.id,
                objectKind: recommendation.candidate.objectKind,
                surface: recommendation.candidate.preferredSection,
                rawText: recommendation.candidate.activationPrompt,
                tags: recommendation.candidate.tags
            )
        }
    }

    private func consumeAcceptedRecommendation(for prompt: String) -> UnifiedMatchRecommendation? {
        guard let recommendation = pendingAcceptedRecommendation else { return nil }
        pendingAcceptedRecommendation = nil

        guard recommendation.candidate.activationPrompt == prompt else {
            return nil
        }

        return recommendation
    }

    private func registerAcceptedRecommendation(
        _ recommendation: UnifiedMatchRecommendation?,
        for route: ConversationRoute?
    ) {
        guard let recommendation else { return }

        let section: AppSection?
        switch route?.destination {
        case .surface(let destination):
            activeRecommendationBySection[destination] = recommendation
            section = destination
        case .persistentPlayer:
            activeRecommendationBySection[.music] = recommendation
            section = .music
        case .userProfile, .none:
            section = nil
        }

        if let section {
            executionStartDates[section] = .now
            eventRecorder.recordExecutionOpen(
                candidate: recommendation,
                surface: section
            )
            preparePendingSurfaceEntryRequest(
                for: section,
                candidate: recommendation
            )
        }
    }

    private func preparePendingSurfaceEntryRequest(
        for section: AppSection,
        candidate: UnifiedMatchRecommendation
    ) {
        guard section != .chat else { return }
        let intent = SurfaceEntryIntent(section: section)
        var args: [String: String] = [:]
        var objectType: String = candidate.candidate.objectKind.rawValue
        var objectId: String? = candidate.candidate.id
        var handoffSummary: String? = nil

        switch section {
        case .maps:
            if let task = resolvedMapTask {
                objectType = MatchingObjectKind.place.rawValue
                objectId = task.id
                args["query"] = task.query
                args["task_type"] = task.taskType.rawValue
                args["language"] = task.language.usesChineseCopy ? "zh" : "en"
                args["entry_mode"] = task.entryMode.rawValue
                if let mode = task.transportMode {
                    args["transport_mode"] = mode.rawValue
                }
                handoffSummary = task.resultSummary.isEmpty ? nil : task.resultSummary
            }
        case .music:
            if let musicSession = resolvedMusicSession {
                objectType = MatchingObjectKind.song.rawValue
                objectId = musicSession.id.uuidString
                args["mood"] = musicSession.mood.rawValue
                args["query"] = musicSession.query
                args["title"] = musicSession.title
                handoffSummary = musicSession.subtitle
            }
        case .video:
            if let videoSession = resolvedVideoSession {
                objectType = MatchingObjectKind.video.rawValue
                objectId = videoSession.id.uuidString
                args["category"] = videoSession.category.rawValue
                args["query"] = videoSession.query
                args["title"] = videoSession.title
                handoffSummary = videoSession.summary
            }
        case .health:
            if let healthSession = resolvedHealthSession {
                objectType = MatchingObjectKind.answerCard.rawValue
                args["topic"] = healthSession.topic.rawValue
                args["language"] = healthSession.language == .chinese ? "zh" : "en"
                args["original_prompt"] = healthSession.originalPrompt
                handoffSummary = healthSession.originalPrompt
            }
        case .store, .ai:
            break
        case .chat:
            return
        }

        let request = SurfaceEntryRequest(
            surfaceType: section,
            entryIntent: intent,
            sourceCardId: candidate.candidate.id,
            sourceRecommendationId: activeDecision?.recommendationId,
            sourceThreadId: self.session.id.uuidString,
            objectType: objectType,
            objectId: objectId,
            normalizedArgs: args,
            handoffContext: SurfaceEntryHandoffContext(
                sourceMessagePreview: candidate.candidate.activationPrompt,
                returnThreadId: self.session.id.uuidString,
                priorContextStateSummary: handoffSummary
            )
        )
        pendingSurfaceEntryRequests[section] = request
    }

    func pendingSurfaceEntryRequest(for section: AppSection) -> SurfaceEntryRequest? {
        pendingSurfaceEntryRequests[section]
    }

    func consumePendingSurfaceEntryRequest(for section: AppSection) -> SurfaceEntryRequest? {
        let request = pendingSurfaceEntryRequests[section]
        pendingSurfaceEntryRequests[section] = nil
        return request
    }

    func handleSurfaceEntryEvent(
        phase: SurfaceEntryEventPhase,
        request: SurfaceEntryRequest
    ) {
        let candidate = activeRecommendationBySection[request.surfaceType]
        switch phase {
        case .requested:
            eventRecorder.recordSurfaceEntryRequested(
                request: request,
                candidate: candidate
            )
            pendingSurfaceEntryRequests[request.surfaceType] = nil
            activeSurfaceEntryRequests[request.surfaceType] = request
        case .started:
            eventRecorder.recordSurfaceEntryStarted(
                request: request,
                candidate: candidate
            )
            activeSurfaceEntryRequests[request.surfaceType] = request
        case .returned:
            eventRecorder.recordSurfaceEntryReturned(
                request: request,
                payload: nil,
                candidate: candidate
            )
            activeSurfaceEntryRequests[request.surfaceType] = nil
        }
    }

    private func routeSection(for destination: ConversationDestination?) -> AppSection? {
        switch destination {
        case .surface(let section):
            return section
        case .persistentPlayer:
            return .music
        case .userProfile, .none:
            return nil
        }
    }

    private func executionReturnPayload(
        for section: AppSection,
        candidate: UnifiedMatchRecommendation?,
        stage: MatchingBehaviorEvent.Stage,
        metrics: MatchingOutcomeMetrics
    ) -> ExecutionReturnPayload {
        let outcome: ExecutionOutcome = {
            switch stage {
            case .completion:
                return metrics.wasSuccessful ? .completed : .partial
            case .abandon:
                return .abandoned
            default:
                return metrics.wasSuccessful ? .completed : .abandoned
            }
        }()
        let duration: TimeInterval = {
            if let metricDuration = metrics.dwellSeconds {
                return metricDuration
            }
            if let started = executionStartDates[section] {
                return max(0, Date.now.timeIntervalSince(started))
            }
            return 0
        }()
        let addedIntentTags = executionFoldbackTags(
            for: section,
            candidate: candidate,
            stage: stage,
            metrics: metrics
        )
        let resolvedObjectIds: [String]
        let dismissedObjectIds: [String]

        switch stage {
        case .completion:
            resolvedObjectIds = candidate.map { [$0.candidate.id] } ?? []
            dismissedObjectIds = []
        case .abandon:
            resolvedObjectIds = []
            dismissedObjectIds = []
        case .accept, .click, .dismiss, .impression:
            resolvedObjectIds = []
            dismissedObjectIds = []
        }

        let delta = ExecutionReturnPayload.ReturnContextDelta(
            downstreamValue: metrics.downstreamValue,
            completionScore: metrics.completionScore,
            addedIntentTags: addedIntentTags,
            resolvedObjectIds: resolvedObjectIds,
            dismissedObjectIds: dismissedObjectIds,
            summary: candidate?.candidate.activationPrompt ?? section.title
        )
        let entryRequest = activeSurfaceEntryRequests[section]
            ?? pendingSurfaceEntryRequests[section]
        return ExecutionReturnPayload(
            executedCandidateId: candidate?.candidate.id ?? section.rawValue,
            executionSurfaceType: section,
            outcome: outcome,
            duration: duration,
            returnContextDelta: delta,
            sourceRequestId: entryRequest?.requestId,
            sourceRecommendationId: entryRequest?.sourceRecommendationId
                ?? activeDecision?.recommendationId
        )
    }

    private func executionFoldbackTags(
        for section: AppSection,
        candidate: UnifiedMatchRecommendation?,
        stage: MatchingBehaviorEvent.Stage,
        metrics: MatchingOutcomeMetrics
    ) -> [MatchingIntentTag] {
        guard stage == .completion else {
            return []
        }

        var tags = candidate?.candidate.tags ?? []
        if metrics.wasSuccessful {
            switch section {
            case .maps:
                tags.formUnion([.navigation, .planning])
            case .music:
                tags.formUnion([.focus, .entertainment])
            case .video:
                tags.formUnion([.entertainment, .search])
            case .health:
                tags.formUnion([.health])
            case .ai:
                tags.formUnion([.ai, .search])
            case .store:
                tags.formUnion([.shopping])
            case .chat:
                break
            }
        }
        return tags.sorted { $0.rawValue < $1.rawValue }
    }

    private func surfaceReturnStage(for context: AppSurfaceReturnContext) -> MatchingBehaviorEvent.Stage {
        switch context.section {
        case .music:
            return context.musicSession == nil ? .abandon : .completion
        case .video:
            return context.videoSession == nil ? .abandon : .completion
        case .health, .ai, .store:
            return .completion
        case .chat, .maps:
            return .abandon
        }
    }

    private func outcomeMetrics(
        for context: AppSurfaceReturnContext,
        healthSession: HealthRouteSession?
    ) -> MatchingOutcomeMetrics {
        switch context.section {
        case .health:
            return MatchingOutcomeMetrics(
                downstreamValue: healthSession == nil ? 0.18 : 0.72,
                completionScore: healthSession == nil ? 0.22 : 0.74,
                dwellSeconds: healthSession.map { Date.now.timeIntervalSince($0.generatedAt) },
                wasSuccessful: healthSession != nil
            )
        case .ai:
            return MatchingOutcomeMetrics(
                downstreamValue: 0.5,
                completionScore: 0.58,
                wasSuccessful: true
            )
        case .music:
            return MatchingOutcomeMetrics(
                downstreamValue: context.musicSession == nil ? 0.12 : 0.7,
                completionScore: context.musicSession == nil ? 0.16 : 0.68,
                dwellSeconds: context.musicSession.map { Date.now.timeIntervalSince($0.startedAt) },
                wasSuccessful: context.musicSession != nil
            )
        case .store:
            return MatchingOutcomeMetrics(
                downstreamValue: 0.42,
                completionScore: 0.46,
                wasSuccessful: true
            )
        case .video:
            return MatchingOutcomeMetrics(
                downstreamValue: context.videoSession == nil ? 0.2 : 0.6,
                completionScore: context.videoSession == nil ? 0.22 : 0.64,
                dwellSeconds: context.videoSession.map { Date.now.timeIntervalSince($0.startedAt) },
                wasSuccessful: context.videoSession != nil
            )
        case .chat, .maps:
            return .neutral
        }
    }

    private func outcomeMetrics(for feedback: MatchingFeedbackKind) -> MatchingOutcomeMetrics {
        switch feedback {
        case .dismiss:
            return MatchingOutcomeMetrics(
                downstreamValue: -0.10,
                completionScore: 0,
                wasSuccessful: false
            )
        case .notInterested:
            return MatchingOutcomeMetrics(
                downstreamValue: -0.28,
                completionScore: 0,
                wasSuccessful: false
            )
        case .lessLikeThis:
            return MatchingOutcomeMetrics(
                downstreamValue: -0.18,
                completionScore: 0,
                wasSuccessful: false
            )
        case .notNow:
            return MatchingOutcomeMetrics(
                downstreamValue: -0.05,
                completionScore: 0.08,
                wasSuccessful: false
            )
        case .alreadyDone:
            return MatchingOutcomeMetrics(
                downstreamValue: 0.34,
                completionScore: 0.62,
                wasSuccessful: true
            )
        }
    }

    private func mapReturnStage(for task: MapTask) -> MatchingBehaviorEvent.Stage {
        if task.hasResolvedDestination || task.hasUsableRoutes || task.nearbyResults.isEmpty == false {
            return .completion
        }

        return .abandon
    }

    private func outcomeMetrics(for task: MapTask) -> MatchingOutcomeMetrics {
        let success = task.hasResolvedDestination || task.hasUsableRoutes || task.nearbyResults.isEmpty == false
        let downstreamValue: Double

        switch task.taskType {
        case .goToPlace:
            downstreamValue = success ? 0.84 : 0.2
        case .nearbySearch, .recommendation:
            downstreamValue = success ? 0.66 : 0.18
        case .routeComparison:
            downstreamValue = success ? 0.88 : 0.24
        }

        return MatchingOutcomeMetrics(
            downstreamValue: downstreamValue,
            completionScore: success ? 0.78 : 0.22,
            dwellSeconds: Date.now.timeIntervalSince(task.generatedAt),
            wasSuccessful: success
        )
    }

    private func mapObjectKind(for task: MapTask) -> MatchingObjectKind {
        switch task.taskType {
        case .goToPlace, .nearbySearch, .recommendation:
            return .place
        case .routeComparison:
            return .route
        }
    }

    private func syncSpatialContext(from task: MapTask) {
        switch task.permissionState {
        case .authorizedWhenInUse:
            locationState = .precise
        case .manualOnly:
            locationState = .approximate
        case .denied:
            locationState = .unavailable
        case .unknown, .notDetermined:
            break
        }

        switch task.transportMode {
        case .walking:
            motionContext = .walking
        case .driving:
            motionContext = .driving
        case .transit, .none:
            motionContext = .stationary
        }
    }

    private func matchingSnapshot(
        label: String,
        recentPrompt: String?
    ) -> MatchingReplaySnapshot {
        MatchingReplaySnapshot(
            label: label,
            recentPrompt: recentPrompt,
            capturedAt: .now,
            session: session,
            healthAvailability: healthAvailability,
            locationState: locationState,
            motionContext: motionContext,
            activeSurface: .chat,
            returnContextState: pendingReturnContextState,
            behaviorLog: behaviorLog
        )
    }

    private func persistIfNeeded() {
        guard isTemplateChat == false else {
            return
        }
        persistence.save(session)
    }

    private static func isGenericMapsPrompt(_ normalized: String, prompt: String) -> Bool {
        let englishKeywords = [
            "apple store",
            "navigate",
            "direction",
            "route",
            "nearby",
            "map",
            "clinic",
            "pharmacy"
        ]
        let chineseKeywords = [
            "地图",
            "路线",
            "导航",
            "附近",
            "诊所",
            "药店",
            "超市"
        ]

        if englishKeywords.contains(where: normalized.contains) {
            return true
        }

        return chineseKeywords.contains(where: prompt.contains)
    }

    private static func isMusicPrompt(_ normalized: String, prompt: String) -> Bool {
        let englishKeywords = [
            "music",
            "playlist",
            "song",
            "jazz",
            "lofi",
            "ambient",
            "focus music",
            "play",
        ]
        let chineseKeywords = [
            "音乐",
            "播放",
            "歌",
            "歌单",
            "爵士",
            "白噪音",
            "专注",
            "放松",
        ]

        let englishSignal = englishKeywords.contains(where: normalized.contains) &&
            (normalized.contains("play") ||
                normalized.contains("music") ||
                normalized.contains("playlist"))

        if englishSignal {
            return true
        }

        return chineseKeywords.contains(where: prompt.contains)
    }

    private static func isVideoPrompt(_ normalized: String, prompt: String) -> Bool {
        let englishKeywords = [
            "video",
            "tutorial",
            "demo",
            "walkthrough",
            "watch",
        ]
        let chineseKeywords = [
            "视频",
            "教程",
            "演示",
            "示范",
        ]

        if englishKeywords.contains(where: normalized.contains) {
            return true
        }

        return chineseKeywords.contains(where: prompt.contains)
    }

    private static func containsChinese(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00 ... 0x9FFF).contains(Int(scalar.value))
        }
    }
}
