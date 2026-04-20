//
//  MatchingRuntimeReplayCorpus.swift
//  kAir
//
//  Ingests persisted runtime lifecycle exports and turns them into a
//  canonical replay corpus plus a runtime-derived residual ledger.
//

import Foundation

enum RuntimeReplayEvidenceSource: String, Codable, Hashable, Sendable {
    case runtimeExportedSessions = "runtime_exported_sessions"
    case syntheticReplay = "synthetic_replay"
}

enum RuntimeReplayDiagnosisTarget: String, Codable, Hashable, Sendable {
    case weakTrace = "weak_trace"
    case nearMiss = "near_miss"
    case residualScorerCompetition = "residual_scorer_competition"
    case traceStrengthRepresentation = "trace_strength_representation"
    case none = "none"
}

struct RuntimeReplayCorpusSession: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let fileName: String
    let sessionId: String
    let recommendationId: String
    let prompt: String
    let directSlotCandidateId: String?
    let rankedCandidateIds: [String]
    let acceptedCandidateIds: [String]
    let completedCandidateIds: [String]
    let dismissedCandidateIds: [String]
    let terminalOutcome: String
    let eventCount: Int
    let executionReturnCount: Int
    let exportedAt: Date
    let policyVersion: String
}

struct RuntimeReplayCorpus: Codable, Hashable, Sendable {
    let baselineArtifactVersion: String
    let policyVersion: String
    let replayExportSchemaVersion: String
    let source: RuntimeReplayEvidenceSource
    let sourceDirectory: String
    let sessionCount: Int
    let generatedAt: Date
    let sessions: [RuntimeReplayCorpusSession]
}

struct RuntimeReplayResidualLedger: Codable, Hashable, Sendable {
    let baselineArtifactVersion: String
    let policyVersion: String
    let replayExportSchemaVersion: String
    let source: RuntimeReplayEvidenceSource
    let sourceDirectory: String
    let sessionCount: Int
    let directSlotRecoveryCount: Int
    let directSlotRecoveryRate: Double
    let nearMissCount: Int
    let weakTraceCount: Int
    let candidateMissCount: Int
    let terminalOutcomeDistribution: [String: Int]
    let nextDiagnosisTarget: RuntimeReplayDiagnosisTarget
    let nextDiagnosisRationale: String
    let generatedAt: Date
    let entries: [LiveResidualLedgerEntry]
}

struct RuntimeReplayArtifactBundle {
    let baseline: MatchingKernelBaselineArtifact
    let corpus: RuntimeReplayCorpus
    let ledger: RuntimeReplayResidualLedger

    func write(to directory: URL) throws -> (baseline: URL, corpus: URL, ledger: URL) {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let baselineURL = directory.appendingPathComponent("matching_kernel_baseline.json")
        let corpusURL = directory.appendingPathComponent("runtime_replay_corpus.json")
        let ledgerURL = directory.appendingPathComponent("runtime_residual_ledger.json")

        try MatchingKernelBaselineArtifact.jsonEncoder().encode(baseline).write(to: baselineURL, options: .atomic)
        try RuntimeReplayCorpus.jsonEncoder().encode(corpus).write(to: corpusURL, options: .atomic)
        try RuntimeReplayResidualLedger.jsonEncoder().encode(ledger).write(to: ledgerURL, options: .atomic)

        return (baselineURL, corpusURL, ledgerURL)
    }
}

enum MatchingRuntimeReplayCorpusBuilder {
    private struct ExportRecord {
        let url: URL
        let export: ReplayExportedSession
    }

    static func build(
        from exportDirectory: URL = MatchingEventRecorder.defaultReplayExportDirectory(),
        baseline: MatchingKernelBaselineArtifact = MatchingKernelBaseline.current,
        now: Date = .now,
        limit: Int = 5
    ) throws -> RuntimeReplayArtifactBundle {
        let records = try loadExports(from: exportDirectory)
        let scenarios = records.map(makeScenario)
        let engine = MatchingReplayEngine()
        let comparisons = scenarios.map { scenario in
            engine.compare(
                scenario: scenario,
                baseline: .baseline,
                candidate: .baseline,
                now: now,
                limit: limit
            )
        }
        let ledger = engine.buildResidualLedger(
            comparisons: comparisons,
            policy: .current,
            now: now
        )

        let terminalDistribution = records.reduce(into: [String: Int]()) { partial, record in
            let key = terminalOutcome(for: record.export)
            partial[key, default: 0] += 1
        }

        let corpus = RuntimeReplayCorpus(
            baselineArtifactVersion: baseline.artifactVersion,
            policyVersion: baseline.policyVersion,
            replayExportSchemaVersion: baseline.replayExportSchemaVersion,
            source: .runtimeExportedSessions,
            sourceDirectory: exportDirectory.path,
            sessionCount: records.count,
            generatedAt: now,
            sessions: records.map(makeCorpusSession)
        )

        let directSlotRecoveryCount = ledger.directMatchCount
        let sessionCount = max(records.count, 1)
        let nextTarget = diagnosisTarget(from: ledger)
        let residualLedger = RuntimeReplayResidualLedger(
            baselineArtifactVersion: baseline.artifactVersion,
            policyVersion: baseline.policyVersion,
            replayExportSchemaVersion: baseline.replayExportSchemaVersion,
            source: .runtimeExportedSessions,
            sourceDirectory: exportDirectory.path,
            sessionCount: records.count,
            directSlotRecoveryCount: directSlotRecoveryCount,
            directSlotRecoveryRate: Double(directSlotRecoveryCount) / Double(sessionCount),
            nearMissCount: ledger.nearMissCount,
            weakTraceCount: ledger.weakTraceCount,
            candidateMissCount: ledger.candidateMissCount,
            terminalOutcomeDistribution: terminalDistribution,
            nextDiagnosisTarget: nextTarget,
            nextDiagnosisRationale: diagnosisRationale(for: nextTarget, ledger: ledger),
            generatedAt: now,
            entries: ledger.entries
        )

        return RuntimeReplayArtifactBundle(
            baseline: baseline,
            corpus: corpus,
            ledger: residualLedger
        )
    }

    static func defaultArtifactDirectory() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("kAir", isDirectory: true)
            .appendingPathComponent("ReplayArtifacts", isDirectory: true)
    }

    private static func loadExports(from directory: URL) throws -> [ExportRecord] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }

        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.lastPathComponent.hasPrefix("replay_session_") && $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return try urls.map { url in
            let data = try Data(contentsOf: url)
            return ExportRecord(url: url, export: try ReplayExportedSession.decode(from: data))
        }
    }

    private static func makeScenario(from record: ExportRecord) -> MatchingReplayScenario {
        let snapshot = MatchingReplaySnapshot(
            label: record.url.deletingPathExtension().lastPathComponent,
            recentPrompt: record.export.context.prompt.isEmpty ? nil : record.export.context.prompt,
            capturedAt: record.export.context.capturedAt,
            session: replaySession(from: record.export),
            healthAvailability: record.export.context.healthAvailability,
            locationState: record.export.context.locationState,
            motionContext: record.export.context.motionContext,
            activeSurface: record.export.context.activeSurface,
            returnContextState: returnContextState(from: record.export.context),
            behaviorLog: recentBehavior(from: record.export.context)
        )

        return MatchingReplayScenario(
            label: record.url.deletingPathExtension().lastPathComponent,
            snapshot: snapshot,
            recentEventsWindow: recentBehavior(from: record.export.context),
            groundTruthEvents: groundTruthEvents(from: record.export),
            createdAt: record.export.exportedAt
        )
    }

    private static func makeCorpusSession(from record: ExportRecord) -> RuntimeReplayCorpusSession {
        let accepted = record.export.events.compactMap { event in
            event.type == .accept ? event.candidateId : nil
        }
        let completed = record.export.events.compactMap { event in
            event.type == .completion ? event.candidateId : nil
        }
        let dismissed = record.export.events.compactMap { event in
            event.type == .dismiss ? event.candidateId : nil
        }

        return RuntimeReplayCorpusSession(
            id: record.export.decision.recommendationId,
            fileName: record.url.lastPathComponent,
            sessionId: record.export.sessionId,
            recommendationId: record.export.decision.recommendationId,
            prompt: record.export.context.prompt,
            directSlotCandidateId: record.export.decision.directSlotCandidateId,
            rankedCandidateIds: record.export.decision.rankedCandidateIds,
            acceptedCandidateIds: accepted,
            completedCandidateIds: completed,
            dismissedCandidateIds: dismissed,
            terminalOutcome: terminalOutcome(for: record.export),
            eventCount: record.export.events.count,
            executionReturnCount: record.export.executionReturns.count,
            exportedAt: record.export.exportedAt,
            policyVersion: record.export.policyVersion
        )
    }

    private static func replaySession(from export: ReplayExportedSession) -> ChatSession {
        let prompt = export.context.prompt
        let messages: [ConversationMessage]
        if prompt.isEmpty {
            messages = []
        } else {
            messages = [
                .user(
                    text: prompt,
                    timestamp: export.context.capturedAt,
                    tags: export.context.intentTags.map(\.rawValue)
                )
            ]
        }

        return ChatSession(
            title: export.sessionId,
            messages: messages
        )
    }

    private static func returnContextState(
        from context: MatchingContextSnapshot
    ) -> ExecutionReturnContextState? {
        let surfaceStates = context.executionSurfaceStates.map { state in
            ExecutionReturnContextState.SurfaceState(
                section: state.section,
                outcome: state.outcome,
                downstreamValue: state.downstreamValue,
                completionScore: state.completionScore
            )
        }

        guard context.foldedIntentTags.isEmpty == false ||
                context.resolvedObjectIds.isEmpty == false ||
                context.dismissedObjectIds.isEmpty == false ||
                surfaceStates.isEmpty == false else {
            return nil
        }

        return ExecutionReturnContextState(
            addedIntentTags: context.foldedIntentTags,
            resolvedObjectIds: context.resolvedObjectIds,
            dismissedObjectIds: context.dismissedObjectIds,
            surfaceStates: surfaceStates,
            summary: nil,
            createdAt: context.capturedAt
        )
    }

    private static func recentBehavior(
        from context: MatchingContextSnapshot
    ) -> [MatchingBehaviorEvent] {
        let sharedTags = Set(context.intentTags + context.foldedIntentTags)

        return context.recentBehavior.compactMap { entry in
            guard let stage = MatchingBehaviorEvent.Stage(rawValue: entry.stage),
                  let subject = MatchingBehaviorEvent.Subject(rawValue: entry.subject) else {
                return nil
            }

            return MatchingBehaviorEvent(
                stage: stage,
                subject: subject,
                candidateID: entry.candidateId,
                objectKind: entry.objectType.flatMap(MatchingObjectKind.init(rawValue:)),
                surface: entry.surface.flatMap(AppSection.init(rawValue:)),
                rawText: nil,
                tags: sharedTags,
                feedback: entry.feedback.flatMap(MatchingFeedbackKind.init(rawValue:)),
                timestamp: entry.timestamp,
                outcome: .neutral
            )
        }
    }

    private static func groundTruthEvents(
        from export: ReplayExportedSession
    ) -> [MatchingBehaviorEvent] {
        let sharedTags = Set(export.context.intentTags + export.context.foldedIntentTags)
        let returnTags = export.executionReturns.reduce(into: [String: Set<MatchingIntentTag>]()) { partial, payload in
            partial[payload.executedCandidateId, default: []]
                .formUnion(payload.returnContextDelta.addedIntentTags)
        }

        return export.events.compactMap { event in
            guard let stage = behaviorStage(for: event.type) else { return nil }
            let subject: MatchingBehaviorEvent.Subject = {
                switch stage {
                case .completion, .abandon:
                    return .surface
                case .click, .accept, .dismiss, .impression:
                    return .recommendation
                }
            }()

            let candidateTags = event.candidateId.flatMap { returnTags[$0] } ?? []
            return MatchingBehaviorEvent(
                stage: stage,
                subject: subject,
                candidateID: event.candidateId,
                objectKind: event.objectType.flatMap(MatchingObjectKind.init(rawValue:)),
                surface: event.executionSurfaceType.flatMap(AppSection.init(rawValue:)),
                rawText: export.context.prompt.isEmpty ? nil : export.context.prompt,
                tags: sharedTags.union(candidateTags),
                feedback: event.feedbackOption.flatMap { MatchingFeedbackKind(rawValue: $0.rawValue) },
                timestamp: event.timestamp,
                outcome: MatchingOutcomeMetrics(
                    downstreamValue: event.outcome?.downstreamValue ?? 0,
                    completionScore: event.outcome?.completionScore ?? 0,
                    dwellSeconds: event.outcome?.dwellSeconds,
                    wasSuccessful: event.outcome?.wasSuccessful ?? false
                )
            )
        }
    }

    private static func behaviorStage(
        for type: MatchingEventType
    ) -> MatchingBehaviorEvent.Stage? {
        switch type {
        case .impression:
            return .impression
        case .click:
            return .click
        case .accept:
            return .accept
        case .dismiss:
            return .dismiss
        case .abandon:
            return .abandon
        case .completion:
            return .completion
        case .downstreamValue:
            return nil
        case .surfaceEntryRequested, .surfaceEntryStarted, .surfaceEntryReturned:
            return nil
        }
    }

    private static func terminalOutcome(
        for export: ReplayExportedSession
    ) -> String {
        export.events.last { event in
            event.type == .dismiss || event.type == .completion || event.type == .abandon
        }?.type.rawValue ?? "unknown"
    }

    private static func diagnosisTarget(
        from ledger: LiveResidualLedger
    ) -> RuntimeReplayDiagnosisTarget {
        let counts: [(RuntimeReplayDiagnosisTarget, Int)] = [
            (.traceStrengthRepresentation, ledger.candidateMissCount),
            (.weakTrace, ledger.weakTraceCount),
            (.nearMiss, ledger.nearMissCount),
        ]
        let top = counts.max { lhs, rhs in
            if lhs.1 == rhs.1 {
                return lhs.0.rawValue > rhs.0.rawValue
            }
            return lhs.1 < rhs.1
        }

        guard let top, top.1 > 0 else { return .none }

        if top.0 == .nearMiss {
            let scorerDominant = ledger.entries
                .filter { $0.residualType == .nearMiss }
                .filter { $0.rootCause == .scorer }
                .count
            if scorerDominant * 2 >= max(1, ledger.nearMissCount) {
                return .residualScorerCompetition
            }
        }

        return top.0
    }

    private static func diagnosisRationale(
        for target: RuntimeReplayDiagnosisTarget,
        ledger: LiveResidualLedger
    ) -> String {
        switch target {
        case .none:
            return "No residual bucket is large enough to justify the next diagnosis pass."
        case .weakTrace:
            return "Weak-trace is the largest residual class in the runtime-derived corpus, so the next pass should focus on trace quality before any new patch."
        case .nearMiss:
            return "Near-miss is the largest residual class in the runtime-derived corpus, so the next pass should stay on ranking misses that already reach top-k."
        case .residualScorerCompetition:
            return "Near-miss leads the runtime-derived residual distribution and the dominant root cause is scorer competition, so the next pass should inspect residual scorer competition instead of weak-trace."
        case .traceStrengthRepresentation:
            return "Candidate-miss is the leading residual class in runtime-derived evidence, so the next pass should focus on trace strength / representation rather than ranking."
        }
    }
}

private extension MatchingKernelBaselineArtifact {
    static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension RuntimeReplayCorpus {
    static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension RuntimeReplayResidualLedger {
    static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
