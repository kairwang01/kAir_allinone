//
//  InferenceTypes.swift
//  kAir
//
//  Minimal request / result types for inference adapters (local + cloud).
//  These types do not imply an implementation — they are the shape the
//  stub interfaces expose so product code can be typed against them.
//

import Foundation

enum InferenceOutcomeCode: String, Codable, CaseIterable, Hashable, Sendable {
    case ok
    case empty
    case parseFailure
    case timeout
    case unsupported
    case unavailable
    case unknown
}

struct InferenceRequest: Hashable, Sendable {
    let requestId: String
    let prompt: String
    let systemPrompt: String?
    let maxTokens: Int?
    let temperature: Double?
    let expectsStructuredToolSelection: Bool

    init(
        requestId: String = UUID().uuidString,
        prompt: String,
        systemPrompt: String? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        expectsStructuredToolSelection: Bool = true
    ) {
        self.requestId = requestId
        self.prompt = prompt
        self.systemPrompt = systemPrompt
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.expectsStructuredToolSelection = expectsStructuredToolSelection
    }
}

struct InferenceResult: Hashable, Sendable {
    let requestId: String
    let outcome: InferenceOutcomeCode
    let rawText: String?
    let structuredSelection: StructuredToolSelection?
    let latencyMs: Int?
    let providerLabel: String?

    init(
        requestId: String,
        outcome: InferenceOutcomeCode,
        rawText: String? = nil,
        structuredSelection: StructuredToolSelection? = nil,
        latencyMs: Int? = nil,
        providerLabel: String? = nil
    ) {
        self.requestId = requestId
        self.outcome = outcome
        self.rawText = rawText
        self.structuredSelection = structuredSelection
        self.latencyMs = latencyMs
        self.providerLabel = providerLabel
    }
}
