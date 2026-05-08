//
//  RecommendationFixtures.swift
//  kAir
//
//  Sample MatchingObject instances and slates for previews and tests.
//  Covers the 9 object kinds and the layout states (absent / single /
//  dual / triple) per Contracts/UX/mixed-recommendation-rail-visual-v1.md
//  §4.
//
//  Trust-pill assignments for these fixtures live in the UI-side
//  adapter `ActionCardTrustPillResolver.fixturePills`; the domain
//  `MatchingObject` does not carry pill data.
//

import Foundation

enum RecommendationFixtures {
    // MARK: - Single objects (one per kind, where useful)

    static let placeRoute = MatchingObject(
        id: "place-pier-7",
        kind: .place,
        title: "Pier 7",
        subtitleTokens: ["1.4 mi", "Café"],
        reasonText: "Matches your morning pattern",
        primaryCTA: "Open in Maps",
        secondaryCTA: "Save for later"
    )

    static let placeWithTrustPills = MatchingObject(
        id: "place-pier-7-trusted",
        kind: .place,
        title: "Pier 7",
        subtitleTokens: ["1.4 mi", "Café"],
        reasonText: "Matches your morning pattern",
        primaryCTA: "Open in Maps",
        secondaryCTA: "Save for later"
    )

    static let routeBay = MatchingObject(
        id: "route-bay",
        kind: .route,
        title: "Route to Pier 7",
        subtitleTokens: ["12 min", "Walking"],
        reasonText: "Calmer than the direct route",
        primaryCTA: "Start route",
        secondaryCTA: nil
    )

    static let songSunset = MatchingObject(
        id: "song-sunset-drive",
        kind: .song,
        title: "Sunset Drive",
        subtitleTokens: ["Aurora Skies", "3:42"],
        reasonText: "From your focus mix",
        primaryCTA: "Play",
        secondaryCTA: "Queue"
    )

    static let videoTutorial = MatchingObject(
        id: "video-swiftui-101",
        kind: .video,
        title: "SwiftUI 101: layouts",
        subtitleTokens: ["7 min", "Tutorial"],
        reasonText: "Picks up where you left off",
        primaryCTA: "Watch",
        secondaryCTA: nil
    )

    static let answerCard = MatchingObject(
        id: "answer-spo2-trend",
        kind: .answerCard,
        title: "Your SpO₂ trended up this week",
        subtitleTokens: ["AI-synthesized", "1-paragraph"],
        reasonText: "Based on the last 7 days of data",
        primaryCTA: "Read",
        secondaryCTA: "Open Health"
    )

    static let searchResult = MatchingObject(
        id: "search-apple-news",
        kind: .searchResult,
        title: "Apple announces design updates",
        subtitleTokens: ["apple.com", "2 days ago"],
        reasonText: nil,
        primaryCTA: "Open",
        secondaryCTA: nil
    )

    static let toolEntryHealth = MatchingObject(
        id: "tool-health",
        kind: .toolEntry,
        title: "Health workspace",
        subtitleTokens: ["Health", "Used this morning"],
        reasonText: nil,
        primaryCTA: "Open",
        secondaryCTA: nil
    )

    static let threadPriorChat = MatchingObject(
        id: "thread-prior",
        kind: .thread,
        title: "Last week's planning thread",
        subtitleTokens: ["Last msg Tue"],
        reasonText: nil,
        primaryCTA: "Continue",
        secondaryCTA: nil
    )

    static let contactCoworker = MatchingObject(
        id: "contact-alex",
        kind: .contact,
        title: "Alex Chen",
        subtitleTokens: ["Coworker", "Last msg Mon"],
        reasonText: nil,
        primaryCTA: "Message",
        secondaryCTA: nil
    )

    // MARK: - Slates (V2 §4.2)

    static let absentSlate: [MatchingObject] = []

    static let singleSlate: [MatchingObject] = [placeRoute]

    static let dualSlate: [MatchingObject] = [placeRoute, songSunset]

    static let tripleSlate: [MatchingObject] = [placeRoute, songSunset, answerCard]

    /// Mixed-kind triple — exercises the no-grouping rule (V2 §8 / behavior §2.4).
    static let mixedTripleSlate: [MatchingObject] = [routeBay, videoTutorial, threadPriorChat]

    /// Triple with the direct slot carrying trust pills and the
    /// alternatives without — exercises V2 §5.2 rule (3) "alternatives
    /// may not reduce information density." Both render through the
    /// same shell; the alternatives simply have no pills registered in
    /// `ActionCardTrustPillResolver.fixturePills`, not by view-tree
    /// downgrade.
    static let trustPillTripleSlate: [MatchingObject] = [
        placeWithTrustPills,
        songSunset,
        answerCard
    ]
}
