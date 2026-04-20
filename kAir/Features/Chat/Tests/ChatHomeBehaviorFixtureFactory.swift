//
//  ChatHomeBehaviorFixtureFactory.swift
//  kAir
//
//  Shared fixture factory for the T10b / T11b / T12b shell-behavior test
//  suites. Builds the minimum viable `UnifiedMatchRecommendation` needed
//  to seed `ChatStore.recommendedMatches` without invoking the full
//  matcher pipeline. Every fixture is pure-value construction — no
//  replay engine, no scorer, no provider.
//
//  Why a shared factory:
//    - Post-return, negative-feedback, and mixed-layout tests all need
//      to put a card on the rail and then observe what happens. Each
//      needs the same neutral-baseline recommendation; duplicating that
//      construction in three files would guarantee drift.
//    - A single file means when the matcher adds a required field to
//      `UnifiedMatchingCandidate`, one place updates, not three.
//
//  This file follows the review-only-isolation rule used by the rest of
//  the shell branch: it references matcher types (`UnifiedMatchingCandidate`,
//  `MatchingScoreBreakdown`, etc.) that land with the matching PR. It
//  will not build standalone.
//

import Foundation

@MainActor
struct ChatHomeBehaviorFixtureFactory {
    static let shared = ChatHomeBehaviorFixtureFactory()

    func makeRecommendation(
        kind: MatchingObjectKind,
        id: String,
        preferredSection: AppSection? = nil,
        rank: Int = 0
    ) -> UnifiedMatchRecommendation {
        let section = preferredSection ?? defaultSection(for: kind)
        let candidate = UnifiedMatchingCandidate(
            id: id,
            title: "Fixture \(kind.rawValue)",
            summary: "Fixture summary for \(kind.rawValue)",
            objectKind: kind,
            preferredSection: section,
            activationPrompt: "open fixture \(kind.rawValue)",
            tags: [],
            sourcePool: "fixture.\(kind.rawValue)",
            utilityProfile: MatchingUtilityProfile(
                goal: .taskCompletion,
                domainWeight: 0.5,
                nextStepWeight: 0.5
            )
        )
        let breakdown = MatchingScoreBreakdown(
            globalEligibility: 0.5,
            domainUtility: 0.5,
            nextStepValue: 0.5,
            explorationBoost: 0.0,
            diversityPenalty: 0.0,
            finalScore: 0.5,
            confidence: 0.5,
            reasonCodes: [.lowFrictionAction],
            debugPayload: MatchingScoringDebugPayload(
                userFeatureKeys: [],
                contextFeatureKeys: [],
                candidateFeatureKeys: [],
                interactionFeatureKeys: [],
                fatigueFeatureKeys: [],
                retrievalMetadata: [],
                policyVersion: "fixture"
            ),
            contribution: ScoreContributionBreakdown.zero
        )
        let package = MatchingRecommendationPackage(
            style: .directPrompt,
            ctaTitle: "Open",
            prompt: "open fixture \(kind.rawValue)"
        )
        return UnifiedMatchRecommendation(
            candidate: candidate,
            breakdown: breakdown,
            package: package,
            rank: rank
        )
    }

    /// The default AppSection for a given object kind — mirrors the
    /// mapping used in production without importing the matcher's
    /// surface-routing logic. Keeping this local means a fixture change
    /// in the matcher does not propagate here silently.
    private func defaultSection(for kind: MatchingObjectKind) -> AppSection {
        switch kind {
        case .place, .route:
            return .maps
        case .song:
            return .music
        case .video:
            return .video
        case .searchResult, .answerCard:
            return .chat // Search surface is not yet its own AppSection — v1+ per spec §1.2.
        case .contact, .thread:
            return .chat
        case .toolEntry:
            return .ai
        }
    }
}
