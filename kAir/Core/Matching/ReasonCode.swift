//
//  ReasonCode.swift
//  kAir
//
//  Decision-level reason codes attached to a RecommendationDecision and to
//  every Action Card. These sit above the internal `MatchingReasonCode` that
//  scorers emit — they describe the decision itself, not intermediate scoring
//  signals. The kernel derives ReasonCodes from score contributions,
//  suppression state, and surface/object context so Chat, Recommended Next,
//  and Action Cards read from one contract.
//

import Foundation

enum ReasonCode: String, Codable, CaseIterable, Hashable, Sendable {
    case promptMatch = "prompt_match"
    case contextMatch = "context_match"
    case phraseMatch = "phrase_match"
    case suppressedByDismiss = "suppressed_by_dismiss"
    case surfaceAffinity = "surface_affinity"
    case historyConflict = "history_conflict"
    case multiObjectAmbiguity = "multi_object_ambiguity"
    case lowTraceStrength = "low_trace_strength"

    var isPositive: Bool {
        switch self {
        case .promptMatch, .contextMatch, .phraseMatch, .surfaceAffinity:
            return true
        case .suppressedByDismiss, .historyConflict, .multiObjectAmbiguity, .lowTraceStrength:
            return false
        }
    }

    var userFacingText: String {
        switch self {
        case .promptMatch:
            return "Matches your prompt"
        case .contextMatch:
            return "Fits the current context"
        case .phraseMatch:
            return "Matches a phrase you used"
        case .suppressedByDismiss:
            return "Suppressed because you dismissed similar suggestions"
        case .surfaceAffinity:
            return "Matches the surface you just used"
        case .historyConflict:
            return "Conflicts with your recent behavior"
        case .multiObjectAmbiguity:
            return "Ambiguous between several objects"
        case .lowTraceStrength:
            return "Weak signal from prompt and context"
        }
    }
}

enum ReasonCodeDeriver {
    static func derive(
        from breakdown: MatchingScoreBreakdown,
        candidate: UnifiedMatchingCandidate,
        context: MatchingFeatureContext
    ) -> [ReasonCode] {
        var codes: [ReasonCode] = []
        let c = breakdown.contribution

        if c.promptLexical > 0.08 {
            codes.append(.promptMatch)
        }
        if c.contextLexical > 0.02 {
            codes.append(.contextMatch)
        }
        if c.phrase > 0.02 {
            codes.append(.phraseMatch)
        }
        if let preferred = candidate.preferredSection,
           preferred == context.activeSurface || context.crossSurfaceTransitions[preferred, default: 0] > 0 {
            codes.append(.surfaceAffinity)
        }
        if breakdown.reasonCodes.contains(.rejectionPenalty) ||
           context.recentRejectedCandidateIDs.contains(candidate.id) {
            codes.append(.suppressedByDismiss)
        }
        if breakdown.reasonCodes.contains(.alreadyHandled) ||
           breakdown.reasonCodes.contains(.fatiguePenalty) {
            codes.append(.historyConflict)
        }
        if c.promptLexical <= 0.02, c.phrase <= 0.01, c.contextLexical <= 0.01 {
            codes.append(.lowTraceStrength)
        }

        return unique(codes)
    }

    static func deriveMultiObjectAmbiguity(
        from ranked: [UnifiedMatchRecommendation]
    ) -> Bool {
        guard ranked.count >= 2 else { return false }
        let topScore = ranked[0].breakdown.finalScore
        let runnerUp = ranked[1].breakdown.finalScore
        guard topScore > 0 else { return false }
        let closeScore = (topScore - runnerUp) / topScore < 0.05
        let differentKind = ranked[0].candidate.objectKind != ranked[1].candidate.objectKind
        return closeScore && differentKind
    }

    private static func unique(_ codes: [ReasonCode]) -> [ReasonCode] {
        var seen: Set<ReasonCode> = []
        var ordered: [ReasonCode] = []
        for code in codes where seen.insert(code).inserted {
            ordered.append(code)
        }
        return ordered
    }
}
