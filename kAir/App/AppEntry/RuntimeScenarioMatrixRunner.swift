//
//  RuntimeScenarioMatrixRunner.swift
//  kAir
//
//  Deterministic runtime corpus generator for round-0 collection.
//  It drives the real ChatStore / event-recorder loop and writes persisted
//  replay sessions into the app support ReplaySessions directory.
//

import Foundation

@MainActor
enum RuntimeScenarioMatrixRunner {
    private enum ToolKind: String, CaseIterable {
        case music
        case message
        case route
        case search
        case answer

        var providerID: String { "scenario-\(rawValue)" }

        var targetObjectKind: MatchingObjectKind {
            switch self {
            case .music:
                return .song
            case .message:
                return .contact
            case .route:
                return .route
            case .search:
                return .searchResult
            case .answer:
                return .answerCard
            }
        }

        var preferredSection: AppSection? {
            switch self {
            case .music:
                return .music
            case .route:
                return .maps
            case .message, .search, .answer:
                return nil
            }
        }

        var targetTags: Set<MatchingIntentTag> {
            switch self {
            case .music:
                return [.focus, .entertainment]
            case .message:
                return [.social, .planning]
            case .route:
                return [.navigation, .planning]
            case .search:
                return [.search, .learning]
            case .answer:
                return [.ai, .planning]
            }
        }

        var sourcePool: String {
            switch self {
            case .music:
                return "scenario_song_tower"
            case .message:
                return "scenario_contact_tower"
            case .route:
                return "scenario_route_tower"
            case .search:
                return "scenario_search_tower"
            case .answer:
                return "scenario_answer_tower"
            }
        }

        var utilityProfile: MatchingUtilityProfile {
            switch self {
            case .music:
                return MatchingUtilityProfile(
                    goal: .sessionSatisfaction,
                    domainWeight: 0.88,
                    nextStepWeight: 0.72
                )
            case .message:
                return MatchingUtilityProfile(
                    goal: .taskCompletion,
                    domainWeight: 0.82,
                    nextStepWeight: 0.8
                )
            case .route:
                return MatchingUtilityProfile(
                    goal: .taskCompletion,
                    domainWeight: 0.92,
                    nextStepWeight: 0.94
                )
            case .search:
                return MatchingUtilityProfile(
                    goal: .explanation,
                    domainWeight: 0.84,
                    nextStepWeight: 0.78
                )
            case .answer:
                return MatchingUtilityProfile(
                    goal: .explanation,
                    domainWeight: 0.8,
                    nextStepWeight: 0.82
                )
            }
        }

        var resolvedPrompts: [String] {
            switch self {
            case .music:
                return [
                    "play focus music",
                    "play a calm commute playlist",
                    "play something upbeat for cooking",
                    "play jazz for dinner prep",
                    "play ambient music for deep work",
                    "play relaxing music before bed",
                    "play workout music",
                    "play something for studying",
                    "play road trip music",
                    "play focus songs for writing",
                    "play calm music for reading",
                    "play energetic music for cleaning",
                ]
            case .message:
                return [
                    "text Sarah that I'll be 10 minutes late",
                    "tell Alex dinner starts at 7",
                    "message Priya that I'm downstairs",
                    "text Jordan I'll call after the meeting",
                    "tell Mom I got home safely",
                    "message Nina that the reservation is confirmed",
                    "tell Chris to bring the charger",
                    "text Ben that practice starts at 6",
                    "message Maya that the deck is ready",
                    "tell Emma I'll send the notes tonight",
                    "text Leo that I'm outside the cafe",
                    "message Ava that the train is delayed",
                ]
            case .route:
                return [
                    "navigate to Union Station",
                    "navigate to Pearson Airport",
                    "get me to High Park",
                    "directions to St. Lawrence Market",
                    "route me to CN Tower",
                    "navigate to Toronto General Hospital",
                    "directions to Billy Bishop Airport",
                    "route to Yorkdale Mall",
                    "navigate to Distillery District",
                    "get me to Kensington Market",
                    "directions to Nathan Phillips Square",
                    "route to Harbourfront Centre",
                ]
            case .search:
                return [
                    "search for Apple Store hours downtown",
                    "look up Toronto weather this weekend",
                    "search for best carry-on size rules",
                    "find the latest TTC subway delay update",
                    "search for a recipe for miso pasta",
                    "look up what ECE means in calibration",
                    "search for Jazz FM Toronto playlists",
                    "look up CN Tower ticket hours",
                    "search for how to renew a passport in Canada",
                    "find a Blue Jays score recap",
                    "search for why the Rust borrow checker exists",
                    "look up the definition of foldback",
                ]
            case .answer:
                return [
                    "what can kAir do",
                    "summarize the next step from this thread",
                    "who built this app",
                    "what mode am I in",
                    "explain how routing works here",
                    "what should I do next",
                    "give me a short summary",
                    "what's the point of this shell",
                    "how does this stay in one thread",
                    "what can you help me with",
                    "why did you suggest music",
                    "what surface am I using",
                ]
            }
        }

        var ambiguousPrompts: [String] {
            switch self {
            case .music:
                return [
                    "play that again",
                    "put something on",
                    "resume the song",
                    "play what I had before",
                    "music please",
                    "start something good",
                    "continue the last track",
                    "play it again",
                    "put on that mix",
                    "give me music",
                    "same song as before",
                    "queue the last one",
                ]
            case .message:
                return [
                    "send a message",
                    "tell him I'll be late",
                    "text her the update",
                    "let them know I'm outside",
                    "send that note",
                    "message the group",
                    "tell my friend the plan",
                    "write back",
                    "reply to that",
                    "tell them I'll call later",
                    "send it",
                    "draft a text",
                ]
            case .route:
                return [
                    "let's go",
                    "get me there",
                    "head out now",
                    "take me somewhere nearby",
                    "route me",
                    "how do I get there",
                    "let's leave",
                    "start navigation",
                    "take me to the place",
                    "head that way",
                    "let's get moving",
                    "how do I go",
                ]
            case .search:
                return [
                    "look it up",
                    "search for something",
                    "can you check that",
                    "find it online",
                    "look into it",
                    "search that",
                    "google it",
                    "check the web",
                    "find more info",
                    "pull it up",
                    "look this up",
                    "search please",
                ]
            case .answer:
                return [
                    "do the thing",
                    "help me with this",
                    "what now",
                    "fix it",
                    "make it happen",
                    "do something",
                    "figure it out",
                    "handle that",
                    "what should happen",
                    "help",
                    "can you do it",
                    "take care of it",
                ]
            }
        }

        var clarificationResolutionIndices: Set<Int> {
            [2, 7]
        }

        var clarificationFallbackPrompt: String {
            switch self {
            case .music:
                return "thanks, not now"
            case .message:
                return "I'll handle it later"
            case .route:
                return "never mind, not leaving yet"
            case .search:
                return "skip it for now"
            case .answer:
                return "thanks, that's enough"
            }
        }
    }

    private enum NormalOutcome {
        case complete
        case dismiss(MatchingFeedbackKind)
        case abandon
    }

    private struct Config {
        let enabled: Bool
        let resetBeforeRun: Bool

        static var current: Config {
            let env = ProcessInfo.processInfo.environment
            return Config(
                enabled: truthy(env["KAIR_RUNTIME_SCENARIO_MATRIX"]),
                resetBeforeRun: !falsy(env["KAIR_RUNTIME_RESET_REPLAY"])
            )
        }

        private static func truthy(_ value: String?) -> Bool {
            guard let value else { return false }
            return ["1", "true", "yes", "on"].contains(value.lowercased())
        }

        private static func falsy(_ value: String?) -> Bool {
            guard let value else { return false }
            return ["0", "false", "no", "off"].contains(value.lowercased())
        }
    }

    private struct ScenarioReport: Codable {
        let generatedAt: Date
        let exportDirectory: String
        let artifactDirectory: String
        let persistedSessionCount: Int
        let expectedMinimumSessionCount: Int
        let toolScenarioCount: [String: Int]
        let terminalOutcomeDistribution: [String: Int]
    }

    private struct RunnerStatus: Codable {
        let updatedAt: Date
        let enabled: Bool
        let resetBeforeRun: Bool
        let phase: String
        let tool: String?
        let index: Int?
        let detail: String?
        let error: String?
    }

    private struct ScenarioCandidateProvider: CandidateProvider {
        let id: String
        let versionID: String
        let candidates: [UnifiedMatchingCandidate]

        func generateCandidates(for _: MatchingFeatureContext) -> [UnifiedMatchingCandidate] {
            candidates
        }
    }

    private struct ScenarioMapProvider: MapProviding {
        private let places: [MapPlaceCandidate] = [
            MapPlaceCandidate(
                id: "place-union-station",
                title: "Union Station",
                subtitle: "65 Front St W, Toronto",
                coordinate: MapCoordinate(latitude: 43.6453, longitude: -79.3806)
            ),
            MapPlaceCandidate(
                id: "place-pearson-airport",
                title: "Toronto Pearson Airport",
                subtitle: "6301 Silver Dart Dr, Mississauga",
                coordinate: MapCoordinate(latitude: 43.6777, longitude: -79.6248)
            ),
            MapPlaceCandidate(
                id: "place-high-park",
                title: "High Park",
                subtitle: "Toronto",
                coordinate: MapCoordinate(latitude: 43.6465, longitude: -79.4637)
            ),
            MapPlaceCandidate(
                id: "place-st-lawrence-market",
                title: "St. Lawrence Market",
                subtitle: "Toronto",
                coordinate: MapCoordinate(latitude: 43.6487, longitude: -79.3715)
            ),
            MapPlaceCandidate(
                id: "place-cn-tower",
                title: "CN Tower",
                subtitle: "Toronto",
                coordinate: MapCoordinate(latitude: 43.6426, longitude: -79.3871)
            ),
            MapPlaceCandidate(
                id: "place-tgh",
                title: "Toronto General Hospital",
                subtitle: "Toronto",
                coordinate: MapCoordinate(latitude: 43.6584, longitude: -79.3891)
            ),
            MapPlaceCandidate(
                id: "place-billy-bishop",
                title: "Billy Bishop Airport",
                subtitle: "Toronto",
                coordinate: MapCoordinate(latitude: 43.6287, longitude: -79.3962)
            ),
            MapPlaceCandidate(
                id: "place-yorkdale",
                title: "Yorkdale Mall",
                subtitle: "Toronto",
                coordinate: MapCoordinate(latitude: 43.7250, longitude: -79.4520)
            ),
            MapPlaceCandidate(
                id: "place-distillery",
                title: "Distillery District",
                subtitle: "Toronto",
                coordinate: MapCoordinate(latitude: 43.6503, longitude: -79.3596)
            ),
            MapPlaceCandidate(
                id: "place-kensington",
                title: "Kensington Market",
                subtitle: "Toronto",
                coordinate: MapCoordinate(latitude: 43.6544, longitude: -79.4000)
            ),
            MapPlaceCandidate(
                id: "place-nps",
                title: "Nathan Phillips Square",
                subtitle: "Toronto",
                coordinate: MapCoordinate(latitude: 43.6525, longitude: -79.3839)
            ),
            MapPlaceCandidate(
                id: "place-harbourfront",
                title: "Harbourfront Centre",
                subtitle: "Toronto",
                coordinate: MapCoordinate(latitude: 43.6380, longitude: -79.3827)
            ),
        ]

        func resolvePlaces(
            matching query: String,
            near _: MapPlaceCandidate?
        ) async throws -> [MapPlaceCandidate] {
            let lowered = query.lowercased()
            let matches = places.filter {
                lowered.contains($0.title.lowercased()) ||
                $0.title.lowercased().contains(lowered)
            }
            if matches.isEmpty == false {
                return matches
            }
            return [
                MapPlaceCandidate(
                    id: "place-\(Self.slug(query))",
                    title: query,
                    subtitle: "Scenario destination",
                    coordinate: MapCoordinate(latitude: 43.6532, longitude: -79.3832)
                )
            ]
        }

        func searchNearby(
            query: String,
            around _: MapPlaceCandidate
        ) async throws -> [MapPlaceCandidate] {
            try await resolvePlaces(matching: query, near: nil)
        }

        func calculateRoutes(
            from _: MapPlaceCandidate,
            to destination: MapPlaceCandidate,
            preferredMode: MapTransportMode?
        ) async -> [MapRouteOption] {
            let modes = preferredMode.map { [$0] } ?? MapTransportMode.allCases
            return modes.enumerated().map { index, mode in
                MapRouteOption(
                    id: "route-\(mode.rawValue)-\(destination.id)",
                    mode: mode,
                    title: mode.title(for: .english),
                    summary: "Scenario route to \(destination.title)",
                    etaText: "\(18 + index * 6) min",
                    distanceText: "\(6 + index * 2) km",
                    distanceMeters: Double(6_000 + index * 2_000),
                    expectedTravelTime: Double(1_080 + index * 360),
                    emphasis: index == 0 ? "Fastest" : "Alternate",
                    recommended: index == 0,
                    available: true,
                    rankingValue: Double(index),
                    polylineCoordinates: [
                        MapCoordinate(latitude: 43.6532, longitude: -79.3832),
                        destination.coordinate ?? MapCoordinate(latitude: 43.6453, longitude: -79.3806),
                    ],
                    steps: []
                )
            }
        }

        private static func slug(_ text: String) -> String {
            text
                .lowercased()
                .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }
    }

    static func maybeRunOnStartup() async {
        let config = Config.current
        guard config.enabled else { return }

        do {
            try writeStatus(
                RunnerStatus(
                    updatedAt: .now,
                    enabled: config.enabled,
                    resetBeforeRun: config.resetBeforeRun,
                    phase: "starting",
                    tool: nil,
                    index: nil,
                    detail: nil,
                    error: nil
                )
            )
            let report = try await run(config: config)
            print("[RuntimeScenarioMatrixRunner] persisted=\(report.persistedSessionCount)")
        } catch {
            try? writeStatus(
                RunnerStatus(
                    updatedAt: .now,
                    enabled: config.enabled,
                    resetBeforeRun: config.resetBeforeRun,
                    phase: "failed",
                    tool: nil,
                    index: nil,
                    detail: nil,
                    error: String(describing: error)
                )
            )
            print("[RuntimeScenarioMatrixRunner] failed: \(error)")
        }
    }

    private static func run(config: Config) async throws -> ScenarioReport {
        let exportDirectory = MatchingEventRecorder.defaultReplayExportDirectory()
        let artifactDirectory = MatchingRuntimeReplayCorpusBuilder.defaultArtifactDirectory()

        if config.resetBeforeRun {
            try clearDirectory(exportDirectory)
            try clearDirectory(artifactDirectory)
        }

        try writeStatus(
            RunnerStatus(
                updatedAt: .now,
                enabled: config.enabled,
                resetBeforeRun: config.resetBeforeRun,
                phase: "directories-ready",
                tool: nil,
                index: nil,
                detail: nil,
                error: nil
            )
        )

        let scenarioMapRuntime = MapsRuntime(provider: ScenarioMapProvider())
        scenarioMapRuntime.permissionState = .authorizedWhenInUse

        var toolScenarioCount: [String: Int] = [:]

        for tool in ToolKind.allCases {
            let resolved = tool.resolvedPrompts
            let ambiguous = tool.ambiguousPrompts
            guard resolved.count == ambiguous.count else {
                throw NSError(domain: "RuntimeScenarioMatrixRunner", code: 1)
            }

            for index in resolved.indices {
                try writeStatus(
                    RunnerStatus(
                        updatedAt: .now,
                        enabled: config.enabled,
                        resetBeforeRun: config.resetBeforeRun,
                        phase: "running-scenario",
                        tool: tool.rawValue,
                        index: index,
                        detail: resolved[index],
                        error: nil
                    )
                )
                let targetPrompt = resolved[index]
                let store = makeStore(
                    tool: tool,
                    index: index,
                    targetPrompt: targetPrompt,
                    exportDirectory: exportDirectory
                )
                store.scenarioPrimeRecommendations(seedPrompt: targetPrompt)
                try await runNormalFlow(
                    tool: tool,
                    index: index,
                    targetPrompt: targetPrompt,
                    store: store,
                    mapsRuntime: scenarioMapRuntime
                )
                toolScenarioCount[tool.rawValue, default: 0] += 1

                let clarifyStore = makeStore(
                    tool: tool,
                    index: index + 100,
                    targetPrompt: targetPrompt,
                    exportDirectory: exportDirectory
                )
                clarifyStore.scenarioPrimeRecommendations(seedPrompt: ambiguous[index])
                _ = await clarifyStore.submitPrompt(
                    ambiguous[index],
                    using: nil,
                    mapsRuntime: scenarioMapRuntime
                )
                toolScenarioCount[tool.rawValue, default: 0] += 1

                if tool.clarificationResolutionIndices.contains(index) {
                    try await resolveClarificationFollowup(
                        tool: tool,
                        index: index,
                        targetPrompt: targetPrompt,
                        store: clarifyStore,
                        mapsRuntime: scenarioMapRuntime
                    )
                    toolScenarioCount[tool.rawValue, default: 0] += 1
                } else {
                    _ = await clarifyStore.submitPrompt(
                        tool.clarificationFallbackPrompt,
                        using: nil,
                        mapsRuntime: scenarioMapRuntime
                    )
                }
            }
        }

        let bundle = try MatchingRuntimeReplayCorpusBuilder.build(now: .now)
        _ = try bundle.write(to: artifactDirectory)

        let report = ScenarioReport(
            generatedAt: .now,
            exportDirectory: exportDirectory.path,
            artifactDirectory: artifactDirectory.path,
            persistedSessionCount: bundle.corpus.sessionCount,
            expectedMinimumSessionCount: 120,
            toolScenarioCount: toolScenarioCount,
            terminalOutcomeDistribution: bundle.ledger.terminalOutcomeDistribution
        )

        let reportURL = artifactDirectory.appendingPathComponent("runtime_scenario_matrix_report.json")
        try ReplayExportedSession.jsonEncoder().encode(report).write(to: reportURL, options: .atomic)
        try writeStatus(
            RunnerStatus(
                updatedAt: .now,
                enabled: config.enabled,
                resetBeforeRun: config.resetBeforeRun,
                phase: "completed",
                tool: nil,
                index: nil,
                detail: "persisted=\(report.persistedSessionCount)",
                error: nil
            )
        )
        return report
    }

    private static func runNormalFlow(
        tool: ToolKind,
        index: Int,
        targetPrompt: String,
        store: ChatStore,
        mapsRuntime: MapsRuntime
    ) async throws {
        let candidate = scenarioRecommendation(
            tool: tool,
            index: index,
            targetPrompt: targetPrompt
        )

        switch normalOutcome(for: tool, index: index) {
        case .complete:
            store.prepareRecommendationForAccept(candidate)
            _ = await store.submitPrompt(
                candidate.candidate.activationPrompt,
                using: nil,
                mapsRuntime: mapsRuntime
            )
        case .dismiss(let feedback):
            store.dismissRecommendation(candidate, feedback: feedback)
        case .abandon:
            store.prepareRecommendationForAccept(candidate)
            _ = await store.submitPrompt(
                candidate.candidate.activationPrompt,
                using: nil,
                mapsRuntime: mapsRuntime
            )
            if tool == .music {
                store.recordSilentSurfaceExit(.music)
            } else if tool == .route {
                store.recordSilentSurfaceExit(.maps)
            } else {
                _ = await store.submitPrompt(
                    "not now",
                    using: nil,
                    mapsRuntime: mapsRuntime
                )
            }
            return
        }

        if tool == .music, case .complete = normalOutcome(for: tool, index: index) {
            if let musicSession = store.consumeResolvedMusicSession() {
                store.recordSurfaceReturn(
                    from: AppSurfaceReturnContext(
                        section: .music,
                        musicSession: musicSession,
                        videoSession: nil
                    ),
                    dashboard: nil,
                    healthSession: nil
                )
            }
            return
        }

        if tool == .route, case .complete = normalOutcome(for: tool, index: index) {
            if let task = store.consumeResolvedMapTask() {
                store.recordMapReturn(from: task)
            }
        }
    }

    private static func resolveClarificationFollowup(
        tool: ToolKind,
        index: Int,
        targetPrompt: String,
        store: ChatStore,
        mapsRuntime: MapsRuntime
    ) async throws {
        store.scenarioPrimeRecommendations(seedPrompt: targetPrompt)
        let candidate = scenarioRecommendation(
            tool: tool,
            index: index,
            targetPrompt: targetPrompt
        )
        store.prepareRecommendationForAccept(candidate)
        _ = await store.submitPrompt(
            candidate.candidate.activationPrompt,
            using: nil,
            mapsRuntime: mapsRuntime
        )

        switch tool {
        case .music:
            if let musicSession = store.consumeResolvedMusicSession() {
                store.recordSurfaceReturn(
                    from: AppSurfaceReturnContext(
                        section: .music,
                        musicSession: musicSession,
                        videoSession: nil
                    ),
                    dashboard: nil,
                    healthSession: nil
                )
            }
        case .route:
            if let task = store.consumeResolvedMapTask() {
                store.recordMapReturn(from: task)
            }
        case .message, .search, .answer:
            break
        }
    }

    private static func makeStore(
        tool: ToolKind,
        index: Int,
        targetPrompt: String,
        exportDirectory: URL
    ) -> ChatStore {
        let provider = ScenarioCandidateProvider(
            id: tool.providerID,
            versionID: "scenario-matrix-v1",
            candidates: candidates(
                for: tool,
                index: index,
                targetPrompt: targetPrompt
            )
        )
        let engine = UnifiedMatchingEngine(
            strategyID: "scenario-matrix-\(tool.rawValue)",
            candidateProviders: [provider]
        )
        let store = ChatStore(
            replayLab: MatchingReplayLab(),
            matchingEngine: engine,
            eventRecorder: MatchingEventRecorder(
                sessionId: "scenario-\(tool.rawValue)-\(index)",
                exportDirectory: exportDirectory
            ),
            autostartLifecycle: false
        )
        store.isTemplateChat = true
        store.session = ChatSession(
            title: "Scenario \(tool.rawValue) \(index)",
            messages: []
        )
        store.bootstrapWithoutDashboard(supportsHealthData: false)
        return store
    }

    private static func candidates(
        for tool: ToolKind,
        index: Int,
        targetPrompt: String
    ) -> [UnifiedMatchingCandidate] {
        let target = UnifiedMatchingCandidate(
            id: "\(tool.rawValue)-target-\(index)",
            title: "Scenario \(tool.rawValue) target",
            summary: "Primary scenario candidate",
            objectKind: tool.targetObjectKind,
            preferredSection: tool.preferredSection,
            activationPrompt: targetPrompt,
            tags: tool.targetTags,
            sourcePool: tool.sourcePool,
            providerID: tool.providerID,
            retrieval: MatchingRetrievalDescriptor(
                providerID: tool.providerID,
                retrievalScore: 0.98,
                coarseReasonTags: [.context, .policy]
            ),
            utilityProfile: tool.utilityProfile
        )

        let distractors: [UnifiedMatchingCandidate] = [
            buildDistractor(
                id: "answer-distractor-\(tool.rawValue)-\(index)",
                title: "Summarize next step",
                prompt: "summarize what matters next",
                objectKind: .answerCard,
                preferredSection: nil,
                tags: [.ai, .planning]
            ),
            buildDistractor(
                id: "search-distractor-\(tool.rawValue)-\(index)",
                title: "Search explanation",
                prompt: "search the web for context",
                objectKind: .searchResult,
                preferredSection: nil,
                tags: [.search, .learning]
            ),
            buildDistractor(
                id: "music-distractor-\(tool.rawValue)-\(index)",
                title: "Background music",
                prompt: "play calm music",
                objectKind: .song,
                preferredSection: .music,
                tags: [.focus, .relaxation]
            ),
        ]

        return [target] + distractors.filter { $0.id.hasPrefix(tool.rawValue) == false }
    }

    private static func scenarioRecommendation(
        tool: ToolKind,
        index: Int,
        targetPrompt: String
    ) -> UnifiedMatchRecommendation {
        let candidate = candidates(
            for: tool,
            index: index,
            targetPrompt: targetPrompt
        )[0]

        let style: MatchingRecommendationPackageStyle
        if candidate.preferredSection == .music {
            style = .persistentPlayer
        } else if candidate.preferredSection == nil {
            style = .directPrompt
        } else {
            style = .focusedSurface
        }

        let contribution = ScoreContributionBreakdown(
            globalEligibility: 0.92,
            domainUtility: 0.88,
            nextStepValue: 0.81,
            explorationBoost: 0,
            retrievalLift: 0.08,
            promptDirectnessBonus: 0.06,
            diversityPenalty: 0,
            promptLexical: 0.82,
            contextLexical: 0.44,
            phrase: 0.38,
            suppression: 0,
            finalScore: 0.94,
            policyVersion: "scenario-matrix-v1"
        )

        return UnifiedMatchRecommendation(
            candidate: candidate,
            breakdown: MatchingScoreBreakdown(
                globalEligibility: contribution.globalEligibility,
                domainUtility: contribution.domainUtility,
                nextStepValue: contribution.nextStepValue,
                explorationBoost: contribution.explorationBoost,
                diversityPenalty: contribution.diversityPenalty,
                finalScore: contribution.finalScore,
                confidence: 0.93,
                reasonCodes: [.sessionIntentMatch, .eligibleNow, .lowFrictionAction],
                debugPayload: MatchingScoringDebugPayload(
                    userFeatureKeys: ["scenario_matrix"],
                    contextFeatureKeys: ["tool_\(tool.rawValue)"],
                    candidateFeatureKeys: [candidate.objectKind.rawValue],
                    interactionFeatureKeys: ["prompt_direct"],
                    fatigueFeatureKeys: [],
                    retrievalMetadata: candidate.retrieval.metadata,
                    policyVersion: "scenario-matrix-v1"
                ),
                contribution: contribution
            ),
            package: MatchingRecommendationPackage(
                style: style,
                ctaTitle: candidate.title,
                prompt: candidate.activationPrompt
            ),
            rank: 1
        )
    }

    private static func buildDistractor(
        id: String,
        title: String,
        prompt: String,
        objectKind: MatchingObjectKind,
        preferredSection: AppSection?,
        tags: Set<MatchingIntentTag>
    ) -> UnifiedMatchingCandidate {
        UnifiedMatchingCandidate(
            id: id,
            title: title,
            summary: "Scenario distractor",
            objectKind: objectKind,
            preferredSection: preferredSection,
            activationPrompt: prompt,
            tags: tags,
            sourcePool: "scenario_distractor",
            providerID: "scenario-distractor",
            retrieval: MatchingRetrievalDescriptor(
                providerID: "scenario-distractor",
                retrievalScore: 0.12,
                coarseReasonTags: [.exploration]
            ),
            utilityProfile: MatchingUtilityProfile(
                goal: .explanation,
                domainWeight: 0.2,
                nextStepWeight: 0.16
            )
        )
    }

    private static func normalOutcome(for tool: ToolKind, index: Int) -> NormalOutcome {
        let cycle = index % 4
        switch tool {
        case .music, .route:
            switch cycle {
            case 0:
                return .complete
            case 1:
                return .dismiss(.dismiss)
            case 2:
                return .dismiss(.notInterested)
            default:
                return .abandon
            }
        case .message, .search, .answer:
            switch cycle {
            case 0:
                return .complete
            case 1:
                return .dismiss(.dismiss)
            case 2:
                return .dismiss(.lessLikeThis)
            default:
                return .dismiss(.notNow)
            }
        }
    }

    private static func clearDirectory(_ url: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
        try fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }

    private static func writeStatus(_ status: RunnerStatus) throws {
        let artifactDirectory = MatchingRuntimeReplayCorpusBuilder.defaultArtifactDirectory()
        try FileManager.default.createDirectory(
            at: artifactDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let url = artifactDirectory.appendingPathComponent("runtime_scenario_matrix_status.json")
        try ReplayExportedSession.jsonEncoder().encode(status).write(to: url, options: .atomic)
    }

    private static func truthy(_ value: String?) -> Bool {
        guard let value else { return false }
        return ["1", "true", "yes", "on"].contains(value.lowercased())
    }

    private static func falsy(_ value: String?) -> Bool {
        guard let value else { return false }
        return ["0", "false", "no", "off"].contains(value.lowercased())
    }
}
