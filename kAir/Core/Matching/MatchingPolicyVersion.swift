//
//  MatchingPolicyVersion.swift
//  kAir
//
//  Single authoritative source for the shipped matching policy and its version identity.
//  UnifiedMatchingEngine and MatchingReplayEngine both read from here — no local hardcoding
//  of provider / scorer IDs or scoring weights allowed elsewhere in the kernel.
//

import Foundation

struct MatchingPolicyVersion: Codable, Hashable, Sendable {
    let policyVersion: String
    let providerBaselineID: String
    let scorerBaselineID: String
    let retrievalLiftWeight: Double
    let promptDirectnessWeight: Double
    let closedHypothesisFlags: [String: Bool]

    init(
        policyVersion: String,
        providerBaselineID: String,
        scorerBaselineID: String,
        retrievalLiftWeight: Double,
        promptDirectnessWeight: Double,
        closedHypothesisFlags: [String: Bool]
    ) {
        self.policyVersion = policyVersion
        self.providerBaselineID = providerBaselineID
        self.scorerBaselineID = scorerBaselineID
        self.retrievalLiftWeight = retrievalLiftWeight
        self.promptDirectnessWeight = promptDirectnessWeight
        self.closedHypothesisFlags = closedHypothesisFlags
    }

    init(artifact: MatchingKernelBaselineArtifact) {
        self.init(
            policyVersion: artifact.policyVersion,
            providerBaselineID: artifact.providerBaselineID,
            scorerBaselineID: artifact.scorerBaselineID,
            retrievalLiftWeight: artifact.retrievalLiftWeight,
            promptDirectnessWeight: artifact.promptDirectnessWeight,
            closedHypothesisFlags: artifact.closedHypothesisFlags
        )
    }

    static let current = MatchingPolicyVersion(
        artifact: MatchingKernelBaseline.current
    )

    static let providerBaseline = MatchingPolicyVersion(
        policyVersion: "provider-baseline-v4",
        providerBaselineID: "retrieval-provider-v4-query-hardening",
        scorerBaselineID: "heuristic-scorer-v2.1-retrieval-lift",
        retrievalLiftWeight: 0.24,
        promptDirectnessWeight: 0,
        closedHypothesisFlags: [
            "prompt_directness_bonus": false,
            "context_lexical_patch": false,
            "weak_trace_bonus": false,
        ]
    )

    static let legacy = MatchingPolicyVersion(
        policyVersion: "legacy-v1",
        providerBaselineID: "default-matching-providers-v1",
        scorerBaselineID: "heuristic-scorer-v1",
        retrievalLiftWeight: 0,
        promptDirectnessWeight: 0,
        closedHypothesisFlags: [:]
    )
}
