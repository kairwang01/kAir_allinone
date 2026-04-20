//
//  MatchingReplayEngine.swift
//  kAir
//
//  Replay and comparison harness for matching decisions.
//

import Foundation

struct MatchingReplayStrategy {
    let roleID: String
    let roleTitle: String
    let engine: UnifiedMatchingEngine

    static let legacyBaseline = MatchingReplayStrategy(
        roleID: "legacy-baseline",
        roleTitle: "Legacy",
        engine: UnifiedMatchingEngine(
            strategyID: "heuristic-v1-baseline",
            policyVersion: .legacy,
            candidateProviders: .defaultMatchingProviders,
            scoringPolicy: LegacyHeuristicScoringPolicy()
        )
    )

    static let baseline = MatchingReplayStrategy(
        roleID: "baseline",
        roleTitle: "Baseline",
        engine: UnifiedMatchingEngine(
            strategyID: "baseline-v2.2-prompt-directness",
            policyVersion: .current,
            candidateProviders: .retrievalMatchingProvidersV4,
            scoringPolicy: HeuristicScoringPolicy(policy: .current)
        )
    )

    static let candidate = MatchingReplayStrategy(
        roleID: "candidate",
        roleTitle: "Candidate",
        engine: UnifiedMatchingEngine(
            strategyID: "scorer-v2.2-prompt-directness",
            policyVersion: .current,
            candidateProviders: .retrievalMatchingProvidersV4,
            scoringPolicy: HeuristicScoringPolicy(policy: .current)
        )
    )

    static let providerBaseline = MatchingReplayStrategy(
        roleID: "provider-baseline",
        roleTitle: "Provider Baseline",
        engine: UnifiedMatchingEngine(
            strategyID: "provider-baseline-v4-retrieval-lift",
            policyVersion: .providerBaseline,
            candidateProviders: .retrievalMatchingProvidersV4,
            scoringPolicy: HeuristicScoringPolicy(policy: .providerBaseline)
        )
    )
}

struct MatchingReplayEngine {
    func run(
        snapshot: MatchingReplaySnapshot,
        strategy: MatchingReplayStrategy = .candidate,
        now: Date? = nil,
        limit: Int = 5
    ) -> MatchingReplayRun {
        let evaluation = strategy.engine.evaluate(
            snapshot: snapshot,
            now: now,
            limit: limit
        )

        return MatchingReplayRun(
            roleID: strategy.roleID,
            roleTitle: strategy.roleTitle,
            strategy: evaluation.strategy,
            context: evaluation.context,
            providerOutput: evaluation.providerOutput,
            candidateCount: evaluation.candidateCount,
            filteredCandidates: evaluation.droppedCandidates,
            scoredCandidates: evaluation.scoredCandidates,
            recommendations: evaluation.recommendations
        )
    }

    func replay(
        snapshots: [MatchingReplaySnapshot],
        strategy: MatchingReplayStrategy = .candidate,
        now: Date? = nil,
        limit: Int = 4
    ) -> [MatchingReplayFrame] {
        snapshots.map { snapshot in
            let run = run(
                snapshot: snapshot,
                strategy: strategy,
                now: now,
                limit: limit
            )

            return MatchingReplayFrame(
                label: snapshot.label,
                context: run.context,
                recommendations: Array(run.recommendations.prefix(limit))
            )
        }
    }

    func compare(
        scenario: MatchingReplayScenario,
        baseline: MatchingReplayStrategy = .baseline,
        candidate: MatchingReplayStrategy = .candidate,
        now: Date? = nil,
        limit: Int = 5
    ) -> MatchingReplayComparison {
        let baselineRun = run(
            snapshot: scenario.snapshot,
            strategy: baseline,
            now: now,
            limit: limit
        )
        let candidateRun = run(
            snapshot: scenario.snapshot,
            strategy: candidate,
            now: now,
            limit: limit
        )
        let observedOutcome = observedOutcome(for: scenario)
        let baselineAlignment = alignment(
            for: baselineRun,
            observedOutcome: observedOutcome,
            limit: limit
        )
        let candidateAlignment = alignment(
            for: candidateRun,
            observedOutcome: observedOutcome,
            limit: limit
        )

        return MatchingReplayComparison(
            scenario: scenario,
            baselineRun: baselineRun,
            candidateRun: candidateRun,
            diffSummary: diffSummary(
                baseline: baselineRun,
                candidate: candidateRun,
                limit: limit
            ),
            observedOutcome: observedOutcome,
            baselineAlignment: baselineAlignment,
            candidateAlignment: candidateAlignment,
            verdict: verdict(
                baseline: baselineAlignment,
                candidate: candidateAlignment
            )
        )
    }

    private func diffSummary(
        baseline: MatchingReplayRun,
        candidate: MatchingReplayRun,
        limit: Int
    ) -> MatchingReplayDiffSummary {
        let baselineTop = Array(baseline.recommendations.prefix(limit))
        let candidateTop = Array(candidate.recommendations.prefix(limit))
        let baselineMap = Dictionary(uniqueKeysWithValues: baselineTop.map { ($0.id, $0) })
        let candidateMap = Dictionary(uniqueKeysWithValues: candidateTop.map { ($0.id, $0) })
        let baselineIDs = baselineTop.map(\.id)
        let candidateIDs = candidateTop.map(\.id)
        let sharedIDs = Set(baselineIDs).intersection(candidateIDs)
        let allIDs = baselineIDs + candidateIDs.filter { baselineIDs.contains($0) == false }

        let rankShifts = allIDs.compactMap { candidateID -> MatchingReplayRankShift? in
            let baselineEntry = baselineMap[candidateID]
            let candidateEntry = candidateMap[candidateID]

            guard let entry = candidateEntry ?? baselineEntry else {
                return nil
            }

            let kind: MatchingReplayRankChangeKind
            switch (baselineEntry?.rank, candidateEntry?.rank) {
            case (nil, .some):
                kind = .added
            case (.some, nil):
                kind = .removed
            case let (.some(lhs), .some(rhs)) where rhs < lhs:
                kind = .up
            case let (.some(lhs), .some(rhs)) where rhs > lhs:
                kind = .down
            default:
                kind = .unchanged
            }

            let reasonDelta = orderedUniqueReasonCodes(
                (baselineEntry?.breakdown.reasonCodes ?? []) +
                    (candidateEntry?.breakdown.reasonCodes ?? [])
            ).filter { reasonCode in
                let baselineHas = baselineEntry?.breakdown.reasonCodes.contains(reasonCode) ?? false
                let candidateHas = candidateEntry?.breakdown.reasonCodes.contains(reasonCode) ?? false
                return baselineHas != candidateHas
            }

            return MatchingReplayRankShift(
                candidateID: entry.id,
                title: entry.candidate.title,
                objectKind: entry.candidate.objectKind,
                baselineRank: baselineEntry?.rank,
                candidateRank: candidateEntry?.rank,
                baselineScore: baselineEntry?.breakdown.finalScore,
                candidateScore: candidateEntry?.breakdown.finalScore,
                baselineConfidence: baselineEntry?.breakdown.confidence,
                candidateConfidence: candidateEntry?.breakdown.confidence,
                kind: kind,
                reasonDelta: reasonDelta
            )
        }
        .sorted { lhs, rhs in
            rankShiftSort(lhs: lhs, rhs: rhs)
        }

        let allObjectKinds = Set(
            baselineTop.map(\.candidate.objectKind) + candidateTop.map(\.candidate.objectKind)
        )
        let typeDeltas = allObjectKinds
            .map { objectKind in
                MatchingReplayTypeDelta(
                    objectKind: objectKind,
                    baselineCount: baselineTop.filter { $0.candidate.objectKind == objectKind }.count,
                    candidateCount: candidateTop.filter { $0.candidate.objectKind == objectKind }.count
                )
            }
            .sorted { lhs, rhs in
                lhs.objectKind.rawValue < rhs.objectKind.rawValue
            }

        return MatchingReplayDiffSummary(
            topKOverlap: sharedIDs.count,
            addedCandidateIDs: candidateIDs.filter { baselineIDs.contains($0) == false },
            removedCandidateIDs: baselineIDs.filter { candidateIDs.contains($0) == false },
            rankShifts: rankShifts,
            typeDeltas: typeDeltas
        )
    }

    private func observedOutcome(
        for scenario: MatchingReplayScenario
    ) -> MatchingObservedOutcome {
        let candidateIDs = scenario.groundTruthEvents.compactMap(\.candidateID)
        let acceptedCandidateIDs = scenario.groundTruthEvents.compactMap { event in
            switch event.stage {
            case .accept, .completion:
                return event.candidateID
            case .impression, .click, .dismiss, .abandon:
                return nil
            }
        }
        let completedCandidateIDs = scenario.groundTruthEvents.compactMap { event in
            event.stage == .completion ? event.candidateID : nil
        }
        let dismissedCandidateIDs = scenario.groundTruthEvents.compactMap { event in
            event.stage == .dismiss ? event.candidateID : nil
        }

        let prioritizedEvents = scenario.groundTruthEvents.sorted { lhs, rhs in
            priority(for: lhs.stage) > priority(for: rhs.stage)
        }
        let primaryObjectKind = prioritizedEvents.compactMap(\.objectKind).first
        let primaryTags = Set(scenario.groundTruthEvents.flatMap(\.tags))
        let surfaces = Set(scenario.groundTruthEvents.compactMap(\.surface))
        let totalDownstreamValue = scenario.groundTruthEvents.reduce(0) { partial, event in
            partial + event.outcome.downstreamValue
        }

        return MatchingObservedOutcome(
            events: scenario.groundTruthEvents,
            candidateIDs: candidateIDs,
            acceptedCandidateIDs: acceptedCandidateIDs,
            completedCandidateIDs: completedCandidateIDs,
            dismissedCandidateIDs: dismissedCandidateIDs,
            primaryObjectKind: primaryObjectKind,
            primaryTags: primaryTags,
            surfaces: surfaces,
            didAccept: acceptedCandidateIDs.isEmpty == false,
            didComplete: completedCandidateIDs.isEmpty == false,
            totalDownstreamValue: totalDownstreamValue,
            hadExplicitDismiss: scenario.groundTruthEvents.contains { $0.stage == .dismiss }
        )
    }

    private func alignment(
        for run: MatchingReplayRun,
        observedOutcome: MatchingObservedOutcome,
        limit: Int
    ) -> MatchingReplayOutcomeAlignment {
        let topRecommendations = Array(run.recommendations.prefix(limit))
        let chosenSet = Set(observedOutcome.candidateIDs)
        let acceptedSet = Set(observedOutcome.acceptedCandidateIDs)
        let completedSet = Set(observedOutcome.completedCandidateIDs)

        let directPosition = topRecommendations.firstIndex { recommendation in
            chosenSet.contains(recommendation.id)
        }
        let sameFamilyPosition = topRecommendations.firstIndex { recommendation in
            recommendation.candidate.objectKind == observedOutcome.primaryObjectKind
        }
        let weakPosition = topRecommendations.firstIndex { recommendation in
            recommendation.candidate.tags.isDisjoint(with: observedOutcome.primaryTags) == false ||
                recommendation.candidate.preferredSection.map { section in
                    observedOutcome.surfaces.contains(section)
                } == true
        }

        let level: MatchingOutcomeAlignmentLevel
        let firstRelevantPosition: Int?

        if let directPosition {
            level = .directMatch
            firstRelevantPosition = directPosition + 1
        } else if let sameFamilyPosition {
            level = .sameTaskFamily
            firstRelevantPosition = sameFamilyPosition + 1
        } else if let weakPosition {
            level = .weaklyAligned
            firstRelevantPosition = weakPosition + 1
        } else {
            level = .notAligned
            firstRelevantPosition = nil
        }

        let chosenItemHitAtK = topRecommendations.contains { chosenSet.contains($0.id) }
        let acceptedPathHitAtK = topRecommendations.contains { acceptedSet.contains($0.id) }
        let completedPathHitAtK = topRecommendations.contains { completedSet.contains($0.id) }

        var alignmentScore = Double(level.rawValue) * 0.22
        alignmentScore += chosenItemHitAtK ? 0.18 : 0
        alignmentScore += acceptedPathHitAtK ? 0.16 : 0
        alignmentScore += completedPathHitAtK ? 0.24 : 0

        if let firstRelevantPosition {
            alignmentScore += max(0, 0.18 - Double(firstRelevantPosition - 1) * 0.04)
        }

        alignmentScore = min(1, alignmentScore)

        return MatchingReplayOutcomeAlignment(
            level: level,
            chosenItemHitAtK: chosenItemHitAtK,
            acceptedPathHitAtK: acceptedPathHitAtK,
            completedPathHitAtK: completedPathHitAtK,
            firstRelevantPosition: firstRelevantPosition,
            taskProgressionAlignment: alignmentScore
        )
    }

    private func verdict(
        baseline: MatchingReplayOutcomeAlignment,
        candidate: MatchingReplayOutcomeAlignment
    ) -> MatchingReplayVerdict {
        let baselineScore = baseline.taskProgressionAlignment
        let candidateScore = candidate.taskProgressionAlignment

        if abs(candidateScore - baselineScore) < 0.08 {
            return .uncertain
        }

        return candidateScore > baselineScore ? .candidateCloser : .baselineCloser
    }

    private func priority(for stage: MatchingBehaviorEvent.Stage) -> Int {
        switch stage {
        case .completion:
            return 5
        case .accept:
            return 4
        case .click:
            return 3
        case .dismiss:
            return 2
        case .abandon:
            return 1
        case .impression:
            return 0
        }
    }

    private func rankShiftSort(
        lhs: MatchingReplayRankShift,
        rhs: MatchingReplayRankShift
    ) -> Bool {
        let lhsRank = lhs.candidateRank ?? lhs.baselineRank ?? .max
        let rhsRank = rhs.candidateRank ?? rhs.baselineRank ?? .max

        if lhsRank == rhsRank {
            return lhs.title < rhs.title
        }

        return lhsRank < rhsRank
    }

    private func orderedUniqueReasonCodes(
        _ reasonCodes: [MatchingReasonCode]
    ) -> [MatchingReasonCode] {
        var seen: Set<MatchingReasonCode> = []
        var ordered: [MatchingReasonCode] = []

        for reasonCode in reasonCodes where seen.insert(reasonCode).inserted {
            ordered.append(reasonCode)
        }

        return ordered
    }
}
