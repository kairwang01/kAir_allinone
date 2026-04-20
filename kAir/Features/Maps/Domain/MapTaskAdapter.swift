//
//  MapTaskAdapter.swift
//  kAir
//
//  Partner-first integration shell for resolving a user query into a concrete
//  `MapTask`. The product design intentionally keeps Maps on a thin partner
//  layer — we do NOT build our own POI system or routing engine. This
//  adapter is the named contract for that layer so replacing the underlying
//  provider (or simulating it in tests) touches one place.
//
//  Scope is deliberately narrow:
//    - query text  →  MapTask (one of goToPlace / nearbySearch / routeCompare)
//    - normalized args used by the execution surface handoff
//    - a `notes` field so stubbed edges are observable
//

import Foundation

// MARK: - Request / result

struct MapTaskAdapterRequest: Hashable, Sendable {
    let query: String
    let threadId: UUID
    let language: MapsConversationLanguage
    /// Optional hint when the caller already knows which of the 3 card kinds
    /// to resolve against. Nil means the adapter must classify from scratch.
    let preferredKind: MapActionCardTaskKind?

    init(
        query: String,
        threadId: UUID,
        language: MapsConversationLanguage,
        preferredKind: MapActionCardTaskKind? = nil
    ) {
        self.query = query
        self.threadId = threadId
        self.language = language
        self.preferredKind = preferredKind
    }
}

/// Resolution outcome. The three `*Args` keys are the canonical arg names
/// threaded into `SurfaceEntryRequest.normalizedArgs` at handoff.
struct MapTaskAdapterResult: Hashable, Sendable {
    static let argKeyQuery = "query"
    static let argKeyTaskType = "task_type"
    static let argKeyLanguage = "language"
    static let argKeyEntryMode = "entry_mode"
    static let argKeyTransportMode = "transport_mode"
    static let argKeyDestinationTitle = "destination_title"

    let task: MapTask?
    let normalizedArgs: [String: String]
    /// Optional note describing which parts of resolution were stubbed. Read
    /// by tests and telemetry. Empty string when fully real.
    let stubNote: String
}

// MARK: - Protocol

protocol MapTaskAdapter: Sendable {
    func resolve(
        _ request: MapTaskAdapterRequest,
        runtime: MapsRuntime
    ) async -> MapTaskAdapterResult
}

// MARK: - Default partner-first adapter

/// Default adapter that wraps the existing `MapsIntentRouter` — which is the
/// current partner-first integration. It does not implement any POI or
/// routing logic itself; it asks `MapsRuntime.resolvePlaces` (stubbed) and
/// shapes the outputs.
///
/// Known stubs flagged via `stubNote`:
///   - place resolution uses the in-process `MapsRuntime` fixture dataset
///   - distance / ETA come from a canned provider
///   - routing polylines are placeholder geometry
struct DefaultMapTaskAdapter: MapTaskAdapter {
    func resolve(
        _ request: MapTaskAdapterRequest,
        runtime: MapsRuntime
    ) async -> MapTaskAdapterResult {
        let response = await MapsIntentRouter.handlePrompt(
            request.query,
            threadId: request.threadId,
            pendingTask: nil,
            runtime: runtime
        )

        let task = response?.pendingTask
        let args = normalizedArgs(for: task, request: request)
        let note = stubNote(for: task)
        return MapTaskAdapterResult(task: task, normalizedArgs: args, stubNote: note)
    }

    // MARK: Arg normalization

    func normalizedArgs(
        for task: MapTask?,
        request: MapTaskAdapterRequest
    ) -> [String: String] {
        var args: [String: String] = [
            MapTaskAdapterResult.argKeyQuery: request.query,
            MapTaskAdapterResult.argKeyLanguage: request.language.usesChineseCopy ? "zh" : "en",
        ]
        guard let task else { return args }

        args[MapTaskAdapterResult.argKeyQuery] = task.query
        args[MapTaskAdapterResult.argKeyTaskType] = task.taskType.rawValue
        args[MapTaskAdapterResult.argKeyLanguage] = task.language.usesChineseCopy ? "zh" : "en"
        args[MapTaskAdapterResult.argKeyEntryMode] = task.entryMode.rawValue
        if let mode = task.transportMode {
            args[MapTaskAdapterResult.argKeyTransportMode] = mode.rawValue
        }
        if let destination = task.selectedDestination {
            args[MapTaskAdapterResult.argKeyDestinationTitle] = destination.title
        }
        return args
    }

    // MARK: Diagnostics

    func stubNote(for task: MapTask?) -> String {
        guard task != nil else {
            return "partner-first adapter produced no task (query did not classify as a map intent)"
        }
        return "partner-first resolution: place resolution / distance / polyline are stubbed fixtures"
    }
}
