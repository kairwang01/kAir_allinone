import Foundation

private enum ThreadStyle {
    case shallow
    case active
    case deep
}

private struct ScenarioBlueprint {
    let label: String
    let prompt: String
    let expectedCandidateID: String
    let activeSurface: AppSection
    let healthAvailability: MatchingHealthAvailability
    let locationState: MatchingLocationState
    let motionContext: MatchingMotionContext
    let capturedAt: Date
    let threadStyle: ThreadStyle
    let transcriptContext: [String]
    let longTermCandidateIDs: [String]
    let recentCandidateIDs: [String]
    let dismissHistory: [(candidateID: String, feedback: MatchingFeedbackKind)]
    let groundTruthDismissObjectKind: MatchingObjectKind?
}

private enum RetrievalRegressionCause: String {
    case recallMissing = "Recall missing"
    case recallOffTopic = "Recall off-topic"
    case queryExpansionDistortion = "Query expansion distortion"
    case contextPollution = "Context pollution"
    case activeSurfaceInterference = "Active surface interference"
    case explicitDismissIneffective = "Explicit dismiss ineffective"
    case objectTypeOverConcentration = "Object type over-concentration"

    var explanation: String {
        switch self {
        case .recallMissing:
            return "The target path disappeared from the retrieval candidate set or never made it into the retrieved pool."
        case .recallOffTopic:
            return "The retrieved top-k drifted into a different task family even though the target family stayed available."
        case .queryExpansionDistortion:
            return "Query expansion terms or tag expansion dominated the lexical match and pulled retrieval toward the wrong interpretation."
        case .contextPollution:
            return "Recent or long-term context outweighed the prompt and pushed retrieval toward stale or adjacent intent."
        case .activeSurfaceInterference:
            return "The currently open surface biased retrieval toward itself instead of the prompt's actual next step."
        case .explicitDismissIneffective:
            return "Negative feedback existed for the retrieved candidate or its object family, but retrieval still promoted it."
        case .objectTypeOverConcentration:
            return "Retrieval collapsed too heavily onto one object type and reduced top-k breadth."
        }
    }
}

private struct RegressionAttribution {
    let cause: RetrievalRegressionCause
    let details: [String]
}

private enum RetrievalHardeningLayer: String {
    case queryConstruction = "Query construction"
    case candidatePoolCoverage = "Candidate pool coverage"
    case lexicalWeighting = "Lexical weighting"
}

private enum RetrievalExposureKind: String {
    case nearMiss = "Near-miss"
    case candidateMiss = "Candidate miss"
    case weakTrace = "Weak-trace"
}

private struct RetrievalExposureCase: Identifiable {
    let id = UUID()
    let kind: RetrievalExposureKind
    let scenarioLabel: String
    let prompt: String
    let expectedCandidateID: String
    let expectedCandidateTitle: String
    let actualTopCandidateID: String?
    let actualTopCandidateTitle: String?
    let actualTopKIDs: [String]
    let actualTopKTitles: [String]
    let explanation: String
    let hardeningLayer: RetrievalHardeningLayer
    let evidence: [String]
}

private struct RetrievalRankShiftAggregate: Identifiable {
    var id: String { candidateID }

    let candidateID: String
    let title: String
    let addedCount: Int
    let removedCount: Int
    let upCount: Int
    let downCount: Int
    let averageAbsoluteShift: Double
}

private struct RetrievalFailureExposureReport {
    let nearMissCases: [RetrievalExposureCase]
    let candidateMissCases: [RetrievalExposureCase]
    let weakTraceCases: [RetrievalExposureCase]
    let rankShiftAggregates: [RetrievalRankShiftAggregate]
    let reasonDistribution: [(MatchingCoarseReasonTag, Int)]
}

@main
struct ProviderPhaseReplayMain {
    static func main() throws {
        let outputPath = CommandLine.arguments.dropFirst().first
            ?? "/Users/kair/Projects/kAir/Contracts/provider-phase-replay-report.md"

        let catalog = ProviderPhaseReplayCatalog()
        let scenarios = catalog.makeScenarios()

        let replayEngine = MatchingReplayEngine()
        let batchAnalyzer = MatchingReplayBatchAnalyzer()
        let report = batchAnalyzer.buildReport(
            scenarios: scenarios,
            replayEngine: replayEngine,
            baseline: .baseline,
            candidate: .candidate,
            now: Date(),
            limit: 5
        )
        let comparisons = scenarios.map { scenario in
            replayEngine.compare(
                scenario: scenario,
                baseline: .baseline,
                candidate: .candidate,
                limit: 5
            )
        }

        let formatter = ProviderPhaseReplayReportFormatter(
            comparisons: comparisons,
            report: report
        )
        let markdown = formatter.render()

        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try markdown.write(to: outputURL, atomically: true, encoding: .utf8)

        let metrics = report.aggregateMetrics
        print("Provider-phase replay complete.")
        print("Scenarios evaluated: \(report.evaluatedScenarioCount)/\(report.trackedScenarioCount)")
        print("Offline gate: \(report.offlineGate.status.title)")
        print("Completed-path hit@k: \(percent(metrics.baselineCompletedPathHitRate)) -> \(percent(metrics.candidateCompletedPathHitRate))")
        print("Same-task-family alignment: \(percent(metrics.baselineTaskFamilyAlignmentRate)) -> \(percent(metrics.candidateTaskFamilyAlignmentRate))")
        print("Not aligned: \(percent(metrics.baselineNotAlignedRate)) -> \(percent(metrics.candidateNotAlignedRate))")
        print("Object-type concentration: \(format(metrics.baselineObjectTypeConcentration)) -> \(format(metrics.candidateObjectTypeConcentration))")
        print("Report: \(outputURL.path)")
    }
}

private struct ProviderPhaseReplayCatalog {
    private let registry: [String: UnifiedMatchingCandidate]

    init() {
        registry = Self.buildCandidateRegistry()
    }

    func makeScenarios() -> [MatchingReplayScenario] {
        blueprints().map(makeScenario(from:))
    }

    private func makeScenario(
        from blueprint: ScenarioBlueprint
    ) -> MatchingReplayScenario {
        let session = makeSession(from: blueprint)
        let behaviorLog = makeBehaviorLog(for: blueprint)
        let snapshot = MatchingReplaySnapshot(
            label: blueprint.label,
            recentPrompt: blueprint.prompt,
            capturedAt: blueprint.capturedAt,
            session: session,
            healthAvailability: blueprint.healthAvailability,
            locationState: blueprint.locationState,
            motionContext: blueprint.motionContext,
            activeSurface: blueprint.activeSurface,
            behaviorLog: behaviorLog
        )

        return MatchingReplayScenario(
            label: blueprint.label,
            snapshot: snapshot,
            recentEventsWindow: Array(behaviorLog.suffix(4)),
            groundTruthEvents: makeGroundTruthEvents(for: blueprint),
            createdAt: blueprint.capturedAt
        )
    }

    private func makeSession(
        from blueprint: ScenarioBlueprint
    ) -> ChatSession {
        var messages: [ConversationMessage] = [
            .assistant(
                text: "kAir stays in one thread and picks the next best action when it has enough context.",
                timestamp: blueprint.capturedAt.addingTimeInterval(-1800),
                tags: ["Chat-first"]
            ),
        ]

        let contextLines: [String]
        switch blueprint.threadStyle {
        case .shallow:
            contextLines = Array(blueprint.transcriptContext.prefix(1))
        case .active:
            contextLines = Array(blueprint.transcriptContext.prefix(2))
        case .deep:
            contextLines = blueprint.transcriptContext
        }

        for (index, line) in contextLines.enumerated() {
            let timestamp = blueprint.capturedAt.addingTimeInterval(Double(-900 + index * 240))
            if index.isMultiple(of: 2) {
                messages.append(.user(text: line, timestamp: timestamp))
            } else {
                messages.append(.assistant(text: line, timestamp: timestamp))
            }
        }

        messages.append(
            .user(
                text: blueprint.prompt,
                timestamp: blueprint.capturedAt.addingTimeInterval(-45)
            )
        )

        return ChatSession(
            title: "Provider-phase replay",
            messages: messages
        )
    }

    private func makeBehaviorLog(
        for blueprint: ScenarioBlueprint
    ) -> [MatchingBehaviorEvent] {
        var events: [MatchingBehaviorEvent] = []

        for (index, candidateID) in blueprint.longTermCandidateIDs.enumerated() {
            events.append(
                positiveCompletionEvent(
                    candidateID: candidateID,
                    timestamp: blueprint.capturedAt.addingTimeInterval(Double(-172_800 - index * 9_000)),
                    downstreamValue: 0.72
                )
            )
        }

        for (index, candidateID) in blueprint.recentCandidateIDs.enumerated() {
            events.append(
                positiveAcceptEvent(
                    candidateID: candidateID,
                    timestamp: blueprint.capturedAt.addingTimeInterval(Double(-3_600 - index * 420)),
                    downstreamValue: 0.34
                )
            )

            if let candidate = registry[candidateID], let surface = candidate.preferredSection {
                events.append(
                    MatchingBehaviorEvent(
                        stage: .accept,
                        subject: .surface,
                        candidateID: candidateID,
                        objectKind: candidate.objectKind,
                        surface: surface,
                        rawText: "Returned to \(surface.title)",
                        tags: candidate.tags,
                        timestamp: blueprint.capturedAt.addingTimeInterval(Double(-2_100 - index * 300)),
                        outcome: MatchingOutcomeMetrics(
                            downstreamValue: 0.16,
                            completionScore: 0.1,
                            wasSuccessful: true
                        )
                    )
                )
            }
        }

        for (index, dismiss) in blueprint.dismissHistory.enumerated() {
            guard let candidate = registry[dismiss.candidateID] else { continue }
            events.append(
                MatchingBehaviorEvent(
                    stage: .dismiss,
                    subject: .recommendation,
                    candidateID: dismiss.candidateID,
                    objectKind: candidate.objectKind,
                    surface: candidate.preferredSection,
                    rawText: candidate.activationPrompt,
                    tags: candidate.tags,
                    feedback: dismiss.feedback,
                    timestamp: blueprint.capturedAt.addingTimeInterval(Double(-1_200 - index * 240)),
                    outcome: MatchingOutcomeMetrics(
                        downstreamValue: 0,
                        completionScore: 0,
                        wasSuccessful: false
                    )
                )
            )
        }

        return events.sorted { $0.timestamp < $1.timestamp }
    }

    private func makeGroundTruthEvents(
        for blueprint: ScenarioBlueprint
    ) -> [MatchingBehaviorEvent] {
        guard let expected = registry[blueprint.expectedCandidateID] else {
            return []
        }

        var events: [MatchingBehaviorEvent] = []
        let start = blueprint.capturedAt.addingTimeInterval(90)

        if let dismissObjectKind = blueprint.groundTruthDismissObjectKind {
            let dismissTags = tags(for: dismissObjectKind)
            events.append(
                MatchingBehaviorEvent(
                    stage: .dismiss,
                    subject: .recommendation,
                    candidateID: nil,
                    objectKind: dismissObjectKind,
                    surface: surface(for: dismissObjectKind),
                    rawText: "Dismissed an earlier suggestion",
                    tags: dismissTags,
                    feedback: .notNow,
                    timestamp: start,
                    outcome: MatchingOutcomeMetrics(
                        downstreamValue: 0,
                        completionScore: 0,
                        wasSuccessful: false
                    )
                )
            )
        }

        events.append(
            MatchingBehaviorEvent(
                stage: .click,
                subject: .recommendation,
                candidateID: expected.id,
                objectKind: expected.objectKind,
                surface: expected.preferredSection,
                rawText: expected.activationPrompt,
                tags: expected.tags,
                timestamp: start.addingTimeInterval(45),
                outcome: MatchingOutcomeMetrics(
                    downstreamValue: 0.12,
                    completionScore: 0.08,
                    wasSuccessful: true
                )
            )
        )
        events.append(
            MatchingBehaviorEvent(
                stage: .accept,
                subject: expected.preferredSection == nil ? .recommendation : .surface,
                candidateID: expected.id,
                objectKind: expected.objectKind,
                surface: expected.preferredSection,
                rawText: expected.activationPrompt,
                tags: expected.tags,
                timestamp: start.addingTimeInterval(120),
                outcome: MatchingOutcomeMetrics(
                    downstreamValue: 0.48,
                    completionScore: 0.52,
                    wasSuccessful: true
                )
            )
        )
        events.append(
            MatchingBehaviorEvent(
                stage: .completion,
                subject: subject(for: expected.objectKind),
                candidateID: expected.id,
                objectKind: expected.objectKind,
                surface: expected.preferredSection,
                rawText: expected.activationPrompt,
                tags: expected.tags,
                timestamp: start.addingTimeInterval(360),
                outcome: MatchingOutcomeMetrics(
                    downstreamValue: 0.9,
                    completionScore: 0.92,
                    dwellSeconds: 180,
                    wasSuccessful: true
                )
            )
        )

        return events
    }

    private func positiveCompletionEvent(
        candidateID: String,
        timestamp: Date,
        downstreamValue: Double
    ) -> MatchingBehaviorEvent {
        let candidate = registry[candidateID]!
        return MatchingBehaviorEvent(
            stage: .completion,
            subject: subject(for: candidate.objectKind),
            candidateID: candidateID,
            objectKind: candidate.objectKind,
            surface: candidate.preferredSection,
            rawText: candidate.activationPrompt,
            tags: candidate.tags,
            timestamp: timestamp,
            outcome: MatchingOutcomeMetrics(
                downstreamValue: downstreamValue,
                completionScore: 0.88,
                dwellSeconds: 240,
                wasSuccessful: true
            )
        )
    }

    private func positiveAcceptEvent(
        candidateID: String,
        timestamp: Date,
        downstreamValue: Double
    ) -> MatchingBehaviorEvent {
        let candidate = registry[candidateID]!
        return MatchingBehaviorEvent(
            stage: .accept,
            subject: candidate.preferredSection == nil ? .recommendation : .surface,
            candidateID: candidateID,
            objectKind: candidate.objectKind,
            surface: candidate.preferredSection,
            rawText: candidate.activationPrompt,
            tags: candidate.tags,
            timestamp: timestamp,
            outcome: MatchingOutcomeMetrics(
                downstreamValue: downstreamValue,
                completionScore: 0.26,
                wasSuccessful: true
            )
        )
    }

    private func subject(
        for objectKind: MatchingObjectKind
    ) -> MatchingBehaviorEvent.Subject {
        switch objectKind {
        case .place, .route:
            return .route
        case .song:
            return .playback
        case .video:
            return .surface
        case .searchResult:
            return .search
        case .toolEntry:
            return .tool
        case .answerCard, .contact, .thread:
            return .recommendation
        }
    }

    private func surface(
        for objectKind: MatchingObjectKind
    ) -> AppSection? {
        switch objectKind {
        case .place, .route:
            return .maps
        case .song:
            return .music
        case .video:
            return .video
        case .toolEntry:
            return .ai
        case .searchResult, .answerCard, .contact, .thread:
            return .chat
        }
    }

    private func tags(
        for objectKind: MatchingObjectKind
    ) -> Set<MatchingIntentTag> {
        switch objectKind {
        case .place:
            return [.navigation, .localDiscovery]
        case .route:
            return [.navigation, .planning, .commute]
        case .song:
            return [.entertainment]
        case .video:
            return [.learning]
        case .searchResult:
            return [.search]
        case .toolEntry:
            return [.ai]
        case .answerCard, .thread:
            return [.planning]
        case .contact:
            return [.social]
        }
    }

    private func blueprints() -> [ScenarioBlueprint] {
        let dinnerNight = date(year: 2026, month: 4, day: 10, hour: 19, minute: 10)
        let commuteEvening = date(year: 2026, month: 4, day: 11, hour: 18, minute: 20)
        let workMorning = date(year: 2026, month: 4, day: 12, hour: 9, minute: 15)
        let middayDocs = date(year: 2026, month: 4, day: 13, hour: 13, minute: 5)
        let stretchEvening = date(year: 2026, month: 4, day: 14, hour: 20, minute: 0)
        let recoveryMidday = date(year: 2026, month: 4, day: 15, hour: 12, minute: 30)

        var scenarios: [ScenarioBlueprint] = [
            ScenarioBlueprint(
                label: "local-dinner-clean",
                prompt: "Tonight I need a quiet place to meet a friend, not too expensive, and parking would help.",
                expectedCandidateID: "maps-quiet-dinner",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .stationary,
                capturedAt: dinnerNight,
                threadStyle: .shallow,
                transcriptContext: [
                    "Let's plan tonight quickly."
                ],
                longTermCandidateIDs: [],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "local-dinner-history",
                prompt: "Find a quiet affordable dinner spot for tonight where driving and parking won't be annoying.",
                expectedCandidateID: "maps-quiet-dinner",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .stationary,
                capturedAt: dinnerNight.addingTimeInterval(86_400),
                threadStyle: .active,
                transcriptContext: [
                    "We're meeting after work.",
                    "Parking matters because we're driving.",
                    "Keep it calm and not too expensive."
                ],
                longTermCandidateIDs: ["maps-evening-cafe", "search-parking"],
                recentCandidateIDs: ["maps-evening-cafe"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "local-cafe-maps-surface",
                prompt: "Dinner feels heavy now, show me a calm cafe nearby for tonight instead.",
                expectedCandidateID: "maps-evening-cafe",
                activeSurface: .maps,
                healthAvailability: .availableLater,
                locationState: .approximate,
                motionContext: .stationary,
                capturedAt: dinnerNight.addingTimeInterval(172_800),
                threadStyle: .active,
                transcriptContext: [
                    "We were comparing routes already.",
                    "A cafe would be enough if it's quiet.",
                    "Nearby is more important than options."
                ],
                longTermCandidateIDs: ["maps-evening-cafe"],
                recentCandidateIDs: ["maps-route-compare"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "local-dinner-dismiss",
                prompt: "Pick the best quiet dinner option for tonight and keep parking in mind.",
                expectedCandidateID: "maps-quiet-dinner",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .stationary,
                capturedAt: dinnerNight.addingTimeInterval(259_200),
                threadStyle: .deep,
                transcriptContext: [
                    "We already know it's tonight.",
                    "Budget matters.",
                    "I do not want another wall of search results.",
                    "Driving still matters."
                ],
                longTermCandidateIDs: ["maps-quiet-dinner"],
                recentCandidateIDs: ["maps-evening-cafe"],
                dismissHistory: [("search-parking", .notNow)],
                groundTruthDismissObjectKind: .searchResult
            ),
            ScenarioBlueprint(
                label: "commute-route-clean",
                prompt: "Compare the fastest route and parking before I drive over there.",
                expectedCandidateID: "maps-route-compare",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .driving,
                capturedAt: commuteEvening,
                threadStyle: .shallow,
                transcriptContext: [
                    "I just need the route decision."
                ],
                longTermCandidateIDs: [],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "commute-route-history",
                prompt: "Before I leave, compare routes and parking so I can decide if the stop is worth it.",
                expectedCandidateID: "maps-route-compare",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .driving,
                capturedAt: commuteEvening.addingTimeInterval(86_400),
                threadStyle: .active,
                transcriptContext: [
                    "I will be driving.",
                    "I only want a low-friction route check."
                ],
                longTermCandidateIDs: ["maps-route-compare"],
                recentCandidateIDs: ["music-social"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "commute-route-from-music",
                prompt: "I'm already in music, but I need the route and parking before I leave.",
                expectedCandidateID: "maps-route-compare",
                activeSurface: .music,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .driving,
                capturedAt: commuteEvening.addingTimeInterval(172_800),
                threadStyle: .active,
                transcriptContext: [
                    "Music is already running.",
                    "The real question is whether the drive still makes sense."
                ],
                longTermCandidateIDs: ["music-commute"],
                recentCandidateIDs: ["music-commute"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "commute-route-dismiss",
                prompt: "Route first. I do not need another commute playlist right now.",
                expectedCandidateID: "maps-route-compare",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .driving,
                capturedAt: commuteEvening.addingTimeInterval(259_200),
                threadStyle: .deep,
                transcriptContext: [
                    "I'm leaving soon.",
                    "The route and parking are the real blockers.",
                    "Do not distract me with media."
                ],
                longTermCandidateIDs: ["maps-route-compare"],
                recentCandidateIDs: ["maps-route-compare"],
                dismissHistory: [("music-commute", .notInterested)],
                groundTruthDismissObjectKind: .song
            ),
            ScenarioBlueprint(
                label: "music-focus-clean",
                prompt: "Play something to help me focus while I work.",
                expectedCandidateID: "music-focus",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: workMorning,
                threadStyle: .shallow,
                transcriptContext: [
                    "I want to stay in chat and keep working."
                ],
                longTermCandidateIDs: [],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "music-focus-history",
                prompt: "Play deep work music while I focus on search-heavy tasks this morning.",
                expectedCandidateID: "music-deep-work",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: workMorning.addingTimeInterval(86_400),
                threadStyle: .active,
                transcriptContext: [
                    "I am staying heads-down today.",
                    "Search and research are the main tasks."
                ],
                longTermCandidateIDs: ["music-focus", "music-deep-work"],
                recentCandidateIDs: ["music-focus"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "music-commute-surface",
                prompt: "Keep something calm on while I drive to dinner.",
                expectedCandidateID: "music-commute",
                activeSurface: .music,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .driving,
                capturedAt: workMorning.addingTimeInterval(172_800),
                threadStyle: .active,
                transcriptContext: [
                    "Navigation is mostly settled.",
                    "The only thing left is the mood on the drive."
                ],
                longTermCandidateIDs: ["music-commute"],
                recentCandidateIDs: ["maps-route-compare"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "music-focus-dismiss",
                prompt: "I just need focus music, not another tutorial or video.",
                expectedCandidateID: "music-focus",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: workMorning.addingTimeInterval(259_200),
                threadStyle: .deep,
                transcriptContext: [
                    "Stay in the thread.",
                    "Keep it lightweight.",
                    "This is a work session."
                ],
                longTermCandidateIDs: ["music-focus"],
                recentCandidateIDs: ["answer-next-step"],
                dismissHistory: [("video-howto", .lessLikeThis)],
                groundTruthDismissObjectKind: .video
            ),
            ScenarioBlueprint(
                label: "search-parking-clean",
                prompt: "Before I go, look up whether parking is hard and if I need a reservation.",
                expectedCandidateID: "search-parking",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .stationary,
                capturedAt: middayDocs,
                threadStyle: .shallow,
                transcriptContext: [
                    "I want facts before I commit."
                ],
                longTermCandidateIDs: [],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "search-runtime-history",
                prompt: "Explain why kAir would route this request the way it does.",
                expectedCandidateID: "search-runtime",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: middayDocs.addingTimeInterval(86_400),
                threadStyle: .active,
                transcriptContext: [
                    "I want the reasoning, not just the action.",
                    "This is about routing and runtime choice."
                ],
                longTermCandidateIDs: ["tool-ai-runtime", "search-runtime"],
                recentCandidateIDs: ["tool-ai-runtime"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "search-runtime-ai-surface",
                prompt: "I'm already on AI. Explain the routing logic clearly.",
                expectedCandidateID: "search-runtime",
                activeSurface: .ai,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: middayDocs.addingTimeInterval(172_800),
                threadStyle: .active,
                transcriptContext: [
                    "The current question is about why this route happened.",
                    "I still want a search-style explanation."
                ],
                longTermCandidateIDs: ["search-runtime"],
                recentCandidateIDs: ["search-runtime"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "search-health-dismiss",
                prompt: "Use AI search to summarize my local health data before opening Health.",
                expectedCandidateID: "search-health-proof",
                activeSurface: .chat,
                healthAvailability: .ready,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: middayDocs.addingTimeInterval(259_200),
                threadStyle: .deep,
                transcriptContext: [
                    "I don't want to jump straight into Health.",
                    "Search the relevant signals first.",
                    "Then I can decide if Health needs to open."
                ],
                longTermCandidateIDs: ["search-health-proof"],
                recentCandidateIDs: ["tool-health"],
                dismissHistory: [("tool-health", .notNow)],
                groundTruthDismissObjectKind: .toolEntry
            ),
            ScenarioBlueprint(
                label: "video-yoga-clean",
                prompt: "Show me a quick yoga stretch video.",
                expectedCandidateID: "video-yoga",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: stretchEvening,
                threadStyle: .shallow,
                transcriptContext: [
                    "A short visual answer is enough."
                ],
                longTermCandidateIDs: [],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "video-neighborhood-history",
                prompt: "Show me a short video about this area before I choose the place.",
                expectedCandidateID: "video-neighborhood",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .stationary,
                capturedAt: stretchEvening.addingTimeInterval(86_400),
                threadStyle: .active,
                transcriptContext: [
                    "I'm still deciding whether the neighborhood feels right.",
                    "A quick visual check is better than more text."
                ],
                longTermCandidateIDs: ["maps-quiet-dinner"],
                recentCandidateIDs: ["search-parking"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "video-howto-surface",
                prompt: "I need a tutorial video, not a long paragraph.",
                expectedCandidateID: "video-howto",
                activeSurface: .video,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: stretchEvening.addingTimeInterval(172_800),
                threadStyle: .active,
                transcriptContext: [
                    "The answer needs to be visual.",
                    "A direct how-to is better than more chat."
                ],
                longTermCandidateIDs: ["video-howto"],
                recentCandidateIDs: ["answer-next-step"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "video-howto-dismiss",
                prompt: "Show me the tutorial video. I don't want another answer card first.",
                expectedCandidateID: "video-howto",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: stretchEvening.addingTimeInterval(259_200),
                threadStyle: .deep,
                transcriptContext: [
                    "Keep it visual.",
                    "Avoid summarizing and just show the guide.",
                    "This should be easy to act on."
                ],
                longTermCandidateIDs: ["video-howto"],
                recentCandidateIDs: ["video-howto"],
                dismissHistory: [("answer-next-step", .lessLikeThis)],
                groundTruthDismissObjectKind: .answerCard
            ),
            ScenarioBlueprint(
                label: "tool-health-clean",
                prompt: "Open Health and use AI to summarize what matters today.",
                expectedCandidateID: "tool-health",
                activeSurface: .chat,
                healthAvailability: .ready,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: recoveryMidday,
                threadStyle: .shallow,
                transcriptContext: [
                    "Health is available if it is actually useful."
                ],
                longTermCandidateIDs: [],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "tool-ai-runtime-history",
                prompt: "Open AI and explain the current routing logic.",
                expectedCandidateID: "tool-ai-runtime",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: recoveryMidday.addingTimeInterval(86_400),
                threadStyle: .active,
                transcriptContext: [
                    "I want the orchestration view.",
                    "Tell me how the shell decided."
                ],
                longTermCandidateIDs: ["tool-ai-runtime", "search-runtime"],
                recentCandidateIDs: ["search-runtime"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "tool-store-surface",
                prompt: "Open Store and suggest recovery gear that actually matters.",
                expectedCandidateID: "tool-store",
                activeSurface: .store,
                healthAvailability: .ready,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: recoveryMidday.addingTimeInterval(172_800),
                threadStyle: .active,
                transcriptContext: [
                    "This is purchase-adjacent.",
                    "Recovery context is the main filter."
                ],
                longTermCandidateIDs: ["tool-store"],
                recentCandidateIDs: ["tool-health"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "tool-health-dismiss",
                prompt: "Open Health and summarize what matters today. Search can wait.",
                expectedCandidateID: "tool-health",
                activeSurface: .chat,
                healthAvailability: .ready,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: recoveryMidday.addingTimeInterval(259_200),
                threadStyle: .deep,
                transcriptContext: [
                    "I need the actual Health surface now.",
                    "Don't stall on search.",
                    "Keep the answer actionable."
                ],
                longTermCandidateIDs: ["tool-health"],
                recentCandidateIDs: ["search-health-proof"],
                dismissHistory: [("search-health-proof", .notNow)],
                groundTruthDismissObjectKind: .searchResult
            ),
        ]

        scenarios += additionalLocalDiscoveryBlueprints(baseDate: dinnerNight.addingTimeInterval(345_600))
        scenarios += additionalCommuteBlueprints(baseDate: commuteEvening.addingTimeInterval(345_600))
        scenarios += additionalMusicBlueprints(baseDate: workMorning.addingTimeInterval(345_600))
        scenarios += additionalSearchBlueprints(baseDate: middayDocs.addingTimeInterval(345_600))
        scenarios += additionalVideoBlueprints(baseDate: stretchEvening.addingTimeInterval(345_600))
        scenarios += additionalToolBlueprints(baseDate: recoveryMidday.addingTimeInterval(345_600))

        return scenarios
    }

    private func additionalLocalDiscoveryBlueprints(
        baseDate: Date
    ) -> [ScenarioBlueprint] {
        [
            ScenarioBlueprint(
                label: "local-dinner-ambiguous",
                prompt: "Need somewhere quiet tonight, maybe dinner, maybe just a place to talk, and driving still matters.",
                expectedCandidateID: "maps-quiet-dinner",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .stationary,
                capturedAt: baseDate,
                threadStyle: .active,
                transcriptContext: [
                    "We are meeting after work.",
                    "I still want something calm and affordable."
                ],
                longTermCandidateIDs: [],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "local-dinner-low-info",
                prompt: "quiet dinner parking",
                expectedCandidateID: "maps-quiet-dinner",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(86_400),
                threadStyle: .shallow,
                transcriptContext: [
                    "It's for tonight."
                ],
                longTermCandidateIDs: [],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "local-search-conflict",
                prompt: "Should I check parking and reservation facts first, or just choose the place now?",
                expectedCandidateID: "search-parking",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(172_800),
                threadStyle: .active,
                transcriptContext: [
                    "I only need enough info to avoid a bad choice.",
                    "Dinner is still tonight."
                ],
                longTermCandidateIDs: ["maps-quiet-dinner"],
                recentCandidateIDs: ["maps-quiet-dinner"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "local-recent-music-pollution",
                prompt: "Find the quiet dinner option first. Music can wait.",
                expectedCandidateID: "maps-quiet-dinner",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(259_200),
                threadStyle: .deep,
                transcriptContext: [
                    "We're still deciding the place.",
                    "Driving and parking matter more than mood right now.",
                    "The destination is the blocker."
                ],
                longTermCandidateIDs: ["music-social", "music-commute"],
                recentCandidateIDs: ["music-social", "music-commute"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "local-multi-object",
                prompt: "I need the best quiet spot first, then something I can send to my friend.",
                expectedCandidateID: "maps-quiet-dinner",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(345_600),
                threadStyle: .active,
                transcriptContext: [
                    "Choosing the place is still step one.",
                    "Sharing the plan comes after."
                ],
                longTermCandidateIDs: ["answer-share-plan"],
                recentCandidateIDs: ["answer-share-plan"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "local-cafe-long-term-drift",
                prompt: "Actually I need the dinner option, not the cafe fallback.",
                expectedCandidateID: "maps-quiet-dinner",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .approximate,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(432_000),
                threadStyle: .deep,
                transcriptContext: [
                    "We've used the cafe fallback before.",
                    "Tonight is a real dinner plan.",
                    "Driving still matters."
                ],
                longTermCandidateIDs: ["maps-evening-cafe", "maps-evening-cafe"],
                recentCandidateIDs: ["maps-evening-cafe"],
                dismissHistory: [("maps-evening-cafe", .lessLikeThis)],
                groundTruthDismissObjectKind: .place
            ),
        ]
    }

    private func additionalCommuteBlueprints(
        baseDate: Date
    ) -> [ScenarioBlueprint] {
        [
            ScenarioBlueprint(
                label: "commute-ambiguous-go-now",
                prompt: "Should I head out now or rethink the stop if traffic and parking are bad?",
                expectedCandidateID: "maps-route-compare",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .driving,
                capturedAt: baseDate,
                threadStyle: .active,
                transcriptContext: [
                    "I'm leaving soon.",
                    "The decision depends on the route friction."
                ],
                longTermCandidateIDs: ["maps-route-compare"],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "commute-low-info",
                prompt: "route?",
                expectedCandidateID: "maps-route-compare",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .driving,
                capturedAt: baseDate.addingTimeInterval(86_400),
                threadStyle: .shallow,
                transcriptContext: [
                    "I am driving to the meetup."
                ],
                longTermCandidateIDs: [],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "commute-search-facts",
                prompt: "Before I leave, I need parking facts as much as the route.",
                expectedCandidateID: "search-parking",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .driving,
                capturedAt: baseDate.addingTimeInterval(172_800),
                threadStyle: .active,
                transcriptContext: [
                    "The route is one part of it.",
                    "Parking difficulty is the other blocker."
                ],
                longTermCandidateIDs: ["maps-route-compare"],
                recentCandidateIDs: ["maps-route-compare"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "commute-recent-music-drift",
                prompt: "No playlist yet. I need the route decision first.",
                expectedCandidateID: "maps-route-compare",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .driving,
                capturedAt: baseDate.addingTimeInterval(259_200),
                threadStyle: .deep,
                transcriptContext: [
                    "I am already in the car.",
                    "The route is still unresolved.",
                    "Media is secondary."
                ],
                longTermCandidateIDs: ["music-commute", "music-social"],
                recentCandidateIDs: ["music-commute", "music-social"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "commute-multi-object",
                prompt: "I need the route and maybe something to play, but the route should win.",
                expectedCandidateID: "maps-route-compare",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .driving,
                capturedAt: baseDate.addingTimeInterval(345_600),
                threadStyle: .active,
                transcriptContext: [
                    "Driving is happening now.",
                    "Navigation is the first decision."
                ],
                longTermCandidateIDs: ["music-commute"],
                recentCandidateIDs: ["music-commute"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "commute-long-term-drift",
                prompt: "Route first. The drive-home playlist can come later.",
                expectedCandidateID: "maps-route-compare",
                activeSurface: .music,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .driving,
                capturedAt: baseDate.addingTimeInterval(432_000),
                threadStyle: .deep,
                transcriptContext: [
                    "Music has been the default lately.",
                    "This time the real blocker is navigation.",
                    "Parking still matters."
                ],
                longTermCandidateIDs: ["music-commute", "music-commute"],
                recentCandidateIDs: ["music-commute"],
                dismissHistory: [("music-commute", .notNow)],
                groundTruthDismissObjectKind: .song
            ),
        ]
    }

    private func additionalMusicBlueprints(
        baseDate: Date
    ) -> [ScenarioBlueprint] {
        [
            ScenarioBlueprint(
                label: "music-ambiguous-session",
                prompt: "Play something that fits this work session.",
                expectedCandidateID: "music-focus",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate,
                threadStyle: .active,
                transcriptContext: [
                    "I'm working.",
                    "I want to stay in chat while it plays."
                ],
                longTermCandidateIDs: ["music-focus"],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "music-low-info",
                prompt: "music",
                expectedCandidateID: "music-focus",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(86_400),
                threadStyle: .shallow,
                transcriptContext: [
                    "This is a focus block."
                ],
                longTermCandidateIDs: [],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "music-conflict-route-later",
                prompt: "I'll need the route later, but right now I just want calm drive music.",
                expectedCandidateID: "music-commute",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .driving,
                capturedAt: baseDate.addingTimeInterval(172_800),
                threadStyle: .active,
                transcriptContext: [
                    "The route is mostly settled.",
                    "The mood for the drive is the active need."
                ],
                longTermCandidateIDs: ["maps-route-compare"],
                recentCandidateIDs: ["maps-route-compare"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "music-recent-search-drift",
                prompt: "No more explanations. Just put on focus music.",
                expectedCandidateID: "music-focus",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(259_200),
                threadStyle: .deep,
                transcriptContext: [
                    "I've been asking questions all morning.",
                    "Now I just want the focus layer.",
                    "Keep it low friction."
                ],
                longTermCandidateIDs: ["search-runtime", "answer-next-step"],
                recentCandidateIDs: ["search-runtime", "answer-next-step"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "music-multi-object",
                prompt: "I need focus music now and maybe a tutorial later, but music is the next step.",
                expectedCandidateID: "music-focus",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(345_600),
                threadStyle: .active,
                transcriptContext: [
                    "The current need is still a background layer.",
                    "Video can wait."
                ],
                longTermCandidateIDs: ["video-howto"],
                recentCandidateIDs: ["video-howto"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "music-long-term-commute-drift",
                prompt: "This is not a driving session. I need work music.",
                expectedCandidateID: "music-focus",
                activeSurface: .music,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(432_000),
                threadStyle: .deep,
                transcriptContext: [
                    "Commute playlists were popular recently.",
                    "Right now I'm stationary and working.",
                    "Focus should win."
                ],
                longTermCandidateIDs: ["music-commute", "music-commute"],
                recentCandidateIDs: ["music-commute"],
                dismissHistory: [("music-commute", .lessLikeThis)],
                groundTruthDismissObjectKind: .song
            ),
        ]
    }

    private func additionalSearchBlueprints(
        baseDate: Date
    ) -> [ScenarioBlueprint] {
        [
            ScenarioBlueprint(
                label: "search-ambiguous-why",
                prompt: "Why did it choose that?",
                expectedCandidateID: "search-runtime",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate,
                threadStyle: .active,
                transcriptContext: [
                    "This is about routing logic.",
                    "I want the explanation, not a tool jump."
                ],
                longTermCandidateIDs: ["search-runtime"],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "search-low-info",
                prompt: "look it up",
                expectedCandidateID: "search-parking",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(86_400),
                threadStyle: .shallow,
                transcriptContext: [
                    "I still need parking and reservation facts."
                ],
                longTermCandidateIDs: [],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "search-vs-health-tool",
                prompt: "Search the health context first. Don't open Health yet.",
                expectedCandidateID: "search-health-proof",
                activeSurface: .chat,
                healthAvailability: .ready,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(172_800),
                threadStyle: .active,
                transcriptContext: [
                    "I want evidence first.",
                    "Health should open only if the search still says it matters."
                ],
                longTermCandidateIDs: ["tool-health"],
                recentCandidateIDs: ["tool-health"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "search-recent-tool-drift",
                prompt: "Explain the routing logic clearly. I don't need to open AI.",
                expectedCandidateID: "search-runtime",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(259_200),
                threadStyle: .deep,
                transcriptContext: [
                    "The question is still explanatory.",
                    "I want reasoning in-chat.",
                    "A tool jump is extra friction."
                ],
                longTermCandidateIDs: ["tool-ai-runtime"],
                recentCandidateIDs: ["tool-ai-runtime"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "search-multi-object",
                prompt: "I need route facts and parking facts before deciding, not the route screen yet.",
                expectedCandidateID: "search-parking",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(345_600),
                threadStyle: .active,
                transcriptContext: [
                    "This is still a fact-finding step.",
                    "Decision comes after search."
                ],
                longTermCandidateIDs: ["maps-route-compare"],
                recentCandidateIDs: ["maps-route-compare"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "search-answer-drift",
                prompt: "I want the answer grounded in search, not just another summary card.",
                expectedCandidateID: "search-runtime",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(432_000),
                threadStyle: .deep,
                transcriptContext: [
                    "Search-backed explanation matters more than a plan card.",
                    "This is still an analysis step.",
                    "Keep it in chat."
                ],
                longTermCandidateIDs: ["answer-next-step"],
                recentCandidateIDs: ["answer-next-step"],
                dismissHistory: [("answer-next-step", .lessLikeThis)],
                groundTruthDismissObjectKind: .answerCard
            ),
        ]
    }

    private func additionalVideoBlueprints(
        baseDate: Date
    ) -> [ScenarioBlueprint] {
        [
            ScenarioBlueprint(
                label: "video-ambiguous-show-me",
                prompt: "Show me how to do this.",
                expectedCandidateID: "video-howto",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate,
                threadStyle: .active,
                transcriptContext: [
                    "The answer needs to be visual.",
                    "A tutorial is better than more text."
                ],
                longTermCandidateIDs: ["video-howto"],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "video-low-info",
                prompt: "video",
                expectedCandidateID: "video-yoga",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(86_400),
                threadStyle: .shallow,
                transcriptContext: [
                    "I want a quick stretch guide."
                ],
                longTermCandidateIDs: [],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "video-vs-answer-conflict",
                prompt: "A short video would help more than another answer card.",
                expectedCandidateID: "video-howto",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(172_800),
                threadStyle: .active,
                transcriptContext: [
                    "The next step should be visual.",
                    "The text summary is not enough."
                ],
                longTermCandidateIDs: ["answer-next-step"],
                recentCandidateIDs: ["answer-next-step"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "video-recent-search-drift",
                prompt: "No more search results. Show me the neighborhood video.",
                expectedCandidateID: "video-neighborhood",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(259_200),
                threadStyle: .deep,
                transcriptContext: [
                    "The place decision is still open.",
                    "I want to preview the area visually.",
                    "Search already gave enough facts."
                ],
                longTermCandidateIDs: ["search-parking", "search-parking"],
                recentCandidateIDs: ["search-parking"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "video-multi-object",
                prompt: "I need a quick area video before I choose, not another map explanation.",
                expectedCandidateID: "video-neighborhood",
                activeSurface: .chat,
                healthAvailability: .availableLater,
                locationState: .precise,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(345_600),
                threadStyle: .active,
                transcriptContext: [
                    "The choice is still about the neighborhood vibe.",
                    "A video preview is the fastest next step."
                ],
                longTermCandidateIDs: ["maps-route-compare"],
                recentCandidateIDs: ["maps-route-compare"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "video-yoga-answer-drift",
                prompt: "Just show me the stretch video. I don't need a written plan.",
                expectedCandidateID: "video-yoga",
                activeSurface: .video,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(432_000),
                threadStyle: .deep,
                transcriptContext: [
                    "This is a quick reset.",
                    "The answer needs to be visual.",
                    "Avoid another card."
                ],
                longTermCandidateIDs: ["answer-next-step"],
                recentCandidateIDs: ["answer-next-step"],
                dismissHistory: [("answer-next-step", .notInterested)],
                groundTruthDismissObjectKind: .answerCard
            ),
        ]
    }

    private func additionalToolBlueprints(
        baseDate: Date
    ) -> [ScenarioBlueprint] {
        [
            ScenarioBlueprint(
                label: "tool-ambiguous-open-right-thing",
                prompt: "Open the right thing for today's health context.",
                expectedCandidateID: "tool-health",
                activeSurface: .chat,
                healthAvailability: .ready,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate,
                threadStyle: .active,
                transcriptContext: [
                    "Health data is available.",
                    "I want the direct tool, not more explanation."
                ],
                longTermCandidateIDs: ["tool-health"],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "tool-low-info",
                prompt: "health",
                expectedCandidateID: "tool-health",
                activeSurface: .chat,
                healthAvailability: .ready,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(86_400),
                threadStyle: .shallow,
                transcriptContext: [
                    "Open Health if it helps."
                ],
                longTermCandidateIDs: [],
                recentCandidateIDs: [],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "tool-vs-search-conflict",
                prompt: "Open Health now. Search can wait.",
                expectedCandidateID: "tool-health",
                activeSurface: .chat,
                healthAvailability: .ready,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(172_800),
                threadStyle: .active,
                transcriptContext: [
                    "The decision is already made.",
                    "The next step should be the Health surface."
                ],
                longTermCandidateIDs: ["search-health-proof"],
                recentCandidateIDs: ["search-health-proof"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "tool-recent-search-drift",
                prompt: "Open Health and summarize what matters. Stop circling in search.",
                expectedCandidateID: "tool-health",
                activeSurface: .chat,
                healthAvailability: .ready,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(259_200),
                threadStyle: .deep,
                transcriptContext: [
                    "I already saw enough search context.",
                    "Now I want the actual tool.",
                    "Keep it actionable."
                ],
                longTermCandidateIDs: ["search-health-proof", "search-health-proof"],
                recentCandidateIDs: ["search-health-proof"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "tool-store-vs-health",
                prompt: "Open Store for recovery gear, not the Health surface.",
                expectedCandidateID: "tool-store",
                activeSurface: .chat,
                healthAvailability: .ready,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(345_600),
                threadStyle: .active,
                transcriptContext: [
                    "This is purchase-adjacent.",
                    "Recovery context matters more than metrics right now."
                ],
                longTermCandidateIDs: ["tool-health"],
                recentCandidateIDs: ["tool-health"],
                dismissHistory: [],
                groundTruthDismissObjectKind: nil
            ),
            ScenarioBlueprint(
                label: "tool-runtime-long-term-drift",
                prompt: "Open AI and explain the routing logic. I don't need a search answer.",
                expectedCandidateID: "tool-ai-runtime",
                activeSurface: .ai,
                healthAvailability: .availableLater,
                locationState: .unknown,
                motionContext: .stationary,
                capturedAt: baseDate.addingTimeInterval(432_000),
                threadStyle: .deep,
                transcriptContext: [
                    "The main task is still orchestration visibility.",
                    "Search explanations have happened a lot already.",
                    "The AI surface is the right next step."
                ],
                longTermCandidateIDs: ["search-runtime", "search-runtime"],
                recentCandidateIDs: ["search-runtime"],
                dismissHistory: [("search-runtime", .notNow)],
                groundTruthDismissObjectKind: .searchResult
            ),
        ]
    }

    private static func buildCandidateRegistry() -> [String: UnifiedMatchingCandidate] {
        let contexts = [
            MatchingFeatureContext(
                recentPrompt: "Plan dinner and parking tonight",
                activeSurface: .chat,
                messageCount: 4,
                daypart: .evening,
                weekday: 5,
                locationState: .precise,
                healthAvailability: .ready,
                motionContext: .stationary,
                sessionIntentTags: [.navigation, .planning, .social, .relaxation],
                recencyTags: [],
                longTermTags: [],
                crossSurfaceTransitions: [:],
                objectTypeAffinity: [:],
                objectTypeFatigue: [:],
                recentRejectedCandidateIDs: [],
                recentCompletedCandidateIDs: [],
                recentFeedbackByCandidate: [:],
                behaviorLog: []
            ),
            MatchingFeatureContext(
                recentPrompt: "Play focus music while I work",
                activeSurface: .chat,
                messageCount: 4,
                daypart: .morning,
                weekday: 2,
                locationState: .unknown,
                healthAvailability: .ready,
                motionContext: .stationary,
                sessionIntentTags: [.focus, .search, .ai],
                recencyTags: [],
                longTermTags: [],
                crossSurfaceTransitions: [:],
                objectTypeAffinity: [:],
                objectTypeFatigue: [:],
                recentRejectedCandidateIDs: [],
                recentCompletedCandidateIDs: [],
                recentFeedbackByCandidate: [:],
                behaviorLog: []
            ),
            MatchingFeatureContext(
                recentPrompt: "Open Health and explain what matters",
                activeSurface: .chat,
                messageCount: 4,
                daypart: .midday,
                weekday: 3,
                locationState: .approximate,
                healthAvailability: .ready,
                motionContext: .stationary,
                sessionIntentTags: [.health, .ai, .search],
                recencyTags: [],
                longTermTags: [],
                crossSurfaceTransitions: [:],
                objectTypeAffinity: [:],
                objectTypeFatigue: [:],
                recentRejectedCandidateIDs: [],
                recentCompletedCandidateIDs: [],
                recentFeedbackByCandidate: [:],
                behaviorLog: []
            ),
        ]

        var registry: [String: UnifiedMatchingCandidate] = [:]
        for context in contexts {
            for provider in [any CandidateProvider].defaultMatchingProviders {
                for candidate in provider.generateCandidates(for: context) {
                    registry[candidate.id] = candidate
                }
            }
        }

        return registry
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        let components = DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return calendar.date(from: components)!
    }
}

private struct ProviderPhaseReplayReportFormatter {
    let comparisons: [MatchingReplayComparison]
    let report: MatchingReplayBatchReport

    func render() -> String {
        let exposureReport = RetrievalFailureExposureAnalyzer().analyze(comparisons: comparisons)
        let decompositionReport = WeightDecompositionAnalyzer().analyze(comparisons: comparisons, exposureReport: exposureReport)
        let replayEngine = MatchingReplayEngine()
        let frozenBaselineComparisons = comparisons.map { comparison in
            replayEngine.compare(
                scenario: comparison.scenario,
                baseline: .baseline,
                candidate: .baseline,
                limit: 5
            )
        }
        let frozenBaselineExposureReport = RetrievalFailureExposureAnalyzer().analyze(comparisons: frozenBaselineComparisons)
        let frozenBaselineResidualReport = ResidualAttributionAnalyzer().analyze(
            comparisons: frozenBaselineComparisons,
            exposureReport: frozenBaselineExposureReport
        )
        let directSlotAudit = DirectSlotAuditAnalyzer().analyze(
            baselineComparisons: frozenBaselineComparisons,
            candidateComparisons: comparisons,
            baselineExposureReport: frozenBaselineExposureReport,
            candidateExposureReport: exposureReport
        )
        let composerAuditReport = ComposerDiversifierAuditAnalyzer().analyze(
            comparisons: comparisons,
            exposureReport: exposureReport
        )
        let attributions = comparisons.reduce(into: [UUID: RegressionAttribution]()) { partial, comparison in
            guard comparison.verdict == .baselineCloser else { return }
            partial[comparison.scenario.id] = RegressionAttributionAnalyzer().analyze(comparison: comparison)
        }

        let sortedImprovements = comparisons
            .filter { delta(for: $0) > 0.0001 || $0.verdict == .candidateCloser }
            .sorted { lhs, rhs in
                delta(for: lhs) > delta(for: rhs)
            }
            .prefix(20)
        let sortedRegressions = comparisons
            .filter { delta(for: $0) < -0.0001 || $0.verdict == .baselineCloser }
            .sorted { lhs, rhs in
                delta(for: lhs) < delta(for: rhs)
            }
            .prefix(20)
        let regressionComparisons = comparisons
            .filter { $0.verdict == .baselineCloser }
            .sorted { lhs, rhs in
                delta(for: lhs) < delta(for: rhs)
            }

        let baselineStrategy = comparisons.first?.baselineRun.strategy
        let candidateStrategy = comparisons.first?.candidateRun.strategy
        let sameProviders = baselineStrategy?.providerVersions == candidateStrategy?.providerVersions
        let sameScorer = baselineStrategy?.scorerVersion == candidateStrategy?.scorerVersion
        let providerOnlyExperiment = sameScorer && sameProviders == false
        let scorerOnlyExperiment = sameProviders && sameScorer == false
        var lines: [String] = []
        if providerOnlyExperiment {
            lines.append("# Provider-Only Replay Report")
        } else if scorerOnlyExperiment {
            lines.append("# Scorer-Phase Replay Report")
        } else {
            lines.append("# Provider-Phase Replay Report")
        }
        lines.append("")
        lines.append("- Generated: \(timestamp(report.generatedAt))")
        lines.append("- Scenarios evaluated: \(report.evaluatedScenarioCount) / \(report.trackedScenarioCount)")
        lines.append("- Baseline strategy: `\(comparisons.first?.baselineRun.strategy.id ?? "baseline")`")
        lines.append("- Candidate strategy: `\(comparisons.first?.candidateRun.strategy.id ?? "candidate")`")
        lines.append("- Offline gate: **\(report.offlineGate.status.title)**")
        lines.append("")
        lines.append("## Frozen Baseline")
        lines.append("")
        lines.append("- Baseline scorer: `\(comparisons.first?.baselineRun.strategy.scorerVersion ?? "unknown")`")
        lines.append("- Baseline provider: `\(comparisons.first?.baselineRun.strategy.providerVersions.joined(separator: ", ") ?? "unknown")`")
        lines.append("- Residual unresolved on frozen baseline: \(frozenBaselineExposureReport.nearMissCases.count) near-miss / \(frozenBaselineExposureReport.candidateMissCases.count) candidate-miss / \(frozenBaselineExposureReport.weakTraceCases.count) weak-trace.")
        lines.append("")
        lines.append("## Post-patch Residual Attribution (P0)")
        lines.append("")
        lines.append("Residual report is rebuilt from the frozen patched baseline only. It does not reuse pre-patch labels or recovered samples.")
        lines.append("")
        lines.append("| Residual slice | Count | Cases |")
        lines.append("| --- | ---: | --- |")
        for row in frozenBaselineResidualReport.distribution {
            lines.append("| \(row.rootCause.displayName) | \(row.count) | \(row.labels.joined(separator: ", ")) |")
        }
        lines.append("")
        lines.append("## Decision")
        lines.append("")
        lines.append(goNoGoSummary(using: attributions, exposureReport: exposureReport))
        lines.append("")
        lines.append("## Overall Metrics")
        lines.append("")
        lines.append("| Metric | Baseline | Candidate | Delta |")
        lines.append("| --- | ---: | ---: | ---: |")
        appendMetricRow("Chosen item hit@k", report.aggregateMetrics.baselineChosenItemHitRate, report.aggregateMetrics.candidateChosenItemHitRate, to: &lines)
        appendMetricRow("Accepted-path hit@k", report.aggregateMetrics.baselineAcceptedPathHitRate, report.aggregateMetrics.candidateAcceptedPathHitRate, to: &lines)
        appendMetricRow("Completed-path hit@k", report.aggregateMetrics.baselineCompletedPathHitRate, report.aggregateMetrics.candidateCompletedPathHitRate, to: &lines)
        appendMetricRow("Same-task-family alignment", report.aggregateMetrics.baselineTaskFamilyAlignmentRate, report.aggregateMetrics.candidateTaskFamilyAlignmentRate, to: &lines)
        appendMetricRow("Direct match", report.aggregateMetrics.baselineDirectMatchRate, report.aggregateMetrics.candidateDirectMatchRate, to: &lines)
        appendMetricRow("Not aligned", report.aggregateMetrics.baselineNotAlignedRate, report.aggregateMetrics.candidateNotAlignedRate, to: &lines)
        appendMetricRow("Avg task progression", report.aggregateMetrics.baselineAverageTaskProgressionAlignment, report.aggregateMetrics.candidateAverageTaskProgressionAlignment, formatAsPercent: false, to: &lines)
        appendMetricRow("Object-type concentration", report.aggregateMetrics.baselineObjectTypeConcentration, report.aggregateMetrics.candidateObjectTypeConcentration, formatAsPercent: false, to: &lines)
        appendMetricRow("Direct Slot Recovery Rate", 0, directSlotAudit.directSlotRecoveryRate, to: &lines)
        appendMetricRow("Average top-k overlap", report.aggregateMetrics.averageTopKOverlap, report.aggregateMetrics.averageTopKOverlap, formatAsPercent: false, deltaOverride: "—", to: &lines)
        lines.append("")
        lines.append("### Provider-Phase Gate")
        lines.append("")
        lines.append("- \(report.offlineGate.summary)")
        for reason in report.offlineGate.reasons {
            lines.append("- \(reason)")
        }
        lines.append("")
        lines.append("## Hidden Failure Exposure")
        lines.append("")
        lines.append("- Near-miss cases: \(exposureReport.nearMissCases.count)")
        lines.append("- Candidate miss cases: \(exposureReport.candidateMissCases.count)")
        lines.append("- Weak-trace cases: \(exposureReport.weakTraceCases.count)")
        lines.append("")
        lines.append("## Slice Metrics")
        lines.append("")

        for group in report.sliceGroups {
            lines.append("### \(group.dimension.title)")
            lines.append("")
            lines.append("| Slice | Scenarios | Completed hit@k | Not aligned | Avg progression |")
            lines.append("| --- | ---: | ---: | ---: | ---: |")
            for row in group.rows {
                lines.append(
                    "| \(row.title) | \(row.scenarioCount) | \(percent(row.baselineCompletedPathHitRate)) -> \(percent(row.candidateCompletedPathHitRate)) | \(percent(row.baselineNotAlignedRate)) -> \(percent(row.candidateNotAlignedRate)) | \(format(row.baselineAverageTaskProgressionAlignment)) -> \(format(row.candidateAverageTaskProgressionAlignment)) |"
                )
            }
            lines.append("")
        }

        lines.append("## Top Improvements")
        lines.append("")
        if sortedImprovements.isEmpty {
            lines.append("No positive replay deltas beyond parity.")
        } else {
            for comparison in sortedImprovements {
                lines.append("- \(comparison.scenario.label) | delta \(format(delta(for: comparison))) | \(comparison.baselineAlignment.level.title) -> \(comparison.candidateAlignment.level.title)")
            }
        }
        lines.append("")
        lines.append("## Top Regressions")
        lines.append("")
        if sortedRegressions.isEmpty {
            lines.append("No replay regressions. Candidate never lost to baseline on the evaluated scenario set.")
        } else {
            for comparison in sortedRegressions {
                let attribution = attributions[comparison.scenario.id]
                let cause = attribution?.cause.rawValue ?? "n/a"
                lines.append("- \(comparison.scenario.label) | delta \(format(delta(for: comparison))) | \(comparison.baselineAlignment.level.title) -> \(comparison.candidateAlignment.level.title) | \(cause)")
            }
        }
        lines.append("")
        lines.append("## Top-k Diff Highlights")
        lines.append("")
        let topKDiffCases = comparisons
            .filter {
                $0.diffSummary.addedCandidateIDs.isEmpty == false ||
                    $0.diffSummary.removedCandidateIDs.isEmpty == false ||
                    $0.diffSummary.rankShifts.contains(where: { $0.kind != .unchanged })
            }
            .sorted { lhs, rhs in
                abs(delta(for: lhs)) > abs(delta(for: rhs))
            }
            .prefix(10)
        if topKDiffCases.isEmpty {
            lines.append("No meaningful top-k diffs. Retrieval stayed effectively identical to baseline on the evaluated set.")
        } else {
            for comparison in topKDiffCases {
                lines.append("- \(comparison.scenario.label) | overlap \(comparison.diffSummary.topKOverlap) | added [\(comparison.diffSummary.addedCandidateIDs.joined(separator: ", "))] | removed [\(comparison.diffSummary.removedCandidateIDs.joined(separator: ", "))]")
            }
        }
        lines.append("")
        lines.append("## Near-miss Cases")
        lines.append("")
        appendExposureSection(
            exposureReport.nearMissCases,
            emptyState: "No near-miss cases. Candidate top-1 decisions stayed direct whenever the expected candidate was recalled into the final recommendation set.",
            to: &lines
        )
        lines.append("")
        lines.append("## Candidate Miss Cases")
        lines.append("")
        appendExposureSection(
            exposureReport.candidateMissCases,
            emptyState: "No candidate miss cases. Every expected next-step candidate appeared in the retrieval provider output for the evaluated scenario set.",
            to: &lines
        )
        lines.append("")
        lines.append("## Weak-trace Cases")
        lines.append("")
        appendExposureSection(
            exposureReport.weakTraceCases,
            emptyState: "No weak-trace cases. Retrieval explanations stayed strong enough across the evaluated scenario set.",
            to: &lines
        )
        lines.append("")
        lines.append("## Weight Decomposition Analysis")
        lines.append("")
        lines.append("4-bucket breakdown for every unresolved case: prompt lexical / context lexical / phrase / suppression.")
        lines.append("Base retrieval score = 0.08. Formula: base + promptLexical(×0.42) + tagOverlap(×0.24) + phrase(×0.14) + contextSupport − suppression.")
        lines.append("")
        appendDecompositionSection(decompositionReport, to: &lines)
        lines.append("")
        lines.append("## Failure Attribution Table")
        lines.append("")
        appendAttributionSection(decompositionReport.attribution, to: &lines)
        lines.append("")
        appendDirectSlotAuditSection(directSlotAudit, to: &lines)
        lines.append("")
        lines.append("## Composer / Diversifier Audit (P2)")
        lines.append("")
        lines.append("- Audited residual near-miss cases: \(composerAuditReport.entries.count)")
        lines.append("- Expected candidate already in high-score set: \(composerAuditReport.highScoreSetCount) / \(composerAuditReport.entries.count)")
        lines.append("- Dropped after scoring: \(composerAuditReport.droppedAfterScoringCount) / \(composerAuditReport.entries.count)")
        lines.append("")
        lines.append("| Case | Expected | Scored rank | Final rank | High-score set | Drop stage | Direct reason |")
        lines.append("| --- | --- | ---: | ---: | --- | --- | --- |")
        for entry in composerAuditReport.entries {
            let scoredRank = entry.expectedScoredRank.map(String.init) ?? "—"
            let finalRank = entry.expectedRecommendationRank.map(String.init) ?? "—"
            lines.append("| `\(entry.scenarioLabel)` | `\(entry.expectedCandidateID)` | \(scoredRank) | \(finalRank) | \(entry.inHighScoreSet ? "yes" : "no") | \(entry.dropStage) | \(entry.directReason) |")
        }
        lines.append("")
        lines.append("## Top-k Rank Shift Analysis")
        lines.append("")
        if exposureReport.rankShiftAggregates.isEmpty {
            lines.append("No aggregated rank shifts beyond unchanged top-k order.")
        } else {
            lines.append("| Candidate | Added | Removed | Up | Down | Avg |")
            lines.append("| --- | ---: | ---: | ---: | ---: | ---: |")
            for aggregate in exposureReport.rankShiftAggregates.prefix(20) {
                lines.append(
                    "| \(aggregate.title) (`\(aggregate.candidateID)`) | \(aggregate.addedCount) | \(aggregate.removedCount) | \(aggregate.upCount) | \(aggregate.downCount) | \(format(aggregate.averageAbsoluteShift)) |"
                )
            }
        }
        lines.append("")
        lines.append("## Retrieval-only Reason Code Distribution")
        lines.append("")
        if exposureReport.reasonDistribution.isEmpty {
            lines.append("No retrieval-only reason tags were recorded.")
        } else {
            for (reason, count) in exposureReport.reasonDistribution {
                lines.append("- `\(reason.rawValue)`: \(count)")
            }
        }
        lines.append("")
        lines.append("## Regression Cases")
        lines.append("")

        if regressionComparisons.isEmpty {
            lines.append("No failure cases. The candidate provider did not produce any baseline-losing scenarios in this replay set.")
            lines.append("")
        }

        for comparison in regressionComparisons {
            let attribution = attributions[comparison.scenario.id] ?? RegressionAttribution(
                cause: .recallOffTopic,
                details: ["No attribution details were produced."]
            )
            lines.append("### \(comparison.scenario.label)")
            lines.append("")
            lines.append("- Prompt: \(comparison.scenario.snapshot.recentPrompt ?? comparison.scenario.label)")
            lines.append("- Delta: \(format(delta(for: comparison)))")
            lines.append("- Baseline alignment: \(comparison.baselineAlignment.level.title)")
            lines.append("- Candidate alignment: \(comparison.candidateAlignment.level.title)")
            lines.append("- Verdict: \(comparison.verdict.title)")
            lines.append("- Retrieval attribution: **\(attribution.cause.rawValue)**")
            lines.append("- Attribution detail: \(attribution.cause.explanation)")
            for detail in attribution.details {
                lines.append("  - \(detail)")
            }
            lines.append("- Top-k overlap: \(comparison.diffSummary.topKOverlap)")
            lines.append("- Added IDs: \(comparison.diffSummary.addedCandidateIDs.joined(separator: ", "))")
            lines.append("- Removed IDs: \(comparison.diffSummary.removedCandidateIDs.joined(separator: ", "))")
            lines.append("")
            lines.append("#### Baseline Top 5")
            lines.append("")
            lines.append(renderTopRecommendations(comparison.baselineRun))
            lines.append("")
            lines.append("#### Candidate Top 5")
            lines.append("")
            lines.append(renderTopRecommendations(comparison.candidateRun))
            lines.append("")
            lines.append("#### Rank Shifts")
            lines.append("")
            if comparison.diffSummary.rankShifts.isEmpty {
                lines.append("- None")
            } else {
                for shift in comparison.diffSummary.rankShifts {
                    let reasons = shift.reasonDelta.map(\.userFacingText).joined(separator: " • ")
                    lines.append("- \(shift.title): \(shift.baselineRank.map(String.init) ?? "–") -> \(shift.candidateRank.map(String.init) ?? "–") | score \(format(shift.baselineScore)) -> \(format(shift.candidateScore)) | confidence \(format(shift.baselineConfidence)) -> \(format(shift.candidateConfidence)) | \(reasons)")
                }
            }
            lines.append("")
            lines.append("#### Candidate Retrieval Trace")
            lines.append("")
            for recommendation in comparison.candidateRun.recommendations.prefix(5) {
                lines.append("- \(recommendation.candidate.title) (`\(recommendation.id)`)")
                lines.append("  - Reason codes: \(recommendation.breakdown.reasonCodes.map(\.rawValue).joined(separator: ", "))")
                lines.append("  - Trace: \(recommendation.candidate.retrieval.metadata.map { "\($0.key)=\($0.value)" }.joined(separator: " | "))")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func goNoGoSummary(
        using attributions: [UUID: RegressionAttribution],
        exposureReport: RetrievalFailureExposureReport
    ) -> String {
        let unexplainedRegressionCount = comparisons
            .filter { $0.verdict == .baselineCloser && attributions[$0.scenario.id] == nil }
            .count
        let metrics = report.aggregateMetrics
        let baselineStrategy = comparisons.first?.baselineRun.strategy
        let candidateStrategy = comparisons.first?.candidateRun.strategy
        let sameProviders = baselineStrategy?.providerVersions == candidateStrategy?.providerVersions
        let sameScorer = baselineStrategy?.scorerVersion == candidateStrategy?.scorerVersion
        let providerOnlyExperiment = sameScorer && sameProviders == false
        let scorerOnlyExperiment = sameProviders && sameScorer == false
        let closedLoopDelta = metrics.candidateCompletedPathHitRate - metrics.baselineCompletedPathHitRate
        let familyDelta = metrics.candidateTaskFamilyAlignmentRate - metrics.baselineTaskFamilyAlignmentRate
        let hiddenFailureSummary = "\(exposureReport.nearMissCases.count) near-miss / \(exposureReport.candidateMissCases.count) candidate-miss / \(exposureReport.weakTraceCases.count) weak-trace"

        if report.offlineGate.status == .pass, unexplainedRegressionCount == 0 {
            if providerOnlyExperiment {
        return "Go. Frozen baseline holds, provider-only candidate clears the 60/60 gate, and residual unresolved is now \(hiddenFailureSummary). The remaining failures are now dominated by residual ranking and post-processing behavior rather than provider misses."
            }

            if scorerOnlyExperiment {
                return "Go. The scorer-only prompt-directness patch clears the 60/60 gate with closed-loop uplift, no not-aligned regression, and stronger direct-slot recovery on the residual near-miss set. Hidden-failure exposure is now \(hiddenFailureSummary)."
            }

            if closedLoopDelta > 0.0001 || familyDelta > 0.0001 {
                return "Conditional go. The retrieval provider clears the provider-phase gate and shows early replay uplift, but hidden-failure exposure still surfaces \(hiddenFailureSummary). Keep the scorer fixed and continue with retrieval-only hardening."
            }

            if abs(closedLoopDelta) < 0.0001, abs(familyDelta) < 0.0001 {
                return "Go for provider hardening, not for uplift. The retrieval provider clears the non-regression gate and every replay regression is explainable, but replay does not yet show closed-loop metric lift. Hidden-failure exposure currently reports \(hiddenFailureSummary)."
            }

            return "Go. The retrieval provider clears the current provider-phase gate and every replay regression has a retrieval-level explanation. Hidden-failure exposure currently reports \(hiddenFailureSummary)."
        }

        if report.offlineGate.status == .insufficientData {
            return "No-go. Replay coverage is not yet sufficient to make a provider decision."
        }

        if scorerOnlyExperiment {
            return "No-go. The scorer-only prompt-directness patch does not clear the 60/60 gate. Revert the scorer patch and keep retrieval and ranking changes separated."
        }

        return "No-go. The retrieval provider does not yet clear the provider-phase gate. Keep the scorer fixed and only adjust query construction, candidate pool coverage, or lexical weighting."
    }

    private func renderTopRecommendations(
        _ run: MatchingReplayRun
    ) -> String {
        run.recommendations.prefix(5).map { recommendation in
            let trace = recommendation.candidate.retrieval.metadata
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " | ")
            return "- #\(recommendation.rank) \(recommendation.candidate.title) (`\(recommendation.id)`) | \(recommendation.candidate.objectKind.title) | score \(format(recommendation.breakdown.finalScore)) | conf \(format(recommendation.breakdown.confidence)) | \(trace)"
        }
        .joined(separator: "\n")
    }

    private func appendMetricRow(
        _ title: String,
        _ baseline: Double,
        _ candidate: Double,
        formatAsPercent: Bool = true,
        deltaOverride: String? = nil,
        to lines: inout [String]
    ) {
        let baselineText = formatAsPercent ? percent(baseline) : format(baseline)
        let candidateText = formatAsPercent ? percent(candidate) : format(candidate)
        let deltaText = deltaOverride ?? formatSigned(candidate - baseline, percentStyle: formatAsPercent)
        lines.append("| \(title) | \(baselineText) | \(candidateText) | \(deltaText) |")
    }

    private func delta(
        for comparison: MatchingReplayComparison
    ) -> Double {
        comparison.candidateAlignment.taskProgressionAlignment - comparison.baselineAlignment.taskProgressionAlignment
    }

    private func appendDecompositionSection(
        _ report: WeightDecompositionReport,
        to lines: inout [String]
    ) {
        if report.cases.isEmpty {
            lines.append("No unresolved cases to decompose.")
            return
        }
        for c in report.cases {
            lines.append("### \(c.label) (\(c.caseType))")
            lines.append("")
            lines.append("- Prompt: \(c.prompt)")
            lines.append("- Expected: `\(c.expectedID)` — \(c.expectedTitle)")
            lines.append("- Top-1 actual: `\(c.top1Breakdown.candidateID)` — \(c.top1Breakdown.title)")
            lines.append("")
            if let e = c.expectedBreakdown {
                lines.append("| Bucket | Expected | Top-1 | Delta (top-1 − expected) |")
                lines.append("| --- | ---: | ---: | ---: |")
                let t = c.top1Breakdown
                lines.append("| prompt lexical | \(format(e.promptLexicalContrib)) | \(format(t.promptLexicalContrib)) | \(formatSigned(t.promptLexicalContrib - e.promptLexicalContrib, percentStyle: false)) |")
                lines.append("| context lexical | \(format(e.contextLexicalContrib)) | \(format(t.contextLexicalContrib)) | \(formatSigned(t.contextLexicalContrib - e.contextLexicalContrib, percentStyle: false)) |")
                lines.append("| phrase | \(format(e.phraseContrib)) | \(format(t.phraseContrib)) | \(formatSigned(t.phraseContrib - e.phraseContrib, percentStyle: false)) |")
                lines.append("| suppression (−) | \(format(e.suppressionPenalty)) | \(format(t.suppressionPenalty)) | \(formatSigned(e.suppressionPenalty - t.suppressionPenalty, percentStyle: false)) |")
                lines.append("| **retrieval score** | **\(format(e.retrievalScore))** | **\(format(t.retrievalScore))** | **\(formatSigned(t.retrievalScore - e.retrievalScore, percentStyle: false))** |")
                lines.append("| **final score** | **\(format(e.finalScore))** | **\(format(t.finalScore))** | **\(formatSigned(t.finalScore - e.finalScore, percentStyle: false))** |")
                lines.append("")
                lines.append("- Raw sub-scores (expected): promptLexical=\(format(e.promptLexicalScore)) tagOverlap=\(format(e.tagOverlap)) phrase=\(format(e.phraseScore)) recency=\(format(e.recencyOverlap)) longTerm=\(format(e.longTermOverlap)) suppress=\(format(e.suppressionPenalty))")
                lines.append("- Rank in top-k: \(e.rankInTopK.map(String.init) ?? "—")")
            } else {
                lines.append("- Expected breakdown: not available (candidate never entered retrieval pool)")
                lines.append("- Top-1 retrieval score: \(format(c.top1Breakdown.retrievalScore)), finalScore: \(format(c.top1Breakdown.finalScore))")
            }
            lines.append("- **Dominant delta bucket**: `\(c.dominantDeltaBucket)`")
            lines.append("- **Root cause**: `\(c.primaryRootCause.rawValue)` — \(c.primaryRootCause.displayName)")
            lines.append("- Attribution: \(c.attributionNote)")
            lines.append("")
        }
    }

    private func appendAttributionSection(
        _ report: FailureAttributionReport,
        to lines: inout [String]
    ) {
        lines.append("### All Unresolved Cases")
        lines.append("")
        lines.append("| Root cause | Count | Cases |")
        lines.append("| --- | ---: | --- |")
        for row in report.allCasesRows {
            lines.append("| \(row.rootCause.displayName) | \(row.count) | \(row.labels.joined(separator: ", ")) |")
        }
        lines.append("")
        lines.append("### Route / Dinner Slice")
        lines.append("")
        if report.routeDinnerRows.isEmpty {
            lines.append("No route / dinner cases in unresolved set.")
        } else {
            lines.append("| Root cause | Count | Cases |")
            lines.append("| --- | ---: | --- |")
            for row in report.routeDinnerRows {
                lines.append("| \(row.rootCause.displayName) | \(row.count) | \(row.labels.joined(separator: ", ")) |")
            }
        }
        lines.append("")
        lines.append("### Candidate Miss Pool Answer")
        lines.append("")
        lines.append(report.candidateMissPoolAnswer)
    }

    private func appendExposureSection(
        _ cases: [RetrievalExposureCase],
        emptyState: String,
        to lines: inout [String]
    ) {
        if cases.isEmpty {
            lines.append(emptyState)
            return
        }

        for exposure in cases.prefix(20) {
            lines.append("### \(exposure.scenarioLabel)")
            lines.append("")
            lines.append("- Prompt: \(exposure.prompt)")
            lines.append("- Should recall: \(exposure.expectedCandidateTitle) (`\(exposure.expectedCandidateID)`)")
            lines.append("- Actually recalled: \(renderActualTopK(exposure))")
            lines.append("- Why it missed / stayed weak: \(exposure.explanation)")
            lines.append("- Retrieval layer: **\(exposure.hardeningLayer.rawValue)**")
            for detail in exposure.evidence {
                lines.append("- Evidence: \(detail)")
            }
            lines.append("")
        }
    }

    private func renderActualTopK(
        _ exposure: RetrievalExposureCase
    ) -> String {
        let actualTop = zip(exposure.actualTopKIDs, exposure.actualTopKTitles)
            .map { pair in
                "\(pair.1) (`\(pair.0)`)"
            }
            .joined(separator: ", ")
        if actualTop.isEmpty {
            if let actualTopCandidateID = exposure.actualTopCandidateID,
               let actualTopCandidateTitle = exposure.actualTopCandidateTitle {
                return "\(actualTopCandidateTitle) (`\(actualTopCandidateID)`)"
            }
            return "None"
        }
        return actualTop
    }
}

private struct RetrievalFailureExposureAnalyzer {
    func analyze(
        comparisons: [MatchingReplayComparison]
    ) -> RetrievalFailureExposureReport {
        let nearMissCases = comparisons.compactMap(makeNearMissCase)
            .sorted(by: compareExposureSeverity)
        let candidateMissCases = comparisons.compactMap(makeCandidateMissCase)
            .sorted(by: compareExposureSeverity)
        let weakTraceCases = comparisons.compactMap(makeWeakTraceCase)
            .sorted(by: compareExposureSeverity)
        let rankShiftAggregates = makeRankShiftAggregates(from: comparisons)
        let reasonDistribution = makeReasonDistribution(from: comparisons)

        return RetrievalFailureExposureReport(
            nearMissCases: nearMissCases,
            candidateMissCases: candidateMissCases,
            weakTraceCases: weakTraceCases,
            rankShiftAggregates: rankShiftAggregates,
            reasonDistribution: reasonDistribution
        )
    }

    private func makeNearMissCase(
        comparison: MatchingReplayComparison
    ) -> RetrievalExposureCase? {
        guard let expectedCandidateID = expectedCandidateID(for: comparison),
              let expectedRecommendation = recommendation(expectedCandidateID, in: comparison.candidateRun),
              expectedRecommendation.rank > 1 else {
            return nil
        }

        let actualTop = comparison.candidateRun.recommendations.first
        let baselineRank = recommendation(expectedCandidateID, in: comparison.baselineRun)?.rank
        let expectedTitle = title(for: expectedCandidateID, in: comparison)
        let actualTitles = comparison.candidateRun.recommendations.prefix(5).map(\.candidate.title)
        let expectedLexical = metadataValue("lexical_score", from: expectedRecommendation.candidate)
        let topLexical = actualTop.map { metadataValue("lexical_score", from: $0.candidate) } ?? 0
        let hardeningLayer = classifyNearMissLayer(
            comparison: comparison,
            expectedCandidate: expectedRecommendation.candidate,
            actualTopCandidate: actualTop?.candidate
        )

        var evidence: [String] = [
            "Expected candidate ranked #\(expectedRecommendation.rank) in the candidate top-k\(baselineRank.map { ", vs #\($0) in baseline" } ?? "").",
            "Expected lexical score \(format(expectedLexical)); top lexical score \(format(topLexical)).",
        ]
        if let actualTop {
            evidence.append("Top-1 stayed on `\(actualTop.candidate.title)` (`\(actualTop.id)`) instead of the expected next step.")
        }

        let explanation: String
        if actualTop?.candidate.objectKind == expectedRecommendation.candidate.objectKind {
            explanation = "Retrieval found the right task family, but it did not make the expected next step direct enough in the final top-k ordering."
        } else {
            explanation = "Retrieval kept the expected candidate in range, but a different task family still took the direct next-step slot."
        }

        return RetrievalExposureCase(
            kind: .nearMiss,
            scenarioLabel: comparison.scenario.label,
            prompt: comparison.scenario.snapshot.recentPrompt ?? comparison.scenario.label,
            expectedCandidateID: expectedCandidateID,
            expectedCandidateTitle: expectedTitle,
            actualTopCandidateID: actualTop?.id,
            actualTopCandidateTitle: actualTop?.candidate.title,
            actualTopKIDs: comparison.candidateRun.recommendations.prefix(5).map(\.id),
            actualTopKTitles: actualTitles,
            explanation: explanation,
            hardeningLayer: hardeningLayer,
            evidence: evidence
        )
    }

    private func makeCandidateMissCase(
        comparison: MatchingReplayComparison
    ) -> RetrievalExposureCase? {
        guard let expectedCandidateID = expectedCandidateID(for: comparison) else {
            return nil
        }

        let providerCandidateIDs = comparison.candidateRun.providerOutput.flatMap(\.candidateIDs)
        guard providerCandidateIDs.contains(expectedCandidateID) == false else {
            return nil
        }

        let expectedTitle = title(for: expectedCandidateID, in: comparison)
        let expectedObjectKind = candidateObjectKind(for: expectedCandidateID, in: comparison)
        let expectedSourcePool = sourcePool(for: expectedCandidateID, in: comparison)
        let actualTop = comparison.candidateRun.recommendations.first
        let hardeningLayer = classifyCandidateMissLayer(
            comparison: comparison,
            expectedObjectKind: expectedObjectKind,
            expectedSourcePool: expectedSourcePool
        )

        var evidence: [String] = [
            "Expected candidate never appeared in retrieval provider output.",
            "Provider output IDs: \(providerCandidateIDs.joined(separator: ", "))",
        ]
        if let expectedObjectKind {
            evidence.append("Expected object kind: \(expectedObjectKind.title).")
        }
        if let expectedSourcePool {
            evidence.append("Expected source pool: \(expectedSourcePool).")
        }
        if let actualTop {
            evidence.append("Top-1 went to `\(actualTop.candidate.title)` (`\(actualTop.id)`) instead.")
        }

        let explanation: String
        switch hardeningLayer {
        case .queryConstruction:
            explanation = "The retrieval query stayed too under-specified or too distorted for the expected candidate to enter the retrieved set at all."
        case .candidatePoolCoverage:
            explanation = "The retrieved pool collapsed away from the expected object family or source, so the expected candidate never surfaced."
        case .lexicalWeighting:
            explanation = "Lexical retrieval over-indexed the wrong terms and failed to pull the expected candidate into the returned set."
        }

        return RetrievalExposureCase(
            kind: .candidateMiss,
            scenarioLabel: comparison.scenario.label,
            prompt: comparison.scenario.snapshot.recentPrompt ?? comparison.scenario.label,
            expectedCandidateID: expectedCandidateID,
            expectedCandidateTitle: expectedTitle,
            actualTopCandidateID: actualTop?.id,
            actualTopCandidateTitle: actualTop?.candidate.title,
            actualTopKIDs: comparison.candidateRun.recommendations.prefix(5).map(\.id),
            actualTopKTitles: comparison.candidateRun.recommendations.prefix(5).map(\.candidate.title),
            explanation: explanation,
            hardeningLayer: hardeningLayer,
            evidence: evidence
        )
    }

    private func makeWeakTraceCase(
        comparison: MatchingReplayComparison
    ) -> RetrievalExposureCase? {
        guard let recommendation = weakTraceSubject(for: comparison) else {
            return nil
        }

        let lexical = metadataValue("lexical_score", from: recommendation.candidate)
        let recency = metadataValue("recency_overlap", from: recommendation.candidate)
        let longTerm = metadataValue("long_term_overlap", from: recommendation.candidate)
        let activeSurfaceBoost = metadataValue("active_surface_boost", from: recommendation.candidate)
        let matchedTerms = metadataString("matched_terms", from: recommendation.candidate)
            .split(separator: ",")
            .map(String.init)
            .filter { $0.isEmpty == false }
        guard lexical < 0.26 || matchedTerms.count <= 1 || (recency + longTerm + activeSurfaceBoost) > lexical + 0.35 else {
            return nil
        }

        let expectedCandidateID = expectedCandidateID(for: comparison) ?? recommendation.id
        let expectedTitle = title(for: expectedCandidateID, in: comparison)
        let hardeningLayer = classifyWeakTraceLayer(
            comparison: comparison,
            recommendation: recommendation,
            lexical: lexical,
            matchedTerms: matchedTerms
        )
        let explanation = "Retrieval recalled a plausible next step, but the trace support is weak enough that the result may not stay stable as prompts and context vary."
        let evidence = [
            "Lexical score \(format(lexical)); recency overlap \(format(recency)); long-term overlap \(format(longTerm)); active-surface boost \(format(activeSurfaceBoost)).",
            "Matched terms: \(matchedTerms.isEmpty ? "none" : matchedTerms.joined(separator: ", ")).",
            "Retrieval reason tags: \(recommendation.candidate.retrieval.coarseReasonTags.map(\.rawValue).joined(separator: ", ")).",
        ]

        return RetrievalExposureCase(
            kind: .weakTrace,
            scenarioLabel: comparison.scenario.label,
            prompt: comparison.scenario.snapshot.recentPrompt ?? comparison.scenario.label,
            expectedCandidateID: expectedCandidateID,
            expectedCandidateTitle: expectedTitle,
            actualTopCandidateID: comparison.candidateRun.recommendations.first?.id,
            actualTopCandidateTitle: comparison.candidateRun.recommendations.first?.candidate.title,
            actualTopKIDs: comparison.candidateRun.recommendations.prefix(5).map(\.id),
            actualTopKTitles: comparison.candidateRun.recommendations.prefix(5).map(\.candidate.title),
            explanation: explanation,
            hardeningLayer: hardeningLayer,
            evidence: evidence
        )
    }

    private func makeRankShiftAggregates(
        from comparisons: [MatchingReplayComparison]
    ) -> [RetrievalRankShiftAggregate] {
        let grouped = Dictionary(grouping: comparisons.flatMap(\.diffSummary.rankShifts).filter { $0.kind != .unchanged }, by: \.candidateID)
        return grouped.compactMap { candidateID, shifts in
            guard let first = shifts.first else { return nil }
            let shiftMagnitudes = shifts.compactMap { shift -> Double? in
                guard let baselineRank = shift.baselineRank,
                      let candidateRank = shift.candidateRank else {
                    return nil
                }
                return Double(abs(candidateRank - baselineRank))
            }
            let averageAbsoluteShift: Double
            if shiftMagnitudes.isEmpty {
                averageAbsoluteShift = 0
            } else {
                averageAbsoluteShift = shiftMagnitudes.reduce(0, +) / Double(shiftMagnitudes.count)
            }
            return RetrievalRankShiftAggregate(
                candidateID: candidateID,
                title: first.title,
                addedCount: shifts.filter { $0.kind == .added }.count,
                removedCount: shifts.filter { $0.kind == .removed }.count,
                upCount: shifts.filter { $0.kind == .up }.count,
                downCount: shifts.filter { $0.kind == .down }.count,
                averageAbsoluteShift: averageAbsoluteShift
            )
        }
        .sorted { lhs, rhs in
            let lhsTotal = lhs.addedCount + lhs.removedCount + lhs.upCount + lhs.downCount
            let rhsTotal = rhs.addedCount + rhs.removedCount + rhs.upCount + rhs.downCount
            if lhsTotal == rhsTotal {
                return lhs.averageAbsoluteShift > rhs.averageAbsoluteShift
            }
            return lhsTotal > rhsTotal
        }
    }

    private func makeReasonDistribution(
        from comparisons: [MatchingReplayComparison]
    ) -> [(MatchingCoarseReasonTag, Int)] {
        var counts: [MatchingCoarseReasonTag: Int] = [:]
        for recommendation in comparisons.flatMap({ $0.candidateRun.recommendations.prefix(5) }) {
            for tag in recommendation.candidate.retrieval.coarseReasonTags {
                counts[tag, default: 0] += 1
            }
        }

        return counts.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key.rawValue < rhs.key.rawValue
            }
            return lhs.value > rhs.value
        }
    }

    private func weakTraceSubject(
        for comparison: MatchingReplayComparison
    ) -> UnifiedMatchRecommendation? {
        if let expectedCandidateID = expectedCandidateID(for: comparison),
           let recommendation = recommendation(expectedCandidateID, in: comparison.candidateRun) {
            return recommendation
        }
        return comparison.candidateRun.recommendations.first
    }

    private func classifyNearMissLayer(
        comparison: MatchingReplayComparison,
        expectedCandidate: UnifiedMatchingCandidate,
        actualTopCandidate: UnifiedMatchingCandidate?
    ) -> RetrievalHardeningLayer {
        if isQueryConstructionSensitive(comparison: comparison),
           metadataValue("lexical_score", from: expectedCandidate) < 0.24 {
            return .queryConstruction
        }

        if let actualTopCandidate,
           actualTopCandidate.objectKind == expectedCandidate.objectKind {
            return .lexicalWeighting
        }

        return .lexicalWeighting
    }

    private func classifyCandidateMissLayer(
        comparison: MatchingReplayComparison,
        expectedObjectKind: MatchingObjectKind?,
        expectedSourcePool: String?
    ) -> RetrievalHardeningLayer {
        if isQueryConstructionSensitive(comparison: comparison) {
            return .queryConstruction
        }

        let topKinds = Set(comparison.candidateRun.recommendations.prefix(5).map(\.candidate.objectKind))
        let topSourcePools = Set(comparison.candidateRun.recommendations.prefix(5).map(\.candidate.sourcePool))
        if let expectedObjectKind, topKinds.contains(expectedObjectKind) == false {
            return .candidatePoolCoverage
        }
        if let expectedSourcePool, topSourcePools.contains(expectedSourcePool) == false {
            return .candidatePoolCoverage
        }

        return .lexicalWeighting
    }

    private func classifyWeakTraceLayer(
        comparison: MatchingReplayComparison,
        recommendation: UnifiedMatchRecommendation,
        lexical: Double,
        matchedTerms: [String]
    ) -> RetrievalHardeningLayer {
        if isQueryConstructionSensitive(comparison: comparison), matchedTerms.count <= 1 || lexical < 0.22 {
            return .queryConstruction
        }

        let recency = metadataValue("recency_overlap", from: recommendation.candidate)
        let longTerm = metadataValue("long_term_overlap", from: recommendation.candidate)
        let activeSurfaceBoost = metadataValue("active_surface_boost", from: recommendation.candidate)
        if (recency + longTerm + activeSurfaceBoost) > lexical + 0.35 {
            return .lexicalWeighting
        }

        return .queryConstruction
    }

    private func isQueryConstructionSensitive(
        comparison: MatchingReplayComparison
    ) -> Bool {
        let label = comparison.scenario.label
        let promptTokenCount = promptTokens(comparison.scenario.snapshot.recentPrompt).count
        return label.contains("ambiguous") ||
            label.contains("low-info") ||
            label.contains("conflict") ||
            promptTokenCount <= 3
    }

    private func compareExposureSeverity(
        lhs: RetrievalExposureCase,
        rhs: RetrievalExposureCase
    ) -> Bool {
        let lhsScore = exposureSeverity(lhs)
        let rhsScore = exposureSeverity(rhs)
        if lhsScore == rhsScore {
            return lhs.scenarioLabel < rhs.scenarioLabel
        }
        return lhsScore > rhsScore
    }

    private func exposureSeverity(
        _ exposure: RetrievalExposureCase
    ) -> Double {
        let topKGap = exposure.actualTopCandidateID == exposure.expectedCandidateID ? 0 : 1
        let evidenceWeight = Double(exposure.evidence.count) * 0.1
        let layerWeight: Double
        switch exposure.hardeningLayer {
        case .candidatePoolCoverage:
            layerWeight = 1
        case .queryConstruction:
            layerWeight = 0.75
        case .lexicalWeighting:
            layerWeight = 0.5
        }
        return Double(topKGap) + evidenceWeight + layerWeight
    }

    private func expectedCandidateID(
        for comparison: MatchingReplayComparison
    ) -> String? {
        comparison.observedOutcome.completedCandidateIDs.first
            ?? comparison.observedOutcome.acceptedCandidateIDs.first
            ?? comparison.observedOutcome.candidateIDs.first
    }

    private func title(
        for candidateID: String,
        in comparison: MatchingReplayComparison
    ) -> String {
        if let recommendation = recommendation(candidateID, in: comparison.candidateRun) {
            return recommendation.candidate.title
        }
        if let recommendation = recommendation(candidateID, in: comparison.baselineRun) {
            return recommendation.candidate.title
        }
        if let scoredCandidate = scoredCandidate(candidateID, in: comparison.candidateRun) {
            return scoredCandidate.candidate.title
        }
        if let scoredCandidate = scoredCandidate(candidateID, in: comparison.baselineRun) {
            return scoredCandidate.candidate.title
        }
        return candidateID
    }

    private func candidateObjectKind(
        for candidateID: String,
        in comparison: MatchingReplayComparison
    ) -> MatchingObjectKind? {
        recommendation(candidateID, in: comparison.candidateRun)?.candidate.objectKind ??
            recommendation(candidateID, in: comparison.baselineRun)?.candidate.objectKind ??
            scoredCandidate(candidateID, in: comparison.candidateRun)?.candidate.objectKind ??
            scoredCandidate(candidateID, in: comparison.baselineRun)?.candidate.objectKind ??
            comparison.observedOutcome.primaryObjectKind
    }

    private func sourcePool(
        for candidateID: String,
        in comparison: MatchingReplayComparison
    ) -> String? {
        recommendation(candidateID, in: comparison.candidateRun)?.candidate.sourcePool ??
            recommendation(candidateID, in: comparison.baselineRun)?.candidate.sourcePool ??
            scoredCandidate(candidateID, in: comparison.candidateRun)?.candidate.sourcePool ??
            scoredCandidate(candidateID, in: comparison.baselineRun)?.candidate.sourcePool
    }

    private func recommendation(
        _ candidateID: String,
        in run: MatchingReplayRun
    ) -> UnifiedMatchRecommendation? {
        run.recommendations.first { $0.id == candidateID }
    }

    private func scoredCandidate(
        _ candidateID: String,
        in run: MatchingReplayRun
    ) -> ScoredMatchCandidate? {
        run.scoredCandidates.first { $0.candidate.id == candidateID }
    }
}

private struct ResidualAttributionEntry: Identifiable {
    var id: String { "\(exposureKind.rawValue)-\(scenarioLabel)" }

    let scenarioLabel: String
    let exposureKind: RetrievalExposureKind
    let expectedCandidateID: String
    let rootCause: FailureRootCause
    let note: String
}

private struct ResidualAttributionReport {
    struct DistributionRow {
        let rootCause: FailureRootCause
        let count: Int
        let labels: [String]
    }

    let entries: [ResidualAttributionEntry]
    let distribution: [DistributionRow]

    var totalExposureCount: Int { entries.count }
}

private struct ComposerAuditEntry: Identifiable {
    var id: String { scenarioLabel }

    let scenarioLabel: String
    let expectedCandidateID: String
    let expectedTitle: String
    let expectedScoredRank: Int?
    let expectedRecommendationRank: Int?
    let inHighScoreSet: Bool
    let dropStage: String
    let directReason: String
}

private struct ComposerAuditReport {
    let entries: [ComposerAuditEntry]

    var highScoreSetCount: Int {
        entries.filter(\.inHighScoreSet).count
    }

    var droppedAfterScoringCount: Int {
        entries.filter { $0.dropStage == "Dropped after scoring" }.count
    }
}

private struct ResidualAttributionAnalyzer {
    func analyze(
        comparisons: [MatchingReplayComparison],
        exposureReport: RetrievalFailureExposureReport
    ) -> ResidualAttributionReport {
        let allExposures = exposureReport.nearMissCases + exposureReport.candidateMissCases + exposureReport.weakTraceCases
        let entries = allExposures.compactMap { exposure -> ResidualAttributionEntry? in
            guard let comparison = comparisons.first(where: { $0.scenario.label == exposure.scenarioLabel }) else {
                return nil
            }
            return makeEntry(
                exposure: exposure,
                comparison: comparison
            )
        }

        let distribution = FailureRootCause.allCases.compactMap { cause -> ResidualAttributionReport.DistributionRow? in
            let matching = entries.filter { $0.rootCause == cause }
            guard matching.isEmpty == false else { return nil }
            return ResidualAttributionReport.DistributionRow(
                rootCause: cause,
                count: matching.count,
                labels: matching.map(\.scenarioLabel)
            )
        }

        return ResidualAttributionReport(
            entries: entries,
            distribution: distribution
        )
    }

    private func makeEntry(
        exposure: RetrievalExposureCase,
        comparison: MatchingReplayComparison
    ) -> ResidualAttributionEntry {
        let expectedID = exposure.expectedCandidateID
        let expectedRecommendation = recommendation(expectedID, in: comparison.candidateRun)
        let expectedScored = scoredCandidate(expectedID, in: comparison.candidateRun)
        let referenceCandidate = expectedRecommendation?.candidate ??
            expectedScored?.candidate ??
            comparison.candidateRun.recommendations.first?.candidate
        let suppressionPenalty = referenceCandidate.map { metadataValue("suppression_penalty", from: $0) } ?? 0
        let lexicalScore = referenceCandidate.map { metadataValue("lexical_score", from: $0) } ?? 0
        let matchedTerms = referenceCandidate.map {
            metadataString("matched_terms", from: $0)
                .split(separator: ",")
                .map(String.init)
                .filter { $0.isEmpty == false }
        } ?? []

        let rootCause: FailureRootCause
        let note: String

        switch exposure.kind {
        case .candidateMiss:
            rootCause = .provider
            note = "Expected candidate never entered the retrieval pool."
        case .nearMiss:
            if let expectedRecommendation {
                if suppressionPenalty > 0.30 {
                    rootCause = .suppression
                    note = "Expected candidate survived into the final top-k at rank #\(expectedRecommendation.rank), but suppression stayed high enough to block the direct slot."
                } else {
                    rootCause = .scorer
                    note = "Expected candidate stayed in the final top-k at rank #\(expectedRecommendation.rank); direct-slot loss is now a ranking problem, not recall."
                }
            } else if let expectedScored {
                rootCause = .composerDiversifier
                note = "Expected candidate scored at #\(scoredRank(for: expectedScored.candidate.id, in: comparison.candidateRun) ?? 0) before post-processing, but it dropped out before the final top-k."
            } else {
                rootCause = .provider
                note = "Expected candidate did not survive retrieval/scoring strongly enough to reach the final list."
            }
        case .weakTrace:
            if expectedScored != nil, expectedRecommendation == nil {
                rootCause = .composerDiversifier
                note = "Expected candidate made it into scored candidates, but post-processing removed it before the final list."
            } else if suppressionPenalty > 0.30 {
                rootCause = .suppression
                note = "Residual weakness is still being driven by suppression pressure on the expected path."
            } else if lexicalScore < 0.26 || matchedTerms.count <= 1 {
                rootCause = .provider
                note = "Residual trace is still too provider-dependent: prompt evidence is thin and matched terms are sparse."
            } else {
                rootCause = .scorer
                note = "Prompt evidence is present, but the final ordering still leaves the trace unstable."
            }
        }

        return ResidualAttributionEntry(
            scenarioLabel: exposure.scenarioLabel,
            exposureKind: exposure.kind,
            expectedCandidateID: expectedID,
            rootCause: rootCause,
            note: note
        )
    }

    private func recommendation(
        _ candidateID: String,
        in run: MatchingReplayRun
    ) -> UnifiedMatchRecommendation? {
        run.recommendations.first { $0.id == candidateID }
    }

    private func scoredCandidate(
        _ candidateID: String,
        in run: MatchingReplayRun
    ) -> ScoredMatchCandidate? {
        run.scoredCandidates.first { $0.candidate.id == candidateID }
    }

    private func scoredRank(
        for candidateID: String,
        in run: MatchingReplayRun
    ) -> Int? {
        run.scoredCandidates
            .sorted { $0.breakdown.finalScore > $1.breakdown.finalScore }
            .firstIndex { $0.candidate.id == candidateID }
            .map { $0 + 1 }
    }
}

private struct ComposerDiversifierAuditAnalyzer {
    func analyze(
        comparisons: [MatchingReplayComparison],
        exposureReport: RetrievalFailureExposureReport
    ) -> ComposerAuditReport {
        let entries = exposureReport.nearMissCases.compactMap { exposure -> ComposerAuditEntry? in
            guard let comparison = comparisons.first(where: { $0.scenario.label == exposure.scenarioLabel }) else {
                return nil
            }
            return makeEntry(
                exposure: exposure,
                comparison: comparison
            )
        }

        return ComposerAuditReport(entries: entries)
    }

    private func makeEntry(
        exposure: RetrievalExposureCase,
        comparison: MatchingReplayComparison
    ) -> ComposerAuditEntry {
        let expectedID = exposure.expectedCandidateID
        let sortedScored = comparison.candidateRun.scoredCandidates.sorted {
            $0.breakdown.finalScore > $1.breakdown.finalScore
        }
        let expectedScoredRank = sortedScored.firstIndex(where: { $0.candidate.id == expectedID }).map { $0 + 1 }
        let expectedRecommendationRank = comparison.candidateRun.recommendations.first(where: { $0.id == expectedID })?.rank
        let expectedTitle = comparison.candidateRun.scoredCandidates.first(where: { $0.candidate.id == expectedID })?.candidate.title
            ?? comparison.candidateRun.recommendations.first(where: { $0.id == expectedID })?.candidate.title
            ?? expectedID

        let topKCutoffScore = sortedScored.dropFirst(4).first?.breakdown.finalScore ?? sortedScored.last?.breakdown.finalScore ?? 0
        let expectedScore = sortedScored.first(where: { $0.candidate.id == expectedID })?.breakdown.finalScore ?? 0
        let inHighScoreSet = (expectedScoredRank ?? .max) <= 8 || expectedScore >= topKCutoffScore - 0.05

        let dropStage: String
        let directReason: String
        if expectedRecommendationRank != nil {
            dropStage = "Stayed in final top-k"
            directReason = "Ranked below the direct slot"
        } else if let expectedScored = sortedScored.first(where: { $0.candidate.id == expectedID }) {
            dropStage = "Dropped after scoring"
            directReason = inferDiversifierReason(
                expected: expectedScored.candidate,
                sortedScored: sortedScored,
                context: comparison.candidateRun.context
            )
        } else {
            dropStage = "Missing before scoring"
            directReason = "Provider miss"
        }

        return ComposerAuditEntry(
            scenarioLabel: exposure.scenarioLabel,
            expectedCandidateID: expectedID,
            expectedTitle: expectedTitle,
            expectedScoredRank: expectedScoredRank,
            expectedRecommendationRank: expectedRecommendationRank,
            inHighScoreSet: inHighScoreSet,
            dropStage: dropStage,
            directReason: directReason
        )
    }

    private func inferDiversifierReason(
        expected: UnifiedMatchingCandidate,
        sortedScored: [ScoredMatchCandidate],
        context: MatchingFeatureContext
    ) -> String {
        var seenObjectKinds: [MatchingObjectKind: Int] = [:]
        var seenSources: [String: Int] = [:]
        var seenSemanticKeys: Set<String> = []

        for entry in sortedScored {
            if entry.candidate.id == expected.id {
                if seenSemanticKeys.contains(expected.semanticKey) {
                    return "Semantic de-duplication"
                }
                if seenObjectKinds[expected.objectKind, default: 0] >= 2 {
                    return "Object-type quota"
                }
                if seenSources[expected.sourcePool, default: 0] >= 2 {
                    return "Source-pool quota"
                }
                if context.activeSurface != .chat,
                   expected.preferredSection != nil,
                   expected.preferredSection != context.activeSurface {
                    return "Surface routing bias"
                }
                return "Score order below top-k"
            }

            if seenSemanticKeys.contains(entry.candidate.semanticKey) {
                continue
            }
            if seenObjectKinds[entry.candidate.objectKind, default: 0] >= 2 {
                continue
            }
            if seenSources[entry.candidate.sourcePool, default: 0] >= 2 {
                continue
            }

            seenSemanticKeys.insert(entry.candidate.semanticKey)
            seenObjectKinds[entry.candidate.objectKind, default: 0] += 1
            seenSources[entry.candidate.sourcePool, default: 0] += 1
        }

        return "Unknown post-processing rule"
    }
}

// MARK: - Weight Decomposition

private struct CandidateWeightBreakdown {
    let candidateID: String
    let title: String
    let promptLexicalScore: Double
    let tagOverlap: Double
    let phraseScore: Double
    let contextSupport: Double
    let suppressionPenalty: Double
    let recencyOverlap: Double
    let longTermOverlap: Double
    let retrievalScore: Double
    let finalScore: Double
    let rankInTopK: Int?

    var promptLexicalContrib: Double { promptLexicalScore * 0.42 + tagOverlap * 0.24 }
    var contextLexicalContrib: Double { contextSupport }
    var phraseContrib: Double { phraseScore * 0.14 }
}

private enum FailureRootCause: String, CaseIterable {
    case provider = "provider"
    case scorer = "scorer"
    case composerDiversifier = "composer_diversifier"
    case suppression = "suppression"

    var displayName: String {
        switch self {
        case .provider: return "Provider"
        case .scorer: return "Scorer"
        case .composerDiversifier: return "Composer / diversifier"
        case .suppression: return "Suppression"
        }
    }
}

private struct CaseWeightDecomposition {
    let label: String
    let prompt: String
    let caseType: String
    let expectedID: String
    let expectedTitle: String
    let expectedBreakdown: CandidateWeightBreakdown?
    let top1Breakdown: CandidateWeightBreakdown
    let dominantDeltaBucket: String
    let primaryRootCause: FailureRootCause
    let attributionNote: String
}

private struct FailureAttributionReport {
    struct Row {
        let rootCause: FailureRootCause
        let count: Int
        let labels: [String]
    }
    let allCasesRows: [Row]
    let routeDinnerRows: [Row]
    let candidateMissPoolAnswer: String
}

private struct WeightDecompositionReport {
    let cases: [CaseWeightDecomposition]
    let attribution: FailureAttributionReport
}

private struct WeightDecompositionAnalyzer {
    func analyze(
        comparisons: [MatchingReplayComparison],
        exposureReport: RetrievalFailureExposureReport
    ) -> WeightDecompositionReport {
        let exposureLabels: [String] = exposureReport.nearMissCases.map(\.scenarioLabel)
            + exposureReport.candidateMissCases.map(\.scenarioLabel)
        let exposureLabelSet = Set(exposureLabels)
        let alignmentUnresolved = comparisons.filter {
            $0.candidateAlignment.level != .directMatch
        }
        let alignmentLabels = Set(alignmentUnresolved.map(\.scenario.label))

        var seenLabels = Set<String>()
        var orderedComparisons: [MatchingReplayComparison] = []
        for label in exposureLabels {
            guard !seenLabels.contains(label),
                  let match = comparisons.first(where: { $0.scenario.label == label })
            else { continue }
            orderedComparisons.append(match)
            seenLabels.insert(label)
        }
        for comparison in alignmentUnresolved
        where !seenLabels.contains(comparison.scenario.label) && !exposureLabelSet.contains(comparison.scenario.label) {
            orderedComparisons.append(comparison)
            seenLabels.insert(comparison.scenario.label)
        }
        _ = alignmentLabels

        var cases: [CaseWeightDecomposition] = []

        for comparison in orderedComparisons {
            guard let expectedID = expectedCandidateID(for: comparison),
                  let top1 = comparison.candidateRun.recommendations.first else { continue }

            let top1Breakdown = makeBreakdown(from: top1, rankInTopK: 1)
            let providerCandidateIDs = Set(comparison.candidateRun.providerOutput.flatMap(\.candidateIDs))

            if !providerCandidateIDs.contains(expectedID) {
                cases.append(CaseWeightDecomposition(
                    label: comparison.scenario.label,
                    prompt: comparison.scenario.snapshot.recentPrompt ?? comparison.scenario.label,
                    caseType: "candidate_miss",
                    expectedID: expectedID,
                    expectedTitle: titleFor(expectedID, in: comparison),
                    expectedBreakdown: nil,
                    top1Breakdown: top1Breakdown,
                    dominantDeltaBucket: "provider_recall",
                    primaryRootCause: .provider,
                    attributionNote: "Expected candidate never entered retrieval pool. Pool had \(providerCandidateIDs.count) candidates; expected ID absent. Pool coverage gap, not a ranking issue."
                ))
                continue
            }

            if let expectedRec = comparison.candidateRun.recommendations.first(where: { $0.id == expectedID }) {
                let expectedBreakdown = makeBreakdown(from: expectedRec, rankInTopK: expectedRec.rank)
                let rootCause = attributeRootCause(expected: expectedBreakdown, top1: top1Breakdown)
                let dominantBucket = dominantDeltaBucket(expected: expectedBreakdown, top1: top1Breakdown)
                cases.append(CaseWeightDecomposition(
                    label: comparison.scenario.label,
                    prompt: comparison.scenario.snapshot.recentPrompt ?? comparison.scenario.label,
                    caseType: "near_miss",
                    expectedID: expectedID,
                    expectedTitle: expectedRec.candidate.title,
                    expectedBreakdown: expectedBreakdown,
                    top1Breakdown: top1Breakdown,
                    dominantDeltaBucket: dominantBucket,
                    primaryRootCause: rootCause,
                    attributionNote: buildAttributionNote(rootCause: rootCause, expected: expectedBreakdown, top1: top1Breakdown)
                ))
            } else if let scored = comparison.candidateRun.scoredCandidates.first(where: { $0.candidate.id == expectedID }) {
                let expectedBreakdown = makeBreakdownFromScored(scored)
                cases.append(CaseWeightDecomposition(
                    label: comparison.scenario.label,
                    prompt: comparison.scenario.snapshot.recentPrompt ?? comparison.scenario.label,
                    caseType: "near_miss",
                    expectedID: expectedID,
                    expectedTitle: scored.candidate.title,
                    expectedBreakdown: expectedBreakdown,
                    top1Breakdown: top1Breakdown,
                    dominantDeltaBucket: "composer_diversity",
                    primaryRootCause: .composerDiversifier,
                    attributionNote: "Scored but cut by diversifier before top-k. finalScore=\(format(scored.breakdown.finalScore))."
                ))
            } else {
                cases.append(CaseWeightDecomposition(
                    label: comparison.scenario.label,
                    prompt: comparison.scenario.snapshot.recentPrompt ?? comparison.scenario.label,
                    caseType: "near_miss",
                    expectedID: expectedID,
                    expectedTitle: titleFor(expectedID, in: comparison),
                    expectedBreakdown: nil,
                    top1Breakdown: top1Breakdown,
                    dominantDeltaBucket: "provider_recall",
                    primaryRootCause: .provider,
                    attributionNote: "In provider pool but dropped by constraint or score threshold before scoring."
                ))
            }
        }

        return WeightDecompositionReport(cases: cases, attribution: buildAttribution(cases: cases))
    }

    private func makeBreakdown(from rec: UnifiedMatchRecommendation, rankInTopK: Int) -> CandidateWeightBreakdown {
        let c = rec.candidate
        return CandidateWeightBreakdown(
            candidateID: rec.id, title: c.title,
            promptLexicalScore: meta("prompt_lexical_score", c),
            tagOverlap: meta("tag_overlap", c),
            phraseScore: meta("phrase_score", c),
            contextSupport: meta("context_support", c),
            suppressionPenalty: meta("suppression_penalty", c),
            recencyOverlap: meta("recency_overlap", c),
            longTermOverlap: meta("long_term_overlap", c),
            retrievalScore: c.retrieval.retrievalScore,
            finalScore: rec.breakdown.finalScore,
            rankInTopK: rankInTopK
        )
    }

    private func makeBreakdownFromScored(_ scored: ScoredMatchCandidate) -> CandidateWeightBreakdown {
        let c = scored.candidate
        return CandidateWeightBreakdown(
            candidateID: c.id, title: c.title,
            promptLexicalScore: meta("prompt_lexical_score", c),
            tagOverlap: meta("tag_overlap", c),
            phraseScore: meta("phrase_score", c),
            contextSupport: meta("context_support", c),
            suppressionPenalty: meta("suppression_penalty", c),
            recencyOverlap: meta("recency_overlap", c),
            longTermOverlap: meta("long_term_overlap", c),
            retrievalScore: c.retrieval.retrievalScore,
            finalScore: scored.breakdown.finalScore,
            rankInTopK: nil
        )
    }

    private func meta(_ key: String, _ c: UnifiedMatchingCandidate) -> Double {
        Double(c.retrieval.metadata.first(where: { $0.key == key })?.value ?? "0") ?? 0
    }

    private func attributeRootCause(expected: CandidateWeightBreakdown, top1: CandidateWeightBreakdown) -> FailureRootCause {
        let suppressionDelta = expected.suppressionPenalty - top1.suppressionPenalty
        if expected.suppressionPenalty > 0.30, suppressionDelta > 0.20 {
            return .suppression
        }
        return .scorer
    }

    private func dominantDeltaBucket(expected: CandidateWeightBreakdown, top1: CandidateWeightBreakdown) -> String {
        let buckets: [(String, Double)] = [
            ("prompt_lexical", top1.promptLexicalContrib - expected.promptLexicalContrib),
            ("context_lexical", top1.contextLexicalContrib - expected.contextLexicalContrib),
            ("phrase", top1.phraseContrib - expected.phraseContrib),
            ("suppression", expected.suppressionPenalty - top1.suppressionPenalty),
        ]
        return buckets.max(by: { $0.1 < $1.1 })?.0 ?? "prompt_lexical"
    }

    private func buildAttributionNote(
        rootCause: FailureRootCause,
        expected: CandidateWeightBreakdown,
        top1: CandidateWeightBreakdown
    ) -> String {
        let finalScoreDelta = top1.finalScore - expected.finalScore
        switch rootCause {
        case .suppression:
            return "Suppression penalty on expected: \(format(expected.suppressionPenalty)), top-1: \(format(top1.suppressionPenalty)). Delta: \(format(expected.suppressionPenalty - top1.suppressionPenalty))."
        case .scorer:
            return "Scorer gave top-1 a +\(format(finalScoreDelta)) finalScore advantage. Expected retrieval \(format(expected.retrievalScore)) vs top-1 \(format(top1.retrievalScore)). Retrieval contributes only ~3.9% to finalScore; scorer context heuristics dominate."
        case .composerDiversifier:
            return "Diversifier removed expected candidate from top-k."
        case .provider:
            return "Expected candidate not in provider pool."
        }
    }

    private func buildAttribution(cases: [CaseWeightDecomposition]) -> FailureAttributionReport {
        let routeDinnerLabels: Set<String> = [
            "commute-ambiguous-go-now", "commute-route-dismiss", "commute-route-history",
            "commute-search-facts", "commute-long-term-drift",
            "local-cafe-long-term-drift", "local-dinner-ambiguous", "local-dinner-clean",
            "local-dinner-low-info", "local-recent-music-pollution", "local-search-conflict",
            "local-dinner-dismiss",
        ]

        func rows(from subset: [CaseWeightDecomposition]) -> [FailureAttributionReport.Row] {
            FailureRootCause.allCases.compactMap { cause in
                let matching = subset.filter { $0.primaryRootCause == cause }
                guard !matching.isEmpty else { return nil }
                return FailureAttributionReport.Row(
                    rootCause: cause, count: matching.count, labels: matching.map(\.label)
                )
            }
        }

        let candidateMiss = cases.first(where: { $0.caseType == "candidate_miss" })
        let poolAnswer: String
        if let cm = candidateMiss {
            poolAnswer = "[\(cm.label)] `\(cm.expectedID)` was **never recalled into the pool** (confirmed pool coverage gap, not a ranking failure). Root cause: `provider`."
        } else {
            poolAnswer = "No candidate miss cases found."
        }

        return FailureAttributionReport(
            allCasesRows: rows(from: cases),
            routeDinnerRows: rows(from: cases.filter { routeDinnerLabels.contains($0.label) }),
            candidateMissPoolAnswer: poolAnswer
        )
    }

    private func expectedCandidateID(for comparison: MatchingReplayComparison) -> String? {
        comparison.observedOutcome.completedCandidateIDs.first
            ?? comparison.observedOutcome.acceptedCandidateIDs.first
            ?? comparison.observedOutcome.candidateIDs.first
    }

    private func titleFor(_ id: String, in comparison: MatchingReplayComparison) -> String {
        comparison.candidateRun.recommendations.first(where: { $0.id == id })?.candidate.title
            ?? comparison.baselineRun.recommendations.first(where: { $0.id == id })?.candidate.title
            ?? comparison.candidateRun.scoredCandidates.first(where: { $0.candidate.id == id })?.candidate.title
            ?? id
    }
}

private struct RegressionAttributionAnalyzer {
    func analyze(
        comparison: MatchingReplayComparison
    ) -> RegressionAttribution {
        let targetID = comparison.observedOutcome.completedCandidateIDs.first
            ?? comparison.observedOutcome.acceptedCandidateIDs.first
            ?? comparison.observedOutcome.candidateIDs.first
        let candidateTop = comparison.candidateRun.recommendations
        let baselineTop = comparison.baselineRun.recommendations
        let candidateTopFirst = candidateTop.first
        let promptTokenSet = Set(promptTokens(comparison.scenario.snapshot.recentPrompt))
        let concentrationGap = concentration(for: comparison.candidateRun) - concentration(for: comparison.baselineRun)
        let candidateTopKinds = Dictionary(grouping: candidateTop.prefix(5), by: \.candidate.objectKind)
        let negativeHistory = comparison.scenario.snapshot.behaviorLog.filter {
            $0.stage == .dismiss || $0.stage == .abandon
        }

        if let targetID,
           baselineTop.contains(where: { $0.id == targetID }),
           comparison.candidateRun.providerOutput.flatMap(\.candidateIDs).contains(targetID) == false {
            return RegressionAttribution(
                cause: .recallMissing,
                details: [
                    "Baseline kept the target candidate `\(targetID)` in top-k, but the retrieval provider never returned it.",
                    "Candidate provider IDs: \(comparison.candidateRun.providerOutput.flatMap(\.candidateIDs).joined(separator: ", "))",
                ]
            )
        }

        if concentrationGap > 0.15 || candidateTopKinds.values.map(\.count).max() ?? 0 >= 4 {
            return RegressionAttribution(
                cause: .objectTypeOverConcentration,
                details: [
                    "Candidate concentration worsened by \(format(concentrationGap)).",
                    "Candidate top kinds: \(candidateTopKinds.map { "\($0.key.title)=\($0.value.count)" }.sorted().joined(separator: ", "))",
                ]
            )
        }

        if let top = candidateTopFirst,
           comparison.scenario.snapshot.activeSurface != .chat,
           top.candidate.preferredSection == comparison.scenario.snapshot.activeSurface,
           top.candidate.objectKind != comparison.observedOutcome.primaryObjectKind {
            return RegressionAttribution(
                cause: .activeSurfaceInterference,
                details: [
                    "Active surface was `\(comparison.scenario.snapshot.activeSurface.title)` and the candidate top result stayed on that surface.",
                    "Top retrieved candidate: `\(top.id)` (\(top.candidate.objectKind.title))",
                ]
            )
        }

        if let top = candidateTopFirst {
            let negativeMatch = negativeHistory.first { event in
                if let candidateID = event.candidateID, candidateID == top.id {
                    return true
                }
                return event.objectKind == top.candidate.objectKind
            }
            if let negativeMatch {
                return RegressionAttribution(
                    cause: .explicitDismissIneffective,
                    details: [
                        "Negative history existed for `\(negativeMatch.candidateID ?? negativeMatch.objectKind?.title ?? "unknown")` but retrieval still promoted `\(top.id)`.",
                        "Feedback: \(negativeMatch.feedback?.title ?? "n/a")",
                    ]
                )
            }
        }

        if let top = candidateTopFirst {
            let lexicalScore = metadataValue("lexical_score", from: top.candidate)
            let recencyOverlap = metadataValue("recency_overlap", from: top.candidate)
            let longTermOverlap = metadataValue("long_term_overlap", from: top.candidate)
            let matchedTerms = metadataString("matched_terms", from: top.candidate)
                .split(separator: ",")
                .map(String.init)
            let matchedPromptTerms = promptTokenSet.intersection(matchedTerms)

            if lexicalScore < 0.24, matchedPromptTerms.isEmpty == true, (recencyOverlap > 0.24 || longTermOverlap > 0.24) {
                return RegressionAttribution(
                    cause: .contextPollution,
                    details: [
                        "Prompt token overlap was weak, but recency/long-term overlap stayed high.",
                        "lexical=\(format(lexicalScore)), recency=\(format(recencyOverlap)), longTerm=\(format(longTermOverlap)), matched_terms=\(matchedTerms.joined(separator: ", "))",
                    ]
                )
            }

            if lexicalScore < 0.24, matchedPromptTerms.isEmpty == true, matchedTerms.isEmpty == false {
                return RegressionAttribution(
                    cause: .queryExpansionDistortion,
                    details: [
                        "Top retrieval terms came from expansion instead of prompt tokens.",
                        "Prompt tokens: \(promptTokenSet.sorted().joined(separator: ", "))",
                        "Matched terms: \(matchedTerms.joined(separator: ", "))",
                    ]
                )
            }
        }

        return RegressionAttribution(
            cause: .recallOffTopic,
            details: [
                "The retrieval top-k stayed in a different task family than the observed outcome.",
                "Observed primary object: \(comparison.observedOutcome.primaryObjectKind?.title ?? "Unknown")",
                "Candidate top-k IDs: \(candidateTop.prefix(5).map(\.id).joined(separator: ", "))",
            ]
        )
    }

    private func concentration(
        for run: MatchingReplayRun
    ) -> Double {
        let recommendations = Array(run.recommendations.prefix(5))
        guard recommendations.isEmpty == false else { return 0 }
        let grouped = Dictionary(grouping: recommendations, by: \.candidate.objectKind)
        return grouped.values.reduce(0) { partial, entries in
            let ratio = Double(entries.count) / Double(recommendations.count)
            return partial + ratio * ratio
        }
    }

    private func metadataValue(
        _ key: String,
        from candidate: UnifiedMatchingCandidate
    ) -> Double {
        guard let rawValue = candidate.retrieval.metadata.first(where: { $0.key == key })?.value else {
            return 0
        }
        return Double(rawValue) ?? 0
    }

    private func metadataString(
        _ key: String,
        from candidate: UnifiedMatchingCandidate
    ) -> String {
        candidate.retrieval.metadata.first(where: { $0.key == key })?.value ?? ""
    }
}

private func promptTokens(
    _ text: String?
) -> [String] {
    guard let text, text.isEmpty == false else { return [] }
    let normalized = text
        .lowercased()
        .replacingOccurrences(of: "-", with: " ")
        .replacingOccurrences(of: "_", with: " ")
    let pattern = #"[a-z0-9]+|[\p{Han}]+"#
    guard let expression = try? NSRegularExpression(pattern: pattern) else {
        return []
    }
    let range = NSRange(normalized.startIndex..., in: normalized)
    return expression.matches(in: normalized, range: range).compactMap { match in
        guard let range = Range(match.range, in: normalized) else { return nil }
        return String(normalized[range])
    }
}

private func percent(_ value: Double) -> String {
    String(format: "%.1f%%", value * 100)
}

private func format(_ value: Double?) -> String {
    guard let value else { return "–" }
    return String(format: "%.2f", value)
}

private func metadataValue(
    _ key: String,
    from candidate: UnifiedMatchingCandidate
) -> Double {
    guard let rawValue = candidate.retrieval.metadata.first(where: { $0.key == key })?.value else {
        return 0
    }
    return Double(rawValue) ?? 0
}

private func metadataString(
    _ key: String,
    from candidate: UnifiedMatchingCandidate
) -> String {
    candidate.retrieval.metadata.first(where: { $0.key == key })?.value ?? ""
}

private func formatSigned(
    _ value: Double,
    percentStyle: Bool
) -> String {
    if percentStyle {
        return String(format: "%+.1f%%", value * 100)
    }
    return String(format: "%+.2f", value)
}

private func timestamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(identifier: "America/Toronto")
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
}

// MARK: - Scorer-Only Counterfactual (P0)

private struct ScorerCounterfactualHypothesis {
    let beta: Double = 0.24
    let patchLanded: Bool
    let scorerVersion: String

    var description: String {
        if patchLanded {
            return "Scorer patch is currently landed in `HeuristicScoringPolicy`: `finalScore += retrievalScore × 0.24`. Replay compares the recovered pre-patch rank (`current finalScore − retrievalScore × 0.24`) against the current post-patch rank inside the frozen scoredCandidates pool. No retrieval / composer / diversifier changes."
        }

        return "Scorer patch is not currently landed. Replay evaluates the same single-term patch counterfactually by adding `retrievalScore × 0.24` on top of the current scorer output inside the frozen scoredCandidates pool. No retrieval / composer / diversifier changes."
    }
}

private struct ScorerCounterfactualCaseResult {
    let label: String
    let isRouteDinner: Bool
    let expectedID: String
    let expectedTitle: String
    let currentRank: Int?
    let currentFinalScore: Double
    let retrievalScore: Double
    let retrievalLift: Double
    let prePatchTop1ID: String
    let postPatchTop1ID: String
    let prePatchExpectedRank: Int?
    let postPatchExpectedRank: Int?
    let prePatchTopKContains: Bool
    let postPatchTopKContains: Bool
    let prePatchTop1Contains: Bool
    let postPatchTop1Contains: Bool
}

private struct ScorerCounterfactualReport {
    let hypothesis: ScorerCounterfactualHypothesis
    let cases: [ScorerCounterfactualCaseResult]
    let providerBacklog: [(label: String, expectedID: String, prompt: String)]
}

private struct ScorerCounterfactualAnalyzer {
    func analyze(
        comparisons: [MatchingReplayComparison],
        exposureReport: RetrievalFailureExposureReport
    ) -> ScorerCounterfactualReport {
        let scorerVersion = comparisons.first?.candidateRun.strategy.scorerVersion ?? "unknown"
        let hypothesis = ScorerCounterfactualHypothesis(
            patchLanded: scorerVersion.contains("retrieval-lift"),
            scorerVersion: scorerVersion
        )
        let nearMissLabels = exposureReport.nearMissCases.map(\.scenarioLabel)
        let candidateMissLabels = Set(exposureReport.candidateMissCases.map(\.scenarioLabel))

        let routeDinnerLabels: Set<String> = [
            "commute-ambiguous-go-now", "commute-route-dismiss", "commute-route-history",
            "commute-search-facts", "commute-long-term-drift",
            "local-cafe-long-term-drift", "local-dinner-ambiguous", "local-dinner-clean",
            "local-dinner-low-info", "local-recent-music-pollution", "local-search-conflict",
            "local-dinner-dismiss",
        ]
        // local-dinner-dismiss is composer_error per P1 attribution — exclude from scorer counterfactual success.
        let excludedForScorerExperiment: Set<String> = ["local-dinner-dismiss"]

        var results: [ScorerCounterfactualCaseResult] = []
        for label in nearMissLabels {
            guard let comparison = comparisons.first(where: { $0.scenario.label == label }) else { continue }
            guard let expectedID = expectedCandidateID(for: comparison) else { continue }

            let scored = comparison.candidateRun.scoredCandidates
            let currentSorted = scored.sorted { $0.breakdown.finalScore > $1.breakdown.finalScore }
            let prePatchSorted = scored.sorted {
                prePatchScore(
                    $0,
                    beta: hypothesis.beta,
                    patchLanded: hypothesis.patchLanded
                ) > prePatchScore(
                    $1,
                    beta: hypothesis.beta,
                    patchLanded: hypothesis.patchLanded
                )
            }
            let postPatchSorted = scored.sorted {
                postPatchScore(
                    $0,
                    beta: hypothesis.beta,
                    patchLanded: hypothesis.patchLanded
                ) > postPatchScore(
                    $1,
                    beta: hypothesis.beta,
                    patchLanded: hypothesis.patchLanded
                )
            }

            let currentExpectedRank = currentSorted.firstIndex(where: { $0.candidate.id == expectedID }).map { $0 + 1 }
            let prePatchExpectedRank = prePatchSorted.firstIndex(where: { $0.candidate.id == expectedID }).map { $0 + 1 }
            let postPatchExpectedRank = postPatchSorted.firstIndex(where: { $0.candidate.id == expectedID }).map { $0 + 1 }

            let prePatchTop = prePatchSorted.first
            let postPatchTop = postPatchSorted.first
            let expectedScored = scored.first(where: { $0.candidate.id == expectedID })
            let retrievalScore = expectedScored?.candidate.retrieval.retrievalScore ?? 0
            let retrievalLift = retrievalScore * hypothesis.beta

            results.append(ScorerCounterfactualCaseResult(
                label: label,
                isRouteDinner: routeDinnerLabels.contains(label) && !excludedForScorerExperiment.contains(label),
                expectedID: expectedID,
                expectedTitle: expectedScored?.candidate.title ?? expectedID,
                currentRank: currentExpectedRank,
                currentFinalScore: expectedScored?.breakdown.finalScore ?? 0,
                retrievalScore: retrievalScore,
                retrievalLift: retrievalLift,
                prePatchTop1ID: prePatchTop?.candidate.id ?? "—",
                postPatchTop1ID: postPatchTop?.candidate.id ?? "—",
                prePatchExpectedRank: prePatchExpectedRank,
                postPatchExpectedRank: postPatchExpectedRank,
                prePatchTopKContains: prePatchExpectedRank.map { $0 <= 5 } ?? false,
                postPatchTopKContains: postPatchExpectedRank.map { $0 <= 5 } ?? false,
                prePatchTop1Contains: prePatchExpectedRank == 1,
                postPatchTop1Contains: postPatchExpectedRank == 1
            ))
        }

        var backlog: [(label: String, expectedID: String, prompt: String)] = []
        for label in candidateMissLabels {
            guard let comparison = comparisons.first(where: { $0.scenario.label == label }) else { continue }
            guard let expectedID = expectedCandidateID(for: comparison) else { continue }
            backlog.append((
                label: label,
                expectedID: expectedID,
                prompt: comparison.scenario.snapshot.recentPrompt ?? label
            ))
        }

        return ScorerCounterfactualReport(hypothesis: hypothesis, cases: results, providerBacklog: backlog)
    }

    private func prePatchScore(
        _ scored: ScoredMatchCandidate,
        beta: Double,
        patchLanded: Bool
    ) -> Double {
        if patchLanded {
            return scored.breakdown.finalScore - scored.candidate.retrieval.retrievalScore * beta
        }
        return scored.breakdown.finalScore
    }

    private func postPatchScore(
        _ scored: ScoredMatchCandidate,
        beta: Double,
        patchLanded: Bool
    ) -> Double {
        if patchLanded {
            return scored.breakdown.finalScore
        }
        return scored.breakdown.finalScore + scored.candidate.retrieval.retrievalScore * beta
    }

    private func expectedCandidateID(for comparison: MatchingReplayComparison) -> String? {
        comparison.observedOutcome.completedCandidateIDs.first
            ?? comparison.observedOutcome.acceptedCandidateIDs.first
            ?? comparison.observedOutcome.candidateIDs.first
    }
}

private func appendCounterfactualSection(
    _ report: ScorerCounterfactualReport,
    to lines: inout [String]
) {
    lines.append("Scorer audit: \(report.hypothesis.description)")
    lines.append("")
    lines.append("- Current scorer version: `\(report.hypothesis.scorerVersion)`")
    lines.append("- Patch landed in current code: \(report.hypothesis.patchLanded ? "yes" : "no")")
    lines.append("- Audit fields per case: `currentFinalScore`, `retrievalScore`, `retrievalLift`, `prePatchRank`, `postPatchRank`, `expected top-1/top-5`.")
    lines.append("")
    lines.append("Ranks are computed inside each scenario's frozen scoredCandidates pool. Any provider misses are excluded from scorer success accounting.")
    lines.append("")
    lines.append("### Provider Backlog (not in scorer experiment)")
    lines.append("")
    if report.providerBacklog.isEmpty {
        lines.append("- None.")
    } else {
        for item in report.providerBacklog {
            lines.append("- `\(item.label)` — expected `\(item.expectedID)`, prompt: \(item.prompt). **Tracked as provider recall backlog; excluded from scorer counterfactual.**")
        }
    }
    lines.append("")
    lines.append("### Full Near-miss Counterfactual Table (n=\(report.cases.count))")
    lines.append("")
    lines.append("| Case | Expected | Current final | Retrieval | Lift | Current rank | Pre rank | Post rank | Top-1 (pre → post) | Top-5 (pre → post) |")
    lines.append("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |")
    for c in report.cases {
        let currentRank = c.currentRank.map(String.init) ?? "—"
        let preRank = c.prePatchExpectedRank.map(String.init) ?? "—"
        let postRank = c.postPatchExpectedRank.map(String.init) ?? "—"
        let top1 = "\(c.prePatchTop1Contains ? "yes" : "no") → \(c.postPatchTop1Contains ? "yes" : "no")"
        let top5 = "\(c.prePatchTopKContains ? "yes" : "no") → \(c.postPatchTopKContains ? "yes" : "no")"
        lines.append("| `\(c.label)` | `\(c.expectedID)` | \(format(c.currentFinalScore)) | \(format(c.retrievalScore)) | \(format(c.retrievalLift)) | \(currentRank) | \(preRank) | \(postRank) | \(top1) | \(top5) |")
    }
    lines.append("")

    let routeDinnerCases = report.cases.filter { $0.isRouteDinner }
    lines.append("### Route / Dinner Slice (scorer-only, n=\(routeDinnerCases.count))")
    lines.append("")
    lines.append("Excluded: `local-dinner-dismiss` (composer/diversifier error per P1 attribution; not counted in scorer experiment).")
    lines.append("")
    if routeDinnerCases.isEmpty {
        lines.append("- No cases.")
    } else {
        lines.append("| Case | Expected | Current rank | Pre rank | Post rank | Retrieval | Lift | Top-1 (pre → post) |")
        lines.append("| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |")
        for c in routeDinnerCases {
            let currentRank = c.currentRank.map(String.init) ?? "—"
            let preRank = c.prePatchExpectedRank.map(String.init) ?? "—"
            let postRank = c.postPatchExpectedRank.map(String.init) ?? "—"
            let promoted = "\(c.prePatchTop1Contains ? "yes" : "no") → \(c.postPatchTop1Contains ? "yes" : "no")"
            lines.append("| `\(c.label)` | `\(c.expectedID)` | \(currentRank) | \(preRank) | \(postRank) | \(format(c.retrievalScore)) | \(format(c.retrievalLift)) | \(promoted) |")
        }
    }
    lines.append("")

    let promotedToTop1 = report.cases.filter { $0.postPatchTop1Contains }.count
    let enteredTopK = report.cases.filter { !$0.prePatchTopKContains && $0.postPatchTopKContains }.count
    let rankImproved = report.cases.filter {
        guard let b = $0.prePatchExpectedRank, let n = $0.postPatchExpectedRank else { return false }
        return n < b
    }.count
    let rankRegressed = report.cases.filter {
        guard let b = $0.prePatchExpectedRank, let n = $0.postPatchExpectedRank else { return false }
        return n > b
    }.count

    let rdPromoted = routeDinnerCases.filter { $0.postPatchTop1Contains }.count
    let rdImproved = routeDinnerCases.filter {
        guard let b = $0.prePatchExpectedRank, let n = $0.postPatchExpectedRank else { return false }
        return n < b
    }.count

    lines.append("### Counterfactual Summary")
    lines.append("")
    lines.append("- Cases evaluated: \(report.cases.count) near-miss after excluding provider-miss cases.")
    lines.append("- Rank improved: \(rankImproved) / \(report.cases.count)")
    lines.append("- Rank regressed: \(rankRegressed) / \(report.cases.count)")
    lines.append("- Expected promoted to top-1: \(promotedToTop1) / \(report.cases.count)")
    lines.append("- Expected newly entered top-5: \(enteredTopK) / \(report.cases.count)")
    lines.append("- Route/Dinner slice rank improved: \(rdImproved) / \(routeDinnerCases.count)")
    lines.append("- Route/Dinner slice promoted to top-1: \(rdPromoted) / \(routeDinnerCases.count)")
    lines.append("")
    lines.append("- Single scorer term under audit: `finalScore += retrievalScore × \(format(report.hypothesis.beta))`")
    lines.append("- This audit does not claim recall uplift; it only measures rank recovery inside the current retrieved pool.")
}

private struct DirectSlotAuditEntry {
    let label: String
    let expectedID: String
    let expectedTitle: String
    let baselineRank: Int?
    let candidateRank: Int?
    let status: String
}

private struct WeakTraceAuditEntry {
    let label: String
    let expectedID: String
    let expectedTitle: String
    let baselineRank: Int?
    let candidateRank: Int?
    let status: String
    let excluded: Bool
}

private struct DirectSlotAuditReport {
    let nearMissEntries: [DirectSlotAuditEntry]
    let weakTraceEntries: [WeakTraceAuditEntry]

    var recoveredCount: Int {
        nearMissEntries.filter { $0.status == "improved" }.count
    }

    var heldCount: Int {
        nearMissEntries.filter { $0.status == "held" }.count
    }

    var regressedCount: Int {
        nearMissEntries.filter { $0.status == "regressed" }.count
    }

    var directSlotRecoveryRate: Double {
        guard nearMissEntries.isEmpty == false else { return 0 }
        return Double(recoveredCount) / Double(nearMissEntries.count)
    }

    var weakTraceImprovedCount: Int {
        weakTraceEntries.filter { $0.excluded == false && $0.status == "improved" }.count
    }

    var weakTraceHeldCount: Int {
        weakTraceEntries.filter { $0.excluded == false && $0.status == "held" }.count
    }

    var weakTraceRegressedCount: Int {
        weakTraceEntries.filter { $0.excluded == false && $0.status == "regressed" }.count
    }

    var weakTraceExcludedCount: Int {
        weakTraceEntries.filter(\.excluded).count
    }
}

private struct DirectSlotAuditAnalyzer {
    func analyze(
        baselineComparisons: [MatchingReplayComparison],
        candidateComparisons: [MatchingReplayComparison],
        baselineExposureReport: RetrievalFailureExposureReport,
        candidateExposureReport: RetrievalFailureExposureReport
    ) -> DirectSlotAuditReport {
        let baselineByLabel = Dictionary(uniqueKeysWithValues: baselineComparisons.map { ($0.scenario.label, $0) })
        let candidateByLabel = Dictionary(uniqueKeysWithValues: candidateComparisons.map { ($0.scenario.label, $0) })
        let candidateWeakTraceLabels = Set(candidateExposureReport.weakTraceCases.map(\.scenarioLabel))

        let nearMissEntries = baselineExposureReport.nearMissCases.compactMap { exposure -> DirectSlotAuditEntry? in
            guard let baselineComparison = baselineByLabel[exposure.scenarioLabel],
                  let candidateComparison = candidateByLabel[exposure.scenarioLabel] else {
                return nil
            }

            let baselineRank = recommendation(exposure.expectedCandidateID, in: baselineComparison.candidateRun)?.rank
            let candidateRank = recommendation(exposure.expectedCandidateID, in: candidateComparison.candidateRun)?.rank

            let status: String
            if candidateRank == 1 {
                status = "improved"
            } else if let candidateRank, candidateRank <= 5 {
                status = "held"
            } else {
                status = "regressed"
            }

            return DirectSlotAuditEntry(
                label: exposure.scenarioLabel,
                expectedID: exposure.expectedCandidateID,
                expectedTitle: exposure.expectedCandidateTitle,
                baselineRank: baselineRank,
                candidateRank: candidateRank,
                status: status
            )
        }

        let weakTraceEntries = baselineExposureReport.weakTraceCases.compactMap { exposure -> WeakTraceAuditEntry? in
            guard let baselineComparison = baselineByLabel[exposure.scenarioLabel],
                  let candidateComparison = candidateByLabel[exposure.scenarioLabel] else {
                return nil
            }

            let baselineRank = recommendation(exposure.expectedCandidateID, in: baselineComparison.candidateRun)?.rank
            let candidateRank = recommendation(exposure.expectedCandidateID, in: candidateComparison.candidateRun)?.rank
            let excluded = (baselineRank == nil) || (baselineRank.map { $0 > 5 } ?? true)

            let status: String
            if excluded {
                status = "hold-out"
            } else if candidateWeakTraceLabels.contains(exposure.scenarioLabel) == false {
                status = "improved"
            } else if let baselineRank, let candidateRank, candidateRank > baselineRank {
                status = "regressed"
            } else if candidateRank == nil || (candidateRank.map { $0 > 5 } ?? false) {
                status = "regressed"
            } else {
                status = "held"
            }

            return WeakTraceAuditEntry(
                label: exposure.scenarioLabel,
                expectedID: exposure.expectedCandidateID,
                expectedTitle: exposure.expectedCandidateTitle,
                baselineRank: baselineRank,
                candidateRank: candidateRank,
                status: status,
                excluded: excluded
            )
        }

        return DirectSlotAuditReport(
            nearMissEntries: nearMissEntries,
            weakTraceEntries: weakTraceEntries
        )
    }

    private func recommendation(
        _ candidateID: String,
        in run: MatchingReplayRun
    ) -> UnifiedMatchRecommendation? {
        run.recommendations.first(where: { $0.id == candidateID })
    }
}

private func appendDirectSlotAuditSection(
    _ audit: DirectSlotAuditReport,
    to lines: inout [String]
) {
    lines.append("## Direct-slot Audit")
    lines.append("")
    lines.append("- Near-miss base set: \(audit.nearMissEntries.count)")
    lines.append("- Direct-slot recovery: \(audit.recoveredCount) improved / \(audit.heldCount) held / \(audit.regressedCount) regressed")
    lines.append("- Direct Slot Recovery Rate: \(percent(audit.directSlotRecoveryRate))")
    lines.append("- Weak-trace base set: \(audit.weakTraceEntries.count)")
    lines.append("- Weak-trace in-scope: \(audit.weakTraceEntries.count - audit.weakTraceExcludedCount)")
    lines.append("- Weak-trace audit: \(audit.weakTraceImprovedCount) improved / \(audit.weakTraceHeldCount) held / \(audit.weakTraceRegressedCount) regressed")
    lines.append("- Weak-trace hold-out excluded: \(audit.weakTraceExcludedCount)")
    lines.append("")
    lines.append("### Near-miss Direct-slot Outcomes")
    lines.append("")
    lines.append("| Case | Expected | Baseline rank | Candidate rank | Status |")
    lines.append("| --- | --- | ---: | ---: | --- |")
    for entry in audit.nearMissEntries {
        lines.append("| `\(entry.label)` | `\(entry.expectedID)` | \(entry.baselineRank.map(String.init) ?? "—") | \(entry.candidateRank.map(String.init) ?? "—") | \(entry.status) |")
    }
    lines.append("")
    lines.append("### Weak-trace Outcomes")
    lines.append("")
    lines.append("| Case | Expected | Baseline rank | Candidate rank | Status | Scope |")
    lines.append("| --- | --- | ---: | ---: | --- | --- |")
    for entry in audit.weakTraceEntries {
        lines.append("| `\(entry.label)` | `\(entry.expectedID)` | \(entry.baselineRank.map(String.init) ?? "—") | \(entry.candidateRank.map(String.init) ?? "—") | \(entry.status) | \(entry.excluded ? "hold-out" : "in-scope") |")
    }
}
