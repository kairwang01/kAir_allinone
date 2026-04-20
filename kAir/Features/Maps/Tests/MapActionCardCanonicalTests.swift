//
//  MapActionCardCanonicalTests.swift
//  kAir
//
//  T4 — end-to-end coverage for the first user-visible vertical slice:
//  Chat → Recommended Next → Map Action Card → Execution Surface → Return.
//
//  Each test:
//    1. Builds a Maps-kind `UnifiedMatchRecommendation` fixture
//    2. Projects it to a `MapActionCardModel` via the frozen factory
//    3. Seeds the full SurfaceEntry chain (requested → started → returned)
//       into an isolated `MatchingReplayLab` using the same APIs the
//       runtime uses
//    4. Asserts kind inference, locked copy, chain invariants,
//       terminalOutcome == .completion, and id-threading between card /
//       request / event / payload
//
//  Scope is Maps only — 3 task kinds (goToPlace / nearbySearch /
//  routeCompare). This is the test pin for the P0+P1+P2 contract.
//

import Foundation

struct MapActionCardCanonicalReport {
    let results: [KernelPhase1TestResult]

    var allPassed: Bool { results.allSatisfy(\.passed) }
    var passedCount: Int { results.filter(\.passed).count }
    var failedCount: Int { results.filter { !$0.passed }.count }
}

enum MapActionCardCanonicalTests {
    @MainActor
    static func runAll() -> MapActionCardCanonicalReport {
        let results: [KernelPhase1TestResult] = [
            testGoToPlaceCardRoundTrip(),
            testNearbySearchCardRoundTrip(),
            testRouteCompareCardRoundTrip(),
            testIdThreadingAcrossChain(),
            testFromRecommendationRejectsNonMaps(),
            testLockedCopyCoversBothLanguages(),
            testMapTaskAdapterNormalizedArgsReturnAllKeys(),
        ]
        return MapActionCardCanonicalReport(results: results)
    }

    // MARK: - 1. goToPlace card → completed chain

    @MainActor
    static func testGoToPlaceCardRoundTrip() -> KernelPhase1TestResult {
        let name = "map_card_go_to_place_round_trip"
        let tag = "map-canon-goto"
        // inferTaskKind: no .localDiscovery and no .planning/.commute →
        // falls through to default .goToPlace.
        let recommendation = makeRecommendation(
            id: tag,
            kind: .goToPlace,
            objectKind: .place,
            tags: [.navigation]
        )
        let threadId = UUID()
        guard let card = MapActionCardModel.fromRecommendation(
            recommendation,
            recommendationId: "rec-session-\(tag)",
            threadId: threadId,
            language: .english
        ) else {
            return .init(name: name, passed: false, detail: "factory rejected maps-kind recommendation")
        }

        guard card.taskKind == .goToPlace,
              card.primaryActionTitle == "Go here",
              card.title == recommendation.candidate.title,
              card.threadId == threadId.uuidString,
              card.candidateId == recommendation.candidate.id else {
            return .init(name: name, passed: false, detail: "card projection mismatch: kind=\(card.taskKind) primary=\(card.primaryActionTitle)")
        }

        let lab = MatchingReplayLab()
        let baseTime = Date(timeIntervalSince1970: 1_700_100_000)
        emitChain(
            into: lab,
            card: card,
            tag: tag,
            threadId: threadId,
            baseTime: baseTime,
            intent: .navigate,
            outcome: .completed
        )

        guard let chain = findChain(in: lab, requestId: requestIdForTag(tag)) else {
            return .init(name: name, passed: false, detail: "chain missing")
        }
        guard chain.terminalOutcome == .completion,
              chain.hasRecommendation,
              chain.hasReturned,
              chain.invariants.allPassed,
              chain.events.count == 3,
              chain.normalizedArgs["task_type"] == MapTaskType.goToPlace.rawValue else {
            return .init(
                name: name,
                passed: false,
                detail: "chain shape wrong: terminal=\(chain.terminalOutcome) events=\(chain.events.count) inv=\(chain.invariants) args=\(chain.normalizedArgs)"
            )
        }
        return .init(name: name, passed: true, detail: "goToPlace card produced 3-event chain with completion + invariants green")
    }

    // MARK: - 2. nearbySearch card → completed chain

    @MainActor
    static func testNearbySearchCardRoundTrip() -> KernelPhase1TestResult {
        let name = "map_card_nearby_search_round_trip"
        let tag = "map-canon-nearby"
        let recommendation = makeRecommendation(
            id: tag,
            kind: .nearbySearch,
            objectKind: .place,
            tags: [.navigation, .localDiscovery, .relaxation]
        )
        let threadId = UUID()
        guard let card = MapActionCardModel.fromRecommendation(
            recommendation,
            recommendationId: "rec-session-\(tag)",
            threadId: threadId,
            language: .chinese
        ) else {
            return .init(name: name, passed: false, detail: "factory rejected maps-kind recommendation")
        }

        guard card.taskKind == .nearbySearch,
              card.primaryActionTitle == "看看附近",
              card.language.usesChineseCopy else {
            return .init(name: name, passed: false, detail: "zh copy missing: primary=\(card.primaryActionTitle)")
        }

        let lab = MatchingReplayLab()
        let baseTime = Date(timeIntervalSince1970: 1_700_100_100)
        emitChain(
            into: lab,
            card: card,
            tag: tag,
            threadId: threadId,
            baseTime: baseTime,
            intent: .discoverNearby,
            outcome: .completed
        )

        guard let chain = findChain(in: lab, requestId: requestIdForTag(tag)) else {
            return .init(name: name, passed: false, detail: "chain missing")
        }
        guard chain.terminalOutcome == .completion,
              chain.hasReturned,
              chain.invariants.allPassed,
              chain.normalizedArgs["task_type"] == MapTaskType.nearbySearch.rawValue,
              chain.normalizedArgs["language"] == "zh" else {
            return .init(
                name: name,
                passed: false,
                detail: "chain shape wrong: terminal=\(chain.terminalOutcome) inv=\(chain.invariants) args=\(chain.normalizedArgs)"
            )
        }
        return .init(name: name, passed: true, detail: "nearbySearch card produced chain with zh args + completion")
    }

    // MARK: - 3. routeCompare card → completed chain

    @MainActor
    static func testRouteCompareCardRoundTrip() -> KernelPhase1TestResult {
        let name = "map_card_route_compare_round_trip"
        let tag = "map-canon-route"
        let recommendation = makeRecommendation(
            id: tag,
            kind: .routeCompare,
            objectKind: .route,
            tags: [.navigation, .planning, .commute]
        )
        let threadId = UUID()
        guard let card = MapActionCardModel.fromRecommendation(
            recommendation,
            recommendationId: "rec-session-\(tag)",
            threadId: threadId,
            language: .english
        ) else {
            return .init(name: name, passed: false, detail: "factory rejected maps-kind recommendation")
        }

        guard card.taskKind == .routeCompare,
              card.primaryActionTitle == "Compare routes" else {
            return .init(name: name, passed: false, detail: "routeCompare kind/copy mismatch: kind=\(card.taskKind) primary=\(card.primaryActionTitle)")
        }

        let lab = MatchingReplayLab()
        let baseTime = Date(timeIntervalSince1970: 1_700_100_200)
        emitChain(
            into: lab,
            card: card,
            tag: tag,
            threadId: threadId,
            baseTime: baseTime,
            intent: .reviewRoute,
            outcome: .completed
        )

        guard let chain = findChain(in: lab, requestId: requestIdForTag(tag)) else {
            return .init(name: name, passed: false, detail: "chain missing")
        }
        guard chain.terminalOutcome == .completion,
              chain.hasReturned,
              chain.invariants.allPassed,
              chain.normalizedArgs["task_type"] == MapTaskType.routeComparison.rawValue else {
            return .init(
                name: name,
                passed: false,
                detail: "chain shape wrong: terminal=\(chain.terminalOutcome) inv=\(chain.invariants) args=\(chain.normalizedArgs)"
            )
        }
        return .init(name: name, passed: true, detail: "routeCompare card produced chain with routeComparison task_type")
    }

    // MARK: - 4. recommendationId / requestId / threadId threaded consistently

    @MainActor
    static func testIdThreadingAcrossChain() -> KernelPhase1TestResult {
        let name = "map_card_id_threading"
        let tag = "map-canon-ids"
        let recommendation = makeRecommendation(
            id: tag,
            kind: .goToPlace,
            objectKind: .place,
            tags: [.navigation]
        )
        let threadId = UUID()
        let sessionRecommendationId = "rec-session-\(tag)"
        guard let card = MapActionCardModel.fromRecommendation(
            recommendation,
            recommendationId: sessionRecommendationId,
            threadId: threadId,
            language: .english
        ) else {
            return .init(name: name, passed: false, detail: "factory rejected maps-kind recommendation")
        }

        let lab = MatchingReplayLab()
        let baseTime = Date(timeIntervalSince1970: 1_700_100_300)
        emitChain(
            into: lab,
            card: card,
            tag: tag,
            threadId: threadId,
            baseTime: baseTime,
            intent: .navigate,
            outcome: .completed
        )

        let requestId = requestIdForTag(tag)
        guard let chain = findChain(in: lab, requestId: requestId),
              let request = chain.request,
              let payload = chain.returnPayload else {
            return .init(name: name, passed: false, detail: "chain/request/payload missing")
        }

        let chainCardRec = chain.sourceRecommendationId
        let chainThread = request.sourceThreadId
        let payloadReq = payload.sourceRequestId
        let payloadRec = payload.sourceRecommendationId

        guard chainCardRec == card.id,
              chainThread == threadId.uuidString,
              payloadReq == requestId,
              payloadRec == card.id,
              chain.invariants.payloadLinksMatchChain,
              card.recommendationId == sessionRecommendationId,
              card.candidateId == recommendation.candidate.id else {
            return .init(
                name: name,
                passed: false,
                detail: "ids drifted: chainRec=\(chainCardRec ?? "nil") chainThread=\(chainThread ?? "nil") payloadReq=\(payloadReq ?? "nil") payloadRec=\(payloadRec ?? "nil")"
            )
        }
        return .init(
            name: name,
            passed: true,
            detail: "card.id / request.threadId / payload ids all threaded consistently; payloadLinksMatchChain green"
        )
    }

    // MARK: - 5. non-Maps recommendation is rejected by the factory gate

    @MainActor
    static func testFromRecommendationRejectsNonMaps() -> KernelPhase1TestResult {
        let name = "map_card_rejects_non_maps"
        let musicRec = makeRecommendation(
            id: "non-maps-music",
            kind: .goToPlace, // kind param unused for non-maps factory
            objectKind: .song,
            tags: [.focus],
            preferredSection: .music
        )
        let card = MapActionCardModel.fromRecommendation(
            musicRec,
            recommendationId: "rec-session-non-maps",
            threadId: UUID(),
            language: .english
        )
        guard card == nil else {
            return .init(name: name, passed: false, detail: "non-maps recommendation unexpectedly produced a card")
        }
        return .init(name: name, passed: true, detail: "factory returns nil for non-Maps preferredSection as expected")
    }

    // MARK: - 6. Locked copy present for zh/en across all 3 kinds

    @MainActor
    static func testLockedCopyCoversBothLanguages() -> KernelPhase1TestResult {
        let name = "map_card_locked_copy"
        let expected: [(MapActionCardTaskKind, String, String)] = [
            (.goToPlace, "Go here", "去这里"),
            (.nearbySearch, "Explore nearby", "看看附近"),
            (.routeCompare, "Compare routes", "看路线"),
        ]
        for (kind, en, zh) in expected {
            let enCopy = MapActionCardCopy.locked(for: kind, language: .english)
            let zhCopy = MapActionCardCopy.locked(for: kind, language: .chinese)
            guard enCopy.primaryActionTitle == en, zhCopy.primaryActionTitle == zh else {
                return .init(
                    name: name,
                    passed: false,
                    detail: "copy drift for \(kind): enPrimary=\(enCopy.primaryActionTitle) zhPrimary=\(zhCopy.primaryActionTitle)"
                )
            }
            guard enCopy.secondaryActionTitle != nil, zhCopy.secondaryActionTitle != nil else {
                return .init(name: name, passed: false, detail: "secondary action missing for \(kind)")
            }
        }
        return .init(name: name, passed: true, detail: "all 3 kinds x zh/en primary+secondary copy locked")
    }

    // MARK: - 7. Adapter normalizedArgs contract

    @MainActor
    static func testMapTaskAdapterNormalizedArgsReturnAllKeys() -> KernelPhase1TestResult {
        let name = "map_task_adapter_normalized_args"
        let adapter = DefaultMapTaskAdapter()

        let destination = MapPlaceCandidate(
            title: "Blue Bottle Oakland",
            subtitle: "Local cafe",
            coordinate: MapCoordinate(latitude: 37.8, longitude: -122.3),
            distanceText: "1.2 km"
        )
        let task = MapTask(
            threadId: UUID(),
            taskType: .goToPlace,
            query: "Blue Bottle Oakland",
            destinationCandidates: [destination],
            selectedDestination: destination,
            transportMode: .driving,
            entryMode: .actionOpenMaps,
            resultSummary: "Blue Bottle Oakland · 8 min",
            language: .english
        )
        let request = MapTaskAdapterRequest(
            query: task.query,
            threadId: task.threadId,
            language: task.language,
            preferredKind: .goToPlace
        )
        let args = adapter.normalizedArgs(for: task, request: request)

        let required = [
            MapTaskAdapterResult.argKeyQuery,
            MapTaskAdapterResult.argKeyTaskType,
            MapTaskAdapterResult.argKeyLanguage,
            MapTaskAdapterResult.argKeyEntryMode,
            MapTaskAdapterResult.argKeyTransportMode,
            MapTaskAdapterResult.argKeyDestinationTitle,
        ]
        for key in required {
            guard args[key] != nil else {
                return .init(name: name, passed: false, detail: "missing key \(key) in normalizedArgs")
            }
        }
        guard args[MapTaskAdapterResult.argKeyTaskType] == MapTaskType.goToPlace.rawValue,
              args[MapTaskAdapterResult.argKeyTransportMode] == MapTransportMode.driving.rawValue,
              args[MapTaskAdapterResult.argKeyDestinationTitle] == "Blue Bottle Oakland" else {
            return .init(name: name, passed: false, detail: "arg values wrong: \(args)")
        }
        return .init(name: name, passed: true, detail: "adapter normalizedArgs contains all 6 canonical keys with correct values")
    }

    // MARK: - Fixtures

    @MainActor
    private static func makeRecommendation(
        id: String,
        kind: MapActionCardTaskKind,
        objectKind: MatchingObjectKind,
        tags: Set<MatchingIntentTag>,
        preferredSection: AppSection = .maps
    ) -> UnifiedMatchRecommendation {
        let candidate = UnifiedMatchingCandidate(
            id: "cand-\(id)",
            title: "Map candidate \(id)",
            summary: "Summary for \(id)",
            objectKind: objectKind,
            preferredSection: preferredSection,
            activationPrompt: "Open \(id)",
            tags: tags,
            sourcePool: "t4-fixture",
            utilityProfile: MatchingUtilityProfile(
                goal: .taskCompletion,
                domainWeight: 0.7,
                nextStepWeight: 0.8
            )
        )
        let breakdown = MatchingScoreBreakdown(
            globalEligibility: 0.8,
            domainUtility: 0.6,
            nextStepValue: 0.7,
            explorationBoost: 0.0,
            diversityPenalty: 0.0,
            finalScore: 0.7,
            confidence: 0.75,
            reasonCodes: [.sessionIntentMatch, .eligibleNow],
            debugPayload: MatchingScoringDebugPayload(
                userFeatureKeys: [],
                contextFeatureKeys: [],
                candidateFeatureKeys: [],
                interactionFeatureKeys: [],
                fatigueFeatureKeys: [],
                retrievalMetadata: [],
                policyVersion: MatchingPolicyVersion.current.scorerBaselineID
            ),
            contribution: ScoreContributionBreakdown(
                globalEligibility: 0.8,
                domainUtility: 0.6,
                nextStepValue: 0.7,
                explorationBoost: 0.0,
                retrievalLift: 0.05,
                promptDirectnessBonus: 0.05,
                diversityPenalty: 0.0,
                promptLexical: 0.1,
                contextLexical: 0.0,
                phrase: 0.0,
                suppression: 0.0,
                finalScore: 0.7,
                policyVersion: MatchingPolicyVersion.current.scorerBaselineID
            )
        )
        let package = MatchingRecommendationPackage(
            style: .focusedSurface,
            ctaTitle: "Open",
            prompt: candidate.activationPrompt
        )
        _ = kind // kind is expressed via objectKind + tags which drive inferTaskKind
        return UnifiedMatchRecommendation(
            candidate: candidate,
            breakdown: breakdown,
            package: package,
            rank: 1
        )
    }

    @MainActor
    private static func emitChain(
        into lab: MatchingReplayLab,
        card: MapActionCardModel,
        tag: String,
        threadId: UUID,
        baseTime: Date,
        intent: SurfaceEntryIntent,
        outcome: ExecutionOutcome
    ) {
        let requestId = requestIdForTag(tag)
        let recommendationId = card.id
        let candidateId = card.candidateId

        let args: [String: String] = [
            "query": "prompt-\(tag)",
            "task_type": card.taskKind.mappedTaskType.rawValue,
            "language": card.language.usesChineseCopy ? "zh" : "en",
            "entry_mode": MapTaskEntryMode.actionOpenMaps.rawValue,
        ]
        let request = SurfaceEntryRequest(
            requestId: requestId,
            surfaceType: .maps,
            entryIntent: intent,
            sourceCardId: card.id,
            sourceRecommendationId: recommendationId,
            sourceThreadId: threadId.uuidString,
            objectType: MatchingObjectKind.place.rawValue,
            objectId: candidateId,
            normalizedArgs: args,
            requiresConfirmation: false,
            handoffContext: SurfaceEntryHandoffContext(
                sourceMessagePreview: "T4 \(tag)",
                returnThreadId: threadId.uuidString,
                priorContextStateSummary: nil
            ),
            issuedAt: baseTime
        )
        lab.retainSurfaceEntryRequest(request)

        lab.submitSurfaceEntryEvent(
            makeEvent(.surfaceEntryRequested, at: baseTime, recId: recommendationId, candidateId: candidateId, requestId: requestId)
        )
        lab.submitSurfaceEntryEvent(
            makeEvent(.surfaceEntryStarted, at: baseTime.addingTimeInterval(0.25), recId: recommendationId, candidateId: candidateId, requestId: requestId)
        )

        let payload = ExecutionReturnPayload(
            executedCandidateId: candidateId,
            executionSurfaceType: .maps,
            outcome: outcome,
            duration: 1.5,
            returnContextDelta: .neutral,
            sourceRequestId: requestId,
            sourceRecommendationId: recommendationId
        )
        lab.retainSurfaceEntryReturnPayload(payload)
        lab.submitSurfaceEntryEvent(
            makeEvent(
                .surfaceEntryReturned,
                at: baseTime.addingTimeInterval(1),
                recId: recommendationId,
                candidateId: candidateId,
                requestId: requestId,
                outcome: payload.toOutcomeEventPayload
            )
        )
    }

    private static func makeEvent(
        _ type: MatchingEventType,
        at timestamp: Date,
        recId: String,
        candidateId: String,
        requestId: String,
        outcome: MatchingEventOutcome? = nil
    ) -> MatchingEvent {
        MatchingEvent(
            type: type,
            sessionId: "t4-session",
            recommendationId: recId,
            candidateId: candidateId,
            timestamp: timestamp,
            objectType: MatchingObjectKind.place.rawValue,
            executionSurfaceType: AppSection.maps.rawValue,
            feedbackOption: nil,
            policyVersion: MatchingPolicyVersion.current.policyVersion,
            outcome: outcome,
            surfaceEntryRequestId: requestId
        )
    }

    @MainActor
    private static func findChain(in lab: MatchingReplayLab, requestId: String) -> SurfaceEntryChain? {
        lab.surfaceEntryChains.first { $0.requestId == requestId }
    }

    private static func requestIdForTag(_ tag: String) -> String {
        "req-\(tag)"
    }
}
