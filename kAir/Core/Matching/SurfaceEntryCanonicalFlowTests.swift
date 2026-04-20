//
//  SurfaceEntryCanonicalFlowTests.swift
//  kAir
//
//  Canonical flow tests for the Surface Entry contract. Each test builds an
//  isolated MatchingReplayLab, seeds a single chain via the same retain /
//  submit API the runtime uses, and asserts the resulting chain's shape,
//  terminal outcome, and invariants.
//
//  These tests accompany Docs/design/surface_entry_contract_audit.md and
//  pin the 10 flows declared there so the contract can't quietly drift.
//

import Foundation

struct SurfaceEntryCanonicalFlowReport {
    let results: [KernelPhase1TestResult]

    var allPassed: Bool { results.allSatisfy(\.passed) }
    var passedCount: Int { results.filter(\.passed).count }
    var failedCount: Int { results.filter { !$0.passed }.count }
}

enum SurfaceEntryCanonicalFlowTests {
    @MainActor
    static func runAll() -> SurfaceEntryCanonicalFlowReport {
        let results: [KernelPhase1TestResult] = [
            testRecommendationCompletion(),
            testRecommendationAbandon(),
            testRecommendationDismiss(),
            testDirectOpenReturned(),
            testDirectOpenInFlight(),
            testFoldbackPayloadLinksByRequestId(),
            testDirectOpenHasNilRecommendationId(),
            testPayloadWithMismatchedRequestIdFailsInvariant(),
            testReturnedOnlyFilterCoversDirectAndRec(),
            testSilentExitAbandonKeepsChainIntact(),
        ]
        return SurfaceEntryCanonicalFlowReport(results: results)
    }

    // MARK: - 1. recommendation → requested → started → returned → completion

    @MainActor
    static func testRecommendationCompletion() -> KernelPhase1TestResult {
        let name = "canonical_rec_completion"
        let lab = MatchingReplayLab()
        let baseTime = Date(timeIntervalSince1970: 1_700_000_000)

        emit(
            into: lab,
            tag: "canon-rec-complete",
            surface: .maps,
            intent: .navigate,
            hasRecommendation: true,
            baseTime: baseTime,
            outcome: .completed,
            includeReturnedEvent: true
        )

        let chain = findChain(in: lab, requestId: "canon-req-canon-rec-complete")
        guard let chain else {
            return KernelPhase1TestResult(name: name, passed: false, detail: "chain missing")
        }
        guard chain.hasRecommendation,
              chain.terminalOutcome == .completion,
              chain.invariants.allPassed,
              chain.events.count == 3,
              chain.hasReturned else {
            return KernelPhase1TestResult(
                name: name,
                passed: false,
                detail: "unexpected chain: hasRec=\(chain.hasRecommendation) terminal=\(chain.terminalOutcome) events=\(chain.events.count) returned=\(chain.hasReturned) inv=\(chain.invariants)"
            )
        }
        return KernelPhase1TestResult(
            name: name,
            passed: true,
            detail: "rec chain completed with 3 events and invariants green"
        )
    }

    // MARK: - 2. recommendation → requested → started → returned → abandon

    @MainActor
    static func testRecommendationAbandon() -> KernelPhase1TestResult {
        let name = "canonical_rec_abandon"
        let lab = MatchingReplayLab()
        let baseTime = Date(timeIntervalSince1970: 1_700_000_100)

        emit(
            into: lab,
            tag: "canon-rec-abandon",
            surface: .maps,
            intent: .reviewRoute,
            hasRecommendation: true,
            baseTime: baseTime,
            outcome: .abandoned,
            includeReturnedEvent: true
        )

        let chain = findChain(in: lab, requestId: "canon-req-canon-rec-abandon")
        guard let chain else {
            return KernelPhase1TestResult(name: name, passed: false, detail: "chain missing")
        }
        guard chain.hasRecommendation,
              chain.terminalOutcome == .abandon,
              chain.invariants.allPassed,
              chain.hasReturned else {
            return KernelPhase1TestResult(
                name: name,
                passed: false,
                detail: "unexpected: hasRec=\(chain.hasRecommendation) terminal=\(chain.terminalOutcome) inv=\(chain.invariants)"
            )
        }
        return KernelPhase1TestResult(
            name: name,
            passed: true,
            detail: "rec chain abandoned with invariants green"
        )
    }

    // MARK: - 3. recommendation → requested → started → returned → dismiss

    @MainActor
    static func testRecommendationDismiss() -> KernelPhase1TestResult {
        let name = "canonical_rec_dismiss"
        let lab = MatchingReplayLab()
        let baseTime = Date(timeIntervalSince1970: 1_700_000_200)
        let tag = "canon-rec-dismiss"
        let requestId = "canon-req-\(tag)"
        let recommendationId = "canon-rec-\(tag)"
        let candidateId = "canon-cand-\(tag)"

        let request = makeRequest(
            requestId: requestId,
            surface: .video,
            intent: .watchVideo,
            hasRecommendation: true,
            recommendationId: recommendationId,
            baseTime: baseTime
        )
        lab.retainSurfaceEntryRequest(request)
        lab.submitSurfaceEntryEvent(makeEvent(.surfaceEntryRequested, at: baseTime, recId: recommendationId, candidateId: candidateId, surface: .video, requestId: requestId))
        lab.submitSurfaceEntryEvent(makeEvent(.surfaceEntryStarted, at: baseTime.addingTimeInterval(0.25), recId: recommendationId, candidateId: candidateId, surface: .video, requestId: requestId))
        lab.submitSurfaceEntryEvent(makeEvent(.dismiss, at: baseTime.addingTimeInterval(1), recId: recommendationId, candidateId: candidateId, surface: .video, requestId: requestId))
        lab.submitSurfaceEntryEvent(makeEvent(.surfaceEntryReturned, at: baseTime.addingTimeInterval(1.05), recId: recommendationId, candidateId: candidateId, surface: .video, requestId: requestId))

        let chain = findChain(in: lab, requestId: requestId)
        guard let chain else {
            return KernelPhase1TestResult(name: name, passed: false, detail: "chain missing")
        }
        guard chain.terminalOutcome == .dismiss,
              chain.hasRecommendation,
              chain.invariants.allPassed,
              chain.hasReturned,
              chain.returnPayload == nil else {
            return KernelPhase1TestResult(
                name: name,
                passed: false,
                detail: "unexpected: terminal=\(chain.terminalOutcome) hasRec=\(chain.hasRecommendation) inv=\(chain.invariants) payload=\(String(describing: chain.returnPayload))"
            )
        }
        return KernelPhase1TestResult(
            name: name,
            passed: true,
            detail: "dismiss chain has .dismiss terminal, no payload, invariants green"
        )
    }

    // MARK: - 4. direct-open → requested → started → returned

    @MainActor
    static func testDirectOpenReturned() -> KernelPhase1TestResult {
        let name = "canonical_direct_returned"
        let lab = MatchingReplayLab()
        let baseTime = Date(timeIntervalSince1970: 1_700_000_300)

        emit(
            into: lab,
            tag: "canon-direct-return",
            surface: .music,
            intent: .playMusic,
            hasRecommendation: false,
            baseTime: baseTime,
            outcome: .completed,
            includeReturnedEvent: true
        )

        let chain = findChain(in: lab, requestId: "canon-req-canon-direct-return")
        guard let chain else {
            return KernelPhase1TestResult(name: name, passed: false, detail: "chain missing")
        }
        guard chain.hasRecommendation == false,
              chain.terminalOutcome == .completion,
              chain.invariants.allPassed,
              chain.hasReturned else {
            return KernelPhase1TestResult(
                name: name,
                passed: false,
                detail: "unexpected: hasRec=\(chain.hasRecommendation) terminal=\(chain.terminalOutcome) inv=\(chain.invariants)"
            )
        }
        return KernelPhase1TestResult(
            name: name,
            passed: true,
            detail: "direct-open chain completed, sourceRecommendationId is nil"
        )
    }

    // MARK: - 5. direct-open → inFlight

    @MainActor
    static func testDirectOpenInFlight() -> KernelPhase1TestResult {
        let name = "canonical_direct_in_flight"
        let lab = MatchingReplayLab()
        let baseTime = Date(timeIntervalSince1970: 1_700_000_400)
        let tag = "canon-direct-inflight"
        let requestId = "canon-req-\(tag)"
        let recommendationId = "synthetic-direct-canon-\(tag)"
        let candidateId = "canon-cand-\(tag)"

        let request = makeRequest(
            requestId: requestId,
            surface: .ai,
            intent: .openAI,
            hasRecommendation: false,
            recommendationId: recommendationId,
            baseTime: baseTime
        )
        lab.retainSurfaceEntryRequest(request)
        lab.submitSurfaceEntryEvent(makeEvent(.surfaceEntryRequested, at: baseTime, recId: recommendationId, candidateId: candidateId, surface: .ai, requestId: requestId))
        lab.submitSurfaceEntryEvent(makeEvent(.surfaceEntryStarted, at: baseTime.addingTimeInterval(0.25), recId: recommendationId, candidateId: candidateId, surface: .ai, requestId: requestId))

        let chain = findChain(in: lab, requestId: requestId)
        guard let chain else {
            return KernelPhase1TestResult(name: name, passed: false, detail: "chain missing")
        }
        guard chain.terminalOutcome == .inFlight,
              chain.hasRecommendation == false,
              chain.invariants.allPassed,
              chain.hasReturned == false,
              chain.events.count == 2 else {
            return KernelPhase1TestResult(
                name: name,
                passed: false,
                detail: "unexpected: terminal=\(chain.terminalOutcome) returned=\(chain.hasReturned) events=\(chain.events.count) inv=\(chain.invariants)"
            )
        }
        return KernelPhase1TestResult(
            name: name,
            passed: true,
            detail: "direct-open in-flight chain has 2 events, no returned, invariants green"
        )
    }

    // MARK: - 6. foldback return payload links back to chain by requestId

    @MainActor
    static func testFoldbackPayloadLinksByRequestId() -> KernelPhase1TestResult {
        let name = "canonical_foldback_payload_links"
        let lab = MatchingReplayLab()
        let baseTime = Date(timeIntervalSince1970: 1_700_000_500)

        emit(
            into: lab,
            tag: "canon-foldback",
            surface: .health,
            intent: .openHealth,
            hasRecommendation: true,
            baseTime: baseTime,
            outcome: .completed,
            includeReturnedEvent: true
        )

        let requestId = "canon-req-canon-foldback"
        let chain = findChain(in: lab, requestId: requestId)
        guard let chain, let payload = chain.returnPayload else {
            return KernelPhase1TestResult(name: name, passed: false, detail: "chain or payload missing")
        }
        guard payload.sourceRequestId == requestId,
              chain.invariants.payloadLinksMatchChain,
              chain.invariants.allPassed,
              chain.terminalOutcome == .completion else {
            return KernelPhase1TestResult(
                name: name,
                passed: false,
                detail: "payload mismatch: sourceRequestId=\(payload.sourceRequestId ?? "nil") inv=\(chain.invariants)"
            )
        }
        return KernelPhase1TestResult(
            name: name,
            passed: true,
            detail: "payload.sourceRequestId matches chain.requestId and payloadLinksMatchChain passes"
        )
    }

    // MARK: - 7. direct-open with sourceRecommendationId=nil is semantically correct

    @MainActor
    static func testDirectOpenHasNilRecommendationId() -> KernelPhase1TestResult {
        let name = "canonical_direct_nil_recommendation_id"
        let lab = MatchingReplayLab()
        let baseTime = Date(timeIntervalSince1970: 1_700_000_600)

        emit(
            into: lab,
            tag: "canon-direct-nilrec",
            surface: .store,
            intent: .openStore,
            hasRecommendation: false,
            baseTime: baseTime,
            outcome: .completed,
            includeReturnedEvent: true
        )

        let chain = findChain(in: lab, requestId: "canon-req-canon-direct-nilrec")
        guard let chain, let request = chain.request else {
            return KernelPhase1TestResult(name: name, passed: false, detail: "chain or request missing")
        }
        guard request.sourceRecommendationId == nil,
              request.sourceCardId == nil,
              chain.hasRecommendation == false,
              chain.sourceRecommendationId == nil,
              chain.invariants.allPassed else {
            return KernelPhase1TestResult(
                name: name,
                passed: false,
                detail: "unexpected: reqRec=\(request.sourceRecommendationId ?? "nil") card=\(request.sourceCardId ?? "nil") chainRec=\(chain.sourceRecommendationId ?? "nil") hasRec=\(chain.hasRecommendation) inv=\(chain.invariants)"
            )
        }
        return KernelPhase1TestResult(
            name: name,
            passed: true,
            detail: "direct-open chain carries nil sourceRecommendationId and nil sourceCardId, hasRecommendation=false"
        )
    }

    // MARK: - 8. payload sourceRequestId must match request chain

    @MainActor
    static func testPayloadWithMismatchedRequestIdFailsInvariant() -> KernelPhase1TestResult {
        let name = "canonical_payload_request_id_mismatch"
        let lab = MatchingReplayLab()
        let baseTime = Date(timeIntervalSince1970: 1_700_000_700)
        let tag = "canon-mismatch"
        let requestId = "canon-req-\(tag)"
        let recommendationId = "canon-rec-\(tag)"
        let candidateId = "canon-cand-\(tag)"

        let request = makeRequest(
            requestId: requestId,
            surface: .maps,
            intent: .navigate,
            hasRecommendation: true,
            recommendationId: recommendationId,
            baseTime: baseTime
        )
        lab.retainSurfaceEntryRequest(request)
        lab.submitSurfaceEntryEvent(makeEvent(.surfaceEntryRequested, at: baseTime, recId: recommendationId, candidateId: candidateId, surface: .maps, requestId: requestId))
        lab.submitSurfaceEntryEvent(makeEvent(.surfaceEntryStarted, at: baseTime.addingTimeInterval(0.25), recId: recommendationId, candidateId: candidateId, surface: .maps, requestId: requestId))
        lab.submitSurfaceEntryEvent(makeEvent(.surfaceEntryReturned, at: baseTime.addingTimeInterval(1), recId: recommendationId, candidateId: candidateId, surface: .maps, requestId: requestId))

        // Payload declares a DIFFERENT sourceRequestId. Because
        // MatchingReplayLab.retainSurfaceEntryReturnPayload keys by the
        // payload's own sourceRequestId, we inject it directly into the
        // retainedPayloads map so it binds to the real chain's requestId
        // while still carrying a mismatched sourceRequestId string.
        let mismatchedPayload = ExecutionReturnPayload(
            executedCandidateId: candidateId,
            executionSurfaceType: .maps,
            outcome: .completed,
            duration: 1.0,
            returnContextDelta: .neutral,
            sourceRequestId: "canon-req-OTHER",
            sourceRecommendationId: recommendationId
        )
        lab.surfaceEntryReturnPayloadsById[requestId] = mismatchedPayload

        guard let chain = findChain(in: lab, requestId: requestId) else {
            return KernelPhase1TestResult(name: name, passed: false, detail: "chain missing")
        }
        guard chain.invariants.payloadLinksMatchChain == false else {
            return KernelPhase1TestResult(
                name: name,
                passed: false,
                detail: "invariant unexpectedly passed: inv=\(chain.invariants)"
            )
        }
        return KernelPhase1TestResult(
            name: name,
            passed: true,
            detail: "mismatched payload.sourceRequestId correctly fails payloadLinksMatchChain invariant"
        )
    }

    // MARK: - 9. returned-only filter covers both direct and rec chains

    @MainActor
    static func testReturnedOnlyFilterCoversDirectAndRec() -> KernelPhase1TestResult {
        let name = "canonical_returned_only_filter"
        let lab = MatchingReplayLab()
        let baseTime = Date(timeIntervalSince1970: 1_700_000_800)

        // Returned rec chain
        emit(
            into: lab,
            tag: "canon-rof-rec",
            surface: .music,
            intent: .playMusic,
            hasRecommendation: true,
            baseTime: baseTime,
            outcome: .completed,
            includeReturnedEvent: true
        )
        // Returned direct chain
        emit(
            into: lab,
            tag: "canon-rof-direct",
            surface: .video,
            intent: .watchVideo,
            hasRecommendation: false,
            baseTime: baseTime.addingTimeInterval(10),
            outcome: .completed,
            includeReturnedEvent: true
        )
        // In-flight direct chain (not returned)
        let inflightRequestId = "canon-req-canon-rof-inflight"
        let inflightRecId = "synthetic-direct-canon-rof-inflight"
        let inflightRequest = makeRequest(
            requestId: inflightRequestId,
            surface: .ai,
            intent: .openAI,
            hasRecommendation: false,
            recommendationId: inflightRecId,
            baseTime: baseTime.addingTimeInterval(20)
        )
        lab.retainSurfaceEntryRequest(inflightRequest)
        lab.submitSurfaceEntryEvent(makeEvent(.surfaceEntryRequested, at: baseTime.addingTimeInterval(20), recId: inflightRecId, candidateId: "c", surface: .ai, requestId: inflightRequestId))
        lab.submitSurfaceEntryEvent(makeEvent(.surfaceEntryStarted, at: baseTime.addingTimeInterval(20.25), recId: inflightRecId, candidateId: "c", surface: .ai, requestId: inflightRequestId))

        let chains = lab.surfaceEntryChains
        guard chains.count == 3 else {
            return KernelPhase1TestResult(
                name: name,
                passed: false,
                detail: "expected 3 chains, got \(chains.count)"
            )
        }
        var filter = SurfaceEntryChainFilter.none
        filter.returnedOnly = true
        let returnedOnly = filter.apply(to: chains)
        guard returnedOnly.count == 2,
              returnedOnly.contains(where: { $0.hasRecommendation }),
              returnedOnly.contains(where: { !$0.hasRecommendation }) else {
            let shape = returnedOnly.map { "\($0.requestId)/hasRec=\($0.hasRecommendation)/returned=\($0.hasReturned)" }
            return KernelPhase1TestResult(
                name: name,
                passed: false,
                detail: "returned-only mix wrong: \(shape)"
            )
        }
        return KernelPhase1TestResult(
            name: name,
            passed: true,
            detail: "returned-only filter kept 2 chains (1 rec + 1 direct) and dropped the in-flight"
        )
    }

    // MARK: - 10. silent-exit abandon keeps the chain intact

    @MainActor
    static func testSilentExitAbandonKeepsChainIntact() -> KernelPhase1TestResult {
        let name = "canonical_silent_exit_abandon"
        let lab = MatchingReplayLab()
        let baseTime = Date(timeIntervalSince1970: 1_700_000_900)

        emit(
            into: lab,
            tag: "canon-silent-exit",
            surface: .health,
            intent: .openHealth,
            hasRecommendation: true,
            baseTime: baseTime,
            outcome: .abandoned,
            includeReturnedEvent: true
        )

        let chain = findChain(in: lab, requestId: "canon-req-canon-silent-exit")
        guard let chain else {
            return KernelPhase1TestResult(name: name, passed: false, detail: "chain missing")
        }
        let eventTypes = Set(chain.events.map(\.type))
        let expected: Set<MatchingEventType> = [
            .surfaceEntryRequested, .surfaceEntryStarted, .surfaceEntryReturned,
        ]
        guard eventTypes == expected,
              chain.terminalOutcome == .abandon,
              chain.invariants.allPassed,
              chain.hasReturned,
              chain.requestedAt != nil,
              chain.startedAt != nil,
              chain.returnedAt != nil else {
            return KernelPhase1TestResult(
                name: name,
                passed: false,
                detail: "chain broken: events=\(eventTypes) terminal=\(chain.terminalOutcome) inv=\(chain.invariants)"
            )
        }
        return KernelPhase1TestResult(
            name: name,
            passed: true,
            detail: "silent-exit abandon chain has all 3 phases and abandon terminal with invariants green"
        )
    }

    // MARK: - Helpers

    @MainActor
    private static func emit(
        into lab: MatchingReplayLab,
        tag: String,
        surface: AppSection,
        intent: SurfaceEntryIntent,
        hasRecommendation: Bool,
        baseTime: Date,
        outcome: ExecutionOutcome,
        includeReturnedEvent: Bool
    ) {
        let requestId = "canon-req-\(tag)"
        // Direct-open chains use a `synthetic-direct-*` sentinel so
        // SurfaceEntryReplayBuilder's "synthetic-" prefix check maps the
        // event-level recommendationId back to nil, matching the runtime
        // semantic where a direct open has no real recommendation.
        let recommendationId = hasRecommendation ? "canon-rec-\(tag)" : "synthetic-direct-canon-\(tag)"
        let candidateId = "canon-cand-\(tag)"

        let request = makeRequest(
            requestId: requestId,
            surface: surface,
            intent: intent,
            hasRecommendation: hasRecommendation,
            recommendationId: recommendationId,
            baseTime: baseTime
        )
        lab.retainSurfaceEntryRequest(request)

        lab.submitSurfaceEntryEvent(makeEvent(.surfaceEntryRequested, at: baseTime, recId: recommendationId, candidateId: candidateId, surface: surface, requestId: requestId))
        lab.submitSurfaceEntryEvent(makeEvent(.surfaceEntryStarted, at: baseTime.addingTimeInterval(0.25), recId: recommendationId, candidateId: candidateId, surface: surface, requestId: requestId))

        let payload = ExecutionReturnPayload(
            executedCandidateId: candidateId,
            executionSurfaceType: surface,
            outcome: outcome,
            duration: 1.0,
            returnContextDelta: .neutral,
            sourceRequestId: requestId,
            sourceRecommendationId: hasRecommendation ? recommendationId : nil
        )
        lab.retainSurfaceEntryReturnPayload(payload)

        if includeReturnedEvent {
            lab.submitSurfaceEntryEvent(
                makeEvent(
                    .surfaceEntryReturned,
                    at: baseTime.addingTimeInterval(1),
                    recId: recommendationId,
                    candidateId: candidateId,
                    surface: surface,
                    requestId: requestId,
                    outcome: payload.toOutcomeEventPayload
                )
            )
        }
    }

    private static func makeRequest(
        requestId: String,
        surface: AppSection,
        intent: SurfaceEntryIntent,
        hasRecommendation: Bool,
        recommendationId: String,
        baseTime: Date
    ) -> SurfaceEntryRequest {
        SurfaceEntryRequest(
            requestId: requestId,
            surfaceType: surface,
            entryIntent: intent,
            sourceCardId: hasRecommendation ? "canon-card-\(recommendationId)" : nil,
            sourceRecommendationId: hasRecommendation ? recommendationId : nil,
            sourceThreadId: "canon-thread",
            objectType: nil,
            objectId: nil,
            normalizedArgs: [:],
            requiresConfirmation: false,
            handoffContext: SurfaceEntryHandoffContext(
                sourceMessagePreview: "canonical test",
                returnThreadId: "canon-thread",
                priorContextStateSummary: nil
            ),
            issuedAt: baseTime
        )
    }

    private static func makeEvent(
        _ type: MatchingEventType,
        at timestamp: Date,
        recId: String,
        candidateId: String,
        surface: AppSection,
        requestId: String,
        outcome: MatchingEventOutcome? = nil
    ) -> MatchingEvent {
        MatchingEvent(
            type: type,
            sessionId: "canonical-session",
            recommendationId: recId,
            candidateId: candidateId,
            timestamp: timestamp,
            objectType: nil,
            executionSurfaceType: surface.rawValue,
            feedbackOption: nil,
            policyVersion: MatchingPolicyVersion.current.policyVersion,
            outcome: outcome,
            surfaceEntryRequestId: requestId
        )
    }

    @MainActor
    private static func findChain(in lab: MatchingReplayLab, requestId: String) -> SurfaceEntryChain? {
        lab.surfaceEntryChains.first { $0.requestId == requestId }
    }
}
