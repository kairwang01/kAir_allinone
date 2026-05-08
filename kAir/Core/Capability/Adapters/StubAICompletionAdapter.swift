//
//  StubAICompletionAdapter.swift
//  kAir
//
//  No-op adapter for the `.aiCompletion` capability per
//  Contracts/capability-registry-and-adapter-contract-v1.md §3.1
//  (shipped scope) and §8.3 (the `.aiCompletion` row: AI is the
//  primary resolver for this capability, not a fallback — so the
//  envelope's `source = .aiSynthesized` is honest provenance, not a
//  substitute for an unavailable partner).
//
//  Skeleton scaffolding only — returns a static placeholder envelope.
//  Real AI runtime delegation lives in the per-adapter doc cited at §3.1.
//

import Foundation

@MainActor
final class StubAICompletionAdapter: CapabilityAdapter {
    static let capability: CapabilityKind = .aiCompletion

    init() {}

    func isAvailable() async -> Bool {
        true
    }

    func resolve(_ request: CapabilityRequest) async throws -> NormalizedResult {
        let completion = AICompletion(
            text: "Placeholder AI completion (stub adapter).",
            runtimeFamily: nil
        )
        return NormalizedResult(
            id: "aiCompletion-stub-\(UUID().uuidString)",
            capability: .aiCompletion,
            payload: .aiCompletion(completion: completion),
            source: .aiSynthesized,
            confidence: 0.0,
            createdAt: Date()
        )
    }
}
