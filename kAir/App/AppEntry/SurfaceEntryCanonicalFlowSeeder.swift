//
//  SurfaceEntryCanonicalFlowSeeder.swift
//  kAir
//
//  Emits a synthetic set of `SurfaceEntryRequest` / `MatchingEvent` /
//  `ExecutionReturnPayload` tuples directly into the shared
//  `MatchingReplayLab` so the Replay panel always has enough
//  surface-entry chains to audit on boot — recommendation flows, direct
//  tab-bar opens, return foldback, silent-exit abandons.
//
//  These are developer-only seeds. They do not touch ChatStore state,
//  do not touch active lifecycles, and are keyed by `synthetic-*`
//  recommendation ids so they can be told apart from real runtime flows.
//

import Foundation

@MainActor
enum SurfaceEntryCanonicalFlowSeeder {
    static func seed(lab: MatchingReplayLab, now: Date = .now) {
        let flows: [CanonicalFlow] = [
            .recommendationCompletion(
                tag: "maps-navigate",
                surface: .maps,
                intent: .navigate,
                objectType: "place",
                objectId: "place-pharmacy-001",
                args: ["query": "pharmacy", "transport_mode": "walking"],
                summary: "Reached CVS at 3rd Ave",
                duration: 8.5,
                hasRecommendation: true
            ),
            .recommendationCompletion(
                tag: "maps-discover",
                surface: .maps,
                intent: .discoverNearby,
                objectType: "place",
                objectId: "place-cafe-002",
                args: ["query": "evening cafe", "task_type": "nearbySearch"],
                summary: "Selected Blue Bottle",
                duration: 4.0,
                hasRecommendation: true
            ),
            .recommendationAbandon(
                tag: "maps-route-compare",
                surface: .maps,
                intent: .reviewRoute,
                objectType: "route",
                objectId: "route-compare-003",
                args: ["task_type": "routeComparison"],
                duration: 2.1
            ),
            .recommendationCompletion(
                tag: "music-play-chill",
                surface: .music,
                intent: .playMusic,
                objectType: "song",
                objectId: "song-chill-004",
                args: ["mood": "focus", "query": "lo-fi"],
                summary: "Completed 20-min chill playlist",
                duration: 1200,
                hasRecommendation: true
            ),
            .directOpenCompletion(
                tag: "music-direct",
                surface: .music,
                intent: .playMusic,
                objectType: "song",
                objectId: "song-tab-005",
                args: [:],
                summary: "Quick tab-bar play",
                duration: 180
            ),
            .recommendationCompletion(
                tag: "video-watch",
                surface: .video,
                intent: .watchVideo,
                objectType: "video",
                objectId: "video-explainer-006",
                args: ["category": "learn", "duration": "6:30"],
                summary: "Watched explainer to end",
                duration: 390,
                hasRecommendation: true
            ),
            .recommendationDismiss(
                tag: "video-dismiss",
                surface: .video,
                intent: .watchVideo,
                objectType: "video",
                objectId: "video-skip-007",
                args: ["category": "promo"],
                duration: 0.5
            ),
            .recommendationCompletion(
                tag: "health-answer",
                surface: .health,
                intent: .openHealth,
                objectType: "answerCard",
                objectId: nil,
                args: ["topic": "sleep", "language": "en"],
                summary: "Health Q&A reviewed",
                duration: 45,
                hasRecommendation: true
            ),
            .silentExitAbandon(
                tag: "health-silent-exit",
                surface: .health,
                intent: .openHealth,
                objectType: "answerCard",
                objectId: nil,
                args: ["topic": "steps"]
            ),
            .directOpenCompletion(
                tag: "store-direct",
                surface: .store,
                intent: .openStore,
                objectType: nil,
                objectId: nil,
                args: [:],
                summary: "Browsed Store from tab bar",
                duration: 30
            ),
            .directOpenInFlight(
                tag: "ai-direct-inflight",
                surface: .ai,
                intent: .openAI,
                objectType: nil,
                objectId: nil,
                args: [:]
            ),
        ]

        for (offset, flow) in flows.enumerated() {
            flow.emit(
                into: lab,
                baseTime: now.addingTimeInterval(-Double((flows.count - offset) * 60))
            )
        }
    }

    private enum CanonicalFlow {
        case recommendationCompletion(
            tag: String,
            surface: AppSection,
            intent: SurfaceEntryIntent,
            objectType: String?,
            objectId: String?,
            args: [String: String],
            summary: String?,
            duration: Double,
            hasRecommendation: Bool
        )
        case recommendationAbandon(
            tag: String,
            surface: AppSection,
            intent: SurfaceEntryIntent,
            objectType: String?,
            objectId: String?,
            args: [String: String],
            duration: Double
        )
        case recommendationDismiss(
            tag: String,
            surface: AppSection,
            intent: SurfaceEntryIntent,
            objectType: String?,
            objectId: String?,
            args: [String: String],
            duration: Double
        )
        case directOpenCompletion(
            tag: String,
            surface: AppSection,
            intent: SurfaceEntryIntent,
            objectType: String?,
            objectId: String?,
            args: [String: String],
            summary: String?,
            duration: Double
        )
        case silentExitAbandon(
            tag: String,
            surface: AppSection,
            intent: SurfaceEntryIntent,
            objectType: String?,
            objectId: String?,
            args: [String: String]
        )
        case directOpenInFlight(
            tag: String,
            surface: AppSection,
            intent: SurfaceEntryIntent,
            objectType: String?,
            objectId: String?,
            args: [String: String]
        )

        func emit(into lab: MatchingReplayLab, baseTime: Date) {
            switch self {
            case let .recommendationCompletion(
                tag, surface, intent, objectType, objectId, args, summary, duration, hasRec
            ):
                SurfaceEntryCanonicalFlowSeeder.emitFullChain(
                    tag: tag,
                    surface: surface,
                    intent: intent,
                    objectType: objectType,
                    objectId: objectId,
                    args: args,
                    summary: summary,
                    duration: duration,
                    outcome: .completed,
                    hasRecommendation: hasRec,
                    includeReturnedEvent: true,
                    baseTime: baseTime,
                    into: lab
                )
            case let .recommendationAbandon(
                tag, surface, intent, objectType, objectId, args, duration
            ):
                SurfaceEntryCanonicalFlowSeeder.emitFullChain(
                    tag: tag,
                    surface: surface,
                    intent: intent,
                    objectType: objectType,
                    objectId: objectId,
                    args: args,
                    summary: "Abandoned early",
                    duration: duration,
                    outcome: .abandoned,
                    hasRecommendation: true,
                    includeReturnedEvent: true,
                    baseTime: baseTime,
                    into: lab
                )
            case let .recommendationDismiss(
                tag, surface, intent, objectType, objectId, args, duration
            ):
                SurfaceEntryCanonicalFlowSeeder.emitDismissChain(
                    tag: tag,
                    surface: surface,
                    intent: intent,
                    objectType: objectType,
                    objectId: objectId,
                    args: args,
                    duration: duration,
                    baseTime: baseTime,
                    into: lab
                )
            case let .directOpenCompletion(
                tag, surface, intent, objectType, objectId, args, summary, duration
            ):
                SurfaceEntryCanonicalFlowSeeder.emitFullChain(
                    tag: tag,
                    surface: surface,
                    intent: intent,
                    objectType: objectType,
                    objectId: objectId,
                    args: args,
                    summary: summary,
                    duration: duration,
                    outcome: .completed,
                    hasRecommendation: false,
                    includeReturnedEvent: true,
                    baseTime: baseTime,
                    into: lab
                )
            case let .silentExitAbandon(
                tag, surface, intent, objectType, objectId, args
            ):
                SurfaceEntryCanonicalFlowSeeder.emitFullChain(
                    tag: tag,
                    surface: surface,
                    intent: intent,
                    objectType: objectType,
                    objectId: objectId,
                    args: args,
                    summary: "Silent exit",
                    duration: 0,
                    outcome: .abandoned,
                    hasRecommendation: true,
                    includeReturnedEvent: true,
                    baseTime: baseTime,
                    into: lab
                )
            case let .directOpenInFlight(
                tag, surface, intent, objectType, objectId, args
            ):
                SurfaceEntryCanonicalFlowSeeder.emitRequestedAndStartedOnly(
                    tag: tag,
                    surface: surface,
                    intent: intent,
                    objectType: objectType,
                    objectId: objectId,
                    args: args,
                    baseTime: baseTime,
                    into: lab
                )
            }
        }
    }

    private static func emitFullChain(
        tag: String,
        surface: AppSection,
        intent: SurfaceEntryIntent,
        objectType: String?,
        objectId: String?,
        args: [String: String],
        summary: String?,
        duration: Double,
        outcome: ExecutionOutcome,
        hasRecommendation: Bool,
        includeReturnedEvent: Bool,
        baseTime: Date,
        into lab: MatchingReplayLab
    ) {
        let requestId = "synthetic-req-\(tag)"
        let recommendationId = hasRecommendation ? "synthetic-rec-\(tag)" : "synthetic-direct-\(tag)"
        let candidateId = objectId ?? "synthetic-cand-\(tag)"
        let sourceRecId = hasRecommendation ? recommendationId : nil

        let request = SurfaceEntryRequest(
            requestId: requestId,
            surfaceType: surface,
            entryIntent: intent,
            sourceCardId: hasRecommendation ? "synthetic-card-\(tag)" : nil,
            sourceRecommendationId: sourceRecId,
            sourceThreadId: "synthetic-thread",
            objectType: objectType,
            objectId: objectId,
            normalizedArgs: args,
            requiresConfirmation: false,
            handoffContext: SurfaceEntryHandoffContext(
                sourceMessagePreview: "synthetic flow: \(tag)",
                returnThreadId: "synthetic-thread",
                priorContextStateSummary: summary
            ),
            issuedAt: baseTime
        )

        lab.retainSurfaceEntryRequest(request)

        let requestedAt = baseTime
        let startedAt = baseTime.addingTimeInterval(0.25)
        let returnedAt = baseTime.addingTimeInterval(duration)

        lab.submitSurfaceEntryEvent(
            makeEvent(
                type: .surfaceEntryRequested,
                at: requestedAt,
                recommendationId: recommendationId,
                candidateId: candidateId,
                objectType: objectType,
                surface: surface,
                requestId: requestId
            )
        )
        lab.submitSurfaceEntryEvent(
            makeEvent(
                type: .surfaceEntryStarted,
                at: startedAt,
                recommendationId: recommendationId,
                candidateId: candidateId,
                objectType: objectType,
                surface: surface,
                requestId: requestId
            )
        )

        let payload = ExecutionReturnPayload(
            executedCandidateId: candidateId,
            executionSurfaceType: surface,
            outcome: outcome,
            duration: duration,
            returnContextDelta: ExecutionReturnPayload.ReturnContextDelta(
                downstreamValue: outcome == .completed ? 0.6 : 0.0,
                completionScore: outcome == .completed ? 0.8 : 0.0,
                addedIntentTags: [],
                resolvedObjectIds: [],
                dismissedObjectIds: [],
                summary: summary
            ),
            sourceRequestId: requestId,
            sourceRecommendationId: sourceRecId
        )
        lab.retainSurfaceEntryReturnPayload(payload)

        if includeReturnedEvent {
            lab.submitSurfaceEntryEvent(
                makeEvent(
                    type: .surfaceEntryReturned,
                    at: returnedAt,
                    recommendationId: recommendationId,
                    candidateId: candidateId,
                    objectType: objectType,
                    surface: surface,
                    requestId: requestId,
                    outcome: payload.toOutcomeEventPayload
                )
            )
        }
    }

    private static func emitRequestedAndStartedOnly(
        tag: String,
        surface: AppSection,
        intent: SurfaceEntryIntent,
        objectType: String?,
        objectId: String?,
        args: [String: String],
        baseTime: Date,
        into lab: MatchingReplayLab
    ) {
        let requestId = "synthetic-req-\(tag)"
        let recommendationId = "synthetic-direct-\(tag)"
        let candidateId = objectId ?? "synthetic-cand-\(tag)"

        let request = SurfaceEntryRequest(
            requestId: requestId,
            surfaceType: surface,
            entryIntent: intent,
            sourceCardId: nil,
            sourceRecommendationId: nil,
            sourceThreadId: "synthetic-thread",
            objectType: objectType,
            objectId: objectId,
            normalizedArgs: args,
            requiresConfirmation: false,
            handoffContext: SurfaceEntryHandoffContext(
                sourceMessagePreview: "synthetic inflight: \(tag)",
                returnThreadId: nil,
                priorContextStateSummary: nil
            ),
            issuedAt: baseTime
        )
        lab.retainSurfaceEntryRequest(request)
        lab.submitSurfaceEntryEvent(
            makeEvent(
                type: .surfaceEntryRequested,
                at: baseTime,
                recommendationId: recommendationId,
                candidateId: candidateId,
                objectType: objectType,
                surface: surface,
                requestId: requestId
            )
        )
        lab.submitSurfaceEntryEvent(
            makeEvent(
                type: .surfaceEntryStarted,
                at: baseTime.addingTimeInterval(0.25),
                recommendationId: recommendationId,
                candidateId: candidateId,
                objectType: objectType,
                surface: surface,
                requestId: requestId
            )
        )
    }

    private static func emitDismissChain(
        tag: String,
        surface: AppSection,
        intent: SurfaceEntryIntent,
        objectType: String?,
        objectId: String?,
        args: [String: String],
        duration: Double,
        baseTime: Date,
        into lab: MatchingReplayLab
    ) {
        let requestId = "synthetic-req-\(tag)"
        let recommendationId = "synthetic-rec-\(tag)"
        let candidateId = objectId ?? "synthetic-cand-\(tag)"

        let request = SurfaceEntryRequest(
            requestId: requestId,
            surfaceType: surface,
            entryIntent: intent,
            sourceCardId: "synthetic-card-\(tag)",
            sourceRecommendationId: recommendationId,
            sourceThreadId: "synthetic-thread",
            objectType: objectType,
            objectId: objectId,
            normalizedArgs: args,
            requiresConfirmation: false,
            handoffContext: SurfaceEntryHandoffContext(
                sourceMessagePreview: "synthetic flow: \(tag)",
                returnThreadId: "synthetic-thread",
                priorContextStateSummary: "User dismissed"
            ),
            issuedAt: baseTime
        )
        lab.retainSurfaceEntryRequest(request)

        let requestedAt = baseTime
        let startedAt = baseTime.addingTimeInterval(0.25)
        let dismissedAt = baseTime.addingTimeInterval(max(duration, 0.1))
        let returnedAt = dismissedAt.addingTimeInterval(0.05)

        lab.submitSurfaceEntryEvent(
            makeEvent(
                type: .surfaceEntryRequested,
                at: requestedAt,
                recommendationId: recommendationId,
                candidateId: candidateId,
                objectType: objectType,
                surface: surface,
                requestId: requestId
            )
        )
        lab.submitSurfaceEntryEvent(
            makeEvent(
                type: .surfaceEntryStarted,
                at: startedAt,
                recommendationId: recommendationId,
                candidateId: candidateId,
                objectType: objectType,
                surface: surface,
                requestId: requestId
            )
        )
        lab.submitSurfaceEntryEvent(
            makeEvent(
                type: .dismiss,
                at: dismissedAt,
                recommendationId: recommendationId,
                candidateId: candidateId,
                objectType: objectType,
                surface: surface,
                requestId: requestId
            )
        )
        lab.submitSurfaceEntryEvent(
            makeEvent(
                type: .surfaceEntryReturned,
                at: returnedAt,
                recommendationId: recommendationId,
                candidateId: candidateId,
                objectType: objectType,
                surface: surface,
                requestId: requestId
            )
        )
    }

    private static func makeEvent(
        type: MatchingEventType,
        at timestamp: Date,
        recommendationId: String,
        candidateId: String,
        objectType: String?,
        surface: AppSection,
        requestId: String,
        outcome: MatchingEventOutcome? = nil
    ) -> MatchingEvent {
        MatchingEvent(
            type: type,
            sessionId: "synthetic-session",
            recommendationId: recommendationId,
            candidateId: candidateId,
            timestamp: timestamp,
            objectType: objectType,
            executionSurfaceType: surface.rawValue,
            feedbackOption: nil,
            policyVersion: MatchingPolicyVersion.current.policyVersion,
            outcome: outcome,
            surfaceEntryRequestId: requestId
        )
    }
}
