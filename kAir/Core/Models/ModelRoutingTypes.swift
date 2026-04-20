//
//  ModelRoutingTypes.swift
//  kAir
//
//  Minimal inputs and outputs for the ModelRouter contract. Routing decides
//  local / cloud / direct-fail only; it does not carry inference results.
//

import Foundation

enum ModelRoutingTarget: String, Codable, CaseIterable, Hashable, Sendable {
    case local
    case cloud
    case directFail
}

struct ModelRoutingRequest: Hashable, Sendable {
    let requestId: String
    let prompt: String
    let priorToolSelection: StructuredToolSelection?
    let preferLocal: Bool
    let maxLatencyMs: Int?

    init(
        requestId: String = UUID().uuidString,
        prompt: String,
        priorToolSelection: StructuredToolSelection? = nil,
        preferLocal: Bool = true,
        maxLatencyMs: Int? = nil
    ) {
        self.requestId = requestId
        self.prompt = prompt
        self.priorToolSelection = priorToolSelection
        self.preferLocal = preferLocal
        self.maxLatencyMs = maxLatencyMs
    }
}

struct ModelRoutingDecision: Hashable, Sendable {
    let requestId: String
    let target: ModelRoutingTarget
    let reason: String
}
