//
//  MatchingEventRecorder.swift
//  kAir
//
//  Runtime logger for the Phase-1 event loop. Owns stable identifiers,
//  appends typed MatchingEvents, associates them with exactly one
//  recommendation lifecycle, and persists replay exports when a lifecycle
//  reaches a terminal state.
//

import Foundation

@MainActor
final class MatchingEventRecorder {
    struct LifecycleSnapshot {
        let sessionId: String
        let recommendationId: String
        let context: MatchingContextSnapshot
        let decision: RecommendationDecision
        let events: [MatchingEvent]
        let executionReturns: [ExecutionReturnPayload]
        let terminalEvent: MatchingEvent?
        let export: ReplayExportedSession?
        let exportURL: URL?
    }

    private struct ActiveLifecycle {
        let sessionId: String
        let recommendationId: String
        let context: MatchingContextSnapshot
        let decision: RecommendationDecision
        var events: [MatchingEvent]
        var executionReturns: [ExecutionReturnPayload]
        var terminalEvent: MatchingEvent?
        var export: ReplayExportedSession?
        var exportURL: URL?
    }

    private(set) var sessionId: String
    private(set) var lastPersistedExport: ReplayExportedSession?
    private(set) var lastPersistedExportURL: URL?
    private(set) var lastClosedLifecycle: LifecycleSnapshot?

    private let exportDirectory: URL
    private var activeLifecycle: ActiveLifecycle?
    private var closedLifecycles: [LifecycleSnapshot] = []
    private var executionStartTimes: [String: Date] = [:]
    private var events: [MatchingEvent] = []
    private var surfaceEntryRequestsById: [String: SurfaceEntryRequest] = [:]
    private var surfaceEntryReturnPayloadsById: [String: ExecutionReturnPayload] = [:]
    private var surfaceEntryRequestOrder: [String] = []

    var onEventAppended: ((MatchingEvent) -> Void)?
    var onSurfaceEntryRequestRetained: ((SurfaceEntryRequest) -> Void)?
    var onExecutionReturnPayloadRetained: ((ExecutionReturnPayload) -> Void)?

    init(
        sessionId: String = UUID().uuidString,
        exportDirectory: URL = MatchingEventRecorder.defaultReplayExportDirectory()
    ) {
        self.sessionId = sessionId
        self.exportDirectory = exportDirectory
    }

    // MARK: - Lifecycle

    func beginLifecycle(
        context: MatchingContextSnapshot,
        decision: RecommendationDecision,
        now: Date = .now
    ) {
        if activeLifecycle != nil {
            _ = closeActiveLifecycle(
                terminalType: .abandon,
                candidateId: activeLifecycle?.decision.directSlotCandidateId,
                objectType: activeLifecycle?.decision.objectType?.rawValue,
                surface: activeLifecycle?.decision.executionSurfaceType.rawValue,
                timestamp: now
            )
        }

        let lifecycle = ActiveLifecycle(
            sessionId: sessionId,
            recommendationId: decision.recommendationId,
            context: context,
            decision: decision,
            events: [],
            executionReturns: [],
            terminalEvent: nil,
            export: nil,
            exportURL: nil
        )
        activeLifecycle = lifecycle
        recordImpressions(for: decision, now: now)
    }

    @discardableResult
    func abandonActiveLifecycleIfNeeded(
        surface: AppSection = .chat,
        now: Date = .now
    ) -> LifecycleSnapshot? {
        guard activeLifecycle?.terminalEvent == nil else { return nil }
        return closeActiveLifecycle(
            terminalType: .abandon,
            candidateId: activeLifecycle?.decision.directSlotCandidateId,
            objectType: activeLifecycle?.decision.objectType?.rawValue,
            surface: surface.rawValue,
            timestamp: now
        )
    }

    @discardableResult
    func exportActiveSession(now: Date = .now) -> ReplayExportedSession? {
        if let closed = abandonActiveLifecycleIfNeeded(now: now) {
            return closed.export
        }
        return lastPersistedExport
    }

    func exportLastClosedLifecycle(now: Date = .now) -> ReplayExportedSession? {
        _ = now
        return lastPersistedExport
    }

    var lifecycleHistory: [LifecycleSnapshot] { closedLifecycles }

    var hasActiveLifecycle: Bool { activeLifecycle != nil }

    // MARK: - Event emission

    func recordImpressions(
        for decision: RecommendationDecision,
        now: Date = .now
    ) {
        let visible = decision.rankedCandidates.prefix(4)
        for recommendation in visible {
            append(
                type: .impression,
                candidate: recommendation,
                timestamp: now
            )
        }
    }

    func recordClick(
        candidate: UnifiedMatchRecommendation,
        now: Date = .now
    ) {
        append(type: .click, candidate: candidate, timestamp: now)
    }

    func recordAccept(
        candidate: UnifiedMatchRecommendation,
        now: Date = .now
    ) {
        append(type: .accept, candidate: candidate, timestamp: now)
    }

    func recordDismiss(
        candidate: UnifiedMatchRecommendation,
        feedback: FeedbackOption,
        now: Date = .now
    ) {
        let terminalType: MatchingEventType = feedback == .alreadyDone ? .completion : .dismiss
        _ = closeActiveLifecycle(
            terminalType: terminalType,
            candidateId: candidate.id,
            objectType: candidate.candidate.objectKind.rawValue,
            surface: candidate.candidate.preferredSection?.rawValue,
            timestamp: now,
            feedback: feedback
        )
    }

    func recordAbandon(
        candidate: UnifiedMatchRecommendation?,
        surface: AppSection,
        now: Date = .now
    ) {
        _ = closeActiveLifecycle(
            terminalType: .abandon,
            candidateId: candidate?.id,
            objectType: candidate?.candidate.objectKind.rawValue,
            surface: surface.rawValue,
            timestamp: now
        )
    }

    func recordExecutionOpen(
        candidate: UnifiedMatchRecommendation,
        surface: AppSection,
        now: Date = .now
    ) {
        executionStartTimes[candidate.id] = now
        append(
            type: .click,
            candidate: candidate,
            timestamp: now,
            surfaceOverride: surface
        )
    }

    // MARK: - Surface entry events

    func recordSurfaceEntryRequested(
        request: SurfaceEntryRequest,
        candidate: UnifiedMatchRecommendation? = nil,
        now: Date = .now
    ) {
        retainSurfaceEntryRequest(request)
        _ = appendRaw(
            type: .surfaceEntryRequested,
            candidateId: candidate?.id ?? request.objectId,
            objectType: request.objectType ?? candidate?.candidate.objectKind.rawValue,
            surface: request.surfaceType.rawValue,
            timestamp: now,
            surfaceEntryRequestId: request.requestId
        )
    }

    func recordSurfaceEntryStarted(
        request: SurfaceEntryRequest,
        candidate: UnifiedMatchRecommendation? = nil,
        now: Date = .now
    ) {
        retainSurfaceEntryRequest(request)
        _ = appendRaw(
            type: .surfaceEntryStarted,
            candidateId: candidate?.id ?? request.objectId,
            objectType: request.objectType ?? candidate?.candidate.objectKind.rawValue,
            surface: request.surfaceType.rawValue,
            timestamp: now,
            surfaceEntryRequestId: request.requestId
        )
    }

    func recordSurfaceEntryReturned(
        request: SurfaceEntryRequest,
        payload: ExecutionReturnPayload? = nil,
        candidate: UnifiedMatchRecommendation? = nil,
        now: Date = .now
    ) {
        retainSurfaceEntryRequest(request)
        if let payload {
            surfaceEntryReturnPayloadsById[request.requestId] = payload
            onExecutionReturnPayloadRetained?(payload)
        }
        _ = appendRaw(
            type: .surfaceEntryReturned,
            candidateId: candidate?.id ?? payload?.executedCandidateId ?? request.objectId,
            objectType: request.objectType ?? candidate?.candidate.objectKind.rawValue,
            surface: payload?.executionSurfaceType.rawValue ?? request.surfaceType.rawValue,
            timestamp: now,
            outcome: payload?.toOutcomeEventPayload,
            surfaceEntryRequestId: request.requestId
        )
    }

    private func retainSurfaceEntryRequest(_ request: SurfaceEntryRequest) {
        if surfaceEntryRequestsById[request.requestId] == nil {
            surfaceEntryRequestOrder.append(request.requestId)
        }
        surfaceEntryRequestsById[request.requestId] = request
        if surfaceEntryRequestOrder.count > 256 {
            let drop = surfaceEntryRequestOrder.removeFirst()
            surfaceEntryRequestsById[drop] = nil
            surfaceEntryReturnPayloadsById[drop] = nil
        }
        onSurfaceEntryRequestRetained?(request)
    }

    func recordExecutionReturn(
        payload: ExecutionReturnPayload,
        candidate: UnifiedMatchRecommendation?,
        now: Date = .now
    ) {
        if let sourceRequestId = payload.sourceRequestId {
            surfaceEntryReturnPayloadsById[sourceRequestId] = payload
        }
        onExecutionReturnPayloadRetained?(payload)
        guard var lifecycle = activeLifecycle else { return }
        guard lifecycle.terminalEvent == nil else { return }

        lifecycle.executionReturns.append(payload)
        activeLifecycle = lifecycle

        let outcomePayload = payload.toOutcomeEventPayload
        let terminalType: MatchingEventType = {
            switch payload.outcome {
            case .completed:
                return .completion
            case .abandoned, .failed:
                return .abandon
            case .partial:
                return .completion
            }
        }()

        if let terminalEvent = appendRaw(
            type: terminalType,
            candidateId: payload.executedCandidateId,
            objectType: candidate?.candidate.objectKind.rawValue,
            surface: payload.executionSurfaceType.rawValue,
            timestamp: now,
            outcome: outcomePayload
        ) {
            activeLifecycle?.terminalEvent = terminalEvent
        }

        if payload.returnContextDelta.downstreamValue != 0 {
            _ = appendRaw(
                type: .downstreamValue,
                candidateId: payload.executedCandidateId,
                objectType: candidate?.candidate.objectKind.rawValue,
                surface: payload.executionSurfaceType.rawValue,
                timestamp: now,
                outcome: outcomePayload
            )
        }

        _ = finalizeActiveLifecycle(now: now)
    }

    // MARK: - Inspection

    var eventLog: [MatchingEvent] { events }

    func events(forRecommendation recommendationId: String) -> [MatchingEvent] {
        events.filter { $0.recommendationId == recommendationId }
    }

    var retainedSurfaceEntryRequests: [String: SurfaceEntryRequest] {
        surfaceEntryRequestsById
    }

    var retainedSurfaceEntryReturnPayloads: [String: ExecutionReturnPayload] {
        surfaceEntryReturnPayloadsById
    }

    // MARK: - Helpers

    @discardableResult
    private func closeActiveLifecycle(
        terminalType: MatchingEventType,
        candidateId: String?,
        objectType: String?,
        surface: String?,
        timestamp: Date,
        feedback: FeedbackOption? = nil,
        outcome: MatchingEventOutcome? = nil
    ) -> LifecycleSnapshot? {
        guard activeLifecycle?.terminalEvent == nil else { return lastClosedLifecycle }

        if let terminalEvent = appendRaw(
            type: terminalType,
            candidateId: candidateId,
            objectType: objectType,
            surface: surface,
            timestamp: timestamp,
            feedback: feedback,
            outcome: outcome
        ) {
            activeLifecycle?.terminalEvent = terminalEvent
        }

        return finalizeActiveLifecycle(now: timestamp)
    }

    @discardableResult
    private func finalizeActiveLifecycle(now: Date = .now) -> LifecycleSnapshot? {
        guard var lifecycle = activeLifecycle else { return nil }

        if lifecycle.terminalEvent == nil,
           let terminalEvent = appendRaw(
                type: .abandon,
                candidateId: lifecycle.decision.directSlotCandidateId,
                objectType: lifecycle.decision.objectType?.rawValue,
                surface: lifecycle.decision.executionSurfaceType.rawValue,
                timestamp: now
           ) {
            lifecycle.terminalEvent = terminalEvent
            activeLifecycle = lifecycle
        }

        let export = ReplaySnapshotExporter.export(
            sessionId: lifecycle.sessionId,
            context: lifecycle.context,
            decision: lifecycle.decision,
            events: lifecycle.events,
            executionReturns: lifecycle.executionReturns,
            now: now
        )

        let exportURL: URL?
        do {
            exportURL = try ReplaySnapshotExporter.write(
                export,
                to: exportDirectory,
                filename: "replay_session_\(lifecycle.recommendationId).json"
            )
        } catch {
            exportURL = nil
        }

        let snapshot = LifecycleSnapshot(
            sessionId: lifecycle.sessionId,
            recommendationId: lifecycle.recommendationId,
            context: lifecycle.context,
            decision: lifecycle.decision,
            events: lifecycle.events,
            executionReturns: lifecycle.executionReturns,
            terminalEvent: lifecycle.terminalEvent,
            export: export,
            exportURL: exportURL
        )

        closedLifecycles.append(snapshot)
        lastClosedLifecycle = snapshot
        lastPersistedExport = export
        lastPersistedExportURL = exportURL
        activeLifecycle = nil
        executionStartTimes = [:]
        return snapshot
    }

    private func append(
        type: MatchingEventType,
        candidate: UnifiedMatchRecommendation,
        timestamp: Date,
        feedback: FeedbackOption? = nil,
        surfaceOverride: AppSection? = nil,
        outcome: MatchingEventOutcome? = nil
    ) {
        let surface = surfaceOverride ?? candidate.candidate.preferredSection
        _ = appendRaw(
            type: type,
            candidateId: candidate.id,
            objectType: candidate.candidate.objectKind.rawValue,
            surface: surface?.rawValue,
            timestamp: timestamp,
            feedback: feedback,
            outcome: outcome
        )
    }

    @discardableResult
    private func appendRaw(
        type: MatchingEventType,
        candidateId: String?,
        objectType: String?,
        surface: String?,
        timestamp: Date,
        feedback: FeedbackOption? = nil,
        outcome: MatchingEventOutcome? = nil,
        surfaceEntryRequestId: String? = nil
    ) -> MatchingEvent? {
        guard var lifecycle = activeLifecycle else {
            return nil
        }

        if lifecycle.terminalEvent != nil,
           type != .downstreamValue,
           type != .surfaceEntryRequested,
           type != .surfaceEntryStarted,
           type != .surfaceEntryReturned {
            return nil
        }

        let event = MatchingEvent(
            type: type,
            sessionId: lifecycle.sessionId,
            recommendationId: lifecycle.recommendationId,
            candidateId: candidateId,
            timestamp: timestamp,
            objectType: objectType,
            executionSurfaceType: surface,
            feedbackOption: feedback,
            policyVersion: lifecycle.decision.policyVersion.policyVersion,
            outcome: outcome,
            surfaceEntryRequestId: surfaceEntryRequestId
        )

        lifecycle.events.append(event)
        activeLifecycle = lifecycle

        events.append(event)
        if events.count > 512 {
            events.removeFirst(events.count - 512)
        }
        onEventAppended?(event)
        return event
    }

    nonisolated static func defaultReplayExportDirectory() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("kAir", isDirectory: true)
            .appendingPathComponent("ReplaySessions", isDirectory: true)
    }
}
