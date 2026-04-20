//
//  EventLoopTests.swift
//  kAir
//
//  P2 tests for the runtime event loop and replay export pipeline.
//  Covers serialization round-trips for MatchingEvent, MatchingContextSnapshot,
//  ExecutionReturnPayload, and an end-to-end integration that drives the
//  recorder through impression → click → accept → execution-return → export.
//

import Foundation

struct EventLoopTestReport {
    let results: [KernelPhase1TestResult]

    var allPassed: Bool { results.allSatisfy(\.passed) }
    var passedCount: Int { results.filter(\.passed).count }
    var failedCount: Int { results.filter { !$0.passed }.count }
}

enum EventLoopTests {
    @MainActor
    static func runAll() -> EventLoopTestReport {
        let results: [KernelPhase1TestResult] = [
            testMatchingEventSerialization(),
            testContextSnapshotSerialization(),
            testExecutionReturnPayloadSerialization(),
            testReplayExportCompleteness(),
            testEndToEndLifecycle(),
            testExecutionReturnFoldbackInfluencesNextDecision(),
            testSilentExitEmitsAbandonWithSingleTerminal(),
        ]
        return EventLoopTestReport(results: results)
    }

    // MARK: - Test 1: MatchingEvent serialization

    static func testMatchingEventSerialization() -> KernelPhase1TestResult {
        let event = MatchingEvent(
            type: .impression,
            sessionId: "sess-1",
            recommendationId: "rec-chat-1",
            candidateId: "cand-1",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            objectType: "place",
            executionSurfaceType: AppSection.maps.rawValue,
            feedbackOption: .notInterested,
            policyVersion: MatchingPolicyVersion.current.policyVersion,
            outcome: MatchingEventOutcome(
                completionScore: 0.4,
                downstreamValue: 0.7,
                dwellSeconds: 12,
                wasSuccessful: true
            )
        )
        do {
            let data = try event.encodeJSONData()
            let decoded = try MatchingEvent.decode(from: data)
            guard decoded == event else {
                return KernelPhase1TestResult(
                    name: "matching_event_serialization",
                    passed: false,
                    detail: "round-trip mismatch"
                )
            }
            return KernelPhase1TestResult(
                name: "matching_event_serialization",
                passed: true,
                detail: "\(data.count) bytes"
            )
        } catch {
            return KernelPhase1TestResult(
                name: "matching_event_serialization",
                passed: false,
                detail: "threw: \(error)"
            )
        }
    }

    // MARK: - Test 2: MatchingContextSnapshot serialization

    static func testContextSnapshotSerialization() -> KernelPhase1TestResult {
        let snapshot = fixtureContextSnapshot()
        do {
            let data = try snapshot.encodeJSONData()
            let decoded = try MatchingContextSnapshot.decode(from: data)
            guard decoded == snapshot else {
                return KernelPhase1TestResult(
                    name: "context_snapshot_serialization",
                    passed: false,
                    detail: "round-trip mismatch"
                )
            }
            guard decoded.policyVersion == MatchingPolicyVersion.current.policyVersion else {
                return KernelPhase1TestResult(
                    name: "context_snapshot_serialization",
                    passed: false,
                    detail: "policyVersion missing"
                )
            }
            return KernelPhase1TestResult(
                name: "context_snapshot_serialization",
                passed: true,
                detail: "\(data.count) bytes"
            )
        } catch {
            return KernelPhase1TestResult(
                name: "context_snapshot_serialization",
                passed: false,
                detail: "threw: \(error)"
            )
        }
    }

    // MARK: - Test 3: ExecutionReturnPayload serialization

    static func testExecutionReturnPayloadSerialization() -> KernelPhase1TestResult {
        let payload = ExecutionReturnPayload(
            executedCandidateId: "cand-9",
            executionSurfaceType: .music,
            outcome: .completed,
            duration: 184,
            returnContextDelta: ExecutionReturnPayload.ReturnContextDelta(
                downstreamValue: 0.58,
                completionScore: 0.66,
                addedIntentTags: [.planning],
                resolvedObjectIds: ["cand-9"],
                dismissedObjectIds: [],
                summary: "Focus playlist started"
            )
        )
        do {
            let data = try payload.encodeJSONData()
            let decoded = try ExecutionReturnPayload.decode(from: data)
            guard decoded == payload else {
                return KernelPhase1TestResult(
                    name: "execution_return_payload_serialization",
                    passed: false,
                    detail: "round-trip mismatch"
                )
            }
            let outcome = decoded.toOutcomeEventPayload
            guard outcome.wasSuccessful else {
                return KernelPhase1TestResult(
                    name: "execution_return_payload_serialization",
                    passed: false,
                    detail: "toOutcomeEventPayload did not carry success"
                )
            }
            return KernelPhase1TestResult(
                name: "execution_return_payload_serialization",
                passed: true,
                detail: "\(data.count) bytes"
            )
        } catch {
            return KernelPhase1TestResult(
                name: "execution_return_payload_serialization",
                passed: false,
                detail: "threw: \(error)"
            )
        }
    }

    // MARK: - Test 4: ReplaySnapshotExporter completeness

    @MainActor
    static func testReplayExportCompleteness() -> KernelPhase1TestResult {
        let recorder = MatchingEventRecorder(
            sessionId: "sess-export",
            exportDirectory: temporaryExportDirectory(named: "sess-export")
        )
        let (context, decision) = fixtureDecisionAndContext()
        recorder.beginLifecycle(context: context, decision: decision)
        guard let direct = decision.directSlotCandidate ?? decision.rankedCandidates.first else {
            return KernelPhase1TestResult(
                name: "replay_export_completeness",
                passed: false,
                detail: "decision missing candidates"
            )
        }
        recorder.recordClick(candidate: direct)
        recorder.recordAccept(candidate: direct)

        let payload = ExecutionReturnPayload(
            executedCandidateId: direct.id,
            executionSurfaceType: direct.candidate.preferredSection ?? .chat,
            outcome: .completed,
            duration: 42,
            returnContextDelta: .neutral
        )
        recorder.recordExecutionReturn(payload: payload, candidate: direct)

        guard let export = recorder.lastPersistedExport else {
            return KernelPhase1TestResult(
                name: "replay_export_completeness",
                passed: false,
                detail: "terminal close did not persist export"
            )
        }
        guard let exportURL = recorder.lastPersistedExportURL,
              FileManager.default.fileExists(atPath: exportURL.path) else {
            return KernelPhase1TestResult(
                name: "replay_export_completeness",
                passed: false,
                detail: "persisted replay file missing"
            )
        }

        guard export.schemaVersion == ReplayExportedSession.currentSchemaVersion else {
            return KernelPhase1TestResult(
                name: "replay_export_completeness",
                passed: false,
                detail: "schemaVersion mismatch: \(export.schemaVersion)"
            )
        }
        guard export.sessionId == "sess-export" else {
            return KernelPhase1TestResult(
                name: "replay_export_completeness",
                passed: false,
                detail: "sessionId mismatch"
            )
        }
        guard export.decision.recommendationId == decision.recommendationId else {
            return KernelPhase1TestResult(
                name: "replay_export_completeness",
                passed: false,
                detail: "decision id mismatch"
            )
        }
        guard export.executionReturns.count == 1 else {
            return KernelPhase1TestResult(
                name: "replay_export_completeness",
                passed: false,
                detail: "expected 1 execution return, got \(export.executionReturns.count)"
            )
        }

        do {
            let encoder = ReplayExportedSession.jsonEncoder()
            let firstData = try encoder.encode(export)
            let roundtrip = try ReplayExportedSession.decode(from: firstData)
            let secondData = try encoder.encode(roundtrip)
            guard firstData == secondData else {
                return KernelPhase1TestResult(
                    name: "replay_export_completeness",
                    passed: false,
                    detail: "canonical encoding unstable across round-trip"
                )
            }
        } catch {
            return KernelPhase1TestResult(
                name: "replay_export_completeness",
                passed: false,
                detail: "encode/decode threw: \(error)"
            )
        }

        return KernelPhase1TestResult(
            name: "replay_export_completeness",
            passed: true,
            detail: "events=\(export.events.count) returns=\(export.executionReturns.count)"
        )
    }

    // MARK: - Test 5: end-to-end lifecycle

    @MainActor
    static func testEndToEndLifecycle() -> KernelPhase1TestResult {
        let recorder = MatchingEventRecorder(
            sessionId: "sess-e2e",
            exportDirectory: temporaryExportDirectory(named: "sess-e2e")
        )
        let (context, decision) = fixtureDecisionAndContext()
        recorder.beginLifecycle(context: context, decision: decision)

        guard let direct = decision.directSlotCandidate ?? decision.rankedCandidates.first else {
            return KernelPhase1TestResult(
                name: "event_loop_end_to_end",
                passed: false,
                detail: "decision missing candidates"
            )
        }

        recorder.recordClick(candidate: direct)
        recorder.recordAccept(candidate: direct)
        recorder.recordExecutionOpen(candidate: direct, surface: .maps)
        recorder.recordExecutionReturn(
            payload: ExecutionReturnPayload(
                executedCandidateId: direct.id,
                executionSurfaceType: .maps,
                outcome: .completed,
                duration: 60,
                returnContextDelta: ExecutionReturnPayload.ReturnContextDelta(
                    downstreamValue: 0.75,
                    completionScore: 0.8,
                    addedIntentTags: [],
                    resolvedObjectIds: [direct.id],
                    dismissedObjectIds: [],
                    summary: nil
                )
            ),
            candidate: direct
        )

        let events = recorder.eventLog
        let types = Set(events.map(\.type))
        guard types.contains(.impression) else {
            return KernelPhase1TestResult(
                name: "event_loop_end_to_end",
                passed: false,
                detail: "no impression emitted"
            )
        }
        guard types.contains(.click) else {
            return KernelPhase1TestResult(
                name: "event_loop_end_to_end",
                passed: false,
                detail: "no click emitted"
            )
        }
        guard types.contains(.accept) else {
            return KernelPhase1TestResult(
                name: "event_loop_end_to_end",
                passed: false,
                detail: "no accept emitted"
            )
        }
        guard types.contains(.completion) else {
            return KernelPhase1TestResult(
                name: "event_loop_end_to_end",
                passed: false,
                detail: "no completion emitted"
            )
        }
        guard events.allSatisfy({ $0.sessionId == "sess-e2e" }) else {
            return KernelPhase1TestResult(
                name: "event_loop_end_to_end",
                passed: false,
                detail: "inconsistent sessionId across events"
            )
        }
        guard events.allSatisfy({ $0.recommendationId == decision.recommendationId }) else {
            return KernelPhase1TestResult(
                name: "event_loop_end_to_end",
                passed: false,
                detail: "event recommendationId does not match decision"
            )
        }
        guard events.allSatisfy({ $0.policyVersion == decision.policyVersion.policyVersion }) else {
            return KernelPhase1TestResult(
                name: "event_loop_end_to_end",
                passed: false,
                detail: "event policyVersion drifted from decision"
            )
        }

        guard let export = recorder.lastPersistedExport else {
            return KernelPhase1TestResult(
                name: "event_loop_end_to_end",
                passed: false,
                detail: "terminal close did not persist export"
            )
        }
        guard export.events.count == events.count else {
            return KernelPhase1TestResult(
                name: "event_loop_end_to_end",
                passed: false,
                detail: "export dropped events: \(export.events.count) vs \(events.count)"
            )
        }
        guard export.executionReturns.count == 1 else {
            return KernelPhase1TestResult(
                name: "event_loop_end_to_end",
                passed: false,
                detail: "expected 1 execution return in export"
            )
        }

        return KernelPhase1TestResult(
            name: "event_loop_end_to_end",
            passed: true,
            detail: "events=\(events.count) types=\(types.count)"
        )
    }

    @MainActor
    static func testExecutionReturnFoldbackInfluencesNextDecision() -> KernelPhase1TestResult {
        let engine = UnifiedMatchingEngine(
            strategyID: "foldback-test",
            candidateProviders: [FoldbackAwareProvider()]
        )
        let store = ChatStore(
            replayLab: MatchingReplayLab(),
            matchingEngine: engine,
            eventRecorder: MatchingEventRecorder(
                sessionId: "sess-foldback",
                exportDirectory: temporaryExportDirectory(named: "sess-foldback")
            )
        )
        store.bootstrapWithoutDashboard(supportsHealthData: false)

        let payload = ExecutionReturnPayload(
            executedCandidateId: "focus-song",
            executionSurfaceType: .music,
            outcome: .completed,
            duration: 120,
            returnContextDelta: ExecutionReturnPayload.ReturnContextDelta(
                downstreamValue: 0.7,
                completionScore: 0.75,
                addedIntentTags: [.focus],
                resolvedObjectIds: ["focus-song"],
                dismissedObjectIds: [],
                summary: "Focus playback completed"
            )
        )
        store.debugApplyExecutionReturnPayload(payload)

        guard store.debugPendingReturnContextState?.addedIntentTags.contains(.focus) == true else {
            return KernelPhase1TestResult(
                name: "execution_return_foldback",
                passed: false,
                detail: "pending foldback state was not stored on ChatStore"
            )
        }

        let session = ChatSession(
            title: "foldback-fixture",
            messages: [.user(text: "what should I do next", timestamp: .now)]
        )
        let baseline = engine.decideWithSnapshot(
            recentPrompt: "what should I do next",
            session: session,
            healthAvailability: .availableLater,
            locationState: .unknown,
            motionContext: .stationary,
            behaviorLog: [],
            returnContextState: nil,
            activeSurface: .chat
        )
        let folded = engine.decideWithSnapshot(
            recentPrompt: "what should I do next",
            session: session,
            healthAvailability: .availableLater,
            locationState: .unknown,
            motionContext: .stationary,
            behaviorLog: [],
            returnContextState: store.debugPendingReturnContextState,
            activeSurface: .chat
        )

        guard folded.decision.directSlotCandidateId == "focus-song" else {
            return KernelPhase1TestResult(
                name: "execution_return_foldback",
                passed: false,
                detail: "next decision ignored folded return state: \(folded.decision.directSlotCandidateId ?? "nil")"
            )
        }
        guard baseline.decision.directSlotCandidateId != folded.decision.directSlotCandidateId else {
            return KernelPhase1TestResult(
                name: "execution_return_foldback",
                passed: false,
                detail: "foldback did not change the next decision: \(folded.decision.directSlotCandidateId ?? "nil")"
            )
        }

        return KernelPhase1TestResult(
            name: "execution_return_foldback",
            passed: true,
            detail: "baseline=\(baseline.decision.directSlotCandidateId ?? "nil") next=focus-song"
        )
    }

    @MainActor
    static func testSilentExitEmitsAbandonWithSingleTerminal() -> KernelPhase1TestResult {
        let recorder = MatchingEventRecorder(
            sessionId: "sess-abandon",
            exportDirectory: temporaryExportDirectory(named: "sess-abandon")
        )
        let (context, decision) = fixtureDecisionAndContext()
        recorder.beginLifecycle(context: context, decision: decision)

        guard let direct = decision.directSlotCandidate ?? decision.rankedCandidates.first else {
            return KernelPhase1TestResult(
                name: "silent_exit_emits_abandon",
                passed: false,
                detail: "decision missing candidates"
            )
        }

        recorder.recordClick(candidate: direct)
        recorder.recordAccept(candidate: direct)
        recorder.recordAbandon(candidate: direct, surface: .maps)
        recorder.recordAbandon(candidate: direct, surface: .maps)

        guard let export = recorder.lastPersistedExport else {
            return KernelPhase1TestResult(
                name: "silent_exit_emits_abandon",
                passed: false,
                detail: "abandon did not persist export"
            )
        }

        let terminalEvents = export.events.filter {
            $0.type == .dismiss || $0.type == .completion || $0.type == .abandon
        }
        guard terminalEvents.count == 1, terminalEvents.first?.type == .abandon else {
            return KernelPhase1TestResult(
                name: "silent_exit_emits_abandon",
                passed: false,
                detail: "expected exactly one abandon terminal, got \(terminalEvents.map { $0.type.rawValue })"
            )
        }

        return KernelPhase1TestResult(
            name: "silent_exit_emits_abandon",
            passed: true,
            detail: "terminal=\(terminalEvents.first?.type.rawValue ?? "nil")"
        )
    }

    // MARK: - Fixtures

    private static func fixtureContextSnapshot() -> MatchingContextSnapshot {
        MatchingContextSnapshot(
            prompt: "take me home",
            recentBehavior: [
                MatchingContextSnapshot.RecentBehaviorEntry(
                    stage: "impression",
                    subject: "recommendation",
                    candidateId: "cand-a",
                    objectType: "place",
                    surface: "maps",
                    feedback: nil,
                    timestamp: Date(timeIntervalSince1970: 1_700_000_000)
                )
            ],
            activeSurface: .chat,
            daypart: .morning,
            locationState: .precise,
            healthAvailability: .ready,
            motionContext: .stationary,
            intentTags: [.planning],
            longTermTags: [.planning],
            foldedIntentTags: [.focus],
            resolvedObjectIds: ["cand-a"],
            dismissedObjectIds: [],
            executionSurfaceStates: [
                MatchingContextSnapshot.ExecutionSurfaceState(
                    section: .music,
                    outcome: .completed,
                    downstreamValue: 0.7,
                    completionScore: 0.75
                )
            ],
            threadDepth: 3,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_123),
            policyVersion: MatchingPolicyVersion.current.policyVersion
        )
    }

    @MainActor
    private static func fixtureDecisionAndContext() -> (MatchingContextSnapshot, RecommendationDecision) {
        let engine = UnifiedMatchingEngine()
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_500)
        let session = ChatSession(
            title: "event-loop-fixture",
            messages: [
                .user(text: "take me home", timestamp: capturedAt.addingTimeInterval(-10))
            ]
        )
        let bundle = engine.decideWithSnapshot(
            recentPrompt: "take me home",
            session: session,
            healthAvailability: .ready,
            locationState: .precise,
            motionContext: .stationary,
            behaviorLog: [],
            activeSurface: .chat,
            now: capturedAt
        )
        return (bundle.contextSnapshot, bundle.decision)
    }

    private static func temporaryExportDirectory(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kair-tests", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
    }
}

private struct FoldbackAwareProvider: CandidateProvider {
    let id = "foldback-aware"
    let versionID = "foldback-aware-v1"

    func generateCandidates(for context: MatchingFeatureContext) -> [UnifiedMatchingCandidate] {
        let generic = UnifiedMatchingCandidate(
            id: "generic-thread",
            title: "Keep chatting",
            summary: "Stay in the thread",
            objectKind: .thread,
            preferredSection: .chat,
            activationPrompt: "keep chatting",
            tags: [.planning],
            sourcePool: id,
            retrieval: MatchingRetrievalDescriptor(
                providerID: id,
                retrievalScore: 0.34,
                coarseReasonTags: [.context],
                metadata: []
            ),
            utilityProfile: MatchingUtilityProfile(
                goal: .taskCompletion,
                domainWeight: 0.58,
                nextStepWeight: 0.26
            )
        )

        let focus = UnifiedMatchingCandidate(
            id: "focus-song",
            title: "Resume focus mix",
            summary: "Go back to a focus playlist",
            objectKind: .song,
            preferredSection: .music,
            activationPrompt: "play focus music",
            tags: [.focus, .entertainment],
            sourcePool: id,
            retrieval: MatchingRetrievalDescriptor(
                providerID: id,
                retrievalScore: 0.92,
                coarseReasonTags: [.context],
                metadata: []
            ),
            utilityProfile: MatchingUtilityProfile(
                goal: .sessionSatisfaction,
                domainWeight: 0.86,
                nextStepWeight: 0.94
            )
        )

        if context.foldedIntentTags.contains(.focus) {
            return [focus, generic]
        }

        return [generic]
    }
}
