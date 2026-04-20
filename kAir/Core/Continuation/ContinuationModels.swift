//
//  ContinuationModels.swift
//  kAir
//
//  Value types for Continuation Runtime v1.
//  Normative spec: Contracts/UX/continuation-runtime-v1.md
//
//  All vocabulary — SurfaceKind, ObjectType, the four outcome cases,
//  the three state cases, the five refresh modes — is owned locally by
//  this layer. The spec §1 frames this runtime as the single owner of
//  post-return behavior; that only works if its types don't depend on
//  the matcher's object-kind enum or the feature layer's section enum.
//
//  Bridging between SurfaceKind/ObjectType here and
//  AppSection/MatchingObjectKind elsewhere is an adapter-level concern
//  and MUST NOT appear in this file or in ContinuationRuntime.swift.
//

import Foundation

// MARK: - §5 External-type vocabulary (local to Continuation layer)

/// Source surface of an execution return. Intentionally local; no
/// typealias to `AppSection`. See spec §13.3 — surfaces are consumers
/// of this contract, not definers of it.
public enum SurfaceKind: String, Equatable, Sendable, CaseIterable {
    case chat
    case maps
    case music
    case video
    case ai
    case search
    case health
    case store
    case me
}

/// Object type carried in return payloads and context. Intentionally
/// local; no typealias to `MatchingObjectKind`. The matcher can
/// converge onto this vocabulary, or an adapter can bridge — but the
/// Continuation runtime v1 contract is defined against these cases.
public enum ObjectType: String, Equatable, Sendable, CaseIterable {
    case place
    case route
    case song
    case video
    case searchResult
    case answerCard
    case contact
    case thread
    case toolEntry
}

// MARK: - §5.1 Input event

public struct ExecutionReturnEvent: Equatable, Sendable {
    public let sourceSurface: SurfaceKind
    public let sourceRequestId: String
    public let sourceRecommendationId: String?
    public let outcome: ContinuationOutcome
    public let payload: ReturnPayload?
    public let returnedAt: Date

    public init(
        sourceSurface: SurfaceKind,
        sourceRequestId: String,
        sourceRecommendationId: String? = nil,
        outcome: ContinuationOutcome,
        payload: ReturnPayload? = nil,
        returnedAt: Date
    ) {
        self.sourceSurface = sourceSurface
        self.sourceRequestId = sourceRequestId
        self.sourceRecommendationId = sourceRecommendationId
        self.outcome = outcome
        self.payload = payload
        self.returnedAt = returnedAt
    }
}

// MARK: - §5.2 Outcome

public enum ContinuationOutcome: String, Equatable, Sendable, CaseIterable {
    case completion
    case abandon
    case dismiss
    case acceptNoEntry
}

// MARK: - §5.3 Context

public struct ContinuationContext: Equatable, Sendable {
    public let threadId: String
    public let activePrompt: String?
    public let activeSurface: SurfaceKind?
    public let currentRecommendationIds: [String]
    public let acceptedRecommendationId: String?
    public let latestUserIntentTags: [String]
    public let latestObjectTypes: [ObjectType]
    public let recentNegativeSignals: [RecentNegativeSignal]

    public init(
        threadId: String,
        activePrompt: String? = nil,
        activeSurface: SurfaceKind? = nil,
        currentRecommendationIds: [String] = [],
        acceptedRecommendationId: String? = nil,
        latestUserIntentTags: [String] = [],
        latestObjectTypes: [ObjectType] = [],
        recentNegativeSignals: [RecentNegativeSignal] = []
    ) {
        self.threadId = threadId
        self.activePrompt = activePrompt
        self.activeSurface = activeSurface
        self.currentRecommendationIds = currentRecommendationIds
        self.acceptedRecommendationId = acceptedRecommendationId
        self.latestUserIntentTags = latestUserIntentTags
        self.latestObjectTypes = latestObjectTypes
        self.recentNegativeSignals = recentNegativeSignals
    }
}

/// Feedback kind is carried as an opaque raw string to avoid pinning
/// the Continuation contract to the (still-unfrozen) feedback enum.
/// When `feedback-runtime-v1.md` lands, v1.1 of this runtime MAY
/// promote this field to a typed `FeedbackKind` — that change is
/// additive and does not break v1.
public struct RecentNegativeSignal: Equatable, Sendable {
    public let recommendationId: String
    public let objectType: ObjectType
    public let observedAt: Date
    public let feedbackKindRawValue: String

    public init(
        recommendationId: String,
        objectType: ObjectType,
        observedAt: Date,
        feedbackKindRawValue: String
    ) {
        self.recommendationId = recommendationId
        self.objectType = objectType
        self.observedAt = observedAt
        self.feedbackKindRawValue = feedbackKindRawValue
    }
}

// MARK: - §9 Return payload

public struct ReturnPayload: Equatable, Sendable {
    public let taskFamily: String?
    public let objectType: ObjectType?
    public let title: String?
    public let subtitle: String?
    public let structuredEvidence: [ReturnEvidenceItem]
    public let downstreamValueHint: String?

    public init(
        taskFamily: String? = nil,
        objectType: ObjectType? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        structuredEvidence: [ReturnEvidenceItem] = [],
        downstreamValueHint: String? = nil
    ) {
        self.taskFamily = taskFamily
        self.objectType = objectType
        self.title = title
        self.subtitle = subtitle
        self.structuredEvidence = structuredEvidence
        self.downstreamValueHint = downstreamValueHint
    }
}

public struct ReturnEvidenceItem: Equatable, Sendable {
    public let key: String
    public let value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

// MARK: - §5.4 Output

public struct ContinuationResult: Equatable, Sendable {
    public let transcriptInsertions: [ChatContinuationEvent]
    public let recommendationRefreshPlan: RecommendationRefreshPlan
    public let continuationState: ContinuationState

    public init(
        transcriptInsertions: [ChatContinuationEvent],
        recommendationRefreshPlan: RecommendationRefreshPlan,
        continuationState: ContinuationState
    ) {
        self.transcriptInsertions = transcriptInsertions
        self.recommendationRefreshPlan = recommendationRefreshPlan
        self.continuationState = continuationState
    }

    /// §15.2 — preserve is safer than incorrect refresh. Declared as
    /// a single constant so the fallback shape is literally one value
    /// and cannot drift across call sites.
    public static let safeFallback = ContinuationResult(
        transcriptInsertions: [],
        recommendationRefreshPlan: RecommendationRefreshPlan(
            mode: .preserve,
            preserveAcceptedCard: false,
            suppressSourceRecommendationId: nil,
            preferredTaskFamily: nil
        ),
        continuationState: .sameTask
    )
}

// MARK: - §5.5 State

public enum ContinuationState: String, Equatable, Sendable, CaseIterable {
    case sameTask
    case adjacentTask
    case newTask
}

// MARK: - §6.1 / §8 Transcript blocks

public enum ChatContinuationEvent: Equatable, Sendable {
    case systemSummary(ContinuationSummaryBlock)
    case systemEvidence(ContinuationEvidenceBlock)
    case nextStepPrompt(ContinuationPromptBlock)
}

public struct ContinuationSummaryBlock: Equatable, Sendable {
    public let sourceSurface: SurfaceKind
    public let outcome: ContinuationOutcome
    public let summaryText: String
    public let sourceRequestId: String
    public let sourceRecommendationId: String?

    public init(
        sourceSurface: SurfaceKind,
        outcome: ContinuationOutcome,
        summaryText: String,
        sourceRequestId: String,
        sourceRecommendationId: String? = nil
    ) {
        self.sourceSurface = sourceSurface
        self.outcome = outcome
        self.summaryText = summaryText
        self.sourceRequestId = sourceRequestId
        self.sourceRecommendationId = sourceRecommendationId
    }
}

public struct ContinuationEvidenceBlock: Equatable, Sendable {
    public let title: String?
    public let items: [ReturnEvidenceItem]

    public init(title: String? = nil, items: [ReturnEvidenceItem]) {
        self.title = title
        self.items = items
    }
}

public struct ContinuationPromptBlock: Equatable, Sendable {
    public let prompt: String
    public let taskFamily: String?

    public init(prompt: String, taskFamily: String? = nil) {
        self.prompt = prompt
        self.taskFamily = taskFamily
    }
}

// MARK: - §6.2 / §11 Refresh plan

public struct RecommendationRefreshPlan: Equatable, Sendable {
    public let mode: RefreshMode
    public let preserveAcceptedCard: Bool
    public let suppressSourceRecommendationId: String?
    public let preferredTaskFamily: TaskFamilyBias?

    public init(
        mode: RefreshMode,
        preserveAcceptedCard: Bool,
        suppressSourceRecommendationId: String? = nil,
        preferredTaskFamily: TaskFamilyBias? = nil
    ) {
        self.mode = mode
        self.preserveAcceptedCard = preserveAcceptedCard
        self.suppressSourceRecommendationId = suppressSourceRecommendationId
        self.preferredTaskFamily = preferredTaskFamily
    }
}

public enum RefreshMode: String, Equatable, Sendable, CaseIterable {
    case preserve
    case refreshSameFamily
    case refreshAdjacentFamily
    case refreshNewTask
    case clear
}

public struct TaskFamilyBias: Equatable, Sendable {
    public let family: String
    public let strength: Double

    public init(family: String, strength: Double) {
        self.family = family
        self.strength = strength
    }
}
