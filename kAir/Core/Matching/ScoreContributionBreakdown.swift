//
//  ScoreContributionBreakdown.swift
//  kAir
//
//  Canonical structured score breakdown emitted for every scored candidate.
//  All scoring policies must populate this payload so replay, residual accounting,
//  and direct-slot audits read from one machine-readable contract.
//

import Foundation

struct ScoreContributionBreakdown: Codable, Hashable, Sendable {
    let globalEligibility: Double
    let domainUtility: Double
    let nextStepValue: Double
    let explorationBoost: Double
    let retrievalLift: Double
    let promptDirectnessBonus: Double
    let diversityPenalty: Double
    let promptLexical: Double
    let contextLexical: Double
    let phrase: Double
    let suppression: Double
    let finalScore: Double
    let policyVersion: String

    static let zero = ScoreContributionBreakdown(
        globalEligibility: 0,
        domainUtility: 0,
        nextStepValue: 0,
        explorationBoost: 0,
        retrievalLift: 0,
        promptDirectnessBonus: 0,
        diversityPenalty: 0,
        promptLexical: 0,
        contextLexical: 0,
        phrase: 0,
        suppression: 0,
        finalScore: 0,
        policyVersion: ""
    )

    func applyingDiversityPenalty(_ penalty: Double) -> ScoreContributionBreakdown {
        ScoreContributionBreakdown(
            globalEligibility: globalEligibility,
            domainUtility: domainUtility,
            nextStepValue: nextStepValue,
            explorationBoost: explorationBoost,
            retrievalLift: retrievalLift,
            promptDirectnessBonus: promptDirectnessBonus,
            diversityPenalty: penalty,
            promptLexical: promptLexical,
            contextLexical: contextLexical,
            phrase: phrase,
            suppression: suppression,
            finalScore: max(0, finalScore - penalty),
            policyVersion: policyVersion
        )
    }
}
