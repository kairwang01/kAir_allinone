//
//  MapActionCardModel.swift
//  kAir
//
//  Frozen contract for Maps Action Cards shown in Chat → Recommended Next.
//
//  This is the FIRST user-visible vertical slice. The contract is frozen at
//  these 6 fields, 4 states, and 5 events. Do not extend in-place; if the
//  shape needs to change, introduce a new versioned type instead.
//
//  Scope is intentionally narrow — Maps only. Music / Video / Store do not
//  ride on this type.
//

import Foundation

// MARK: - Frozen task kinds

/// The three Maps task types that are exposed to the user-visible card today.
/// Matches the sub-set of `MapTaskType` we promise end-to-end execution for:
/// - `.goToPlace`      → 去某地
/// - `.nearbySearch`   → 附近探索
/// - `.routeCompare`   → 路线查看
enum MapActionCardTaskKind: String, Codable, CaseIterable, Hashable, Sendable {
    case goToPlace
    case nearbySearch
    case routeCompare

    init?(taskType: MapTaskType) {
        switch taskType {
        case .goToPlace: self = .goToPlace
        case .nearbySearch: self = .nearbySearch
        case .routeComparison: self = .routeCompare
        case .recommendation: return nil
        }
    }

    var mappedTaskType: MapTaskType {
        switch self {
        case .goToPlace: return .goToPlace
        case .nearbySearch: return .nearbySearch
        case .routeCompare: return .routeComparison
        }
    }
}

// MARK: - Frozen card state

/// Lifecycle state exposed to the UI. Values are frozen — do not add.
enum MapActionCardState: String, Codable, CaseIterable, Hashable, Sendable {
    case loading
    case recommended
    case accepted
    case dismissed
}

// MARK: - Frozen card events

/// Every observable thing that can happen to a card. Values are frozen —
/// do not add. New wiring MUST route into one of these five buckets.
enum MapActionCardEvent: String, Codable, CaseIterable, Hashable, Sendable {
    case impression
    case tap
    case accept
    case dismiss
    case executionReturn
}

// MARK: - Frozen UI copy

/// Locked user-facing copy. zh/en is the only dimension the UI is allowed to
/// bend on. Anything else ships a new versioned type.
struct MapActionCardCopy: Hashable, Sendable {
    let primaryActionTitle: String
    let secondaryActionTitle: String?
    let reasonChipPrefix: String
    let feedbackAffordanceLabel: String

    static func locked(for kind: MapActionCardTaskKind, language: MapsConversationLanguage) -> MapActionCardCopy {
        let zh = language.usesChineseCopy
        switch kind {
        case .goToPlace:
            return MapActionCardCopy(
                primaryActionTitle: zh ? "去这里" : "Go here",
                secondaryActionTitle: zh ? "换个目的地" : "Change destination",
                reasonChipPrefix: zh ? "为什么推荐" : "Why",
                feedbackAffordanceLabel: zh ? "其他反馈" : "More options"
            )
        case .nearbySearch:
            return MapActionCardCopy(
                primaryActionTitle: zh ? "看看附近" : "Explore nearby",
                secondaryActionTitle: zh ? "换个关键词" : "Change keyword",
                reasonChipPrefix: zh ? "为什么推荐" : "Why",
                feedbackAffordanceLabel: zh ? "其他反馈" : "More options"
            )
        case .routeCompare:
            return MapActionCardCopy(
                primaryActionTitle: zh ? "看路线" : "Compare routes",
                secondaryActionTitle: zh ? "换个出发点" : "Change origin",
                reasonChipPrefix: zh ? "为什么推荐" : "Why",
                feedbackAffordanceLabel: zh ? "其他反馈" : "More options"
            )
        }
    }
}

// MARK: - Frozen model

/// A user-visible Maps Action Card.
///
/// Exactly 6 content fields — do not extend:
///   1. `title`
///   2. `subtitle`
///   3. `primaryActionTitle`
///   4. `secondaryActionTitle`  (optional)
///   5. `reasonChipText`
///   6. `feedbackAffordanceLabel`
///
/// Plus the identity / state / routing fields the framework uses to
/// wire events back into the matching pipeline.
struct MapActionCardModel: Identifiable, Hashable, Sendable {
    let id: String
    let candidateId: String
    let recommendationId: String?
    let threadId: String

    let taskKind: MapActionCardTaskKind
    let language: MapsConversationLanguage
    let state: MapActionCardState

    // The 6 frozen content fields.
    let title: String
    let subtitle: String
    let primaryActionTitle: String
    let secondaryActionTitle: String?
    let reasonChipText: String
    let feedbackAffordanceLabel: String

    // Routing payload — how the card re-enters the matching pipeline.
    let activationPrompt: String
    let objectKindRawValue: String

    init(
        id: String,
        candidateId: String,
        recommendationId: String?,
        threadId: String,
        taskKind: MapActionCardTaskKind,
        language: MapsConversationLanguage,
        state: MapActionCardState,
        title: String,
        subtitle: String,
        primaryActionTitle: String,
        secondaryActionTitle: String?,
        reasonChipText: String,
        feedbackAffordanceLabel: String,
        activationPrompt: String,
        objectKindRawValue: String
    ) {
        self.id = id
        self.candidateId = candidateId
        self.recommendationId = recommendationId
        self.threadId = threadId
        self.taskKind = taskKind
        self.language = language
        self.state = state
        self.title = title
        self.subtitle = subtitle
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitle = secondaryActionTitle
        self.reasonChipText = reasonChipText
        self.feedbackAffordanceLabel = feedbackAffordanceLabel
        self.activationPrompt = activationPrompt
        self.objectKindRawValue = objectKindRawValue
    }

    /// Build a card from a Maps-kind matching recommendation.
    ///
    /// Returns `nil` when the recommendation is not a Maps card. This is the
    /// single gate that enforces "only Maps rides this contract."
    static func fromRecommendation(
        _ recommendation: UnifiedMatchRecommendation,
        recommendationId: String?,
        threadId: UUID,
        language: MapsConversationLanguage,
        state: MapActionCardState = .recommended
    ) -> MapActionCardModel? {
        guard recommendation.candidate.preferredSection == .maps else {
            return nil
        }

        let kind = inferTaskKind(from: recommendation)
        let copy = MapActionCardCopy.locked(for: kind, language: language)
        let reasonBase = recommendation.breakdown.reasonCodes.first?.userFacingText
            ?? recommendation.candidate.summary
        let reasonText = "\(copy.reasonChipPrefix): \(reasonBase)"

        return MapActionCardModel(
            id: recommendation.id,
            candidateId: recommendation.candidate.id,
            recommendationId: recommendationId,
            threadId: threadId.uuidString,
            taskKind: kind,
            language: language,
            state: state,
            title: recommendation.candidate.title,
            subtitle: recommendation.candidate.summary,
            primaryActionTitle: copy.primaryActionTitle,
            secondaryActionTitle: copy.secondaryActionTitle,
            reasonChipText: reasonText,
            feedbackAffordanceLabel: copy.feedbackAffordanceLabel,
            activationPrompt: recommendation.candidate.activationPrompt,
            objectKindRawValue: recommendation.candidate.objectKind.rawValue
        )
    }

    /// Transition a card to a new lifecycle state, keeping all other fields
    /// intact. Used by the host view to reflect accept/dismiss.
    func transitioned(to newState: MapActionCardState) -> MapActionCardModel {
        MapActionCardModel(
            id: id,
            candidateId: candidateId,
            recommendationId: recommendationId,
            threadId: threadId,
            taskKind: taskKind,
            language: language,
            state: newState,
            title: title,
            subtitle: subtitle,
            primaryActionTitle: primaryActionTitle,
            secondaryActionTitle: secondaryActionTitle,
            reasonChipText: reasonChipText,
            feedbackAffordanceLabel: feedbackAffordanceLabel,
            activationPrompt: activationPrompt,
            objectKindRawValue: objectKindRawValue
        )
    }

    private static func inferTaskKind(
        from recommendation: UnifiedMatchRecommendation
    ) -> MapActionCardTaskKind {
        let tags = recommendation.candidate.tags
        if tags.contains(.navigation) && (tags.contains(.planning) || tags.contains(.commute)) {
            return .routeCompare
        }
        if recommendation.candidate.objectKind == .route {
            return .routeCompare
        }
        if tags.contains(.localDiscovery) {
            return .nearbySearch
        }
        return .goToPlace
    }
}
