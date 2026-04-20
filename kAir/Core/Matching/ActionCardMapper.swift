//
//  ActionCardMapper.swift
//  kAir
//
//  Unified Action Card contract. Every matchable object — Place, Route,
//  Song, Video, Search Result, Answer Card, Tool Entry, Service Entry —
//  must map into exactly one `ActionCard`. The card is the single render
//  target for Recommended Next, Chat answers, and the direct-slot area.
//
//  Cards must carry: cardType, title, subtitle, primaryAction,
//  secondaryAction, feedbackActions, reasonCodes.
//

import Foundation

enum ActionCardType: String, Codable, CaseIterable, Hashable, Sendable {
    case place
    case route
    case song
    case video
    case searchResult = "search_result"
    case answerCard = "answer_card"
    case toolEntry = "tool_entry"
    case serviceEntry = "service_entry"
}

struct ActionCardAction: Hashable, Sendable {
    let title: String
    let systemImage: String
    let surface: AppSection?
    let payload: String

    init(
        title: String,
        systemImage: String,
        surface: AppSection?,
        payload: String
    ) {
        self.title = title
        self.systemImage = systemImage
        self.surface = surface
        self.payload = payload
    }
}

struct ActionCard: Hashable, Sendable, Identifiable {
    let id: String
    let cardType: ActionCardType
    let title: String
    let subtitle: String
    let primaryAction: ActionCardAction
    let secondaryAction: ActionCardAction?
    let feedbackActions: [FeedbackOption]
    let reasonCodes: [ReasonCode]
    let candidateId: String
    let policyVersion: String
    let objectKind: MatchingObjectKind
}

enum ActionCardMapper {
    static func map(
        recommendation: UnifiedMatchRecommendation,
        reasonCodes: [ReasonCode],
        feedbackOptions: [FeedbackOption] = FeedbackOption.allCases,
        policyVersion: MatchingPolicyVersion
    ) -> ActionCard {
        let candidate = recommendation.candidate
        let cardType = cardType(for: candidate.objectKind)
        let actions = actions(for: candidate, cardType: cardType)

        return ActionCard(
            id: candidate.id,
            cardType: cardType,
            title: candidate.title,
            subtitle: subtitle(for: candidate, recommendation: recommendation),
            primaryAction: actions.primary,
            secondaryAction: actions.secondary,
            feedbackActions: feedbackOptions,
            reasonCodes: reasonCodes,
            candidateId: candidate.id,
            policyVersion: policyVersion.policyVersion,
            objectKind: candidate.objectKind
        )
    }

    static func map(
        decision: RecommendationDecision,
        policyVersion: MatchingPolicyVersion
    ) -> [ActionCard] {
        decision.rankedCandidates.map { recommendation in
            let isDirect = recommendation.id == decision.directSlotCandidateId
            let reasons = isDirect ? decision.reasonCodes : []
            return map(
                recommendation: recommendation,
                reasonCodes: reasons,
                feedbackOptions: decision.feedbackOptions,
                policyVersion: policyVersion
            )
        }
    }

    // MARK: - Type and action resolution

    private static func cardType(for kind: MatchingObjectKind) -> ActionCardType {
        switch kind {
        case .place:
            return .place
        case .route:
            return .route
        case .song:
            return .song
        case .video:
            return .video
        case .searchResult:
            return .searchResult
        case .answerCard:
            return .answerCard
        case .toolEntry:
            return .toolEntry
        case .contact, .thread:
            return .serviceEntry
        }
    }

    private static func actions(
        for candidate: UnifiedMatchingCandidate,
        cardType: ActionCardType
    ) -> (primary: ActionCardAction, secondary: ActionCardAction?) {
        let surface = candidate.preferredSection

        switch cardType {
        case .place:
            return (
                primary: ActionCardAction(
                    title: "Open in Maps",
                    systemImage: "mappin.and.ellipse",
                    surface: .maps,
                    payload: "place:\(candidate.id)"
                ),
                secondary: ActionCardAction(
                    title: "Route here",
                    systemImage: "arrow.triangle.turn.up.right.diamond",
                    surface: .maps,
                    payload: "route:\(candidate.id)"
                )
            )
        case .route:
            return (
                primary: ActionCardAction(
                    title: "Start navigation",
                    systemImage: "arrow.triangle.turn.up.right.diamond",
                    surface: .maps,
                    payload: "route:\(candidate.id)"
                ),
                secondary: ActionCardAction(
                    title: "Preview",
                    systemImage: "eye",
                    surface: .maps,
                    payload: "preview:\(candidate.id)"
                )
            )
        case .song:
            return (
                primary: ActionCardAction(
                    title: "Play",
                    systemImage: "play.fill",
                    surface: .music,
                    payload: "song:\(candidate.id)"
                ),
                secondary: ActionCardAction(
                    title: "Queue next",
                    systemImage: "text.badge.plus",
                    surface: .music,
                    payload: "queue:\(candidate.id)"
                )
            )
        case .video:
            return (
                primary: ActionCardAction(
                    title: "Watch",
                    systemImage: "play.rectangle",
                    surface: .video,
                    payload: "video:\(candidate.id)"
                ),
                secondary: ActionCardAction(
                    title: "Save for later",
                    systemImage: "bookmark",
                    surface: .video,
                    payload: "save:\(candidate.id)"
                )
            )
        case .searchResult:
            return (
                primary: ActionCardAction(
                    title: "Open result",
                    systemImage: "magnifyingglass",
                    surface: surface ?? .chat,
                    payload: "search:\(candidate.id)"
                ),
                secondary: ActionCardAction(
                    title: "Refine query",
                    systemImage: "text.magnifyingglass",
                    surface: .chat,
                    payload: "refine:\(candidate.id)"
                )
            )
        case .answerCard:
            return (
                primary: ActionCardAction(
                    title: "Read answer",
                    systemImage: "text.bubble",
                    surface: .chat,
                    payload: "answer:\(candidate.id)"
                ),
                secondary: ActionCardAction(
                    title: "Explain more",
                    systemImage: "sparkles",
                    surface: .chat,
                    payload: "elaborate:\(candidate.id)"
                )
            )
        case .toolEntry:
            return (
                primary: ActionCardAction(
                    title: "Open tool",
                    systemImage: "square.stack.3d.up",
                    surface: surface ?? .ai,
                    payload: "tool:\(candidate.id)"
                ),
                secondary: ActionCardAction(
                    title: "Prefill with prompt",
                    systemImage: "text.append",
                    surface: surface ?? .ai,
                    payload: "toolPrefill:\(candidate.id)"
                )
            )
        case .serviceEntry:
            return (
                primary: ActionCardAction(
                    title: "Open",
                    systemImage: surface?.systemImage ?? "square.and.arrow.up.on.square",
                    surface: surface ?? .chat,
                    payload: "service:\(candidate.id)"
                ),
                secondary: nil
            )
        }
    }

    private static func subtitle(
        for candidate: UnifiedMatchingCandidate,
        recommendation: UnifiedMatchRecommendation
    ) -> String {
        if candidate.summary.isEmpty == false {
            return candidate.summary
        }
        return recommendation.package.prompt
    }
}
