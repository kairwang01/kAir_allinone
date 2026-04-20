//
//  UnifiedMatchingEngine.swift
//  kAir
//
//  Explicit matching pipeline orchestration for content, services, and next-step entry points.
//

import Foundation

struct MatchingEvaluation {
    let strategy: MatchingStrategyDescriptor
    let context: MatchingFeatureContext
    let providerOutput: [MatchingProviderOutput]
    let candidateCount: Int
    let droppedCandidates: [MatchingDroppedCandidate]
    let scoredCandidates: [ScoredMatchCandidate]
    let recommendations: [UnifiedMatchRecommendation]
}

struct UnifiedMatchingEngine {
    let strategyID: String
    let policyVersion: MatchingPolicyVersion
    let candidateProviders: [any CandidateProvider]
    let constraintEvaluator: any ConstraintEvaluator
    let scoringPolicy: any ScoringPolicy
    let diversifier: any Diversifier
    let composer: any RecommendationComposer

    init(
        strategyID: String = "retrieval-provider-v1",
        policyVersion: MatchingPolicyVersion = .current,
        candidateProviders: [any CandidateProvider] = .retrievalMatchingProviders,
        constraintEvaluator: any ConstraintEvaluator = DefaultConstraintEvaluator(),
        scoringPolicy: (any ScoringPolicy)? = nil,
        diversifier: any Diversifier = HeuristicDiversifier(),
        composer: any RecommendationComposer = DefaultRecommendationComposer()
    ) {
        self.strategyID = strategyID
        self.policyVersion = policyVersion
        self.candidateProviders = candidateProviders
        self.constraintEvaluator = constraintEvaluator
        self.scoringPolicy = scoringPolicy ?? HeuristicScoringPolicy(policy: policyVersion)
        self.diversifier = diversifier
        self.composer = composer
    }

    var descriptor: MatchingStrategyDescriptor {
        MatchingStrategyDescriptor(
            id: strategyID,
            providerVersions: candidateProviders.map { "\($0.id)@\($0.versionID)" },
            constraintVersion: constraintEvaluator.versionID,
            scorerVersion: scoringPolicy.versionID,
            diversifierVersion: diversifier.versionID,
            composerVersion: composer.versionID,
            featureSchemaVersion: MatchingFeatureSchema.version
        )
    }

    func recommend(
        recentPrompt: String?,
        session: ChatSession,
        healthAvailability: MatchingHealthAvailability,
        locationState: MatchingLocationState,
        motionContext: MatchingMotionContext,
        behaviorLog: [MatchingBehaviorEvent],
        returnContextState: ExecutionReturnContextState? = nil,
        activeSurface: AppSection = .chat,
        now: Date = .now,
        limit: Int = 4
    ) -> [UnifiedMatchRecommendation] {
        evaluate(
            recentPrompt: recentPrompt,
            session: session,
            healthAvailability: healthAvailability,
            locationState: locationState,
            motionContext: motionContext,
            behaviorLog: behaviorLog,
            returnContextState: returnContextState,
            activeSurface: activeSurface,
            now: now,
            limit: limit
        ).recommendations
    }

    func decide(
        recentPrompt: String?,
        session: ChatSession,
        healthAvailability: MatchingHealthAvailability,
        locationState: MatchingLocationState,
        motionContext: MatchingMotionContext,
        behaviorLog: [MatchingBehaviorEvent],
        returnContextState: ExecutionReturnContextState? = nil,
        activeSurface: AppSection = .chat,
        now: Date = .now,
        limit: Int = 4
    ) -> RecommendationDecision {
        let evaluation = evaluate(
            recentPrompt: recentPrompt,
            session: session,
            healthAvailability: healthAvailability,
            locationState: locationState,
            motionContext: motionContext,
            behaviorLog: behaviorLog,
            returnContextState: returnContextState,
            activeSurface: activeSurface,
            now: now,
            limit: limit
        )
        return RecommendationDecisionBuilder.build(
            recentPrompt: recentPrompt,
            activeSurface: activeSurface,
            context: evaluation.context,
            scoredCandidates: evaluation.scoredCandidates,
            recommendations: evaluation.recommendations,
            policyVersion: policyVersion,
            now: now
        )
    }

    func decide(
        snapshot: MatchingReplaySnapshot,
        now: Date? = nil,
        limit: Int = 4
    ) -> RecommendationDecision {
        decide(
            recentPrompt: snapshot.recentPrompt,
            session: snapshot.session,
            healthAvailability: snapshot.healthAvailability,
            locationState: snapshot.locationState,
            motionContext: snapshot.motionContext,
            behaviorLog: snapshot.behaviorLog,
            returnContextState: snapshot.returnContextState,
            activeSurface: snapshot.activeSurface,
            now: now ?? snapshot.capturedAt,
            limit: limit
        )
    }

    struct DecisionWithSnapshot {
        let decision: RecommendationDecision
        let contextSnapshot: MatchingContextSnapshot
    }

    func decideWithSnapshot(
        recentPrompt: String?,
        session: ChatSession,
        healthAvailability: MatchingHealthAvailability,
        locationState: MatchingLocationState,
        motionContext: MatchingMotionContext,
        behaviorLog: [MatchingBehaviorEvent],
        returnContextState: ExecutionReturnContextState? = nil,
        activeSurface: AppSection = .chat,
        now: Date = .now,
        limit: Int = 4
    ) -> DecisionWithSnapshot {
        let evaluation = evaluate(
            recentPrompt: recentPrompt,
            session: session,
            healthAvailability: healthAvailability,
            locationState: locationState,
            motionContext: motionContext,
            behaviorLog: behaviorLog,
            returnContextState: returnContextState,
            activeSurface: activeSurface,
            now: now,
            limit: limit
        )
        let decision = RecommendationDecisionBuilder.build(
            recentPrompt: recentPrompt,
            activeSurface: activeSurface,
            context: evaluation.context,
            scoredCandidates: evaluation.scoredCandidates,
            recommendations: evaluation.recommendations,
            policyVersion: policyVersion,
            now: now
        )
        let contextSnapshot = MatchingContextSnapshot.capture(
            prompt: recentPrompt ?? "",
            context: evaluation.context,
            behaviorLog: behaviorLog,
            policy: policyVersion,
            now: now
        )
        return DecisionWithSnapshot(decision: decision, contextSnapshot: contextSnapshot)
    }

    func evaluate(
        snapshot: MatchingReplaySnapshot,
        now: Date? = nil,
        limit: Int = 4
    ) -> MatchingEvaluation {
        evaluate(
            recentPrompt: snapshot.recentPrompt,
            session: snapshot.session,
            healthAvailability: snapshot.healthAvailability,
            locationState: snapshot.locationState,
            motionContext: snapshot.motionContext,
            behaviorLog: snapshot.behaviorLog,
            returnContextState: snapshot.returnContextState,
            activeSurface: snapshot.activeSurface,
            now: now ?? snapshot.capturedAt,
            limit: limit
        )
    }

    func evaluate(
        recentPrompt: String?,
        session: ChatSession,
        healthAvailability: MatchingHealthAvailability,
        locationState: MatchingLocationState,
        motionContext: MatchingMotionContext,
        behaviorLog: [MatchingBehaviorEvent],
        returnContextState: ExecutionReturnContextState? = nil,
        activeSurface: AppSection = .chat,
        now: Date = .now,
        limit: Int = 4
    ) -> MatchingEvaluation {
        let context = makeContext(
            recentPrompt: recentPrompt,
            session: session,
            healthAvailability: healthAvailability,
            locationState: locationState,
            motionContext: motionContext,
            behaviorLog: behaviorLog,
            returnContextState: returnContextState,
            activeSurface: activeSurface,
            now: now
        )

        let providerResults = candidateProviders.map { provider in
            let candidates = provider.generateCandidates(for: context)
            return (
                MatchingProviderOutput(
                    providerID: provider.id,
                    versionID: provider.versionID,
                    candidateCount: candidates.count,
                    candidateIDs: candidates.map(\.id)
                ),
                candidates
            )
        }

        let candidates = providerResults.flatMap(\.1)
        var droppedCandidates: [MatchingDroppedCandidate] = []

        let scoredCandidates = candidates
            .compactMap { candidate -> ScoredMatchCandidate? in
                let decision = constraintEvaluator.evaluate(
                    candidate: candidate,
                    in: context
                )

                guard decision.isEligible else {
                    droppedCandidates.append(
                        MatchingDroppedCandidate(
                            candidate: candidate,
                            stage: .constraints,
                            reasonCodes: decision.reasonCodes,
                            score: nil
                        )
                    )
                    return nil
                }

                let scoringInput = makeScoringInput(
                    for: candidate,
                    in: context
                )
                let breakdown = scoringPolicy.score(
                    candidate: candidate,
                    constraintDecision: decision,
                    scoringInput: scoringInput,
                    in: context
                )

                guard breakdown.finalScore > 0.05 else {
                    droppedCandidates.append(
                        MatchingDroppedCandidate(
                            candidate: candidate,
                            stage: .scoringThreshold,
                            reasonCodes: breakdown.reasonCodes,
                            score: breakdown.finalScore
                        )
                    )
                    return nil
                }

                return ScoredMatchCandidate(
                    candidate: candidate,
                    constraintDecision: decision,
                    breakdown: breakdown
                )
            }
            .sorted { lhs, rhs in
                lhs.breakdown.finalScore > rhs.breakdown.finalScore
            }

        let diversified = diversifier.diversify(
            scoredCandidates: scoredCandidates,
            in: context,
            limit: limit
        )

        return MatchingEvaluation(
            strategy: descriptor,
            context: context,
            providerOutput: providerResults.map(\.0),
            candidateCount: candidates.count,
            droppedCandidates: droppedCandidates,
            scoredCandidates: scoredCandidates,
            recommendations: composer.compose(
                scoredCandidates: diversified,
                in: context
            )
        )
    }

    func intentTags(for text: String) -> Set<MatchingIntentTag> {
        Self.extractIntentTags(from: text)
    }

    static func extractIntentTags(from text: String) -> Set<MatchingIntentTag> {
        let normalized = text.lowercased()
        var tags: Set<MatchingIntentTag> = []

        if [
            "map", "maps", "route", "navigate", "parking", "nearby", "restaurant", "cafe", "pharmacy", "go to",
        ].contains(where: normalized.contains) || ["地图", "路线", "导航", "停车", "附近", "餐厅", "咖啡", "药店"].contains(where: text.contains) {
            tags.formUnion([.navigation, .localDiscovery])
        }

        if [
            "plan", "tonight", "schedule", "meet", "reservation", "book",
        ].contains(where: normalized.contains) || ["今晚", "安排", "计划", "见朋友", "订位"].contains(where: text.contains) {
            tags.insert(.planning)
        }

        if [
            "focus", "deep work", "study", "concentrate",
        ].contains(where: normalized.contains) || ["专注", "学习", "工作"].contains(where: text.contains) {
            tags.insert(.focus)
        }

        if [
            "relax", "calm", "ambient", "wind down",
        ].contains(where: normalized.contains) || ["放松", "安静", "氛围"].contains(where: text.contains) {
            tags.insert(.relaxation)
        }

        if [
            "music", "playlist", "song", "jazz", "spotify",
        ].contains(where: normalized.contains) || ["音乐", "歌", "歌单", "爵士"].contains(where: text.contains) {
            tags.insert(.entertainment)
        }

        if [
            "video", "tutorial", "guide", "show me", "watch", "demo",
        ].contains(where: normalized.contains) || ["视频", "教程", "演示", "示范"].contains(where: text.contains) {
            tags.insert(.learning)
        }

        if [
            "buy", "shop", "store", "supplement", "wearable",
        ].contains(where: normalized.contains) || ["购买", "商店", "补剂", "穿戴"].contains(where: text.contains) {
            tags.insert(.shopping)
        }

        if [
            "health", "sleep", "heart", "recovery", "workout", "stress",
        ].contains(where: normalized.contains) || ["健康", "睡眠", "心率", "恢复", "运动", "压力"].contains(where: text.contains) {
            tags.insert(.health)
        }

        if [
            "friend", "friends", "share", "group", "message",
        ].contains(where: normalized.contains) || ["朋友", "分享", "群", "消息"].contains(where: text.contains) {
            tags.insert(.social)
        }

        if [
            "search", "find", "look up", "why", "explain",
        ].contains(where: normalized.contains) || ["搜索", "查", "解释", "为什么"].contains(where: text.contains) {
            tags.insert(.search)
        }

        if [
            "ai", "model", "runtime", "agent", "route",
        ].contains(where: normalized.contains) || ["模型", "AI", "路由", "运行时"].contains(where: text.contains) {
            tags.insert(.ai)
        }

        if [
            "drive", "commute", "car",
        ].contains(where: normalized.contains) || ["开车", "通勤"].contains(where: text.contains) {
            tags.insert(.commute)
        }

        if tags.isEmpty {
            tags = [.planning, .search]
        }

        return tags
    }

    private func makeContext(
        recentPrompt: String?,
        session: ChatSession,
        healthAvailability: MatchingHealthAvailability,
        locationState: MatchingLocationState,
        motionContext: MatchingMotionContext,
        behaviorLog: [MatchingBehaviorEvent],
        returnContextState: ExecutionReturnContextState?,
        activeSurface: AppSection,
        now: Date
    ) -> MatchingFeatureContext {
        let recentTranscript = session.messages
            .suffix(6)
            .map(\.text)
            .joined(separator: " ")

        let sessionIntentTags = Self.extractIntentTags(
            from: [recentPrompt, recentTranscript]
                .compactMap { $0 }
                .joined(separator: " ")
        )

        let foldedIntentTags = Set(returnContextState?.addedIntentTags ?? [])

        let recentEvents = behaviorLog.suffix(8)
        let recencyTags = Set(recentEvents.flatMap(\.tags)).union(foldedIntentTags)

        let weightedTags = Dictionary(grouping: behaviorLog.flatMap { event in
            event.tags.map { ($0, event.learningWeight) }
        }, by: \.0)

        let longTermTags = Set(
            weightedTags.compactMap { entry in
                let score = entry.value.reduce(0) { partial, next in
                    partial + next.1
                }
                return score >= 0.9 ? entry.key : nil
            }
        )

        var crossSurfaceTransitions = Dictionary(grouping: behaviorLog.compactMap { event in
            event.subject == .surface || event.subject == .route ? event.surface : nil
        }, by: { $0 })
        .mapValues(\.count)

        let affinityRaw = behaviorLog.reduce(into: [MatchingObjectKind: Double]()) { partial, event in
            guard let objectKind = event.objectKind else { return }
            partial[objectKind, default: 0] += event.learningWeight
        }

        let maxAffinity = max(affinityRaw.values.max() ?? 0, 1)
        let objectTypeAffinity = affinityRaw.mapValues { value in
            max(0, min(1, value / maxAffinity))
        }

        let fatigueRaw = behaviorLog.reduce(into: [MatchingObjectKind: Double]()) { partial, event in
            guard let objectKind = event.objectKind else { return }
            guard event.stage == .dismiss || event.stage == .abandon else { return }

            switch event.feedback {
            case .lessLikeThis:
                partial[objectKind, default: 0] += 0.55
            case .notInterested:
                partial[objectKind, default: 0] += 0.3
            case .notNow:
                partial[objectKind, default: 0] += 0.12
            case .dismiss, .alreadyDone, .none:
                partial[objectKind, default: 0] += 0.08
            }
        }
        let objectTypeFatigue = fatigueRaw.mapValues { value in
            max(0, min(1, value))
        }

        var recentRejectedCandidateIDs = Set(
            behaviorLog.suffix(12).compactMap { event in
                switch event.stage {
                case .dismiss, .abandon:
                    return event.candidateID
                case .impression, .click, .accept, .completion:
                    return nil
                }
            }
        )
        recentRejectedCandidateIDs.formUnion(returnContextState?.dismissedObjectIds ?? [])
        recentRejectedCandidateIDs.subtract(returnContextState?.resolvedObjectIds ?? [])

        var recentCompletedCandidateIDs = Set(
            behaviorLog.suffix(12).compactMap { event in
                event.stage == .completion ? event.candidateID : nil
            }
        )
        recentCompletedCandidateIDs.formUnion(returnContextState?.resolvedObjectIds ?? [])
        recentCompletedCandidateIDs.subtract(returnContextState?.dismissedObjectIds ?? [])

        let recentFeedbackByCandidate = behaviorLog.suffix(16).reduce(into: [String: MatchingFeedbackKind]()) { partial, event in
            guard let candidateID = event.candidateID, let feedback = event.feedback else {
                return
            }
            partial[candidateID] = feedback
        }

        var executionSurfaceStates: [AppSection: ExecutionReturnContextState.SurfaceState] = [:]
        for state in returnContextState?.surfaceStates ?? [] {
            executionSurfaceStates[state.section] = state
            if state.outcome == .completed || state.outcome == .partial {
                crossSurfaceTransitions[state.section, default: 0] += 1
            }
        }

        return MatchingFeatureContext(
            recentPrompt: recentPrompt,
            activeSurface: activeSurface,
            messageCount: session.messages.count,
            daypart: MatchingDaypart.resolve(from: now),
            weekday: Calendar.current.component(.weekday, from: now),
            locationState: locationState,
            healthAvailability: healthAvailability,
            motionContext: motionContext,
            sessionIntentTags: sessionIntentTags.union(foldedIntentTags),
            recencyTags: recencyTags,
            longTermTags: longTermTags,
            crossSurfaceTransitions: crossSurfaceTransitions,
            objectTypeAffinity: objectTypeAffinity,
            objectTypeFatigue: objectTypeFatigue,
            recentRejectedCandidateIDs: recentRejectedCandidateIDs,
            recentCompletedCandidateIDs: recentCompletedCandidateIDs,
            recentFeedbackByCandidate: recentFeedbackByCandidate,
            foldedIntentTags: foldedIntentTags,
            resolvedObjectIds: Set(returnContextState?.resolvedObjectIds ?? []),
            dismissedObjectIds: Set(returnContextState?.dismissedObjectIds ?? []),
            executionSurfaceStates: executionSurfaceStates,
            behaviorLog: Array(behaviorLog.suffix(48))
        )
    }

    private func makeScoringInput(
        for candidate: UnifiedMatchingCandidate,
        in context: MatchingFeatureContext
    ) -> MatchingScoringInput {
        MatchingScoringInput(
            userFeatures: [
                .init(key: "message_count", value: Double(context.messageCount)),
                .init(key: "long_term_tag_overlap", value: Double(candidate.tags.intersection(context.longTermTags).count)),
                .init(key: "object_affinity", value: context.objectTypeAffinity[candidate.objectKind, default: 0]),
            ],
            contextFeatures: [
                .init(key: "daypart_\(context.daypart.rawValue)", value: 1),
                .init(key: "weekday", value: Double(context.weekday)),
                .init(key: "health_\(context.healthAvailability.rawValue)", value: 1),
                .init(key: "location_\(context.locationState.rawValue)", value: 1),
                .init(key: "motion_\(context.motionContext.rawValue)", value: 1),
            ],
            candidateFeatures: [
                .init(key: "retrieval_score", value: candidate.retrieval.retrievalScore),
                .init(key: "domain_weight", value: candidate.utilityProfile.domainWeight),
                .init(key: "next_step_weight", value: candidate.utilityProfile.nextStepWeight),
                .init(key: "available_\(candidate.retrieval.availability.rawValue)", value: 1),
            ],
            interactionFeatures: [
                .init(key: "session_tag_overlap", value: Double(candidate.tags.intersection(context.sessionIntentTags).count)),
                .init(key: "recency_tag_overlap", value: Double(candidate.tags.intersection(context.recencyTags).count)),
                .init(key: "transition_momentum", value: Double(context.crossSurfaceTransitions[candidate.preferredSection ?? .chat, default: 0])),
            ],
            fatigueFeatures: [
                .init(key: "object_fatigue", value: context.objectTypeFatigue[candidate.objectKind, default: 0]),
                .init(key: "recent_rejection", value: context.recentRejectedCandidateIDs.contains(candidate.id) ? 1 : 0),
                .init(key: "recent_completion", value: context.recentCompletedCandidateIDs.contains(candidate.id) ? 1 : 0),
            ]
        )
    }
}
