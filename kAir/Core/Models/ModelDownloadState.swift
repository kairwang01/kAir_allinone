//
//  ModelDownloadState.swift
//  kAir
//
//  Pure value contract for the model download / install state machine.
//
//  A3 model-catalog value contracts (kair-ai-model-memory-v1.md §6). Foundation
//  only — this is a deterministic state vocabulary + transition graph. No real
//  URLSession download, no StoreKit, no model compilation, no side effects.
//
//  §6 rules encoded here:
//    - A download starts only after an explicit user action: `eligible`
//      (free) / a purchased `requiresPurchase` → `downloadQueued`. There is no
//      edge that jumps straight to `downloading`.
//    - A paid model must pass through entitlement before download:
//      `requiresPurchase → purchasing → eligible → downloadQueued`. There is
//      NO `requiresPurchase → downloading` edge (no faked purchase).
//    - Compile / install / verify failures are recoverable and visible:
//      any of those → `failed`, and `failed` can retry back to `downloadQueued`.
//    - Uninstall keeps the purchase: `deleted` returns to `eligible` for an
//      entitled paid model (re-downloadable), not back to `requiresPurchase`.
//

import Foundation

/// The set of download/install lifecycle nodes (§6), with no associated
/// values — the keys for the transition graph and for state coverage checks.
enum ModelDownloadStateKind: String, Codable, Hashable, Sendable, CaseIterable {
    case notInstalled
    case eligible
    case requiresPurchase
    case purchasing
    case downloadQueued
    case downloading
    case downloaded
    case verifying
    case compiling
    case installed
    case active
    case paused
    case failed
    case deleting
    case deleted
    case unavailable
}

/// The model download / install lifecycle state (§6). Carries progress and
/// failure / unavailable reasons; the `kind` projects it onto the transition
/// graph.
enum ModelDownloadState: Hashable, Sendable {
    /// Not present and not yet evaluated.
    case notInstalled
    /// Free, ready to download with no purchase needed ("free" acceptance state).
    case eligible
    /// Paid and not yet entitled — locked ("paid locked" acceptance state).
    case requiresPurchase
    /// A StoreKit purchase is in flight (no real StoreKit in this round).
    case purchasing
    /// User started a download; queued behind quota / connectivity checks.
    case downloadQueued
    /// Actively downloading, `progress` in `0.0...1.0`.
    case downloading(progress: Double)
    /// Bytes on disk, not yet verified.
    case downloaded
    /// Checking checksum + signature (§5).
    case verifying
    /// Compiling the runtime artifact (e.g. Core ML compile).
    case compiling
    /// Installed and ready, not currently the active model for its role.
    case installed
    /// Installed and selected as the active model for its role.
    case active
    /// Download paused, resumable.
    case paused
    /// A recoverable, visible failure (§6).
    case failed(reason: FailureReason)
    /// Uninstall in flight.
    case deleting
    /// Removed from disk (purchase entitlement is kept — §6).
    case deleted
    /// Cannot be installed/used on this device right now (§5/§6).
    case unavailable(reason: UnavailableReason)

    /// Project onto the associated-value-free node set.
    var kind: ModelDownloadStateKind {
        switch self {
        case .notInstalled:     return .notInstalled
        case .eligible:         return .eligible
        case .requiresPurchase: return .requiresPurchase
        case .purchasing:       return .purchasing
        case .downloadQueued:   return .downloadQueued
        case .downloading:      return .downloading
        case .downloaded:       return .downloaded
        case .verifying:        return .verifying
        case .compiling:        return .compiling
        case .installed:        return .installed
        case .active:           return .active
        case .paused:           return .paused
        case .failed:           return .failed
        case .deleting:         return .deleting
        case .deleted:          return .deleted
        case .unavailable:      return .unavailable
        }
    }

    /// Whether this state represents a finished, usable install (§6).
    var isInstalled: Bool {
        switch self {
        case .installed, .active: return true
        default:                  return false
        }
    }

    /// A recoverable failure cause (§6 — failures are visible and retryable).
    enum FailureReason: String, Codable, Hashable, Sendable, CaseIterable {
        case downloadInterrupted
        case checksumMismatch
        case signatureInvalid
        case insufficientDisk
        case compileFailed
        case installFailed
    }

    /// A reason a model cannot be installed/used on this device (§5/§6).
    enum UnavailableReason: String, Codable, Hashable, Sendable, CaseIterable {
        case deviceUnsupported
        case osTooOld
        case removedFromCatalog
        case backendNotWired
    }
}

/// The §6 transition graph as a pure function. Encodes the user-action,
/// entitlement, and recovery rules; holds no state itself.
enum ModelDownloadMachine {
    /// Legal next nodes for each node (§6).
    static let allowedTransitions: [ModelDownloadStateKind: Set<ModelDownloadStateKind>] = [
        // Entry: classify into free-eligible or paid-locked (or unavailable).
        .notInstalled:     [.eligible, .requiresPurchase, .unavailable],
        // Free + ready: the only start edge is a user-initiated queue.
        .eligible:         [.downloadQueued, .unavailable],
        // Paid + locked: must purchase first; cannot queue/download directly.
        .requiresPurchase: [.purchasing, .unavailable],
        // Purchase resolves to entitled (→ eligible), cancelled (→ locked), or failed.
        .purchasing:       [.eligible, .requiresPurchase, .failed],
        // Queued → downloading; pausable; can fail (quota/connectivity).
        .downloadQueued:   [.downloading, .paused, .failed],
        // Downloading → done; pausable; can fail.
        .downloading:      [.downloaded, .paused, .failed],
        // Verify the bytes (§5).
        .downloaded:       [.verifying, .failed],
        // Verify → compile, or fail.
        .verifying:        [.compiling, .failed],
        // Compile → installed, or fail (recoverable).
        .compiling:        [.installed, .failed],
        // Installed: activate for its role, or uninstall.
        .installed:        [.active, .deleting],
        // Active: deactivate (→ installed) or uninstall.
        .active:           [.installed, .deleting],
        // Paused: resume to queue/download, or fail/expire.
        .paused:           [.downloadQueued, .downloading, .failed],
        // Failed: retry (→ queue), re-lock (paid), uninstall, or go unavailable.
        .failed:           [.downloadQueued, .requiresPurchase, .deleting, .unavailable],
        // Deleting → deleted, or fail.
        .deleting:         [.deleted, .failed],
        // Deleted keeps entitlement: a paid+entitled model returns to eligible.
        .deleted:          [.notInstalled, .eligible, .requiresPurchase],
        // Unavailable can clear back to a fresh evaluation.
        .unavailable:      [.notInstalled, .eligible],
    ]

    /// Whether `from → to` is a legal transition (§6).
    static func canTransition(
        from: ModelDownloadStateKind,
        to: ModelDownloadStateKind
    ) -> Bool {
        allowedTransitions[from]?.contains(to) ?? false
    }
}

extension ModelDownloadState {
    /// Whether this state may legally transition to `next` (§6) — a convenience
    /// over `ModelDownloadMachine` that compares each state's `kind`. An
    /// instance method (not a `canTransition(from:to:)` overload) so bare-case
    /// callers stay unambiguous against the kind-based graph API.
    func canTransition(to next: ModelDownloadState) -> Bool {
        ModelDownloadMachine.canTransition(from: kind, to: next.kind)
    }
}
