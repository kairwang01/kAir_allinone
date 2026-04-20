//
//  MatchingReplayBatchAnalyzer.swift
//  kAir
//
//  Aggregate offline evaluation for replay scenarios.
//

import Foundation

struct MatchingReplayBatchAnalyzer {
    private struct SliceValue: Hashable {
        let valueID: String
        let title: String
    }

    func buildReport(
        scenarios: [MatchingReplayScenario],
        replayEngine: MatchingReplayEngine,
        baseline: MatchingReplayStrategy,
        candidate: MatchingReplayStrategy,
        now: Date,
        limit: Int
    ) -> MatchingReplayBatchReport {
        let evaluatedScenarios = scenarios.filter { $0.groundTruthEvents.isEmpty == false }
        let comparisons = evaluatedScenarios.map { scenario in
            replayEngine.compare(
                scenario: scenario,
                baseline: baseline,
                candidate: candidate,
                limit: limit
            )
        }

        let aggregateMetrics = aggregateMetrics(for: comparisons, limit: limit)
        let sliceGroups = sliceGroups(for: comparisons)
        let caseDeltas = comparisons.map(caseDelta(for:))
        let topImprovements = caseDeltas
            .filter { $0.delta > 0.02 }
            .sorted { lhs, rhs in
                lhs.delta > rhs.delta
            }
        let topRegressions = caseDeltas
            .filter { $0.delta < -0.02 }
            .sorted { lhs, rhs in
                lhs.delta < rhs.delta
            }

        return MatchingReplayBatchReport(
            trackedScenarioCount: scenarios.count,
            evaluatedScenarioCount: comparisons.count,
            aggregateMetrics: aggregateMetrics,
            sliceGroups: sliceGroups,
            topImprovements: Array(topImprovements.prefix(5)),
            topRegressions: Array(topRegressions.prefix(5)),
            offlineGate: offlineGate(
                metrics: aggregateMetrics,
                sliceGroups: sliceGroups
            ),
            generatedAt: now
        )
    }

    private func aggregateMetrics(
        for comparisons: [MatchingReplayComparison],
        limit: Int
    ) -> MatchingReplayAggregateMetrics {
        guard comparisons.isEmpty == false else {
            return .empty
        }

        let scenarioCount = comparisons.count
        return MatchingReplayAggregateMetrics(
            scenarioCount: scenarioCount,
            baselineChosenItemHitRate: rate(comparisons) { $0.baselineAlignment.chosenItemHitAtK },
            candidateChosenItemHitRate: rate(comparisons) { $0.candidateAlignment.chosenItemHitAtK },
            baselineAcceptedPathHitRate: rate(comparisons) { $0.baselineAlignment.acceptedPathHitAtK },
            candidateAcceptedPathHitRate: rate(comparisons) { $0.candidateAlignment.acceptedPathHitAtK },
            baselineCompletedPathHitRate: rate(comparisons) { $0.baselineAlignment.completedPathHitAtK },
            candidateCompletedPathHitRate: rate(comparisons) { $0.candidateAlignment.completedPathHitAtK },
            baselineTaskFamilyAlignmentRate: rate(comparisons) { $0.baselineAlignment.level >= .sameTaskFamily },
            candidateTaskFamilyAlignmentRate: rate(comparisons) { $0.candidateAlignment.level >= .sameTaskFamily },
            baselineDirectMatchRate: rate(comparisons) { $0.baselineAlignment.level == .directMatch },
            candidateDirectMatchRate: rate(comparisons) { $0.candidateAlignment.level == .directMatch },
            baselineWeaklyAlignedRate: rate(comparisons) { $0.baselineAlignment.level == .weaklyAligned },
            candidateWeaklyAlignedRate: rate(comparisons) { $0.candidateAlignment.level == .weaklyAligned },
            baselineNotAlignedRate: rate(comparisons) { $0.baselineAlignment.level == .notAligned },
            candidateNotAlignedRate: rate(comparisons) { $0.candidateAlignment.level == .notAligned },
            baselineAverageTaskProgressionAlignment: average(comparisons) { $0.baselineAlignment.taskProgressionAlignment },
            candidateAverageTaskProgressionAlignment: average(comparisons) { $0.candidateAlignment.taskProgressionAlignment },
            averageTopKOverlap: average(comparisons) { Double($0.diffSummary.topKOverlap) / Double(limit) },
            averageAbsoluteRankShift: average(comparisons) { averageAbsoluteRankShift(for: $0) },
            baselineObjectTypeConcentration: average(comparisons) { concentration(for: $0.baselineRun, limit: limit) },
            candidateObjectTypeConcentration: average(comparisons) { concentration(for: $0.candidateRun, limit: limit) }
        )
    }

    private func sliceGroups(
        for comparisons: [MatchingReplayComparison]
    ) -> [MatchingReplaySliceGroup] {
        MatchingReplaySliceDimension.allCases.compactMap { dimension in
            let grouped = Dictionary(grouping: comparisons) { comparison in
                sliceValue(
                    for: dimension,
                    comparison: comparison
                )
            }

            let rows = grouped.map { entry in
                let comparisons = entry.value
                return MatchingReplaySliceRow(
                    id: "\(dimension.rawValue)-\(entry.key.valueID)",
                    valueID: entry.key.valueID,
                    title: entry.key.title,
                    scenarioCount: comparisons.count,
                    baselineAverageTaskProgressionAlignment: average(comparisons) { $0.baselineAlignment.taskProgressionAlignment },
                    candidateAverageTaskProgressionAlignment: average(comparisons) { $0.candidateAlignment.taskProgressionAlignment },
                    baselineCompletedPathHitRate: rate(comparisons) { $0.baselineAlignment.completedPathHitAtK },
                    candidateCompletedPathHitRate: rate(comparisons) { $0.candidateAlignment.completedPathHitAtK },
                    baselineNotAlignedRate: rate(comparisons) { $0.baselineAlignment.level == .notAligned },
                    candidateNotAlignedRate: rate(comparisons) { $0.candidateAlignment.level == .notAligned }
                )
            }
            .sorted { lhs, rhs in
                if lhs.scenarioCount == rhs.scenarioCount {
                    return lhs.title < rhs.title
                }
                return lhs.scenarioCount > rhs.scenarioCount
            }

            guard rows.isEmpty == false else { return nil }
            return MatchingReplaySliceGroup(
                dimension: dimension,
                rows: rows
            )
        }
    }

    private func offlineGate(
        metrics: MatchingReplayAggregateMetrics,
        sliceGroups: [MatchingReplaySliceGroup]
    ) -> MatchingReplayOfflineGate {
        guard metrics.scenarioCount >= 5 else {
            return MatchingReplayOfflineGate(
                status: .insufficientData,
                summary: "Need at least 5 evaluated replay scenarios before using this report as a decision gate.",
                reasons: [
                    "Current evaluated scenarios: \(metrics.scenarioCount)",
                ]
            )
        }

        var reasons: [String] = []

        if metrics.candidateCompletedPathHitRate + 0.001 < metrics.baselineCompletedPathHitRate {
            reasons.append("Completed-path hit@k regressed.")
        }

        if metrics.candidateTaskFamilyAlignmentRate + 0.001 < metrics.baselineTaskFamilyAlignmentRate {
            reasons.append("Same-task-family alignment regressed.")
        }

        if metrics.candidateNotAlignedRate > metrics.baselineNotAlignedRate + 0.03 {
            reasons.append("Not-aligned rate increased beyond tolerance.")
        }

        if let explicitDismissRow = sliceRow(
            in: sliceGroups,
            dimension: .explicitNegativeFeedback,
            valueID: "dismissed"
        ), explicitDismissRow.scenarioCount >= 2 {
            if explicitDismissRow.candidateCompletedPathHitRate + 0.001 < explicitDismissRow.baselineCompletedPathHitRate {
                reasons.append("Explicit-dismiss slice regressed on completed-path hit@k.")
            }

            if explicitDismissRow.candidateNotAlignedRate > explicitDismissRow.baselineNotAlignedRate + 0.05 {
                reasons.append("Explicit-dismiss slice increased not-aligned rate beyond tolerance.")
            }
        }

        if metrics.candidateObjectTypeConcentration > metrics.baselineObjectTypeConcentration + 0.08 {
            reasons.append("Object-type concentration worsened too much.")
        }

        if reasons.isEmpty {
            return MatchingReplayOfflineGate(
                status: .pass,
                summary: "Candidate clears the offline gate against the current replay set.",
                reasons: [
                    "Completed-path hit@k held or improved.",
                    "Same-task-family alignment held or improved.",
                    "Not-aligned rate stayed within tolerance.",
                    "Explicit-dismiss slice did not materially worsen.",
                    "Object-type concentration did not materially worsen.",
                ]
            )
        }

        return MatchingReplayOfflineGate(
            status: .fail,
            summary: "Candidate does not yet clear the offline gate.",
            reasons: reasons
        )
    }

    private func rate(
        _ comparisons: [MatchingReplayComparison],
        predicate: (MatchingReplayComparison) -> Bool
    ) -> Double {
        guard comparisons.isEmpty == false else { return 0 }
        let hits = comparisons.filter(predicate).count
        return Double(hits) / Double(comparisons.count)
    }

    private func average(
        _ comparisons: [MatchingReplayComparison],
        value: (MatchingReplayComparison) -> Double
    ) -> Double {
        guard comparisons.isEmpty == false else { return 0 }
        let total = comparisons.reduce(0) { partial, comparison in
            partial + value(comparison)
        }
        return total / Double(comparisons.count)
    }

    private func averageAbsoluteRankShift(
        for comparison: MatchingReplayComparison
    ) -> Double {
        let sharedShifts = comparison.diffSummary.rankShifts.compactMap { shift -> Double? in
            guard let baselineRank = shift.baselineRank, let candidateRank = shift.candidateRank else {
                return nil
            }
            return Double(abs(candidateRank - baselineRank))
        }

        guard sharedShifts.isEmpty == false else { return 0 }
        return sharedShifts.reduce(0, +) / Double(sharedShifts.count)
    }

    private func concentration(
        for run: MatchingReplayRun,
        limit: Int
    ) -> Double {
        let recommendations = Array(run.recommendations.prefix(limit))
        guard recommendations.isEmpty == false else { return 0 }
        let totalCount = Double(recommendations.count)

        let grouped = Dictionary(grouping: recommendations, by: \.candidate.objectKind)
        return grouped.values.reduce(0) { partial, recommendations in
            let probability = Double(recommendations.count) / totalCount
            return partial + probability * probability
        }
    }

    private func caseDelta(
        for comparison: MatchingReplayComparison
    ) -> MatchingReplayCaseDelta {
        MatchingReplayCaseDelta(
            scenarioID: comparison.scenario.id,
            label: comparison.scenario.label,
            prompt: comparison.scenario.snapshot.recentPrompt ?? comparison.scenario.label,
            primaryObjectKind: comparison.observedOutcome.primaryObjectKind,
            delta: comparison.candidateAlignment.taskProgressionAlignment - comparison.baselineAlignment.taskProgressionAlignment,
            baselineAlignment: comparison.baselineAlignment.level,
            candidateAlignment: comparison.candidateAlignment.level,
            verdict: comparison.verdict,
            topKOverlap: comparison.diffSummary.topKOverlap,
            hadExplicitDismiss: comparison.observedOutcome.hadExplicitDismiss,
            didComplete: comparison.observedOutcome.didComplete
        )
    }

    private func sliceValue(
        for dimension: MatchingReplaySliceDimension,
        comparison: MatchingReplayComparison
    ) -> SliceValue {
        switch dimension {
        case .objectKind:
            if let objectKind = comparison.observedOutcome.primaryObjectKind {
                return SliceValue(valueID: objectKind.rawValue, title: objectKind.title)
            }
            return SliceValue(valueID: "unknown", title: "Unknown")
        case .daypart:
            let value = comparison.candidateRun.context.daypart
            return SliceValue(valueID: value.rawValue, title: value.rawValue.capitalized)
        case .locationState:
            let value = comparison.candidateRun.context.locationState
            return SliceValue(valueID: value.rawValue, title: value.rawValue.capitalized)
        case .healthAvailability:
            let value = comparison.candidateRun.context.healthAvailability
            return SliceValue(valueID: value.rawValue, title: value.rawValue.capitalized)
        case .motionContext:
            let value = comparison.candidateRun.context.motionContext
            return SliceValue(valueID: value.rawValue, title: value.rawValue.capitalized)
        case .threadDepth:
            let messageCount = comparison.scenario.snapshot.session.messages.count
            switch messageCount {
            case 0 ... 3:
                return SliceValue(valueID: "shallow", title: "Shallow")
            case 4 ... 8:
                return SliceValue(valueID: "active", title: "Active")
            default:
                return SliceValue(valueID: "deep", title: "Deep")
            }
        case .explicitNegativeFeedback:
            return comparison.observedOutcome.hadExplicitDismiss ?
                SliceValue(valueID: "dismissed", title: "Explicit dismiss") :
                SliceValue(valueID: "clean", title: "No explicit dismiss")
        }
    }

    private func sliceRow(
        in sliceGroups: [MatchingReplaySliceGroup],
        dimension: MatchingReplaySliceDimension,
        valueID: String
    ) -> MatchingReplaySliceRow? {
        sliceGroups
            .first(where: { $0.dimension == dimension })?
            .rows
            .first(where: { $0.valueID == valueID })
    }
}
