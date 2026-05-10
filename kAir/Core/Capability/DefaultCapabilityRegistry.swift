//
//  DefaultCapabilityRegistry.swift
//  kAir
//
//  Single seam that produces a `CapabilityRegistry` pre-populated with
//  the v1 shipped stubs.
//
//  Per Contracts/capability-registry-and-adapter-contract-v1.md §3.1,
//  three capabilities ship in v1 with at least one production adapter:
//    - `.aiCompletion`     → `StubAICompletionAdapter`
//    - `.threadLookup`     → `StubThreadLookupAdapter`
//    - `.localStoreLookup` → `StubLocalStoreLookupAdapter`
//
//  Per §7.1 the registry holds at most one adapter per kind. Per §3.3
//  adding an eleventh kind is a v2 change, so the trio above is closed
//  for v1 — but a future adapter (e.g. the real AI runtime once
//  `partnerFailure` paths are wired) is allowed to replace the
//  corresponding stub at this seam without changing call sites.
//
//  Why a single-place factory:
//
//    - Reviewer invariant for Main C: "registry 是否在 composition
//      root 单点构造". This file is the single point of construction.
//    - `AppBootstrap` calls this factory once at startup and exposes
//      the resulting registry as a `let` property; consumers (chat
//      home today, surface routing later) read the registry from
//      `AppBootstrap` rather than building their own. Tests inject a
//      custom registry through the same `AppBootstrap` init param.
//    - The 3 shipped kinds register in a deterministic, contract-
//      ordered sequence. v1's §7.1 first-registered-wins rule applies
//      if a future caller mistakenly tries to re-register; the order
//      here documents the intended winners.
//
//  Boundary (intentional):
//
//    - This factory does NOT wire any partner SDK or live runtime.
//      That is per-adapter work and outside Main C scope.
//    - This factory does NOT decide routing. Resolving a capability
//      to a downstream surface or to the recommendation rail is owned
//      by the conversation-intent layer (out of Main C scope).
//    - This factory does NOT register §3.2 reserved kinds. Those have
//      no v1 adapter commitment per the contract.
//

import Foundation

/// Pure-function namespace that produces a `CapabilityRegistry` with
/// the v1 §3.1 shipped adapters pre-registered.
///
/// `AppBootstrap` is the SOLE production caller; tests may also call
/// it to construct a "default-shape" registry without rebuilding the
/// boilerplate.
enum DefaultCapabilityRegistry {
    /// The three §3.1 capability kinds, in the registration order
    /// `makeWithShippedStubs()` uses. Exposed for tests so they can
    /// assert the factory matches the contract without restating the
    /// kinds.
    static let shippedKinds: [CapabilityKind] = [
        .aiCompletion,
        .threadLookup,
        .localStoreLookup,
    ]

    /// Build a `CapabilityRegistry` and register one stub adapter for
    /// each §3.1 shipped capability, in the canonical order.
    ///
    /// `MainActor` because `CapabilityRegistry` is `MainActor`-isolated
    /// per §7.5 and the stub adapters are `MainActor` per §4.
    @MainActor
    static func makeWithShippedStubs() -> CapabilityRegistry {
        let registry = CapabilityRegistry()
        registry.register(StubAICompletionAdapter())
        registry.register(StubThreadLookupAdapter())
        registry.register(StubLocalStoreLookupAdapter())
        return registry
    }
}
