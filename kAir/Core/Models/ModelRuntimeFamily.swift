//
//  ModelRuntimeFamily.swift
//  kAir
//
//  Pure value contract for the model runtime families kAir can target.
//
//  A3 model-catalog value contracts (Docs/architecture/kair-ai-model-memory-v1.md
//  §4). Foundation only — no model runtime calls, no network, no StoreKit, no
//  HealthKit, no SwiftUI. Fixtures/types only.
//

import Foundation

/// The runtime families a kAir model entry can belong to (§4). The app
/// abstracts every runtime behind a provider; this enum only classifies the
/// family and whether it executes on-device.
enum ModelRuntimeFamily: String, Codable, Hashable, Sendable, CaseIterable {
    /// Apple-native on-device text tasks where available (§4).
    case foundationModels
    /// Compiled local classifiers, embeddings, compact specialists.
    case coreML
    /// Apple Silicon experiments / local fine-tuning path.
    case mlx
    /// Optional local generative runtime with grammar constraints (llama.cpp / GGUF).
    case llamaCPP
    /// Edge classifiers / rerankers / specialists.
    case executorch
    /// Premium market models — server-side only, StoreKit-gated (§7). The only
    /// remote family; never used for Health (§1 local-only).
    case remoteGateway

    /// `true` for on-device families. Only `.remoteGateway` is remote.
    var isOnDevice: Bool {
        self != .remoteGateway
    }
}
