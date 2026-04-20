//
//  SurfaceEntryChain.swift
//  kAir
//
//  Aggregation layer that groups Matching events by their
//  `surfaceEntryRequestId` so the replay / evaluation panel can show
//  one row per entry attempt with the full request→return payload.
//
//  Pure data: no UI, no state. Builds chains from
//  (events, retainedRequests, retainedPayloads) and computes the 3
//  contract invariants per chain.
//

import Foundation

enum SurfaceEntryTerminalOutcome: String, Hashable, Sendable {
    case completion
    case abandon
    case dismiss
    case returnedOnly
    case inFlight
}

struct SurfaceEntryChainEvent: Identifiable, Hashable, Sendable {
    let id: UUID
    let type: MatchingEventType
    let timestamp: Date
    let recommendationId: String
    let candidateId: String?
    let surface: String?
}

struct SurfaceEntryInvariantResults: Hashable, Sendable {
    let requestedStartedPaired: Bool
    let returnedLinksByRequestId: Bool
    let payloadLinksMatchChain: Bool

    var allPassed: Bool {
        requestedStartedPaired && returnedLinksByRequestId && payloadLinksMatchChain
    }
}

struct SurfaceEntryChain: Identifiable, Hashable, Sendable {
    let requestId: String
    let request: SurfaceEntryRequest?
    let surfaceType: AppSection
    let entryIntent: SurfaceEntryIntent
    let sourceRecommendationId: String?
    let objectType: String?
    let objectId: String?
    let normalizedArgs: [String: String]
    let requestedAt: Date?
    let startedAt: Date?
    let returnedAt: Date?
    let terminalOutcome: SurfaceEntryTerminalOutcome
    let returnPayload: ExecutionReturnPayload?
    let events: [SurfaceEntryChainEvent]
    let invariants: SurfaceEntryInvariantResults

    var id: String { requestId }
    var hasRecommendation: Bool { sourceRecommendationId != nil }
    var hasReturned: Bool { returnedAt != nil }
}

struct SurfaceEntryInvariantSummary: Hashable, Sendable {
    let totalChains: Int
    let requestedStartedPairedCount: Int
    let returnedLinkedCount: Int
    let payloadConsistentCount: Int

    var requestedStartedPairedPassed: Bool { requestedStartedPairedCount == totalChains }
    var returnedLinkedPassed: Bool { returnedLinkedCount == totalChains }
    var payloadConsistentPassed: Bool { payloadConsistentCount == totalChains }
    var allPassed: Bool {
        requestedStartedPairedPassed && returnedLinkedPassed && payloadConsistentPassed
    }
}

enum SurfaceEntryReplayBuilder {
    static func build(
        events: [MatchingEvent],
        retainedRequests: [String: SurfaceEntryRequest],
        retainedPayloads: [String: ExecutionReturnPayload]
    ) -> [SurfaceEntryChain] {
        var eventsByRequestId: [String: [MatchingEvent]] = [:]
        for event in events {
            guard let requestId = event.surfaceEntryRequestId else { continue }
            eventsByRequestId[requestId, default: []].append(event)
        }

        var chains: [SurfaceEntryChain] = []
        for (requestId, chainEvents) in eventsByRequestId {
            let sorted = chainEvents.sorted { $0.timestamp < $1.timestamp }
            let request = retainedRequests[requestId]
            let payload = retainedPayloads[requestId]

            let requestedEvent = sorted.first { $0.type == .surfaceEntryRequested }
            let startedEvent = sorted.first { $0.type == .surfaceEntryStarted }
            let returnedEvent = sorted.first { $0.type == .surfaceEntryReturned }
            let recommendationId = sorted.first?.recommendationId

            let surfaceType: AppSection = {
                if let request { return request.surfaceType }
                if let raw = sorted.compactMap(\.executionSurfaceType).first,
                   let section = AppSection(rawValue: raw) {
                    return section
                }
                return .chat
            }()

            let intent: SurfaceEntryIntent = {
                if let request { return request.entryIntent }
                return SurfaceEntryIntent(section: surfaceType)
            }()

            let terminal = resolveTerminal(
                chainEvents: sorted,
                payload: payload,
                returnedEvent: returnedEvent,
                recommendationId: recommendationId,
                allEvents: events
            )

            let invariants = evaluateInvariants(
                requestId: requestId,
                requestedEvent: requestedEvent,
                startedEvent: startedEvent,
                returnedEvent: returnedEvent,
                recommendationId: recommendationId,
                request: request,
                payload: payload
            )

            let sourceRecId: String? = {
                if let recId = request?.sourceRecommendationId { return recId }
                if let recId = payload?.sourceRecommendationId { return recId }
                guard let id = recommendationId else { return nil }
                return id.hasPrefix("synthetic-") ? nil : id
            }()

            chains.append(
                SurfaceEntryChain(
                    requestId: requestId,
                    request: request,
                    surfaceType: surfaceType,
                    entryIntent: intent,
                    sourceRecommendationId: sourceRecId,
                    objectType: request?.objectType
                        ?? sorted.compactMap(\.objectType).first,
                    objectId: request?.objectId,
                    normalizedArgs: request?.normalizedArgs ?? [:],
                    requestedAt: requestedEvent?.timestamp,
                    startedAt: startedEvent?.timestamp,
                    returnedAt: returnedEvent?.timestamp,
                    terminalOutcome: terminal,
                    returnPayload: payload,
                    events: sorted.map {
                        SurfaceEntryChainEvent(
                            id: $0.id,
                            type: $0.type,
                            timestamp: $0.timestamp,
                            recommendationId: $0.recommendationId,
                            candidateId: $0.candidateId,
                            surface: $0.executionSurfaceType
                        )
                    },
                    invariants: invariants
                )
            )
        }

        return chains.sorted { lhs, rhs in
            let lhsAt = lhs.requestedAt ?? lhs.startedAt ?? .distantPast
            let rhsAt = rhs.requestedAt ?? rhs.startedAt ?? .distantPast
            return lhsAt > rhsAt
        }
    }

    static func summarize(_ chains: [SurfaceEntryChain]) -> SurfaceEntryInvariantSummary {
        SurfaceEntryInvariantSummary(
            totalChains: chains.count,
            requestedStartedPairedCount: chains.filter { $0.invariants.requestedStartedPaired }.count,
            returnedLinkedCount: chains.filter { $0.invariants.returnedLinksByRequestId }.count,
            payloadConsistentCount: chains.filter { $0.invariants.payloadLinksMatchChain }.count
        )
    }

    private static func resolveTerminal(
        chainEvents: [MatchingEvent],
        payload: ExecutionReturnPayload?,
        returnedEvent: MatchingEvent?,
        recommendationId: String?,
        allEvents: [MatchingEvent]
    ) -> SurfaceEntryTerminalOutcome {
        if let payload {
            switch payload.outcome {
            case .completed, .partial:
                return .completion
            case .abandoned, .failed:
                return .abandon
            }
        }
        if let recommendationId {
            let terminal = allEvents.last { event in
                event.recommendationId == recommendationId
                    && (event.type == .completion || event.type == .abandon || event.type == .dismiss)
            }
            switch terminal?.type {
            case .completion:
                return .completion
            case .abandon:
                return .abandon
            case .dismiss:
                return .dismiss
            default:
                break
            }
        }
        if returnedEvent != nil { return .returnedOnly }
        return .inFlight
    }

    private static func evaluateInvariants(
        requestId: String,
        requestedEvent: MatchingEvent?,
        startedEvent: MatchingEvent?,
        returnedEvent: MatchingEvent?,
        recommendationId: String?,
        request: SurfaceEntryRequest?,
        payload: ExecutionReturnPayload?
    ) -> SurfaceEntryInvariantResults {
        let requestedStartedPaired: Bool = {
            if requestedEvent != nil && startedEvent != nil { return true }
            if requestedEvent == nil && startedEvent == nil { return true }
            return false
        }()

        let returnedLinks: Bool = {
            guard let returnedEvent else { return true }
            return returnedEvent.surfaceEntryRequestId == requestId
        }()

        let payloadLinks: Bool = {
            guard let payload else { return true }
            if payload.sourceRequestId != nil && payload.sourceRequestId != requestId {
                return false
            }
            if let payloadRec = payload.sourceRecommendationId,
               let chainRec = request?.sourceRecommendationId ?? recommendationId {
                let chainIsSynthetic = chainRec.hasPrefix("synthetic-")
                if !chainIsSynthetic && payloadRec != chainRec { return false }
            }
            return true
        }()

        return SurfaceEntryInvariantResults(
            requestedStartedPaired: requestedStartedPaired,
            returnedLinksByRequestId: returnedLinks,
            payloadLinksMatchChain: payloadLinks
        )
    }
}

struct SurfaceEntryChainFilter: Hashable, Sendable {
    var surfaceType: AppSection?
    var entryIntent: SurfaceEntryIntent?
    var hasRecommendation: Bool?
    var returnedOnly: Bool
    var terminalOutcome: SurfaceEntryTerminalOutcome?

    static let none = SurfaceEntryChainFilter(
        surfaceType: nil,
        entryIntent: nil,
        hasRecommendation: nil,
        returnedOnly: false,
        terminalOutcome: nil
    )

    func apply(to chains: [SurfaceEntryChain]) -> [SurfaceEntryChain] {
        chains.filter { chain in
            if let surfaceType, chain.surfaceType != surfaceType { return false }
            if let entryIntent, chain.entryIntent != entryIntent { return false }
            if let hasRecommendation, chain.hasRecommendation != hasRecommendation {
                return false
            }
            if returnedOnly && !chain.hasReturned { return false }
            if let terminalOutcome, chain.terminalOutcome != terminalOutcome {
                return false
            }
            return true
        }
    }
}
