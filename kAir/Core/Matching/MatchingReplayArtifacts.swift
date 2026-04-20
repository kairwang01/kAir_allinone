//
//  MatchingReplayArtifacts.swift
//  kAir
//
//  Canonical machine-readable replay artifacts.
//  `MatchingReplayEngine` emits `MatchingReplaySummary` and `LiveResidualLedger`.
//  Markdown is permitted only as a render target from these JSON payloads.
//

import Foundation

struct MatchingReplayAggregateJSON: Codable, Hashable, Sendable {
    let scenarioCount: Int
    let evaluatedScenarioCount: Int
    let baselineChosenItemHitRate: Double
    let candidateChosenItemHitRate: Double
    let baselineCompletedPathHitRate: Double
    let candidateCompletedPathHitRate: Double
    let baselineTaskFamilyAlignmentRate: Double
    let candidateTaskFamilyAlignmentRate: Double
    let baselineDirectMatchRate: Double
    let candidateDirectMatchRate: Double
    let baselineNotAlignedRate: Double
    let candidateNotAlignedRate: Double
    let baselineAverageTaskProgressionAlignment: Double
    let candidateAverageTaskProgressionAlignment: Double
    let averageTopKOverlap: Double
    let averageAbsoluteRankShift: Double

    init(from report: MatchingReplayBatchReport) {
        let metrics = report.aggregateMetrics
        self.scenarioCount = report.trackedScenarioCount
        self.evaluatedScenarioCount = report.evaluatedScenarioCount
        self.baselineChosenItemHitRate = metrics.baselineChosenItemHitRate
        self.candidateChosenItemHitRate = metrics.candidateChosenItemHitRate
        self.baselineCompletedPathHitRate = metrics.baselineCompletedPathHitRate
        self.candidateCompletedPathHitRate = metrics.candidateCompletedPathHitRate
        self.baselineTaskFamilyAlignmentRate = metrics.baselineTaskFamilyAlignmentRate
        self.candidateTaskFamilyAlignmentRate = metrics.candidateTaskFamilyAlignmentRate
        self.baselineDirectMatchRate = metrics.baselineDirectMatchRate
        self.candidateDirectMatchRate = metrics.candidateDirectMatchRate
        self.baselineNotAlignedRate = metrics.baselineNotAlignedRate
        self.candidateNotAlignedRate = metrics.candidateNotAlignedRate
        self.baselineAverageTaskProgressionAlignment = metrics.baselineAverageTaskProgressionAlignment
        self.candidateAverageTaskProgressionAlignment = metrics.candidateAverageTaskProgressionAlignment
        self.averageTopKOverlap = metrics.averageTopKOverlap
        self.averageAbsoluteRankShift = metrics.averageAbsoluteRankShift
    }
}

struct MatchingReplayOfflineGateJSON: Codable, Hashable, Sendable {
    let status: String
    let summary: String
    let reasons: [String]

    init(from gate: MatchingReplayOfflineGate) {
        self.status = gate.status.rawValue
        self.summary = gate.summary
        self.reasons = gate.reasons
    }
}

struct MatchingReplaySummary: Codable, Hashable, Sendable {
    let baselineArtifactVersion: String
    let policyVersion: MatchingPolicyVersion
    let baselineStrategyID: String
    let candidateStrategyID: String
    let aggregate: MatchingReplayAggregateJSON
    let offlineGate: MatchingReplayOfflineGateJSON
    let shippedHypotheses: [MatchingHypothesis]
    let closedHypotheses: [MatchingHypothesis]
    let generatedAt: Date

    static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func encodeJSONData() throws -> Data {
        try Self.jsonEncoder().encode(self)
    }

    static func decode(from data: Data) throws -> MatchingReplaySummary {
        try jsonDecoder().decode(MatchingReplaySummary.self, from: data)
    }
}

struct MatchingReplayArtifactBundle {
    let summary: MatchingReplaySummary
    let ledger: LiveResidualLedger

    func writeSummary(to directory: URL, filename: String = "replay_summary.json") throws -> URL {
        let url = directory.appendingPathComponent(filename)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try summary.encodeJSONData().write(to: url, options: .atomic)
        return url
    }

    func writeLedger(to directory: URL, filename: String = "live_residual_ledger.json") throws -> URL {
        let url = directory.appendingPathComponent(filename)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try ledger.encodeJSONData().write(to: url, options: .atomic)
        return url
    }
}

extension MatchingReplayEngine {
    func buildResidualLedger(
        comparisons: [MatchingReplayComparison],
        policy: MatchingPolicyVersion,
        now: Date = .now
    ) -> LiveResidualLedger {
        let entries = comparisons.map { comparison in
            residualEntry(for: comparison, policy: policy)
        }
        return LiveResidualLedger(
            baselineArtifactVersion: MatchingKernelBaseline.current.artifactVersion,
            policyVersion: policy,
            generatedAt: now,
            entries: entries
        )
    }

    func buildReplaySummary(
        report: MatchingReplayBatchReport,
        policy: MatchingPolicyVersion,
        baselineStrategy: MatchingReplayStrategy,
        candidateStrategy: MatchingReplayStrategy,
        now: Date = .now
    ) -> MatchingReplaySummary {
        MatchingReplaySummary(
            baselineArtifactVersion: MatchingKernelBaseline.current.artifactVersion,
            policyVersion: policy,
            baselineStrategyID: baselineStrategy.engine.strategyID,
            candidateStrategyID: candidateStrategy.engine.strategyID,
            aggregate: MatchingReplayAggregateJSON(from: report),
            offlineGate: MatchingReplayOfflineGateJSON(from: report.offlineGate),
            shippedHypotheses: MatchingHypothesisRegistry.shipped,
            closedHypotheses: MatchingHypothesisRegistry.closed,
            generatedAt: now
        )
    }

    func buildArtifactBundle(
        scenarios: [MatchingReplayScenario],
        baselineStrategy: MatchingReplayStrategy = .baseline,
        candidateStrategy: MatchingReplayStrategy = .candidate,
        policy: MatchingPolicyVersion = .current,
        limit: Int = 5,
        now: Date = .now
    ) -> MatchingReplayArtifactBundle {
        let analyzer = MatchingReplayBatchAnalyzer()
        let report = analyzer.buildReport(
            scenarios: scenarios,
            replayEngine: self,
            baseline: baselineStrategy,
            candidate: candidateStrategy,
            now: now,
            limit: limit
        )
        let comparisons = scenarios.map { scenario in
            compare(
                scenario: scenario,
                baseline: baselineStrategy,
                candidate: candidateStrategy,
                now: now,
                limit: limit
            )
        }
        let ledger = buildResidualLedger(
            comparisons: comparisons,
            policy: policy,
            now: now
        )
        let summary = buildReplaySummary(
            report: report,
            policy: policy,
            baselineStrategy: baselineStrategy,
            candidateStrategy: candidateStrategy,
            now: now
        )
        return MatchingReplayArtifactBundle(summary: summary, ledger: ledger)
    }

    private func residualEntry(
        for comparison: MatchingReplayComparison,
        policy: MatchingPolicyVersion
    ) -> LiveResidualLedgerEntry {
        let candidateRun = comparison.candidateRun
        let topRecommendations = candidateRun.recommendations
        let top1 = topRecommendations.first
        let expectedID = comparison.observedOutcome.candidateIDs.first
            ?? comparison.observedOutcome.acceptedCandidateIDs.first
            ?? comparison.observedOutcome.completedCandidateIDs.first
            ?? ""

        let expectedRank = topRecommendations.first(where: { $0.id == expectedID })?.rank
        let isInTopK = expectedRank != nil
        let isDirectSlot = expectedRank == 1

        let residualType: ResidualType
        if isDirectSlot {
            residualType = .directMatch
        } else if isInTopK {
            residualType = .nearMiss
        } else if comparison.baselineAlignment.level <= .weaklyAligned,
                  comparison.candidateAlignment.level <= .weaklyAligned {
            residualType = .weakTrace
        } else {
            residualType = .candidateMiss
        }

        let rootCause: ResidualRootCause
        switch residualType {
        case .directMatch, .recoveredDirectSlot:
            rootCause = .unknown
        case .nearMiss, .weakTrace:
            rootCause = .scorer
        case .candidateMiss:
            rootCause = .provider
        }

        let expectedBreakdown = candidateRun.scoredCandidates
            .first(where: { $0.candidate.id == expectedID })?
            .breakdown
            .contribution
        let top1Breakdown = top1?.breakdown.contribution

        let dominantBucket = dominantBucket(
            expected: expectedBreakdown,
            top1: top1Breakdown
        )

        let surfaceRaw = top1?.candidate.preferredSection?.rawValue
            ?? candidateRun.context.activeSurface.rawValue
        let objectType = top1?.candidate.objectKind.rawValue
            ?? comparison.observedOutcome.primaryObjectKind?.rawValue
            ?? "unknown"

        return LiveResidualLedgerEntry(
            caseId: comparison.scenario.label,
            sessionId: comparison.scenario.id.uuidString,
            objectType: objectType,
            surface: surfaceRaw,
            expectedCandidateId: expectedID,
            top1CandidateId: top1?.id,
            expectedRank: expectedRank,
            isInTopK: isInTopK,
            isDirectSlot: isDirectSlot,
            residualType: residualType,
            rootCause: rootCause,
            dominantBucket: dominantBucket,
            scoreBreakdownExpected: expectedBreakdown,
            scoreBreakdownTop1: top1Breakdown,
            policyVersion: policy.policyVersion
        )
    }

    private func dominantBucket(
        expected: ScoreContributionBreakdown?,
        top1: ScoreContributionBreakdown?
    ) -> String? {
        guard let expected, let top1 else { return nil }
        let buckets: [(String, Double)] = [
            ("prompt_lexical", top1.promptLexical - expected.promptLexical),
            ("context_lexical", top1.contextLexical - expected.contextLexical),
            ("phrase", top1.phrase - expected.phrase),
            ("suppression", top1.suppression - expected.suppression),
            ("retrieval_lift", top1.retrievalLift - expected.retrievalLift),
            ("prompt_directness", top1.promptDirectnessBonus - expected.promptDirectnessBonus),
        ]
        return buckets
            .max { lhs, rhs in abs(lhs.1) < abs(rhs.1) }
            .map(\.0)
    }
}
