//
//  CapabilityAdapter.swift
//  kAir
//
//  The adapter protocol every concrete adapter MUST conform to per
//  Contracts/capability-registry-and-adapter-contract-v1.md §4, plus the
//  request shape and the closed CapabilityError vocabulary (§4.5).
//
//  Adapters are reference types and MUST be safe to retain on
//  MainActor-isolated callers; the protocol surface is `MainActor`-isolated
//  for v1.
//

import Foundation

/// Minimum request shape per §4.1. v1 keeps it small: most adapters take a
/// free-text query OR a typed reference. Per-adapter docs may add fields
/// inside their own request shapes; this envelope is the shared minimum.
struct CapabilityRequest: Hashable {
    let kind: CapabilityKind
    let inputText: String?
    let inputObject: MatchingObject?

    init(
        kind: CapabilityKind,
        inputText: String? = nil,
        inputObject: MatchingObject? = nil
    ) {
        self.kind = kind
        self.inputText = inputText
        self.inputObject = inputObject
    }
}

/// Closed at v1 per §4.5. Adding a case is a v2 change.
enum CapabilityError: Error, Hashable {
    /// Adapter not currently available (permission, offline, partner-SDK miss).
    case unavailable
    /// Request was malformed or violated this kind's input shape.
    case invalidRequest
    /// Partner / underlying SDK returned an error.
    case partnerFailure
    /// Resolve exceeded the adapter's internal deadline.
    case timeout
    /// Structured-concurrency task was cancelled.
    case cancelled
}

/// Every concrete adapter MUST conform per §4.1.
///
/// - `static var capability` — the registry key; v1 is one adapter per kind.
/// - `isAvailable()` — cheap availability probe; MUST NOT throw, MUST NOT
///   trigger a permission prompt, SHOULD return cached state (§6).
/// - `resolve(...)` — the single resolution entry point; returned envelope's
///   `capability` MUST equal `Self.capability` (§5.4).
@MainActor
protocol CapabilityAdapter: AnyObject {
    static var capability: CapabilityKind { get }
    func isAvailable() async -> Bool
    func resolve(_ request: CapabilityRequest) async throws -> NormalizedResult
}
