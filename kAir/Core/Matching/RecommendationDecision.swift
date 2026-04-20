//
//  RecommendationDecision.swift
//  kAir
//
//  Phase-1 decision-protocol output of the unified matching kernel.
//  The engine returns one `RecommendationDecision` per prompt. A decision
//  carries an explicit direct-slot candidate, the full ranked list, a
//  bounded alternative set, structured decision-level reason codes,
//  suppression reasons, feedback options, execution surface type, object
//  type, and the policy version that produced it.
//
//  Chat, Recommended Next, and Action Cards all read from this payload.
//

import Foundation

struct RecommendationDecision: Hashable, Sendable {
    let recommendationId: String
    let directSlotCandidate: UnifiedMatchRecommendation?
    let rankedCandidates: [UnifiedMatchRecommendation]
    let alternatives: [UnifiedMatchRecommendation]
    let reasonCodes: [ReasonCode]
    let suppressionReasons: [ReasonCode]
    let feedbackOptions: [FeedbackOption]
    let executionSurfaceType: AppSection
    let objectType: MatchingObjectKind?
    let policyVersion: MatchingPolicyVersion
    let generatedAt: Date

    static let schemaVersion = MatchingKernelBaseline.current.decisionSchemaVersion
}

extension RecommendationDecision {
    var hasDirectSlot: Bool { directSlotCandidate != nil }

    var directSlotCandidateId: String? { directSlotCandidate?.id }

    var alternativeIds: [String] { alternatives.map(\.id) }

    var rankedIds: [String] { rankedCandidates.map(\.id) }
}

enum RecommendationDecisionBuilder {
    static let directSlotScoreFloor: Double = 0.22
    static let alternativeCount: Int = 3

    static func build(
        recentPrompt: String?,
        activeSurface: AppSection,
        context: MatchingFeatureContext,
        scoredCandidates: [ScoredMatchCandidate],
        recommendations: [UnifiedMatchRecommendation],
        policyVersion: MatchingPolicyVersion,
        now: Date
    ) -> RecommendationDecision {
        let sortedScored = scoredCandidates.sorted { lhs, rhs in
            lhs.breakdown.finalScore > rhs.breakdown.finalScore
        }

        let directSlot: UnifiedMatchRecommendation? = {
            guard let top = recommendations.first else { return nil }
            guard top.breakdown.finalScore >= directSlotScoreFloor else { return nil }
            return top
        }()

        let alternatives: [UnifiedMatchRecommendation] = {
            guard recommendations.count > 1 else { return [] }
            return Array(recommendations.dropFirst().prefix(alternativeCount))
        }()

        let positiveCodes: [ReasonCode]
        let suppressionReasons: [ReasonCode]
        if let top = directSlot ?? recommendations.first {
            let derived = ReasonCodeDeriver.derive(
                from: top.breakdown,
                candidate: top.candidate,
                context: context
            )
            var positives: [ReasonCode] = []
            var negatives: [ReasonCode] = []
            for code in derived {
                if code.isPositive {
                    positives.append(code)
                } else {
                    negatives.append(code)
                }
            }
            if ReasonCodeDeriver.deriveMultiObjectAmbiguity(from: recommendations) {
                negatives.append(.multiObjectAmbiguity)
            }
            positiveCodes = positives
            suppressionReasons = negatives
        } else {
            positiveCodes = []
            suppressionReasons = suppressionReasonsFromDrops(sortedScored: sortedScored)
        }

        let objectType = (directSlot ?? recommendations.first)?.candidate.objectKind
        let executionSurface = (directSlot ?? recommendations.first)?
            .candidate
            .preferredSection ?? activeSurface

        let recommendationId = recommendationIdentifier(
            recentPrompt: recentPrompt,
            activeSurface: activeSurface,
            now: now
        )

        return RecommendationDecision(
            recommendationId: recommendationId,
            directSlotCandidate: directSlot,
            rankedCandidates: recommendations,
            alternatives: alternatives,
            reasonCodes: positiveCodes,
            suppressionReasons: suppressionReasons,
            feedbackOptions: FeedbackOption.allCases,
            executionSurfaceType: executionSurface,
            objectType: objectType,
            policyVersion: policyVersion,
            generatedAt: now
        )
    }

    private static func suppressionReasonsFromDrops(
        sortedScored: [ScoredMatchCandidate]
    ) -> [ReasonCode] {
        guard let top = sortedScored.first else { return [.lowTraceStrength] }
        let c = top.breakdown.contribution
        if c.promptLexical <= 0.02, c.phrase <= 0.01, c.contextLexical <= 0.01 {
            return [.lowTraceStrength]
        }
        return []
    }

    private static func recommendationIdentifier(
        recentPrompt: String?,
        activeSurface: AppSection,
        now: Date
    ) -> String {
        let promptHash = (recentPrompt ?? "").unicodeScalars
            .reduce(into: UInt64(5_381)) { partial, scalar in
                partial = partial &* 33 &+ UInt64(scalar.value)
            }
        let ts = UInt64(now.timeIntervalSince1970 * 1_000)
        return "rec-\(activeSurface.rawValue)-\(ts)-\(promptHash)"
    }
}
