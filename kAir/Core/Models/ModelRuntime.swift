//
//  ModelRuntime.swift
//  kAir
//
//  Comment-first reservation for the on-device model runtime binding seam.
//
//  Reserved interface R3 of `Docs/architecture/kair-architecture-redesign-v2.md`
//  §5.3. Lets a catalog role bind to a runtime (MLX for generative inference,
//  Core ML for classifiers/embedders, Apple Foundation Models where available)
//  WITHOUT the catalog knowing the SDK. Marvis/MLX lessons baked in: license is
//  a bundling gate; cap prefill + bound KV cache to keep multi-model concurrency
//  within unified memory.
//
//  This round ships the protocol seam + a fixture conformer + a pure binding
//  policy. No MLX / Core ML / Foundation Models import, no model load, no Metal.
//

import Foundation

/// Lifecycle status of a runtime binding.
enum ModelRuntimeStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case unloaded     // bindable, not yet loaded
    case loading
    case ready
    case unavailable
}

/// Why an on-device runtime cannot be bound.
enum ModelRuntimeUnavailableReason: String, Codable, Hashable, Sendable, CaseIterable {
    case unsupportedRuntimeFamily   // remote-gateway entries have no on-device runtime
    case licenseNotAccepted         // Marvis: license is a bundling gate
    case insufficientMemory
    case deviceUnsupported
}

/// On-device cost hints (Marvis/MLX + SwiftLM). Value-only; the runtime honors
/// them, the catalog does not need to know them.
struct ModelRuntimeBudget: Codable, Hashable, Sendable {
    let prefillChunkTokens: Int   // SwiftLM default 512 — sub-linear unified memory
    let kvCacheTokenBudget: Int

    init(prefillChunkTokens: Int = 512, kvCacheTokenBudget: Int = 4096) {
        self.prefillChunkTokens = prefillChunkTokens
        self.kvCacheTokenBudget = kvCacheTokenBudget
    }
}

/// The outcome of binding a catalog entry to an on-device runtime.
struct ModelRuntimeBinding: Hashable, Sendable {
    let runtimeFamily: ModelRuntimeFamily?
    let status: ModelRuntimeStatus
    let unavailableReason: ModelRuntimeUnavailableReason?
    let budget: ModelRuntimeBudget

    var isAvailable: Bool {
        status != .unavailable
    }
}

/// Pure binding policy: can this catalog entry run on-device here, and under
/// what budget? No SDK, no model load. The license gate (Marvis) and the
/// remote-gateway exclusion are enforced before any runtime exists.
enum ModelRuntimeBindingPolicy {
    static func evaluate(
        entry: ModelCatalogEntry,
        acceptedLicenses: Set<String>,
        deviceMemoryBytes: Int64,
        budget: ModelRuntimeBudget = ModelRuntimeBudget()
    ) -> ModelRuntimeBinding {
        // Remote-gateway entries run server-side; they have no on-device runtime.
        guard entry.runtimeFamily.isOnDevice else {
            return ModelRuntimeBinding(
                runtimeFamily: nil,
                status: .unavailable,
                unavailableReason: .unsupportedRuntimeFamily,
                budget: budget
            )
        }
        // License must be accepted before bundling/loading any weights.
        guard acceptedLicenses.contains(entry.license) else {
            return ModelRuntimeBinding(
                runtimeFamily: entry.runtimeFamily,
                status: .unavailable,
                unavailableReason: .licenseNotAccepted,
                budget: budget
            )
        }
        // Working-set must fit device memory.
        guard entry.estimatedMemoryBytes <= deviceMemoryBytes else {
            return ModelRuntimeBinding(
                runtimeFamily: entry.runtimeFamily,
                status: .unavailable,
                unavailableReason: .insufficientMemory,
                budget: budget
            )
        }
        return ModelRuntimeBinding(
            runtimeFamily: entry.runtimeFamily,
            status: .unloaded,
            unavailableReason: nil,
            budget: budget
        )
    }
}

/// The future SDK seam. A real conformer wraps MLX / Core ML / Foundation
/// Models and adds (reserved, not in v1):
///   - `func load() async throws`
///   - `func unload()`
///   - `func stream(_ prompt:) -> AsyncStream<Token>`  (Marvis: stream, don't chunk)
/// This round ships only the synchronous status surface + a fixture conformer.
protocol ModelRuntime {
    var family: ModelRuntimeFamily { get }
    var status: ModelRuntimeStatus { get }
}

/// Fixture conformer — no SDK, reports a fixed status. Proves the protocol seam
/// without loading a model.
struct FixtureModelRuntime: ModelRuntime, Hashable, Sendable {
    let family: ModelRuntimeFamily
    let status: ModelRuntimeStatus

    init(family: ModelRuntimeFamily, status: ModelRuntimeStatus = .unloaded) {
        self.family = family
        self.status = status
    }
}
