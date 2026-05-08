//
//  StubThreadLookupAdapter.swift
//  kAir
//
//  No-op adapter for the `.threadLookup` capability per
//  Contracts/capability-registry-and-adapter-contract-v1.md §3.1
//  (shipped scope). Backed by the in-app chat store; per §8.3 AI
//  fallback is forbidden — a thread either exists or it doesn't.
//
//  Skeleton scaffolding only — returns a static placeholder envelope
//  with `source = .local` (the in-app chat store path).
//

import Foundation

@MainActor
final class StubThreadLookupAdapter: CapabilityAdapter {
    static let capability: CapabilityKind = .threadLookup

    init() {}

    func isAvailable() async -> Bool {
        true
    }

    func resolve(_ request: CapabilityRequest) async throws -> NormalizedResult {
        let thread = ThreadReference(
            threadID: "stub-thread",
            lastTouchedAt: Date(),
            title: "Placeholder thread (stub adapter)."
        )
        return NormalizedResult(
            id: "threadLookup-stub-\(UUID().uuidString)",
            capability: .threadLookup,
            payload: .threadLookup(thread: thread),
            source: .local,
            confidence: 0.0,
            createdAt: Date()
        )
    }
}
