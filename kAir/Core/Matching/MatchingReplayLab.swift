//
//  MatchingReplayLab.swift
//  kAir
//
//  Stateful replay scenario tracking for side-by-side comparison.
//

import Foundation
import Observation

@MainActor
@Observable
final class MatchingReplayLab {
    private let replayEngine: MatchingReplayEngine
    private let batchAnalyzer: MatchingReplayBatchAnalyzer
    private let baselineStrategy: MatchingReplayStrategy
    private let candidateStrategy: MatchingReplayStrategy

    var scenarios: [MatchingReplayScenario] = []
    var latestComparison: MatchingReplayComparison?
    var latestBatchReport: MatchingReplayBatchReport?

    var surfaceEntryEvents: [MatchingEvent] = []
    var surfaceEntryRequestsById: [String: SurfaceEntryRequest] = [:]
    var surfaceEntryReturnPayloadsById: [String: ExecutionReturnPayload] = [:]
    private var surfaceEntryRequestOrder: [String] = []

    private var pendingScenarioID: MatchingReplayScenario.ID?

    init() {
        self.replayEngine = MatchingReplayEngine()
        self.batchAnalyzer = MatchingReplayBatchAnalyzer()
        self.baselineStrategy = .baseline
        self.candidateStrategy = .candidate
    }

    func beginScenario(
        snapshot: MatchingReplaySnapshot,
        recentEventsWindow: [MatchingBehaviorEvent],
        now: Date = .now,
        recommendationLimit: Int = 4,
        comparisonLimit: Int = 5
    ) -> MatchingReplayFrame {
        finalizePendingScenario(now: now, limit: comparisonLimit)

        let candidateRun = replayEngine.run(
            snapshot: snapshot,
            strategy: candidateStrategy,
            now: now,
            limit: max(recommendationLimit, comparisonLimit)
        )

        let scenario = MatchingReplayScenario(
            label: snapshot.label,
            snapshot: snapshot,
            recentEventsWindow: recentEventsWindow,
            createdAt: now
        )

        scenarios.append(scenario)
        if scenarios.count > 64 {
            scenarios.removeFirst(scenarios.count - 64)
        }
        pendingScenarioID = scenario.id
        refreshBatchReport(now: now, limit: comparisonLimit)

        return MatchingReplayFrame(
            label: snapshot.label,
            context: candidateRun.context,
            recommendations: Array(candidateRun.recommendations.prefix(recommendationLimit))
        )
    }

    func recordOutcomeEvent(_ event: MatchingBehaviorEvent) {
        guard event.stage != .impression else { return }
        guard let pendingScenarioID else { return }
        guard let scenarioIndex = scenarios.firstIndex(where: { $0.id == pendingScenarioID }) else {
            return
        }

        scenarios[scenarioIndex].groundTruthEvents.append(event)
        if scenarios[scenarioIndex].groundTruthEvents.count > 20 {
            scenarios[scenarioIndex].groundTruthEvents.removeFirst(
                scenarios[scenarioIndex].groundTruthEvents.count - 20
            )
        }
    }

    func finalizePendingScenario(
        now: Date = .now,
        limit: Int = 5
    ) {
        guard let pendingScenarioID else { return }
        guard let scenarioIndex = scenarios.firstIndex(where: { $0.id == pendingScenarioID }) else {
            self.pendingScenarioID = nil
            return
        }

        latestComparison = replayEngine.compare(
            scenario: scenarios[scenarioIndex],
            baseline: baselineStrategy,
            candidate: candidateStrategy,
            now: now,
            limit: limit
        )
        self.pendingScenarioID = nil
        refreshBatchReport(now: now, limit: limit)
    }

    private func refreshBatchReport(
        now: Date,
        limit: Int
    ) {
        latestBatchReport = batchAnalyzer.buildReport(
            scenarios: scenarios,
            replayEngine: replayEngine,
            baseline: baselineStrategy,
            candidate: candidateStrategy,
            now: now,
            limit: limit
        )
    }

    // MARK: - Surface entry chain feed

    func submitSurfaceEntryEvent(_ event: MatchingEvent) {
        guard event.surfaceEntryRequestId != nil else { return }
        surfaceEntryEvents.append(event)
        if surfaceEntryEvents.count > 512 {
            surfaceEntryEvents.removeFirst(surfaceEntryEvents.count - 512)
        }
    }

    func retainSurfaceEntryRequest(_ request: SurfaceEntryRequest) {
        if surfaceEntryRequestsById[request.requestId] == nil {
            surfaceEntryRequestOrder.append(request.requestId)
        }
        surfaceEntryRequestsById[request.requestId] = request
        if surfaceEntryRequestOrder.count > 256 {
            let drop = surfaceEntryRequestOrder.removeFirst()
            surfaceEntryRequestsById[drop] = nil
            surfaceEntryReturnPayloadsById[drop] = nil
        }
    }

    func retainSurfaceEntryReturnPayload(_ payload: ExecutionReturnPayload) {
        guard let requestId = payload.sourceRequestId else { return }
        surfaceEntryReturnPayloadsById[requestId] = payload
    }

    var surfaceEntryChains: [SurfaceEntryChain] {
        SurfaceEntryReplayBuilder.build(
            events: surfaceEntryEvents,
            retainedRequests: surfaceEntryRequestsById,
            retainedPayloads: surfaceEntryReturnPayloadsById
        )
    }

    var surfaceEntryInvariantSummary: SurfaceEntryInvariantSummary {
        SurfaceEntryReplayBuilder.summarize(surfaceEntryChains)
    }
}
