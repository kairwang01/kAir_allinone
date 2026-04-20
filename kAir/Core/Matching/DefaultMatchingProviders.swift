//
//  DefaultMatchingProviders.swift
//  kAir
//
//  Heuristic candidate providers for the explicit matching pipeline.
//

import Foundation

struct MapsCandidateProvider: CandidateProvider {
    let id = "maps"
    let versionID = "maps-provider-v1"

    func generateCandidates(for context: MatchingFeatureContext) -> [UnifiedMatchingCandidate] {
        var candidates: [UnifiedMatchingCandidate] = [
            .init(
                id: "maps-quiet-dinner",
                title: "Quiet dinner spots",
                summary: "Recommend restaurants that fit conversation, parking, and budget constraints.",
                objectKind: .place,
                preferredSection: .maps,
                activationPrompt: "Find a quiet affordable place to meet with parking",
                tags: [.navigation, .localDiscovery, .planning, .social],
                sourcePool: "place_tower",
                semanticKey: "maps-dinner-planning",
                constraints: MatchingCandidateConstraints(
                    requiredAnyTags: [.navigation, .localDiscovery, .planning, .social]
                ),
                utilityProfile: MatchingUtilityProfile(
                    goal: .taskCompletion,
                    domainWeight: 0.84,
                    nextStepWeight: 0.9
                )
            ),
            .init(
                id: "maps-pharmacy",
                title: "Nearby pharmacy",
                summary: "Jump into live map search for a task-focused nearby place.",
                objectKind: .place,
                preferredSection: .maps,
                activationPrompt: "Find a nearby pharmacy",
                tags: [.navigation, .localDiscovery, .health],
                sourcePool: "place_tower",
                semanticKey: "maps-health-errand",
                constraints: MatchingCandidateConstraints(
                    requiredAnyTags: [.navigation, .localDiscovery, .health]
                ),
                utilityProfile: MatchingUtilityProfile(
                    goal: .taskCompletion,
                    domainWeight: 0.82,
                    nextStepWeight: 0.86
                )
            ),
            .init(
                id: "maps-route-compare",
                title: "Route and parking check",
                summary: "Compare routes first, then decide whether the destination is still worth it.",
                objectKind: .route,
                preferredSection: .maps,
                activationPrompt: "Compare routes and parking options for tonight",
                tags: [.navigation, .planning, .search, .commute],
                sourcePool: "route_tower",
                semanticKey: "maps-route-compare",
                constraints: MatchingCandidateConstraints(
                    requiredAnyTags: [.navigation, .planning, .commute]
                ),
                utilityProfile: MatchingUtilityProfile(
                    goal: .taskCompletion,
                    domainWeight: 0.88,
                    nextStepWeight: 0.94
                )
            ),
        ]

        if context.daypart == .evening || context.daypart == .night {
            candidates.append(
                .init(
                    id: "maps-evening-cafe",
                    title: "Evening cafe fallback",
                    summary: "A low-noise nearby fallback when a full dinner plan is too much friction.",
                    objectKind: .place,
                    preferredSection: .maps,
                    activationPrompt: "Show me a calm cafe nearby for tonight",
                    tags: [.navigation, .localDiscovery, .relaxation],
                    sourcePool: "place_tower",
                    semanticKey: "maps-evening-cafe",
                    constraints: MatchingCandidateConstraints(
                        requiredAnyTags: [.navigation, .localDiscovery, .relaxation],
                        allowedDayparts: [.evening, .night]
                    ),
                    utilityProfile: MatchingUtilityProfile(
                        goal: .sessionSatisfaction,
                        domainWeight: 0.73,
                        nextStepWeight: 0.76
                    )
                )
            )
        }

        return candidates
    }
}

struct MusicCandidateProvider: CandidateProvider {
    let id = "music"
    let versionID = "music-provider-v1"

    func generateCandidates(for context: MatchingFeatureContext) -> [UnifiedMatchingCandidate] {
        var candidates: [UnifiedMatchingCandidate] = [
            .init(
                id: "music-focus",
                title: "Focus soundtrack",
                summary: "Keep chat primary while the shell runs a focused background layer.",
                objectKind: .song,
                preferredSection: .music,
                activationPrompt: "Play focus music",
                tags: [.focus, .planning],
                sourcePool: "song_tower",
                semanticKey: "music-focus",
                constraints: MatchingCandidateConstraints(
                    requiredAnyTags: [.focus, .planning]
                ),
                utilityProfile: MatchingUtilityProfile(
                    goal: .sessionSatisfaction,
                    domainWeight: 0.8,
                    nextStepWeight: 0.66
                )
            ),
            .init(
                id: "music-commute",
                title: "Commute wind-down",
                summary: "Use current session state to choose a smoother drive-home sequence.",
                objectKind: .song,
                preferredSection: .music,
                activationPrompt: "Play a calm commute playlist",
                tags: [.relaxation, .commute, .planning],
                sourcePool: "song_tower",
                semanticKey: "music-commute",
                constraints: MatchingCandidateConstraints(
                    requiredAnyTags: [.commute, .planning, .relaxation]
                ),
                utilityProfile: MatchingUtilityProfile(
                    goal: .sessionSatisfaction,
                    domainWeight: 0.84,
                    nextStepWeight: 0.72
                )
            ),
            .init(
                id: "music-social",
                title: "Dinner-drive mix",
                summary: "Bridge route planning and mood setting before meeting people.",
                objectKind: .song,
                preferredSection: .music,
                activationPrompt: "Play something good for driving to dinner",
                tags: [.social, .commute, .entertainment],
                sourcePool: "song_tower",
                semanticKey: "music-social-drive",
                constraints: MatchingCandidateConstraints(
                    requiredAnyTags: [.social, .commute, .entertainment]
                ),
                utilityProfile: MatchingUtilityProfile(
                    goal: .sessionSatisfaction,
                    domainWeight: 0.78,
                    nextStepWeight: 0.68
                )
            ),
        ]

        if context.daypart == .morning || context.sessionIntentTags.contains(.focus) {
            candidates.append(
                .init(
                    id: "music-deep-work",
                    title: "Deep work layer",
                    summary: "A stronger focus preset for work, search, and planning sessions.",
                    objectKind: .song,
                    preferredSection: .music,
                    activationPrompt: "Play deep work music",
                    tags: [.focus, .ai, .search],
                    sourcePool: "song_tower",
                    semanticKey: "music-deep-work",
                    constraints: MatchingCandidateConstraints(
                        requiredAnyTags: [.focus, .ai, .search],
                        allowedDayparts: [.morning, .midday]
                    ),
                    utilityProfile: MatchingUtilityProfile(
                        goal: .sessionSatisfaction,
                        domainWeight: 0.82,
                        nextStepWeight: 0.7
                    )
                )
            )
        }

        return candidates
    }
}

struct VideoCandidateProvider: CandidateProvider {
    let id = "video"
    let versionID = "video-provider-v1"

    func generateCandidates(for _: MatchingFeatureContext) -> [UnifiedMatchingCandidate] {
        [
            .init(
                id: "video-yoga",
                title: "Stretch and yoga guide",
                summary: "A compact video surface for movement, cooldown, or evening reset.",
                objectKind: .video,
                preferredSection: .video,
                activationPrompt: "Show me a yoga stretch video",
                tags: [.health, .learning, .relaxation],
                sourcePool: "video_tower",
                semanticKey: "video-yoga-guide",
                constraints: MatchingCandidateConstraints(
                    requiredAnyTags: [.health, .learning, .relaxation]
                ),
                utilityProfile: MatchingUtilityProfile(
                    goal: .explanation,
                    domainWeight: 0.78,
                    nextStepWeight: 0.69
                )
            ),
            .init(
                id: "video-neighborhood",
                title: "Neighborhood explainer",
                summary: "See the area before committing to a route, venue, or meetup plan.",
                objectKind: .video,
                preferredSection: .video,
                activationPrompt: "Show me a short video about this area",
                tags: [.navigation, .learning, .search],
                sourcePool: "video_tower",
                semanticKey: "video-neighborhood-explainer",
                constraints: MatchingCandidateConstraints(
                    requiredAnyTags: [.navigation, .learning, .search]
                ),
                utilityProfile: MatchingUtilityProfile(
                    goal: .explanation,
                    domainWeight: 0.75,
                    nextStepWeight: 0.65
                )
            ),
            .init(
                id: "video-howto",
                title: "How-to walkthrough",
                summary: "Use video only when a visual answer beats a long wall of text.",
                objectKind: .video,
                preferredSection: .video,
                activationPrompt: "Show me a tutorial video",
                tags: [.learning, .search, .ai],
                sourcePool: "video_tower",
                semanticKey: "video-howto",
                constraints: MatchingCandidateConstraints(
                    requiredAnyTags: [.learning, .search, .ai]
                ),
                utilityProfile: MatchingUtilityProfile(
                    goal: .explanation,
                    domainWeight: 0.82,
                    nextStepWeight: 0.7
                )
            ),
        ]
    }
}

struct SearchCandidateProvider: CandidateProvider {
    let id = "search"
    let versionID = "search-provider-v1"

    func generateCandidates(for context: MatchingFeatureContext) -> [UnifiedMatchingCandidate] {
        var candidates: [UnifiedMatchingCandidate] = [
            .init(
                id: "search-parking",
                title: "Parking and reservation search",
                summary: "Search complements Maps when the decision needs extra facts, not just location.",
                objectKind: .searchResult,
                preferredSection: nil,
                activationPrompt: "Search nearby parking difficulty and reservation options",
                tags: [.search, .navigation, .planning],
                sourcePool: "search_tower",
                semanticKey: "search-parking-and-booking",
                constraints: MatchingCandidateConstraints(
                    requiredAnyTags: [.search, .navigation, .planning]
                ),
                utilityProfile: MatchingUtilityProfile(
                    goal: .explanation,
                    domainWeight: 0.8,
                    nextStepWeight: 0.76
                )
            ),
            .init(
                id: "search-runtime",
                title: "Explain runtime choice",
                summary: "Use search-style retrieval to answer why the app picked a certain tool or surface.",
                objectKind: .searchResult,
                preferredSection: nil,
                activationPrompt: "Explain why kAir would route this request the way it does",
                tags: [.search, .ai, .learning],
                sourcePool: "search_tower",
                semanticKey: "search-runtime-choice",
                constraints: MatchingCandidateConstraints(
                    requiredAnyTags: [.search, .ai, .learning]
                ),
                utilityProfile: MatchingUtilityProfile(
                    goal: .explanation,
                    domainWeight: 0.76,
                    nextStepWeight: 0.74
                )
            ),
        ]

        if context.healthAvailability == .ready {
            candidates.append(
                .init(
                    id: "search-health-proof",
                    title: "Health evidence lookup",
                    summary: "Search and summarize local health signals before opening the Health surface.",
                    objectKind: .searchResult,
                    preferredSection: nil,
                    activationPrompt: "Search my local health summary before opening Health",
                    tags: [.search, .health, .ai],
                    sourcePool: "search_tower",
                    semanticKey: "search-health-proof",
                    constraints: MatchingCandidateConstraints(
                        requiredAnyTags: [.search, .health, .ai],
                        requiredHealthAvailability: .ready
                    ),
                    utilityProfile: MatchingUtilityProfile(
                        goal: .taskCompletion,
                        domainWeight: 0.74,
                        nextStepWeight: 0.7
                    )
                )
            )
        }

        return candidates
    }
}

struct AnswerCandidateProvider: CandidateProvider {
    let id = "answer"
    let versionID = "answer-provider-v1"

    func generateCandidates(for _: MatchingFeatureContext) -> [UnifiedMatchingCandidate] {
        [
            .init(
                id: "answer-next-step",
                title: "Next-step card",
                summary: "Turn the current thread into a compact decision card instead of another paragraph.",
                objectKind: .answerCard,
                preferredSection: nil,
                activationPrompt: "Summarize the best next step from this thread",
                tags: [.planning, .ai],
                sourcePool: "answer_tower",
                semanticKey: "answer-next-step",
                utilityProfile: MatchingUtilityProfile(
                    goal: .explanation,
                    domainWeight: 0.74,
                    nextStepWeight: 0.8
                )
            ),
            .init(
                id: "answer-share-plan",
                title: "Shareable plan",
                summary: "Draft something you could send to a friend without needing a separate tab first.",
                objectKind: .contact,
                preferredSection: nil,
                activationPrompt: "Draft a message I can send to a friend about tonight's plan",
                tags: [.social, .planning],
                sourcePool: "contact_tower",
                semanticKey: "answer-share-plan",
                utilityProfile: MatchingUtilityProfile(
                    goal: .taskCompletion,
                    domainWeight: 0.69,
                    nextStepWeight: 0.77
                )
            ),
        ]
    }
}

struct ToolCandidateProvider: CandidateProvider {
    let id = "tool"
    let versionID = "tool-provider-v1"

    func generateCandidates(for context: MatchingFeatureContext) -> [UnifiedMatchingCandidate] {
        var candidates: [UnifiedMatchingCandidate] = [
            .init(
                id: "tool-ai-runtime",
                title: "Open AI runtime",
                summary: "Explain orchestration decisions and active capability layers.",
                objectKind: .toolEntry,
                preferredSection: .ai,
                activationPrompt: "Open AI and explain the current routing logic",
                tags: [.ai, .learning],
                sourcePool: "tool_tower",
                semanticKey: "tool-ai-runtime",
                constraints: MatchingCandidateConstraints(
                    requiredAnyTags: [.ai, .learning, .search]
                ),
                utilityProfile: MatchingUtilityProfile(
                    goal: .explanation,
                    domainWeight: 0.7,
                    nextStepWeight: 0.72
                )
            ),
            .init(
                id: "tool-store",
                title: "Open Store curation",
                summary: "Promote a service entry only when the session looks purchase-adjacent.",
                objectKind: .toolEntry,
                preferredSection: .store,
                activationPrompt: "Open Store and suggest what matters for recovery",
                tags: [.shopping, .health],
                sourcePool: "tool_tower",
                semanticKey: "tool-store",
                constraints: MatchingCandidateConstraints(
                    requiredAnyTags: [.shopping, .health]
                ),
                utilityProfile: MatchingUtilityProfile(
                    goal: .conversion,
                    domainWeight: 0.68,
                    nextStepWeight: 0.63
                )
            ),
        ]

        if context.healthAvailability == .ready {
            candidates.append(
                .init(
                    id: "tool-health",
                    title: "Open Health snapshot",
                    summary: "Use grounded health context only when the thread really calls for it.",
                    objectKind: .toolEntry,
                    preferredSection: .health,
                    activationPrompt: "Open Health and summarize what matters today",
                    tags: [.health, .ai],
                    sourcePool: "tool_tower",
                    semanticKey: "tool-health",
                    constraints: MatchingCandidateConstraints(
                        requiredAnyTags: [.health, .ai],
                        requiredHealthAvailability: .ready
                    ),
                    utilityProfile: MatchingUtilityProfile(
                        goal: .taskCompletion,
                        domainWeight: 0.8,
                        nextStepWeight: 0.79
                    )
                )
            )
        }

        return candidates
    }
}

extension Array where Element == any CandidateProvider {
    static var defaultMatchingProviders: [any CandidateProvider] {
        [
            MapsCandidateProvider(),
            MusicCandidateProvider(),
            VideoCandidateProvider(),
            SearchCandidateProvider(),
            AnswerCandidateProvider(),
            ToolCandidateProvider(),
        ]
    }

    static var retrievalMatchingProvidersV3: [any CandidateProvider] {
        [
            RetrievalCandidateProvider(variant: .v3LexicalBaseline),
        ]
    }

    static var retrievalMatchingProvidersV4: [any CandidateProvider] {
        [
            RetrievalCandidateProvider(variant: .v4FocusQueryHardening),
        ]
    }

    static var retrievalMatchingProviders: [any CandidateProvider] {
        retrievalMatchingProvidersV4
    }
}
