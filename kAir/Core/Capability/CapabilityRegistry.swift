//
//  CapabilityRegistry.swift
//  kAir
//
//  The single registry per app process per
//  Contracts/capability-registry-and-adapter-contract-v1.md §7.
//
//  Holds at most one adapter per `CapabilityKind` (§7.1, §7.4). Lookup
//  returns the registered adapter or `nil`; the snapshot (§7.3) maps each
//  *registered* kind to its current `isAvailable()`. Kinds with no
//  registration are omitted from the snapshot — callers that need the
//  "not in build" signal use `adapter(for:) == nil` (§7.2).
//
//  MainActor-isolated for v1 (§7.5).
//

import Foundation

@MainActor
final class CapabilityRegistry {
    private var adapters: [CapabilityKind: any CapabilityAdapter] = [:]

    init() {}

    /// Register an adapter. v1 forbids more than one adapter per kind
    /// (§7.1). A second `register(...)` for the same kind is a programming
    /// error: it triggers `assertionFailure` in debug; release builds keep
    /// the first-registered adapter.
    func register(_ adapter: any CapabilityAdapter) {
        let kind = type(of: adapter).capability
        guard adapters[kind] == nil else {
            assertionFailure(
                "CapabilityRegistry: adapter for \(kind) is already registered. " +
                "v1 forbids re-registration (§7.1). First-registered wins in release."
            )
            return
        }
        adapters[kind] = adapter
    }

    /// Look up the registered adapter for a kind. `nil` means no adapter
    /// has been registered for this kind in this build (§7.2). Distinct
    /// from "registered but unavailable".
    func adapter(for kind: CapabilityKind) -> (any CapabilityAdapter)? {
        adapters[kind]
    }

    /// Point-in-time availability snapshot. Maps each *registered*
    /// `CapabilityKind` to its current `isAvailable()` value. Kinds with
    /// no registration are omitted (§7.3).
    func availabilitySnapshot() async -> [CapabilityKind: Bool] {
        var snapshot: [CapabilityKind: Bool] = [:]
        for (kind, adapter) in adapters {
            snapshot[kind] = await adapter.isAvailable()
        }
        return snapshot
    }
}
