//
//  UnifiedMatchingModels.swift
//  kAir
//
//  Shared models for the app-wide matching layer.
//

import Foundation

enum MatchingIntentTag: String, CaseIterable, Hashable {
    case navigation
    case localDiscovery
    case planning
    case focus
    case relaxation
    case entertainment
    case learning
    case shopping
    case health
    case social
    case search
    case ai
    case commute
}

enum MatchingObjectKind: String, CaseIterable, Hashable {
    case place
    case route
    case contact
    case song
    case video
    case searchResult
    case answerCard
    case toolEntry
    case thread

    var title: String {
        switch self {
        case .place:
            return "Place"
        case .route:
            return "Route"
        case .contact:
            return "Contact"
        case .song:
            return "Song"
        case .video:
            return "Video"
        case .searchResult:
            return "Search"
        case .answerCard:
            return "Answer"
        case .toolEntry:
            return "Tool"
        case .thread:
            return "Thread"
        }
    }

    var systemImage: String {
        switch self {
        case .place:
            return "mappin.and.ellipse"
        case .route:
            return "arrow.triangle.turn.up.right.diamond"
        case .contact:
            return "person.2"
        case .song:
            return "music.note"
        case .video:
            return "play.rectangle"
        case .searchResult:
            return "magnifyingglass"
        case .answerCard:
            return "text.bubble"
        case .toolEntry:
            return "square.stack.3d.up"
        case .thread:
            return "bubble.left.and.bubble.right"
        }
    }
}

enum MatchingDaypart: String, Hashable {
    case morning
    case midday
    case evening
    case night

    static func resolve(from date: Date) -> MatchingDaypart {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5 ..< 11:
            return .morning
        case 11 ..< 17:
            return .midday
        case 17 ..< 22:
            return .evening
        default:
            return .night
        }
    }
}

enum MatchingLocationState: String, Hashable {
    case unknown
    case unavailable
    case approximate
    case precise
}

enum MatchingHealthAvailability: String, Hashable {
    case ready
    case availableLater
    case unavailable
}

enum MatchingMotionContext: String, Hashable {
    case unknown
    case stationary
    case walking
    case driving
}

struct MatchingOutcomeMetrics: Hashable, Sendable {
    let downstreamValue: Double
    let completionScore: Double
    let dwellSeconds: TimeInterval?
    let wasSuccessful: Bool

    nonisolated init(
        downstreamValue: Double = 0,
        completionScore: Double = 0,
        dwellSeconds: TimeInterval? = nil,
        wasSuccessful: Bool = false
    ) {
        self.downstreamValue = downstreamValue
        self.completionScore = completionScore
        self.dwellSeconds = dwellSeconds
        self.wasSuccessful = wasSuccessful
    }

    nonisolated static let neutral = MatchingOutcomeMetrics()
}

enum MatchingFeedbackKind: String, CaseIterable, Hashable {
    case dismiss
    case notInterested
    case lessLikeThis
    case notNow
    case alreadyDone

    var title: String {
        switch self {
        case .dismiss:
            return "忽略"
        case .notInterested:
            return "不感兴趣"
        case .lessLikeThis:
            return "以后少推这类"
        case .notNow:
            return "现在不需要"
        case .alreadyDone:
            return "已经做过了"
        }
    }

    var summary: String {
        switch self {
        case .dismiss:
            return "Dismiss without explicit negative signal."
        case .notInterested:
            return "Suppress this exact suggestion."
        case .lessLikeThis:
            return "Down-rank this type for a while."
        case .notNow:
            return "De-prioritize this timing, not the whole category."
        case .alreadyDone:
            return "Treat this task as already handled."
        }
    }

    var systemImage: String {
        switch self {
        case .dismiss:
            return "xmark"
        case .notInterested:
            return "hand.thumbsdown"
        case .lessLikeThis:
            return "line.3.horizontal.decrease.circle"
        case .notNow:
            return "clock.arrow.circlepath"
        case .alreadyDone:
            return "checkmark.circle"
        }
    }
}

struct MatchingBehaviorEvent: Identifiable, Hashable {
    enum Stage: String, Hashable {
        case impression
        case click
        case accept
        case dismiss
        case abandon
        case completion
    }

    enum Subject: String, Hashable {
        case prompt
        case recommendation
        case surface
        case route
        case playback
        case search
        case tool
        case reference
    }

    let id: UUID
    let stage: Stage
    let subject: Subject
    let candidateID: String?
    let objectKind: MatchingObjectKind?
    let surface: AppSection?
    let rawText: String?
    let tags: Set<MatchingIntentTag>
    let feedback: MatchingFeedbackKind?
    let timestamp: Date
    let outcome: MatchingOutcomeMetrics

    init(
        id: UUID = UUID(),
        stage: Stage,
        subject: Subject,
        candidateID: String? = nil,
        objectKind: MatchingObjectKind? = nil,
        surface: AppSection? = nil,
        rawText: String? = nil,
        tags: Set<MatchingIntentTag>,
        feedback: MatchingFeedbackKind? = nil,
        timestamp: Date = .now,
        outcome: MatchingOutcomeMetrics = MatchingOutcomeMetrics()
    ) {
        self.id = id
        self.stage = stage
        self.subject = subject
        self.candidateID = candidateID
        self.objectKind = objectKind
        self.surface = surface
        self.rawText = rawText
        self.tags = tags
        self.feedback = feedback
        self.timestamp = timestamp
        self.outcome = outcome
    }

    var learningWeight: Double {
        let base: Double
        switch stage {
        case .impression:
            base = 0.08
        case .click:
            base = 0.35
        case .accept:
            base = 0.7
        case .dismiss:
            switch feedback {
            case .dismiss:
                base = -0.35
            case .notInterested:
                base = -0.52
            case .lessLikeThis:
                base = -0.42
            case .notNow:
                base = -0.18
            case .alreadyDone:
                base = 0.44
            case .none:
                base = -0.35
            }
        case .abandon:
            base = -0.22
        case .completion:
            base = feedback == .alreadyDone ? 0.7 : 0.95
        }

        return base + outcome.downstreamValue * 0.35 + outcome.completionScore * 0.4
    }
}

struct MatchingFeatureContext: Hashable {
    let recentPrompt: String?
    let activeSurface: AppSection
    let messageCount: Int
    let daypart: MatchingDaypart
    let weekday: Int
    let locationState: MatchingLocationState
    let healthAvailability: MatchingHealthAvailability
    let motionContext: MatchingMotionContext
    let sessionIntentTags: Set<MatchingIntentTag>
    let recencyTags: Set<MatchingIntentTag>
    let longTermTags: Set<MatchingIntentTag>
    let crossSurfaceTransitions: [AppSection: Int]
    let objectTypeAffinity: [MatchingObjectKind: Double]
    let objectTypeFatigue: [MatchingObjectKind: Double]
    let recentRejectedCandidateIDs: Set<String>
    let recentCompletedCandidateIDs: Set<String>
    let recentFeedbackByCandidate: [String: MatchingFeedbackKind]
    let foldedIntentTags: Set<MatchingIntentTag>
    let resolvedObjectIds: Set<String>
    let dismissedObjectIds: Set<String>
    let executionSurfaceStates: [AppSection: ExecutionReturnContextState.SurfaceState]
    let behaviorLog: [MatchingBehaviorEvent]
}

enum MatchingNorthStarOutcome: String, Hashable {
    case taskProgression
}

enum MatchingSecondaryMetric: String, Hashable {
    case engagement
    case latency
    case diversity
    case crossSurfaceUtility
}

enum MatchingSuccessLabel: String, Hashable {
    case placeConfirmed
    case navigationStarted
    case answerResolved
    case searchRefined
    case playbackSustained
    case videoConsumed
    case toolFlowCompleted
    case contactDrafted
}

struct MatchingDomainSuccessProfile: Hashable {
    let objectKind: MatchingObjectKind
    let labels: [MatchingSuccessLabel]
}

struct MatchingObjectiveContract {
    let northStar: MatchingNorthStarOutcome
    let secondaryMetrics: [MatchingSecondaryMetric]
    let successProfiles: [MatchingDomainSuccessProfile]

    static let appWide = MatchingObjectiveContract(
        northStar: .taskProgression,
        secondaryMetrics: [.engagement, .latency, .diversity, .crossSurfaceUtility],
        successProfiles: [
            .init(objectKind: .place, labels: [.placeConfirmed, .navigationStarted]),
            .init(objectKind: .route, labels: [.navigationStarted]),
            .init(objectKind: .contact, labels: [.contactDrafted]),
            .init(objectKind: .song, labels: [.playbackSustained]),
            .init(objectKind: .video, labels: [.videoConsumed]),
            .init(objectKind: .searchResult, labels: [.searchRefined]),
            .init(objectKind: .answerCard, labels: [.answerResolved]),
            .init(objectKind: .toolEntry, labels: [.toolFlowCompleted]),
            .init(objectKind: .thread, labels: [.answerResolved]),
        ]
    )
}

enum MatchingUtilityGoal: String, Hashable {
    case taskCompletion
    case sessionSatisfaction
    case engagement
    case explanation
    case conversion
}

struct MatchingUtilityProfile: Hashable {
    let goal: MatchingUtilityGoal
    let domainWeight: Double
    let nextStepWeight: Double

    init(
        goal: MatchingUtilityGoal,
        domainWeight: Double,
        nextStepWeight: Double
    ) {
        self.goal = goal
        self.domainWeight = domainWeight
        self.nextStepWeight = nextStepWeight
    }
}

struct MatchingCandidateConstraints: Hashable {
    let requiredAnyTags: Set<MatchingIntentTag>
    let blockedTags: Set<MatchingIntentTag>
    let allowedDayparts: Set<MatchingDaypart>?
    let requiredHealthAvailability: MatchingHealthAvailability?
    let requiredLocationStates: Set<MatchingLocationState>?

    init(
        requiredAnyTags: Set<MatchingIntentTag> = [],
        blockedTags: Set<MatchingIntentTag> = [],
        allowedDayparts: Set<MatchingDaypart>? = nil,
        requiredHealthAvailability: MatchingHealthAvailability? = nil,
        requiredLocationStates: Set<MatchingLocationState>? = nil
    ) {
        self.requiredAnyTags = requiredAnyTags
        self.blockedTags = blockedTags
        self.allowedDayparts = allowedDayparts
        self.requiredHealthAvailability = requiredHealthAvailability
        self.requiredLocationStates = requiredLocationStates
    }
}

enum MatchingCandidateAvailability: String, Hashable {
    case available
    case limited
    case unavailable
}

enum MatchingReasonCategory: String, Hashable {
    case context
    case behavior
    case temporal
    case availability
    case exploration
    case policy
}

enum MatchingCoarseReasonTag: String, Hashable {
    case context
    case behavior
    case temporal
    case availability
    case exploration
    case policy
}

struct MatchingDebugField: Hashable {
    let key: String
    let value: String
}

struct MatchingRetrievalDescriptor: Hashable {
    let providerID: String
    let retrievalScore: Double
    let freshnessHours: Double?
    let availability: MatchingCandidateAvailability
    let coarseReasonTags: [MatchingCoarseReasonTag]
    let metadata: [MatchingDebugField]

    init(
        providerID: String,
        retrievalScore: Double = 0.5,
        freshnessHours: Double? = nil,
        availability: MatchingCandidateAvailability = .available,
        coarseReasonTags: [MatchingCoarseReasonTag] = [.policy],
        metadata: [MatchingDebugField] = []
    ) {
        self.providerID = providerID
        self.retrievalScore = retrievalScore
        self.freshnessHours = freshnessHours
        self.availability = availability
        self.coarseReasonTags = coarseReasonTags
        self.metadata = metadata
    }
}

struct MatchingFeatureValue: Hashable {
    let key: String
    let value: Double
}

struct MatchingScoringInput: Hashable {
    let userFeatures: [MatchingFeatureValue]
    let contextFeatures: [MatchingFeatureValue]
    let candidateFeatures: [MatchingFeatureValue]
    let interactionFeatures: [MatchingFeatureValue]
    let fatigueFeatures: [MatchingFeatureValue]
}

struct MatchingScoringDebugPayload: Hashable {
    let userFeatureKeys: [String]
    let contextFeatureKeys: [String]
    let candidateFeatureKeys: [String]
    let interactionFeatureKeys: [String]
    let fatigueFeatureKeys: [String]
    let retrievalMetadata: [MatchingDebugField]
    let policyVersion: String
}

enum MatchingRecommendationPackageStyle: String, Hashable {
    case directPrompt
    case focusedSurface
    case persistentPlayer
}

struct MatchingRecommendationPackage: Hashable {
    let style: MatchingRecommendationPackageStyle
    let ctaTitle: String
    let prompt: String
}

struct UnifiedMatchingCandidate: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let objectKind: MatchingObjectKind
    let preferredSection: AppSection?
    let activationPrompt: String
    let tags: Set<MatchingIntentTag>
    let sourcePool: String
    let domainKey: String
    let semanticKey: String
    let providerID: String
    let retrieval: MatchingRetrievalDescriptor
    let constraints: MatchingCandidateConstraints
    let utilityProfile: MatchingUtilityProfile

    init(
        id: String,
        title: String,
        summary: String,
        objectKind: MatchingObjectKind,
        preferredSection: AppSection?,
        activationPrompt: String,
        tags: Set<MatchingIntentTag>,
        sourcePool: String,
        domainKey: String? = nil,
        semanticKey: String? = nil,
        providerID: String? = nil,
        retrieval: MatchingRetrievalDescriptor? = nil,
        constraints: MatchingCandidateConstraints = MatchingCandidateConstraints(),
        utilityProfile: MatchingUtilityProfile
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.objectKind = objectKind
        self.preferredSection = preferredSection
        self.activationPrompt = activationPrompt
        self.tags = tags
        self.sourcePool = sourcePool
        self.domainKey = domainKey ?? objectKind.rawValue
        self.semanticKey = semanticKey ?? id
        self.providerID = providerID ?? sourcePool
        self.retrieval = retrieval ?? MatchingRetrievalDescriptor(
            providerID: providerID ?? sourcePool,
            retrievalScore: 0.5,
            coarseReasonTags: [.context, .policy],
            metadata: [
                MatchingDebugField(key: "source_pool", value: sourcePool),
                MatchingDebugField(key: "domain_key", value: domainKey ?? objectKind.rawValue),
            ]
        )
        self.constraints = constraints
        self.utilityProfile = utilityProfile
    }
}

enum MatchingReasonCode: String, Hashable {
    case sessionIntentMatch
    case recentPositiveSignal
    case eligibleNow
    case lowFrictionAction
    case timeOfDayFit
    case healthReady
    case explorationCandidate
    case diversifiedMix
    case routeContinuation
    case searchContinuation
    case rejectionPenalty
    case alreadyHandled
    case limitedAvailability
    case fatiguePenalty

    var userFacingText: String {
        switch self {
        case .sessionIntentMatch:
            return "Matches the current session intent"
        case .recentPositiveSignal:
            return "Aligned with recent recurring behavior"
        case .eligibleNow:
            return "Available in the current context"
        case .lowFrictionAction:
            return "A low-friction next step"
        case .timeOfDayFit:
            return "Fits the current time of day"
        case .healthReady:
            return "Grounded health context is available"
        case .explorationCandidate:
            return "Included as a controlled exploration pick"
        case .diversifiedMix:
            return "Kept to widen the recommendation mix"
        case .routeContinuation:
            return "Extends the current route or place decision"
        case .searchContinuation:
            return "Helps answer the next question with search-style context"
        case .rejectionPenalty:
            return "Penalized because similar suggestions were recently ignored"
        case .alreadyHandled:
            return "Held back because this task appears to be already handled"
        case .limitedAvailability:
            return "Availability is limited right now"
        case .fatiguePenalty:
            return "Down-ranked because this category was recently deprioritized"
        }
    }

    var category: MatchingReasonCategory {
        switch self {
        case .sessionIntentMatch, .routeContinuation, .searchContinuation:
            return .context
        case .recentPositiveSignal, .rejectionPenalty, .alreadyHandled, .fatiguePenalty:
            return .behavior
        case .timeOfDayFit:
            return .temporal
        case .eligibleNow, .healthReady, .limitedAvailability:
            return .availability
        case .explorationCandidate, .diversifiedMix:
            return .exploration
        case .lowFrictionAction:
            return .policy
        }
    }
}

struct MatchingConstraintDecision: Hashable {
    let isEligible: Bool
    let eligibilityScore: Double
    let reasonCodes: [MatchingReasonCode]
}

struct MatchingScoreBreakdown: Hashable {
    let globalEligibility: Double
    let domainUtility: Double
    let nextStepValue: Double
    let explorationBoost: Double
    let diversityPenalty: Double
    let finalScore: Double
    let confidence: Double
    let reasonCodes: [MatchingReasonCode]
    let debugPayload: MatchingScoringDebugPayload
    let contribution: ScoreContributionBreakdown
}

struct UnifiedMatchRecommendation: Identifiable, Hashable {
    let id: String
    let candidate: UnifiedMatchingCandidate
    let breakdown: MatchingScoreBreakdown
    let package: MatchingRecommendationPackage
    let rank: Int

    init(
        candidate: UnifiedMatchingCandidate,
        breakdown: MatchingScoreBreakdown,
        package: MatchingRecommendationPackage,
        rank: Int
    ) {
        self.id = candidate.id
        self.candidate = candidate
        self.breakdown = breakdown
        self.package = package
        self.rank = rank
    }
}

struct MatchingReplaySnapshot {
    let label: String
    let recentPrompt: String?
    let capturedAt: Date
    let session: ChatSession
    let healthAvailability: MatchingHealthAvailability
    let locationState: MatchingLocationState
    let motionContext: MatchingMotionContext
    let activeSurface: AppSection
    let returnContextState: ExecutionReturnContextState?
    let behaviorLog: [MatchingBehaviorEvent]
}

struct MatchingReplayFrame: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let context: MatchingFeatureContext
    let recommendations: [UnifiedMatchRecommendation]
}

enum MatchingFeatureSchema {
    static let version = MatchingKernelBaseline.current.featureSchemaVersion
}

struct MatchingStrategyDescriptor: Hashable {
    let id: String
    let providerVersions: [String]
    let constraintVersion: String
    let scorerVersion: String
    let diversifierVersion: String
    let composerVersion: String
    let featureSchemaVersion: String
}

struct MatchingProviderOutput: Hashable {
    let providerID: String
    let versionID: String
    let candidateCount: Int
    let candidateIDs: [String]
}

enum MatchingPipelineDropStage: String, Hashable {
    case constraints
    case scoringThreshold
}

struct MatchingDroppedCandidate: Hashable {
    let candidate: UnifiedMatchingCandidate
    let stage: MatchingPipelineDropStage
    let reasonCodes: [MatchingReasonCode]
    let score: Double?
}

struct MatchingReplayScenario: Identifiable {
    let id: UUID
    let label: String
    let snapshot: MatchingReplaySnapshot
    let recentEventsWindow: [MatchingBehaviorEvent]
    var groundTruthEvents: [MatchingBehaviorEvent]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        label: String,
        snapshot: MatchingReplaySnapshot,
        recentEventsWindow: [MatchingBehaviorEvent],
        groundTruthEvents: [MatchingBehaviorEvent] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.label = label
        self.snapshot = snapshot
        self.recentEventsWindow = recentEventsWindow
        self.groundTruthEvents = groundTruthEvents
        self.createdAt = createdAt
    }
}

struct MatchingReplayRun {
    let roleID: String
    let roleTitle: String
    let strategy: MatchingStrategyDescriptor
    let context: MatchingFeatureContext
    let providerOutput: [MatchingProviderOutput]
    let candidateCount: Int
    let filteredCandidates: [MatchingDroppedCandidate]
    let scoredCandidates: [ScoredMatchCandidate]
    let recommendations: [UnifiedMatchRecommendation]
}

enum MatchingReplayRankChangeKind: String, Hashable {
    case added
    case removed
    case up
    case down
    case unchanged
}

struct MatchingReplayRankShift: Identifiable, Hashable {
    var id: String { candidateID }

    let candidateID: String
    let title: String
    let objectKind: MatchingObjectKind
    let baselineRank: Int?
    let candidateRank: Int?
    let baselineScore: Double?
    let candidateScore: Double?
    let baselineConfidence: Double?
    let candidateConfidence: Double?
    let kind: MatchingReplayRankChangeKind
    let reasonDelta: [MatchingReasonCode]
}

struct MatchingReplayTypeDelta: Identifiable, Hashable {
    var id: String { objectKind.rawValue }

    let objectKind: MatchingObjectKind
    let baselineCount: Int
    let candidateCount: Int
}

struct MatchingReplayDiffSummary {
    let topKOverlap: Int
    let addedCandidateIDs: [String]
    let removedCandidateIDs: [String]
    let rankShifts: [MatchingReplayRankShift]
    let typeDeltas: [MatchingReplayTypeDelta]
}

enum MatchingOutcomeAlignmentLevel: Int, Hashable, Comparable {
    case notAligned = 0
    case weaklyAligned = 1
    case sameTaskFamily = 2
    case directMatch = 3

    static func < (
        lhs: MatchingOutcomeAlignmentLevel,
        rhs: MatchingOutcomeAlignmentLevel
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .notAligned:
            return "Not aligned"
        case .weaklyAligned:
            return "Weakly aligned"
        case .sameTaskFamily:
            return "Same task family"
        case .directMatch:
            return "Direct match"
        }
    }
}

struct MatchingObservedOutcome {
    let events: [MatchingBehaviorEvent]
    let candidateIDs: [String]
    let acceptedCandidateIDs: [String]
    let completedCandidateIDs: [String]
    let dismissedCandidateIDs: [String]
    let primaryObjectKind: MatchingObjectKind?
    let primaryTags: Set<MatchingIntentTag>
    let surfaces: Set<AppSection>
    let didAccept: Bool
    let didComplete: Bool
    let totalDownstreamValue: Double
    let hadExplicitDismiss: Bool
}

struct MatchingReplayOutcomeAlignment {
    let level: MatchingOutcomeAlignmentLevel
    let chosenItemHitAtK: Bool
    let acceptedPathHitAtK: Bool
    let completedPathHitAtK: Bool
    let firstRelevantPosition: Int?
    let taskProgressionAlignment: Double
}

enum MatchingReplayVerdict: String {
    case baselineCloser
    case candidateCloser
    case uncertain

    var title: String {
        switch self {
        case .baselineCloser:
            return "Baseline more aligned"
        case .candidateCloser:
            return "Candidate more aligned"
        case .uncertain:
            return "Uncertain"
        }
    }
}

struct MatchingReplayComparison {
    let scenario: MatchingReplayScenario
    let baselineRun: MatchingReplayRun
    let candidateRun: MatchingReplayRun
    let diffSummary: MatchingReplayDiffSummary
    let observedOutcome: MatchingObservedOutcome
    let baselineAlignment: MatchingReplayOutcomeAlignment
    let candidateAlignment: MatchingReplayOutcomeAlignment
    let verdict: MatchingReplayVerdict
}

enum MatchingReplaySliceDimension: String, CaseIterable, Hashable {
    case objectKind
    case daypart
    case locationState
    case healthAvailability
    case motionContext
    case threadDepth
    case explicitNegativeFeedback

    var title: String {
        switch self {
        case .objectKind:
            return "Object type"
        case .daypart:
            return "Daypart"
        case .locationState:
            return "Location"
        case .healthAvailability:
            return "Health"
        case .motionContext:
            return "Motion"
        case .threadDepth:
            return "Thread depth"
        case .explicitNegativeFeedback:
            return "Explicit negative feedback"
        }
    }
}

struct MatchingReplayAggregateMetrics {
    let scenarioCount: Int
    let baselineChosenItemHitRate: Double
    let candidateChosenItemHitRate: Double
    let baselineAcceptedPathHitRate: Double
    let candidateAcceptedPathHitRate: Double
    let baselineCompletedPathHitRate: Double
    let candidateCompletedPathHitRate: Double
    let baselineTaskFamilyAlignmentRate: Double
    let candidateTaskFamilyAlignmentRate: Double
    let baselineDirectMatchRate: Double
    let candidateDirectMatchRate: Double
    let baselineWeaklyAlignedRate: Double
    let candidateWeaklyAlignedRate: Double
    let baselineNotAlignedRate: Double
    let candidateNotAlignedRate: Double
    let baselineAverageTaskProgressionAlignment: Double
    let candidateAverageTaskProgressionAlignment: Double
    let averageTopKOverlap: Double
    let averageAbsoluteRankShift: Double
    let baselineObjectTypeConcentration: Double
    let candidateObjectTypeConcentration: Double

    static let empty = MatchingReplayAggregateMetrics(
        scenarioCount: 0,
        baselineChosenItemHitRate: 0,
        candidateChosenItemHitRate: 0,
        baselineAcceptedPathHitRate: 0,
        candidateAcceptedPathHitRate: 0,
        baselineCompletedPathHitRate: 0,
        candidateCompletedPathHitRate: 0,
        baselineTaskFamilyAlignmentRate: 0,
        candidateTaskFamilyAlignmentRate: 0,
        baselineDirectMatchRate: 0,
        candidateDirectMatchRate: 0,
        baselineWeaklyAlignedRate: 0,
        candidateWeaklyAlignedRate: 0,
        baselineNotAlignedRate: 0,
        candidateNotAlignedRate: 0,
        baselineAverageTaskProgressionAlignment: 0,
        candidateAverageTaskProgressionAlignment: 0,
        averageTopKOverlap: 0,
        averageAbsoluteRankShift: 0,
        baselineObjectTypeConcentration: 0,
        candidateObjectTypeConcentration: 0
    )
}

struct MatchingReplaySliceRow: Identifiable, Hashable {
    let id: String
    let valueID: String
    let title: String
    let scenarioCount: Int
    let baselineAverageTaskProgressionAlignment: Double
    let candidateAverageTaskProgressionAlignment: Double
    let baselineCompletedPathHitRate: Double
    let candidateCompletedPathHitRate: Double
    let baselineNotAlignedRate: Double
    let candidateNotAlignedRate: Double
}

struct MatchingReplaySliceGroup: Identifiable, Hashable {
    var id: String { dimension.rawValue }

    let dimension: MatchingReplaySliceDimension
    let rows: [MatchingReplaySliceRow]
}

struct MatchingReplayCaseDelta: Identifiable, Hashable {
    var id: UUID { scenarioID }

    let scenarioID: UUID
    let label: String
    let prompt: String
    let primaryObjectKind: MatchingObjectKind?
    let delta: Double
    let baselineAlignment: MatchingOutcomeAlignmentLevel
    let candidateAlignment: MatchingOutcomeAlignmentLevel
    let verdict: MatchingReplayVerdict
    let topKOverlap: Int
    let hadExplicitDismiss: Bool
    let didComplete: Bool

    var exportLine: String {
        let objectKindTitle = primaryObjectKind?.title ?? "Unknown"
        return "\(label) | \(objectKindTitle) | delta \(String(format: "%.2f", delta)) | \(baselineAlignment.title) -> \(candidateAlignment.title)"
    }
}

enum MatchingReplayOfflineGateStatus: String, Hashable {
    case pass
    case fail
    case insufficientData

    var title: String {
        switch self {
        case .pass:
            return "Pass"
        case .fail:
            return "Fail"
        case .insufficientData:
            return "Insufficient data"
        }
    }
}

struct MatchingReplayOfflineGate: Hashable {
    let status: MatchingReplayOfflineGateStatus
    let summary: String
    let reasons: [String]
}

struct MatchingReplayBatchReport {
    let trackedScenarioCount: Int
    let evaluatedScenarioCount: Int
    let aggregateMetrics: MatchingReplayAggregateMetrics
    let sliceGroups: [MatchingReplaySliceGroup]
    let topImprovements: [MatchingReplayCaseDelta]
    let topRegressions: [MatchingReplayCaseDelta]
    let offlineGate: MatchingReplayOfflineGate
    let generatedAt: Date
}
