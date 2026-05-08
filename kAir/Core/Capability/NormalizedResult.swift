//
//  NormalizedResult.swift
//  kAir
//
//  The uniform result envelope every `resolve(...)` MUST produce per
//  Contracts/capability-registry-and-adapter-contract-v1.md §5, plus
//  the §5.4 envelope invariants (variant matches capability, confidence
//  in [0, 1], honest source per §8).
//
//  Per §5.2 normative scope, the variant choice (matching `capability`)
//  is what is normative. Per-capability supporting structs below are
//  marked "v1 illustrative; not normative" — concrete field schemas are
//  owned by each per-adapter doc, and consumers that don't recognize an
//  adapter-specific field MUST ignore it.
//

import Foundation

/// `.partner | .local | .aiSynthesized` per §5.3 — frozen vocabulary.
/// Adding a new case is a v2 change (§10).
enum ResultSource: String, Hashable, CaseIterable {
    /// Result came from a partner / native SDK round-trip.
    case partner
    /// Result came from an on-device cache, store, or filesystem without
    /// invoking a partner round-trip.
    case local
    /// Result was produced by an AI runtime (per `.aiCompletion` adapter
    /// or an explicit AI fallback inside another capability — only
    /// `.aiCompletion` is permitted to use this in v1; see §8.3).
    case aiSynthesized
}

/// One variant per `CapabilityKind` per §5.2. The variant on the envelope
/// MUST match the envelope's `capability` field (§5.4).
///
/// Supporting structs are v1 illustrative; not normative — see file
/// header.
enum CapabilityPayload: Hashable {
    case aiCompletion(completion: AICompletion)
    case threadLookup(thread: ThreadReference)
    case localStoreLookup(item: LocalStoreItem)
    case placeSearch(places: [PlaceCandidate])
    case routePlanning(route: RouteSummary)
    case musicPlayback(track: TrackReference)
    case videoPlayback(video: VideoReference)
    case healthRead(snapshot: HealthMetricSnapshot)
    case healthWrite(receipt: HealthWriteReceipt)
    case webSearch(hits: [WebHit])
}

/// The result envelope every adapter returns. Same shape regardless of
/// `CapabilityKind` so callers do not branch on capability to read off
/// the envelope (§5).
struct NormalizedResult: Hashable, Identifiable {
    let id: String
    let capability: CapabilityKind
    let payload: CapabilityPayload
    let source: ResultSource
    let confidence: Double
    let createdAt: Date

    /// Helper for the §5.4 invariant check: the variant on `payload` must
    /// match the envelope's `capability`. Returns `true` when paired
    /// correctly, `false` otherwise.
    static func variantMatchesCapability(
        _ payload: CapabilityPayload,
        _ capability: CapabilityKind
    ) -> Bool {
        switch (payload, capability) {
        case (.aiCompletion, .aiCompletion):           return true
        case (.threadLookup, .threadLookup):           return true
        case (.localStoreLookup, .localStoreLookup):   return true
        case (.placeSearch, .placeSearch):             return true
        case (.routePlanning, .routePlanning):         return true
        case (.musicPlayback, .musicPlayback):         return true
        case (.videoPlayback, .videoPlayback):         return true
        case (.healthRead, .healthRead):               return true
        case (.healthWrite, .healthWrite):             return true
        case (.webSearch, .webSearch):                 return true
        default:                                       return false
        }
    }
}

// MARK: - Illustrative payload supporting structs (v1 illustrative; not
// normative). Per §5.2: only the variant-to-capability one-to-one mapping
// is contract; field shapes are owned by each per-adapter doc and may
// extend without contract changes.

/// v1 illustrative; not normative. Per §5.2 illustrative shape:
/// "text, optional structured-output handle, runtime-family identifier".
struct AICompletion: Hashable {
    let text: String
    let runtimeFamily: String?
}

/// v1 illustrative; not normative. Per §5.2 illustrative shape:
/// "thread id, last-touched-at, optional title".
struct ThreadReference: Hashable {
    let threadID: String
    let lastTouchedAt: Date
    let title: String?
}

/// v1 illustrative; not normative. Per §5.2 illustrative shape:
/// "id, title, optional category".
struct LocalStoreItem: Hashable {
    let id: String
    let title: String
    let category: String?
}

/// v1 illustrative; not normative. Per §5.2 illustrative shape:
/// "id, name, coordinate, address, optional partner-attribution".
struct PlaceCandidate: Hashable {
    let id: String
    let name: String
    let address: String?
}

/// v1 illustrative; not normative. Per §5.2 illustrative shape:
/// "origin, destination, distance, duration, optional polyline reference".
struct RouteSummary: Hashable {
    let origin: String
    let destination: String
    let durationSeconds: Int?
}

/// v1 illustrative; not normative. Per §5.2 illustrative shape:
/// "id, title, artist, optional album, partner-attribution".
struct TrackReference: Hashable {
    let id: String
    let title: String
    let artist: String
}

/// v1 illustrative; not normative. Per §5.2 illustrative shape:
/// "id, title, optional thumbnail-id, partner-attribution".
struct VideoReference: Hashable {
    let id: String
    let title: String
}

/// v1 illustrative; not normative. Per §5.2 illustrative shape:
/// "metric token, value, unit, sampled-at".
struct HealthMetricSnapshot: Hashable {
    let metricToken: String
    let value: Double
    let unit: String
    let sampledAt: Date
}

/// v1 illustrative; not normative. Per §5.2 illustrative shape:
/// "confirmed metric token, written-at".
struct HealthWriteReceipt: Hashable {
    let metricToken: String
    let writtenAt: Date
}

/// v1 illustrative; not normative. Per §5.2 illustrative shape:
/// "title, url, snippet (no inline thumbnails per
/// mixed-recommendation-rail-visual-v1 §8)".
struct WebHit: Hashable {
    let title: String
    let url: String
    let snippet: String?
}
