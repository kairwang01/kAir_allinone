//
//  StubLocalStoreLookupAdapter.swift
//  kAir
//
//  No-op adapter for the `.localStoreLookup` capability per
//  Contracts/capability-registry-and-adapter-contract-v1.md §3.1
//  (shipped scope). Backed by the on-device store; per §8.3 AI fallback
//  is forbidden — the store either has the entry or it doesn't.
//
//  Skeleton scaffolding only — returns a static placeholder envelope
//  with `source = .local` (the on-device store path).
//

import Foundation

@MainActor
final class StubLocalStoreLookupAdapter: CapabilityAdapter {
    static let capability: CapabilityKind = .localStoreLookup

    init() {}

    func isAvailable() async -> Bool {
        true
    }

    func resolve(_ request: CapabilityRequest) async throws -> NormalizedResult {
        let item = LocalStoreItem(
            id: "stub-item",
            title: "Placeholder local-store item (stub adapter).",
            category: nil
        )
        return NormalizedResult(
            id: "localStoreLookup-stub-\(UUID().uuidString)",
            capability: .localStoreLookup,
            payload: .localStoreLookup(item: item),
            source: .local,
            confidence: 0.0,
            createdAt: Date()
        )
    }
}
