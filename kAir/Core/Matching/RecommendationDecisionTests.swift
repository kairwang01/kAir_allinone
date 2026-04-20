//
//  RecommendationDecisionTests.swift
//  kAir
//
//  P1 tests for the Recommendation Decision Protocol.
//  Covers: decision generation, action-card mapping for every object type,
//  feedback option coverage, and reason-code propagation onto cards.
//

import Foundation

struct RecommendationDecisionTestReport {
    let results: [KernelPhase1TestResult]

    var allPassed: Bool { results.allSatisfy(\.passed) }
    var passedCount: Int { results.filter(\.passed).count }
    var failedCount: Int { results.filter { !$0.passed }.count }
}

enum RecommendationDecisionTests {
    static func runAll() -> RecommendationDecisionTestReport {
        let results: [KernelPhase1TestResult] = [
            testDecisionGeneration(),
            testCardMappingCoverage(),
            testFeedbackOptionCoverage(),
            testReasonCodePropagation(),
        ]
        return RecommendationDecisionTestReport(results: results)
    }

    // MARK: - Test 1: decision generation

    static func testDecisionGeneration() -> KernelPhase1TestResult {
        let engine = UnifiedMatchingEngine()
        let snapshot = makeFixtureSnapshot(prompt: "导航回家")
        let decision = engine.decide(snapshot: snapshot, limit: 4)

        guard decision.rankedCandidates.isEmpty == false else {
            return KernelPhase1TestResult(
                name: "decision_generation",
                passed: false,
                detail: "engine returned empty ranked list"
            )
        }

        guard decision.recommendationId.hasPrefix("rec-") else {
            return KernelPhase1TestResult(
                name: "decision_generation",
                passed: false,
                detail: "recommendationId missing rec- prefix: \(decision.recommendationId)"
            )
        }

        guard decision.policyVersion.policyVersion == MatchingPolicyVersion.current.policyVersion else {
            return KernelPhase1TestResult(
                name: "decision_generation",
                passed: false,
                detail: "decision.policyVersion != MatchingPolicyVersion.current"
            )
        }

        if let direct = decision.directSlotCandidate {
            guard direct.id == decision.rankedCandidates.first?.id else {
                return KernelPhase1TestResult(
                    name: "decision_generation",
                    passed: false,
                    detail: "direct slot must equal rank 1"
                )
            }
            guard decision.alternatives.contains(where: { $0.id == direct.id }) == false else {
                return KernelPhase1TestResult(
                    name: "decision_generation",
                    passed: false,
                    detail: "direct slot leaked into alternatives"
                )
            }
        }

        return KernelPhase1TestResult(
            name: "decision_generation",
            passed: true,
            detail: "ranked=\(decision.rankedCandidates.count) direct=\(decision.hasDirectSlot) alt=\(decision.alternatives.count) reasons=\(decision.reasonCodes.count) suppress=\(decision.suppressionReasons.count)"
        )
    }

    // MARK: - Test 2: action card coverage for every object type

    static func testCardMappingCoverage() -> KernelPhase1TestResult {
        let fixturesByType: [ActionCardType: UnifiedMatchingCandidate] = [
            .place: fixtureCandidate(id: "fx-place", kind: .place, surface: .maps),
            .route: fixtureCandidate(id: "fx-route", kind: .route, surface: .maps),
            .song: fixtureCandidate(id: "fx-song", kind: .song, surface: .music),
            .video: fixtureCandidate(id: "fx-video", kind: .video, surface: .video),
            .searchResult: fixtureCandidate(id: "fx-search", kind: .searchResult, surface: .chat),
            .answerCard: fixtureCandidate(id: "fx-answer", kind: .answerCard, surface: .chat),
            .toolEntry: fixtureCandidate(id: "fx-tool", kind: .toolEntry, surface: .ai),
            .serviceEntry: fixtureCandidate(id: "fx-service", kind: .contact, surface: .chat),
        ]

        for (expectedType, candidate) in fixturesByType {
            let recommendation = UnifiedMatchRecommendation(
                candidate: candidate,
                breakdown: fixtureBreakdown(),
                package: MatchingRecommendationPackage(
                    style: .directPrompt,
                    ctaTitle: "Use",
                    prompt: "fixture"
                ),
                rank: 1
            )

            let card = ActionCardMapper.map(
                recommendation: recommendation,
                reasonCodes: [.promptMatch],
                policyVersion: .current
            )

            guard card.cardType == expectedType else {
                return KernelPhase1TestResult(
                    name: "card_mapping_coverage",
                    passed: false,
                    detail: "\(candidate.objectKind.rawValue) -> \(card.cardType.rawValue), expected \(expectedType.rawValue)"
                )
            }
            guard card.title.isEmpty == false else {
                return KernelPhase1TestResult(
                    name: "card_mapping_coverage",
                    passed: false,
                    detail: "\(expectedType.rawValue) card has empty title"
                )
            }
            guard card.primaryAction.title.isEmpty == false else {
                return KernelPhase1TestResult(
                    name: "card_mapping_coverage",
                    passed: false,
                    detail: "\(expectedType.rawValue) card has empty primary action"
                )
            }
            guard card.candidateId == candidate.id else {
                return KernelPhase1TestResult(
                    name: "card_mapping_coverage",
                    passed: false,
                    detail: "\(expectedType.rawValue) card candidateId mismatch"
                )
            }
            guard card.policyVersion == MatchingPolicyVersion.current.policyVersion else {
                return KernelPhase1TestResult(
                    name: "card_mapping_coverage",
                    passed: false,
                    detail: "\(expectedType.rawValue) card policyVersion mismatch"
                )
            }
        }

        return KernelPhase1TestResult(
            name: "card_mapping_coverage",
            passed: true,
            detail: "covered \(fixturesByType.count) card types"
        )
    }

    // MARK: - Test 3: feedback option coverage on every card

    static func testFeedbackOptionCoverage() -> KernelPhase1TestResult {
        let engine = UnifiedMatchingEngine()
        let decision = engine.decide(
            snapshot: makeFixtureSnapshot(prompt: "今晚附近吃什么"),
            limit: 4
        )

        guard Set(decision.feedbackOptions) == Set(FeedbackOption.allCases) else {
            return KernelPhase1TestResult(
                name: "feedback_option_coverage",
                passed: false,
                detail: "decision missing at least one FeedbackOption"
            )
        }

        let cards = ActionCardMapper.map(decision: decision, policyVersion: .current)
        guard cards.isEmpty == false else {
            return KernelPhase1TestResult(
                name: "feedback_option_coverage",
                passed: false,
                detail: "no cards produced from decision"
            )
        }

        for card in cards {
            guard Set(card.feedbackActions) == Set(FeedbackOption.allCases) else {
                return KernelPhase1TestResult(
                    name: "feedback_option_coverage",
                    passed: false,
                    detail: "card \(card.id) missing FeedbackOption(s)"
                )
            }
        }

        return KernelPhase1TestResult(
            name: "feedback_option_coverage",
            passed: true,
            detail: "cards=\(cards.count) feedbackOptions=\(FeedbackOption.allCases.count)"
        )
    }

    // MARK: - Test 4: reason-code propagation from decision to card

    static func testReasonCodePropagation() -> KernelPhase1TestResult {
        let engine = UnifiedMatchingEngine()
        let decision = engine.decide(
            snapshot: makeFixtureSnapshot(prompt: "放一点专注音乐"),
            limit: 4
        )

        let cards = ActionCardMapper.map(decision: decision, policyVersion: .current)
        guard let directSlotId = decision.directSlotCandidateId else {
            guard cards.allSatisfy({ $0.reasonCodes.isEmpty }) else {
                return KernelPhase1TestResult(
                    name: "reason_code_propagation",
                    passed: false,
                    detail: "reasons leaked onto cards when no direct slot"
                )
            }
            return KernelPhase1TestResult(
                name: "reason_code_propagation",
                passed: true,
                detail: "no direct slot, no reason codes — correct"
            )
        }

        guard let directCard = cards.first(where: { $0.id == directSlotId }) else {
            return KernelPhase1TestResult(
                name: "reason_code_propagation",
                passed: false,
                detail: "no card for direct slot id \(directSlotId)"
            )
        }

        guard Set(directCard.reasonCodes) == Set(decision.reasonCodes) else {
            return KernelPhase1TestResult(
                name: "reason_code_propagation",
                passed: false,
                detail: "direct card reasons \(directCard.reasonCodes) != decision reasons \(decision.reasonCodes)"
            )
        }

        for card in cards where card.id != directSlotId {
            guard card.reasonCodes.isEmpty else {
                return KernelPhase1TestResult(
                    name: "reason_code_propagation",
                    passed: false,
                    detail: "non-direct card \(card.id) got reason codes \(card.reasonCodes)"
                )
            }
        }

        return KernelPhase1TestResult(
            name: "reason_code_propagation",
            passed: true,
            detail: "direct card reasons=\(directCard.reasonCodes.count) ranked=\(cards.count)"
        )
    }

    // MARK: - Fixtures

    private static func makeFixtureSnapshot(prompt: String) -> MatchingReplaySnapshot {
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let session = ChatSession(
            title: "decision-fixture",
            messages: [.user(text: prompt, timestamp: capturedAt.addingTimeInterval(-30))]
        )
        return MatchingReplaySnapshot(
            label: "decision-fixture-\(prompt)",
            recentPrompt: prompt,
            capturedAt: capturedAt,
            session: session,
            healthAvailability: .ready,
            locationState: .precise,
            motionContext: .stationary,
            activeSurface: .chat,
            returnContextState: nil,
            behaviorLog: []
        )
    }

    private static func fixtureCandidate(
        id: String,
        kind: MatchingObjectKind,
        surface: AppSection
    ) -> UnifiedMatchingCandidate {
        UnifiedMatchingCandidate(
            id: id,
            title: "\(kind.title) fixture",
            summary: "\(kind.title) summary",
            objectKind: kind,
            preferredSection: surface,
            activationPrompt: "Use \(kind.title)",
            tags: [.planning],
            sourcePool: "fixture",
            utilityProfile: MatchingUtilityProfile(
                goal: .taskCompletion,
                domainWeight: 0.5,
                nextStepWeight: 0.5
            )
        )
    }

    private static func fixtureBreakdown() -> MatchingScoreBreakdown {
        MatchingScoreBreakdown(
            globalEligibility: 0.8,
            domainUtility: 0.6,
            nextStepValue: 0.55,
            explorationBoost: 0.0,
            diversityPenalty: 0.0,
            finalScore: 0.62,
            confidence: 0.7,
            reasonCodes: [.eligibleNow],
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
                nextStepValue: 0.55,
                explorationBoost: 0.0,
                retrievalLift: 0.05,
                promptDirectnessBonus: 0.05,
                diversityPenalty: 0.0,
                promptLexical: 0.2,
                contextLexical: 0.0,
                phrase: 0.05,
                suppression: 0.0,
                finalScore: 0.62,
                policyVersion: MatchingPolicyVersion.current.scorerBaselineID
            )
        )
    }
}
