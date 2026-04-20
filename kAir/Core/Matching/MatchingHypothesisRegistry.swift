//
//  MatchingHypothesisRegistry.swift
//  kAir
//
//  Explicit registry of shipped and closed matching hypotheses.
//  Replay and debug output cite this registry to distinguish what is active
//  from what is intentionally not active.
//

import Foundation

enum MatchingHypothesisStatus: String, Codable, Hashable, Sendable {
    case shipped
    case closed
}

struct MatchingHypothesis: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let title: String
    let status: MatchingHypothesisStatus
    let rationale: String
    let policyVersion: String

    var isShipped: Bool { status == .shipped }
    var isClosed: Bool { status == .closed }
}

enum MatchingHypothesisRegistry {
    static let all: [MatchingHypothesis] = [
        MatchingHypothesis(
            id: "prompt_directness_bonus",
            title: "Prompt directness scorer bonus (promptLexical + phrase − suppression) * 0.30",
            status: .shipped,
            rationale: "60/60 replay gate cleared; +11.7% direct-slot recovery; zero not-aligned regression.",
            policyVersion: MatchingPolicyVersion.current.policyVersion
        ),
        MatchingHypothesis(
            id: "retrieval_lift_weight",
            title: "Retrieval lift weight (0.24) on candidate retrieval score",
            status: .shipped,
            rationale: "Provider baseline clears replay gate with retrieval-score weighting.",
            policyVersion: MatchingPolicyVersion.current.policyVersion
        ),
        MatchingHypothesis(
            id: "context_lexical_patch",
            title: "Context-lexical patch on scorer contribution",
            status: .closed,
            rationale: "Closed per Phase 1 order. Must not be reopened without explicit assignment.",
            policyVersion: MatchingPolicyVersion.current.policyVersion
        ),
        MatchingHypothesis(
            id: "weak_trace_bonus",
            title: "Weak-trace rescue bonus on candidate scoring",
            status: .closed,
            rationale: "Weak-trace is not the next scorer patch target for Phase 1.",
            policyVersion: MatchingPolicyVersion.current.policyVersion
        ),
    ]

    static var shipped: [MatchingHypothesis] {
        all.filter { $0.status == .shipped }
    }

    static var closed: [MatchingHypothesis] {
        all.filter { $0.status == .closed }
    }

    static func hypothesis(withID id: String) -> MatchingHypothesis? {
        all.first { $0.id == id }
    }
}
