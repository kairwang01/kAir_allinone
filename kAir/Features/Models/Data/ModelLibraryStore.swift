//
//  ModelLibraryStore.swift
//  kAir
//
//  UI-facing state owner for the Model Library surface.
//

import Foundation
import Observation

// Architecture note:
// `ModelLibraryStore` is the UI-facing state owner for the Model Library
// surface. It reads model catalog, entitlement, download, install, and
// active-provider state, then exposes rows the SwiftUI view can render
// truthfully.
//
// A3 scope (kair-ai-model-memory-v1.md §5/§6/§7): fixtures only. It merges the
// fixture `ModelCatalog` with per-model entitlement via `ModelEntitlementPolicy`
// and surfaces an honest `ModelDownloadState` per row. Real catalog loading,
// StoreKit, URLSession download, compilation, and the RemoteModelGateway are
// NOT wired here.
//
// Forbidden (enforced by construction):
// - No fake "download complete" state — install/active states must be supplied
//   by a backend snapshot, never fabricated by this store.
// - No fake premium entitlement — paid rows stay `.requiresPurchase` until an
//   entitlement says otherwise (`ModelEntitlementPolicy`).
// - No direct URLSession download from the SwiftUI view.
// - No provider API key in model metadata.
// - No Health specialist remote fallback (the catalog forbids it).

/// Owns the Model Library rows. Observable so the SwiftUI view (A7) can bind
/// without hardcoded cards. All state is derived from fixtures + an injected
/// entitlement / backend snapshot — nothing is fabricated.
@MainActor
@Observable
final class ModelLibraryStore {
    enum BackendStatus: String, Hashable, Sendable {
        case notWired

        var title: String {
            switch self {
            case .notWired:
                return "Backend not wired"
            }
        }

        var summary: String {
            switch self {
            case .notWired:
                return "Backend not wired: downloads, StoreKit purchase, runtime activation, and uninstall flows are intentionally disabled until their service contracts land."
            }
        }
    }

    enum PresentationTone: String, Hashable, Sendable {
        case neutral
        case positive
        case warning
        case danger
        case progress
        case muted
    }

    struct StatePresentation: Hashable, Sendable {
        let title: String
        let summary: String
        let systemImage: String
        let tone: PresentationTone
        let progress: Double?
    }

    struct ActionPresentation: Hashable, Sendable {
        let title: String
        let summary: String
        let isEnabled: Bool
    }

    struct Spec: Identifiable, Hashable, Sendable {
        let title: String
        let value: String

        var id: String {
            "\(title):\(value)"
        }
    }

    /// One render-ready row: a catalog entry plus its honest current state.
    struct Row: Identifiable, Hashable, Sendable {
        let entry: ModelCatalogEntry
        let downloadState: ModelDownloadState
        let backendStatus: BackendStatus
        var id: String { entry.id }

        /// Whether the row is locked behind a purchase (§7).
        var isPaidLocked: Bool {
            downloadState.kind == .requiresPurchase
        }

        var title: String {
            entry.displayName
        }

        var summary: String {
            entry.statusCopy
        }

        var statePresentation: StatePresentation {
            Self.statePresentation(for: downloadState, entry: entry)
        }

        var actionPresentation: ActionPresentation {
            switch downloadState {
            case .eligible:
                let title = entry.runtimeFamily == .remoteGateway
                    ? "Gateway pending"
                    : "Download pending"
                return ActionPresentation(
                    title: title,
                    summary: backendStatus.summary,
                    isEnabled: false
                )
            case .requiresPurchase:
                return ActionPresentation(
                    title: "Purchase required",
                    summary: "This row needs a verified StoreKit entitlement before kAir can use it.",
                    isEnabled: false
                )
            case .purchasing:
                return ActionPresentation(
                    title: "Purchase pending",
                    summary: "StoreKit purchase handling is not wired in this build.",
                    isEnabled: false
                )
            case .downloadQueued, .downloading, .downloaded, .verifying, .compiling, .paused:
                return ActionPresentation(
                    title: "Managed by backend",
                    summary: "Progress can only be changed by a real download manager snapshot.",
                    isEnabled: false
                )
            case .failed:
                return ActionPresentation(
                    title: "Retry pending",
                    summary: "Retry stays disabled until the download manager contract is implemented.",
                    isEnabled: false
                )
            case .installed:
                return ActionPresentation(
                    title: "Installed",
                    summary: "No action is exposed from this shell row.",
                    isEnabled: false
                )
            case .active:
                return ActionPresentation(
                    title: "Active",
                    summary: "This is the active model reported by backend state.",
                    isEnabled: false
                )
            case .unavailable:
                return ActionPresentation(
                    title: "Unavailable",
                    summary: "The model cannot be used on this device or backend state right now.",
                    isEnabled: false
                )
            case .notInstalled, .deleting, .deleted:
                return ActionPresentation(
                    title: "Setup pending",
                    summary: backendStatus.summary,
                    isEnabled: false
                )
            }
        }

        var specs: [Spec] {
            [
                Spec(title: "Role", value: Self.roleTitle(entry.role)),
                Spec(title: "Runtime", value: Self.runtimeTitle(entry.runtimeFamily)),
                Spec(title: "Disk", value: Self.byteText(entry.diskSizeBytes)),
                Spec(title: "Memory", value: Self.byteText(entry.estimatedMemoryBytes)),
                Spec(title: "Version", value: entry.version),
                Spec(title: "Minimum", value: "\(entry.minimumDeviceClass) / iOS \(entry.minimumOS)"),
            ]
        }

        var capabilityLine: String {
            var capabilities: [String] = []
            if entry.supportsStructuredOutput {
                capabilities.append("structured output")
            }
            if entry.supportsToolCalling {
                capabilities.append("tool calling")
            }
            if entry.supportsStreaming {
                capabilities.append("streaming")
            }
            if capabilities.isEmpty {
                capabilities.append("runtime contract only")
            }
            return capabilities.joined(separator: " / ")
        }

        var trustLine: String {
            if entry.role == .health {
                return "Health local-only"
            }
            if entry.isPaid {
                return "Entitlement gated"
            }
            if entry.downloadURL == nil {
                return "Bundled catalog entry"
            }
            return entry.hasTrustedDownloadSource
                ? "Signed download source"
                : "Untrusted download source"
        }

        private static func statePresentation(
            for state: ModelDownloadState,
            entry: ModelCatalogEntry
        ) -> StatePresentation {
            switch state {
            case .notInstalled:
                return StatePresentation(
                    title: "Not installed",
                    summary: "Catalog metadata is visible, but no install state has been reported.",
                    systemImage: "circle",
                    tone: .muted,
                    progress: nil
                )
            case .eligible:
                if entry.runtimeFamily == .remoteGateway {
                    return StatePresentation(
                        title: "Gateway setup pending",
                        summary: "Entitlement allows access, but the remote gateway is not wired.",
                        systemImage: "network",
                        tone: .warning,
                        progress: nil
                    )
                }
                if entry.downloadURL == nil {
                    return StatePresentation(
                        title: "Bundled setup pending",
                        summary: "Catalog marks this as bundled, but runtime activation has not reported active or installed state.",
                        systemImage: "archivebox",
                        tone: .warning,
                        progress: nil
                    )
                }
                return StatePresentation(
                    title: "Download setup pending",
                    summary: "A trusted catalog source exists; the download manager is not wired yet.",
                    systemImage: "arrow.down.circle",
                    tone: .warning,
                    progress: nil
                )
            case .requiresPurchase:
                return StatePresentation(
                    title: "Paid locked",
                    summary: "A verified entitlement is required before use.",
                    systemImage: "lock",
                    tone: .warning,
                    progress: nil
                )
            case .purchasing:
                return StatePresentation(
                    title: "Purchase pending",
                    summary: "Purchase state is in progress according to the backend snapshot.",
                    systemImage: "creditcard",
                    tone: .progress,
                    progress: nil
                )
            case .downloadQueued:
                return StatePresentation(
                    title: "Queued",
                    summary: "Waiting for the download manager.",
                    systemImage: "clock",
                    tone: .progress,
                    progress: nil
                )
            case .downloading(let progress):
                let clamped = min(max(progress, 0), 1)
                return StatePresentation(
                    title: "Downloading \(Int((clamped * 100).rounded()))%",
                    summary: "A backend snapshot reports download progress.",
                    systemImage: "arrow.down.circle.fill",
                    tone: .progress,
                    progress: clamped
                )
            case .downloaded:
                return StatePresentation(
                    title: "Downloaded",
                    summary: "Bytes are present and waiting for verification.",
                    systemImage: "checkmark.circle",
                    tone: .progress,
                    progress: nil
                )
            case .verifying:
                return StatePresentation(
                    title: "Verifying",
                    summary: "Checksum and signature verification are in progress.",
                    systemImage: "checkmark.shield",
                    tone: .progress,
                    progress: nil
                )
            case .compiling:
                return StatePresentation(
                    title: "Compiling",
                    summary: "Runtime artifact compilation is in progress.",
                    systemImage: "hammer",
                    tone: .progress,
                    progress: nil
                )
            case .installed:
                return StatePresentation(
                    title: "Installed",
                    summary: "Installed and ready, but not selected as active.",
                    systemImage: "checkmark.circle.fill",
                    tone: .positive,
                    progress: nil
                )
            case .active:
                return StatePresentation(
                    title: "Active",
                    summary: "Backend state marks this model active for its role.",
                    systemImage: "bolt.circle.fill",
                    tone: .positive,
                    progress: nil
                )
            case .paused:
                return StatePresentation(
                    title: "Paused",
                    summary: "Download is paused and can resume when backend support exists.",
                    systemImage: "pause.circle",
                    tone: .warning,
                    progress: nil
                )
            case .failed(let reason):
                return StatePresentation(
                    title: "Failed",
                    summary: failureCopy(reason),
                    systemImage: "exclamationmark.triangle",
                    tone: .danger,
                    progress: nil
                )
            case .deleting:
                return StatePresentation(
                    title: "Deleting",
                    summary: "Uninstall is in progress according to backend state.",
                    systemImage: "trash",
                    tone: .progress,
                    progress: nil
                )
            case .deleted:
                return StatePresentation(
                    title: "Deleted",
                    summary: "Model files are removed; entitlement is preserved separately.",
                    systemImage: "trash.circle",
                    tone: .muted,
                    progress: nil
                )
            case .unavailable(let reason):
                return StatePresentation(
                    title: "Unavailable",
                    summary: unavailableCopy(reason),
                    systemImage: "nosign",
                    tone: .danger,
                    progress: nil
                )
            }
        }

        private static func roleTitle(_ role: ModelRole) -> String {
            switch role {
            case .router: return "Router"
            case .planner: return "Planner"
            case .embedder: return "Embedder"
            case .health: return "Health"
            case .premium: return "Premium"
            }
        }

        private static func runtimeTitle(_ family: ModelRuntimeFamily) -> String {
            switch family {
            case .foundationModels: return "Foundation Models"
            case .coreML: return "Core ML"
            case .mlx: return "MLX"
            case .llamaCPP: return "llama.cpp"
            case .executorch: return "ExecuTorch"
            case .remoteGateway: return "Remote gateway"
            }
        }

        private static func byteText(_ bytes: Int64) -> String {
            guard bytes > 0 else { return "Server-side" }
            let megabytes = Double(bytes) / 1_000_000
            if megabytes >= 1_000 {
                return String(format: "%.1f GB", megabytes / 1_000)
            }
            return "\(Int(megabytes.rounded())) MB"
        }

        private static func failureCopy(_ reason: ModelDownloadState.FailureReason) -> String {
            switch reason {
            case .downloadInterrupted: return "Download was interrupted."
            case .checksumMismatch: return "Checksum verification failed."
            case .signatureInvalid: return "Signature verification failed."
            case .insufficientDisk: return "Not enough disk space."
            case .compileFailed: return "Runtime compilation failed."
            case .installFailed: return "Install step failed."
            }
        }

        private static func unavailableCopy(_ reason: ModelDownloadState.UnavailableReason) -> String {
            switch reason {
            case .deviceUnsupported: return "This device does not meet the model requirements."
            case .osTooOld: return "The current OS is below the minimum supported version."
            case .removedFromCatalog: return "This model has been removed from the catalog."
            case .backendNotWired: return "The required backend contract is not wired yet."
            }
        }
    }

    /// The rows to render, in catalog order.
    private(set) var rows: [Row]
    let backendStatus: BackendStatus

    /// The entitlement snapshot this store was built from (model id → state).
    private let entitlements: [String: ModelEntitlement]

    /// Build the library from a catalog, an entitlement snapshot, and an
    /// optional backend state snapshot.
    ///
    /// - Parameters:
    ///   - catalog: the model entries (defaults to the fixture catalog).
    ///   - entitlements: model id → entitlement (default: none entitled). Free
    ///     models ignore this; paid models without an `.entitled` entry stay
    ///     `.requiresPurchase`.
    ///   - backendStates: model id → a real, observed download/install state
    ///     (e.g. `.installed`, `.active`, `.failed`, `.unavailable`). Only a
    ///     genuine backend provides these — there is no default that fabricates
    ///     a completed download.
    init(
        catalog: [ModelCatalogEntry]? = nil,
        entitlements: [String: ModelEntitlement] = [:],
        backendStates: [String: ModelDownloadState] = [:],
        backendStatus: BackendStatus = .notWired
    ) {
        let catalog = catalog ?? ModelCatalog.fixtures
        self.entitlements = entitlements
        self.backendStatus = backendStatus
        self.rows = catalog.map { entry in
            let entitlement = entitlements[entry.id] ?? .notEntitled
            // Paid lock has highest priority. A backend snapshot must not make
            // an unentitled paid model appear installed/active/unavailable,
            // because catalog/backend metadata is not entitlement proof.
            let state: ModelDownloadState
            if entry.isPaid, entitlement != .entitled {
                state = .requiresPurchase
            } else {
                // A backend-observed state wins once entitlement allows access
                // (it reflects reality); otherwise the row shows only its
                // entitlement-derived starting state. Never an invented install.
                state = backendStates[entry.id]
                    ?? ModelEntitlementPolicy.initialDownloadState(
                        for: entry,
                        entitlement: entitlement
                    )
            }
            return Row(
                entry: entry,
                downloadState: state,
                backendStatus: backendStatus
            )
        }
    }

    var catalogCountText: String {
        "\(rows.count) catalog entries"
    }

    var localOnlyCountText: String {
        let count = rows.filter { $0.entry.runtimeFamily.isOnDevice }.count
        return "\(count) on-device"
    }

    var paidCountText: String {
        let count = rows.filter(\.entry.isPaid).count
        return "\(count) paid"
    }

    /// The row for a given model id, if present.
    func row(id: String) -> Row? {
        rows.first { $0.id == id }
    }

    /// Whether a user-initiated download may start for `id` — gated on
    /// entitlement (§6/§7). `false` for an unknown id or a paid-locked row.
    /// This never starts a download; it only reports whether the action is
    /// permitted (no real URLSession in this round).
    func canStartDownload(id: String) -> Bool {
        guard let row = row(id: id) else { return false }
        return ModelEntitlementPolicy.canStartDownload(
            for: row.entry,
            entitlement: entitlements[id] ?? .notEntitled
        )
    }
}
