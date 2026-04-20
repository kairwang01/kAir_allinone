//
//  MatchingKernelBaseline.swift
//  kAir
//
//  Frozen Phase 1 closure baseline. Runtime, replay, and evidence generation
//  all read from this single artifact so the shipped kernel can be audited
//  without local hardcoded drift across layers.
//

import Foundation

struct MatchingKernelBaselineArtifact: Codable, Hashable, Sendable {
    let artifactVersion: String
    let policyVersion: String
    let providerBaselineID: String
    let scorerBaselineID: String
    let retrievalLiftWeight: Double
    let promptDirectnessWeight: Double
    let featureSchemaVersion: String
    let decisionSchemaVersion: String
    let eventSchemaVersion: String
    let replayExportSchemaVersion: String
    let closedHypothesisFlags: [String: Bool]
}

enum MatchingKernelBaseline {
    static let phase1Closure = MatchingKernelBaselineArtifact(
        artifactVersion: "phase1-closure-baseline-v1",
        policyVersion: "kernel-phase1-v1.0",
        providerBaselineID: "retrieval-provider-v4-query-hardening",
        scorerBaselineID: "heuristic-scorer-v2.2-prompt-directness",
        retrievalLiftWeight: 0.24,
        promptDirectnessWeight: 0.30,
        featureSchemaVersion: "matching-features-v1",
        decisionSchemaVersion: "recommendation-decision-v1",
        eventSchemaVersion: "matching-event-v1",
        replayExportSchemaVersion: "replay-export-v1",
        closedHypothesisFlags: [
            "context_lexical_patch": false,
            "weak_trace_bonus": false,
        ]
    )

    static let current = phase1Closure
}
