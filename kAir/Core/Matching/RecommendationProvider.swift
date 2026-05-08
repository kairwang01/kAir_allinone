//
//  RecommendationProvider.swift
//  kAir
//
//  Provider abstraction for the Recommended Next slate.
//
//  I2.5 ships a fixed stub. Real ranking / retrieval / scoring lands in
//  a later PR; the protocol exists so consumers (ChatStore) can be
//  wired today without depending on the eventual implementation.
//

import Foundation

protocol RecommendationProvider {
    /// Returns the current Recommended Next slate.
    /// Behavior contract: ≤ 3 cards (mixed-recommendation-layout-v1 §3),
    /// trimmed at the provider level so the rail never has to clip.
    func recommendedMatches() -> [MatchingObject]
}

/// Fixed-slate provider used to prove the I2.5 wiring without
/// introducing scoring. Returns the curated triple-slate fixture.
final class StubRecommendationProvider: RecommendationProvider {
    func recommendedMatches() -> [MatchingObject] {
        return RecommendationFixtures.tripleSlate
    }
}

/// Always returns an empty slate. Used by tests that need to verify
/// the "absent rail" path (V2 §3) without manipulating state.
final class EmptyRecommendationProvider: RecommendationProvider {
    func recommendedMatches() -> [MatchingObject] {
        return []
    }
}
