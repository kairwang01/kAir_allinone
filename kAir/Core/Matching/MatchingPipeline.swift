//
//  MatchingPipeline.swift
//  kAir
//
//  Explicit pipeline contracts for the unified matching layer.
//

import Foundation

protocol CandidateProvider {
    var id: String { get }
    var versionID: String { get }
    func generateCandidates(for context: MatchingFeatureContext) -> [UnifiedMatchingCandidate]
}

protocol ConstraintEvaluator {
    var versionID: String { get }
    func evaluate(
        candidate: UnifiedMatchingCandidate,
        in context: MatchingFeatureContext
    ) -> MatchingConstraintDecision
}

protocol ScoringPolicy {
    var versionID: String { get }
    func score(
        candidate: UnifiedMatchingCandidate,
        constraintDecision: MatchingConstraintDecision,
        scoringInput: MatchingScoringInput,
        in context: MatchingFeatureContext
    ) -> MatchingScoreBreakdown
}

protocol Diversifier {
    var versionID: String { get }
    func diversify(
        scoredCandidates: [ScoredMatchCandidate],
        in context: MatchingFeatureContext,
        limit: Int
    ) -> [ScoredMatchCandidate]
}

protocol RecommendationComposer {
    var versionID: String { get }
    func compose(
        scoredCandidates: [ScoredMatchCandidate],
        in context: MatchingFeatureContext
    ) -> [UnifiedMatchRecommendation]
}

struct ScoredMatchCandidate: Hashable {
    let candidate: UnifiedMatchingCandidate
    let constraintDecision: MatchingConstraintDecision
    let breakdown: MatchingScoreBreakdown
}

struct DefaultConstraintEvaluator: ConstraintEvaluator {
    let versionID = "constraint-v1"

    func evaluate(
        candidate: UnifiedMatchingCandidate,
        in context: MatchingFeatureContext
    ) -> MatchingConstraintDecision {
        var reasonCodes: [MatchingReasonCode] = []
        var score = 1.0

        switch candidate.retrieval.availability {
        case .unavailable:
            return MatchingConstraintDecision(
                isEligible: false,
                eligibilityScore: 0,
                reasonCodes: []
            )
        case .limited:
            score -= 0.16
            reasonCodes.append(.limitedAvailability)
        case .available:
            break
        }

        if candidate.constraints.requiredAnyTags.isEmpty == false,
           candidate.constraints.requiredAnyTags.isDisjoint(with: context.sessionIntentTags.union(context.recencyTags)) {
            return MatchingConstraintDecision(
                isEligible: false,
                eligibilityScore: 0,
                reasonCodes: []
            )
        }

        if candidate.constraints.blockedTags.isDisjoint(with: context.sessionIntentTags.union(context.recencyTags)) == false {
            score -= 0.35
            reasonCodes.append(.rejectionPenalty)
        }

        if let allowedDayparts = candidate.constraints.allowedDayparts,
           allowedDayparts.contains(context.daypart) == false {
            return MatchingConstraintDecision(
                isEligible: false,
                eligibilityScore: 0,
                reasonCodes: []
            )
        }

        if let requiredHealthAvailability = candidate.constraints.requiredHealthAvailability,
           requiredHealthAvailability != context.healthAvailability {
            return MatchingConstraintDecision(
                isEligible: false,
                eligibilityScore: 0,
                reasonCodes: []
            )
        }

        if let requiredLocationStates = candidate.constraints.requiredLocationStates,
           requiredLocationStates.contains(context.locationState) == false {
            return MatchingConstraintDecision(
                isEligible: false,
                eligibilityScore: 0,
                reasonCodes: []
            )
        }

        reasonCodes.append(.eligibleNow)

        if context.healthAvailability == .ready,
           candidate.tags.contains(.health) {
            reasonCodes.append(.healthReady)
        }

        if candidate.constraints.allowedDayparts?.contains(context.daypart) == true {
            reasonCodes.append(.timeOfDayFit)
        }

        return MatchingConstraintDecision(
            isEligible: true,
            eligibilityScore: max(0, min(1, score)),
            reasonCodes: uniqueReasonCodes(reasonCodes)
        )
    }
}

struct HeuristicScoringPolicy: ScoringPolicy {
    let versionID: String

    // Scorer-only patch: add one direct-slot recovery term to finalScore.
    // Nothing else changes: provider output, domainUtility, nextStepValue, explorationBoost,
    // and downstream composition all stay untouched.
    private let retrievalLiftWeight: Double
    private let promptDirectnessWeight: Double

    init(policy: MatchingPolicyVersion) {
        self.retrievalLiftWeight = policy.retrievalLiftWeight
        self.promptDirectnessWeight = policy.promptDirectnessWeight
        self.versionID = policy.scorerBaselineID
    }

    init(
        retrievalLiftWeight: Double = MatchingPolicyVersion.current.retrievalLiftWeight,
        promptDirectnessWeight: Double = 0
    ) {
        self.retrievalLiftWeight = retrievalLiftWeight
        self.promptDirectnessWeight = promptDirectnessWeight
        if promptDirectnessWeight > 0 {
            versionID = MatchingPolicyVersion.current.scorerBaselineID
        } else {
            versionID = MatchingPolicyVersion.providerBaseline.scorerBaselineID
        }
    }

    func score(
        candidate: UnifiedMatchingCandidate,
        constraintDecision: MatchingConstraintDecision,
        scoringInput: MatchingScoringInput,
        in context: MatchingFeatureContext
    ) -> MatchingScoreBreakdown {
        let sessionTags = context.sessionIntentTags
        let recencyTags = context.recencyTags
        let longTermTags = context.longTermTags
        let allContextTags = sessionTags.union(recencyTags)

        var reasonCodes = constraintDecision.reasonCodes

        let globalEligibility = constraintDecision.eligibilityScore

        let domainSignalCount = Double(candidate.tags.intersection(longTermTags).count)
        let objectAffinity = context.objectTypeAffinity[candidate.objectKind, default: 0.35]
        let objectFatigue = context.objectTypeFatigue[candidate.objectKind, default: 0]
        var domainUtility = 0.16 +
            candidate.utilityProfile.domainWeight * 0.36 +
            domainSignalCount * 0.14 +
            objectAffinity * 0.2 +
            candidate.retrieval.retrievalScore * 0.14

        if let freshnessHours = candidate.retrieval.freshnessHours, freshnessHours <= 8 {
            domainUtility += 0.04
        }

        if candidate.tags.isDisjoint(with: longTermTags) == false {
            reasonCodes.append(.recentPositiveSignal)
        }

        if candidate.tags.isDisjoint(with: allContextTags) == false {
            domainUtility += 0.16
            reasonCodes.append(.sessionIntentMatch)
        }

        var nextStepValue = 0.18 + candidate.utilityProfile.nextStepWeight * 0.45
        let transitionMomentum = candidate.preferredSection.map { section in
            min(0.16, Double(context.crossSurfaceTransitions[section, default: 0]) * 0.08)
        } ?? 0

        if candidate.preferredSection != nil {
            nextStepValue += 0.12
            reasonCodes.append(.lowFrictionAction)
        }

        nextStepValue += transitionMomentum

        if candidate.tags.contains(.navigation),
           allContextTags.contains(.planning) || allContextTags.contains(.localDiscovery) {
            nextStepValue += 0.18
            reasonCodes.append(.routeContinuation)
        }

        if candidate.tags.contains(.search),
           context.messageCount > 2 {
            nextStepValue += 0.12
            reasonCodes.append(.searchContinuation)
        }

        let hasContinuationCode = reasonCodes.contains(.routeContinuation) || reasonCodes.contains(.searchContinuation) || reasonCodes.contains(.lowFrictionAction)
        let lastActionWasDismiss = context.behaviorLog.last?.stage == .dismiss || context.behaviorLog.last?.stage == .abandon
        if context.messageCount >= 4,
           let preferred = candidate.preferredSection,
           preferred != context.activeSurface,
           hasContinuationCode,
           !lastActionWasDismiss {
             nextStepValue += 0.12
        }

        if context.motionContext == .driving,
           candidate.tags.contains(.commute) || candidate.tags.contains(.navigation) {
            nextStepValue += 0.1
            reasonCodes.append(.lowFrictionAction)
        }

        if context.motionContext == .walking {
            if candidate.tags.contains(.localDiscovery) || candidate.objectKind == .song {
                nextStepValue += 0.12
                reasonCodes.append(.lowFrictionAction)
            }
            if candidate.objectKind == .video {
                nextStepValue -= 0.20
            }
        }

        if candidate.constraints.allowedDayparts?.contains(context.daypart) == true {
            nextStepValue += 0.12
            if context.daypart == .night && (candidate.tags.contains(.relaxation) || candidate.tags.contains(.entertainment) || candidate.tags.contains(.health)) {
                domainUtility += 0.15
            }
        }

        if let recentFeedback = context.recentFeedbackByCandidate[candidate.id] {
            switch recentFeedback {
            case .dismiss:
                domainUtility -= 0.28
                nextStepValue -= 0.22
                reasonCodes.append(.rejectionPenalty)
            case .notInterested:
                domainUtility -= 0.34
                nextStepValue -= 0.28
                reasonCodes.append(.rejectionPenalty)
            case .lessLikeThis:
                domainUtility -= 0.24
                nextStepValue -= 0.16
                reasonCodes.append(.fatiguePenalty)
            case .notNow:
                nextStepValue -= 0.26
                reasonCodes.append(.rejectionPenalty)
            case .alreadyDone:
                domainUtility -= 0.22
                nextStepValue -= 0.36
                reasonCodes.append(.alreadyHandled)
            }
        } else if context.recentRejectedCandidateIDs.contains(candidate.id) {
            domainUtility -= 0.28
            nextStepValue -= 0.22
            reasonCodes.append(.rejectionPenalty)
        }

        if context.recentCompletedCandidateIDs.contains(candidate.id) {
            domainUtility -= 0.18
            nextStepValue -= 0.34
            reasonCodes.append(.alreadyHandled)
        }

        if objectFatigue > 0 {
            domainUtility -= objectFatigue * 0.18
            nextStepValue -= objectFatigue * 0.12
            reasonCodes.append(.fatiguePenalty)
        }

        let explorationBoost = explorationBoost(for: candidate, in: context, reasonCodes: &reasonCodes)
        let diversityPenalty = 0.0
        let confidence = confidence(
            for: candidate,
            in: context,
            scoringInput: scoringInput
        )

        let retrievalLift = candidate.retrieval.retrievalScore * retrievalLiftWeight
        let promptLexical = promptLexicalContribution(for: candidate)
        let phrase = phraseContribution(for: candidate)
        let suppression = suppressionPenalty(for: candidate)
        let promptDirectnessBonus = max(
            0,
            promptLexical + phrase - suppression
        ) * promptDirectnessWeight
        let finalScore = max(
            0,
            globalEligibility * 0.34 +
                domainUtility * 0.28 +
                nextStepValue * 0.28 +
                explorationBoost * 0.1 +
                retrievalLift +
                promptDirectnessBonus -
                diversityPenalty
        )

        let clampedGlobal = max(0, min(1, globalEligibility))
        let clampedDomain = max(0, min(1, domainUtility))
        let clampedNextStep = max(0, min(1, nextStepValue))

        let contribution = ScoreContributionBreakdown(
            globalEligibility: clampedGlobal,
            domainUtility: clampedDomain,
            nextStepValue: clampedNextStep,
            explorationBoost: explorationBoost,
            retrievalLift: retrievalLift,
            promptDirectnessBonus: promptDirectnessBonus,
            diversityPenalty: diversityPenalty,
            promptLexical: promptLexical,
            contextLexical: 0,
            phrase: phrase,
            suppression: suppression,
            finalScore: finalScore,
            policyVersion: versionID
        )

        return MatchingScoreBreakdown(
            globalEligibility: clampedGlobal,
            domainUtility: clampedDomain,
            nextStepValue: clampedNextStep,
            explorationBoost: explorationBoost,
            diversityPenalty: diversityPenalty,
            finalScore: finalScore,
            confidence: confidence,
            reasonCodes: uniqueReasonCodes(reasonCodes),
            debugPayload: MatchingScoringDebugPayload(
                userFeatureKeys: scoringInput.userFeatures.map(\.key),
                contextFeatureKeys: scoringInput.contextFeatures.map(\.key),
                candidateFeatureKeys: scoringInput.candidateFeatures.map(\.key),
                interactionFeatureKeys: scoringInput.interactionFeatures.map(\.key),
                fatigueFeatureKeys: scoringInput.fatigueFeatures.map(\.key),
                retrievalMetadata: candidate.retrieval.metadata,
                policyVersion: versionID
            ),
            contribution: contribution
        )
    }

    private func promptLexicalContribution(
        for candidate: UnifiedMatchingCandidate
    ) -> Double {
        metadataValue("prompt_lexical_score", from: candidate) * 0.42 +
            metadataValue("tag_overlap", from: candidate) * 0.24
    }

    private func phraseContribution(
        for candidate: UnifiedMatchingCandidate
    ) -> Double {
        metadataValue("phrase_score", from: candidate) * 0.14
    }

    private func suppressionPenalty(
        for candidate: UnifiedMatchingCandidate
    ) -> Double {
        metadataValue("suppression_penalty", from: candidate)
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

    private func confidence(
        for candidate: UnifiedMatchingCandidate,
        in context: MatchingFeatureContext,
        scoringInput: MatchingScoringInput
    ) -> Double {
        let supportingSignals = Double(candidate.tags.intersection(context.sessionIntentTags.union(context.longTermTags)).count)
        let featureCoverage = Double(
            scoringInput.userFeatures.count +
                scoringInput.contextFeatures.count +
                scoringInput.candidateFeatures.count
        )

        return min(
            0.96,
            max(
                0.28,
                0.28 +
                    candidate.retrieval.retrievalScore * 0.24 +
                    supportingSignals * 0.08 +
                    min(featureCoverage, 8) * 0.03
            )
        )
    }

    private func explorationBoost(
        for candidate: UnifiedMatchingCandidate,
        in context: MatchingFeatureContext,
        reasonCodes: inout [MatchingReasonCode]
    ) -> Double {
        let priorImpressions = context.behaviorLog.filter {
            $0.candidateID == candidate.id && $0.stage == .impression
        }.count

        let priorPositiveActions = context.behaviorLog.filter {
            $0.candidateID == candidate.id &&
                ($0.stage == .click || $0.stage == .accept || $0.stage == .completion)
        }.count

        guard priorImpressions <= 1, priorPositiveActions == 0 else {
            return 0
        }

        reasonCodes.append(.explorationCandidate)
        return 0.14
    }
}

struct LegacyHeuristicScoringPolicy: ScoringPolicy {
    let versionID = "heuristic-scorer-v1"

    func score(
        candidate: UnifiedMatchingCandidate,
        constraintDecision: MatchingConstraintDecision,
        scoringInput _: MatchingScoringInput,
        in context: MatchingFeatureContext
    ) -> MatchingScoreBreakdown {
        let allContextTags = context.sessionIntentTags.union(context.recencyTags)
        var reasonCodes = constraintDecision.reasonCodes

        var domainUtility = 0.2 +
            candidate.utilityProfile.domainWeight * 0.34 +
            context.objectTypeAffinity[candidate.objectKind, default: 0.3] * 0.16

        if candidate.tags.isDisjoint(with: context.longTermTags) == false {
            domainUtility += 0.12
            reasonCodes.append(.recentPositiveSignal)
        }

        if candidate.tags.isDisjoint(with: allContextTags) == false {
            domainUtility += 0.1
            reasonCodes.append(.sessionIntentMatch)
        }

        var nextStepValue = 0.24 + candidate.utilityProfile.nextStepWeight * 0.42
        if candidate.preferredSection != nil {
            nextStepValue += 0.08
            reasonCodes.append(.lowFrictionAction)
        }

        if candidate.constraints.allowedDayparts?.contains(context.daypart) == true {
            nextStepValue += 0.05
            reasonCodes.append(.timeOfDayFit)
        }

        let explorationBoost = 0.04
        let finalScore = max(
            0,
            constraintDecision.eligibilityScore * 0.4 +
                domainUtility * 0.28 +
                nextStepValue * 0.26 +
                explorationBoost * 0.06
        )

        let clampedGlobal = max(0, min(1, constraintDecision.eligibilityScore))
        let clampedDomain = max(0, min(1, domainUtility))
        let clampedNextStep = max(0, min(1, nextStepValue))

        let contribution = ScoreContributionBreakdown(
            globalEligibility: clampedGlobal,
            domainUtility: clampedDomain,
            nextStepValue: clampedNextStep,
            explorationBoost: explorationBoost,
            retrievalLift: 0,
            promptDirectnessBonus: 0,
            diversityPenalty: 0,
            promptLexical: 0,
            contextLexical: 0,
            phrase: 0,
            suppression: 0,
            finalScore: finalScore,
            policyVersion: versionID
        )

        return MatchingScoreBreakdown(
            globalEligibility: clampedGlobal,
            domainUtility: clampedDomain,
            nextStepValue: clampedNextStep,
            explorationBoost: explorationBoost,
            diversityPenalty: 0,
            finalScore: finalScore,
            confidence: min(0.82, max(0.3, 0.3 + candidate.utilityProfile.domainWeight * 0.24)),
            reasonCodes: uniqueReasonCodes(reasonCodes),
            debugPayload: MatchingScoringDebugPayload(
                userFeatureKeys: [],
                contextFeatureKeys: [],
                candidateFeatureKeys: [],
                interactionFeatureKeys: [],
                fatigueFeatureKeys: [],
                retrievalMetadata: candidate.retrieval.metadata,
                policyVersion: versionID
            ),
            contribution: contribution
        )
    }
}

struct HeuristicDiversifier: Diversifier {
    let versionID = "diversifier-v1"

    func diversify(
        scoredCandidates: [ScoredMatchCandidate],
        in _: MatchingFeatureContext,
        limit: Int
    ) -> [ScoredMatchCandidate] {
        var selected: [ScoredMatchCandidate] = []
        var seenObjectKinds: [MatchingObjectKind: Int] = [:]
        var seenSources: [String: Int] = [:]
        var seenSemanticKeys: Set<String> = []

        for candidate in scoredCandidates.sorted(by: { $0.breakdown.finalScore > $1.breakdown.finalScore }) {
            let objectKindCount = seenObjectKinds[candidate.candidate.objectKind, default: 0]
            let sourceCount = seenSources[candidate.candidate.sourcePool, default: 0]

            if seenSemanticKeys.contains(candidate.candidate.semanticKey) {
                continue
            }

            if objectKindCount >= 2 || sourceCount >= 2 {
                continue
            }

            var reasonCodes = candidate.breakdown.reasonCodes
            if objectKindCount > 0 || sourceCount > 0 {
                reasonCodes.append(.diversifiedMix)
            }

            let appliedPenalty = objectKindCount > 0 || sourceCount > 0 ? 0.05 : 0
            let diversified = ScoredMatchCandidate(
                candidate: candidate.candidate,
                constraintDecision: candidate.constraintDecision,
                breakdown: MatchingScoreBreakdown(
                    globalEligibility: candidate.breakdown.globalEligibility,
                    domainUtility: candidate.breakdown.domainUtility,
                    nextStepValue: candidate.breakdown.nextStepValue,
                    explorationBoost: candidate.breakdown.explorationBoost,
                    diversityPenalty: appliedPenalty,
                    finalScore: candidate.breakdown.finalScore - appliedPenalty,
                    confidence: candidate.breakdown.confidence,
                    reasonCodes: uniqueReasonCodes(reasonCodes),
                    debugPayload: candidate.breakdown.debugPayload,
                    contribution: candidate.breakdown.contribution.applyingDiversityPenalty(appliedPenalty)
                )
            )

            selected.append(diversified)
            seenObjectKinds[candidate.candidate.objectKind, default: 0] += 1
            seenSources[candidate.candidate.sourcePool, default: 0] += 1
            seenSemanticKeys.insert(candidate.candidate.semanticKey)

            if selected.count >= limit {
                break
            }
        }

        return selected
    }
}

struct DefaultRecommendationComposer: RecommendationComposer {
    let versionID = "composer-v1"

    func compose(
        scoredCandidates: [ScoredMatchCandidate],
        in _: MatchingFeatureContext
    ) -> [UnifiedMatchRecommendation] {
        scoredCandidates.enumerated().map { index, entry in
            UnifiedMatchRecommendation(
                candidate: entry.candidate,
                breakdown: entry.breakdown,
                package: recommendationPackage(for: entry.candidate),
                rank: index + 1
            )
        }
    }

    private func recommendationPackage(
        for candidate: UnifiedMatchingCandidate
    ) -> MatchingRecommendationPackage {
        if candidate.preferredSection == .music {
            return MatchingRecommendationPackage(
                style: .persistentPlayer,
                ctaTitle: "Start",
                prompt: candidate.activationPrompt
            )
        }

        if candidate.preferredSection != nil {
            return MatchingRecommendationPackage(
                style: .focusedSurface,
                ctaTitle: "Open",
                prompt: candidate.activationPrompt
            )
        }

        return MatchingRecommendationPackage(
            style: .directPrompt,
            ctaTitle: "Use",
            prompt: candidate.activationPrompt
        )
    }
}

private func uniqueReasonCodes(_ reasonCodes: [MatchingReasonCode]) -> [MatchingReasonCode] {
    var seen: Set<MatchingReasonCode> = []
    var ordered: [MatchingReasonCode] = []

    for reasonCode in reasonCodes where seen.insert(reasonCode).inserted {
        ordered.append(reasonCode)
    }

    return ordered
}
