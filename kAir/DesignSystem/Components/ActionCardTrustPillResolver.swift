//
//  ActionCardTrustPillResolver.swift
//  kAir
//
//  UI-side adapter that maps a `MatchingObject` to the trust pills the
//  card should render in its metadata row.
//
//  Why this lives here: the trust-pill vocabulary
//  (`ActionCardTrustPillKind`) is a card-presentation concept (label +
//  glyph + tone) and is owned by the design system per
//  Docs/design/action-card-component-inventory.md §5. Keeping the per-
//  object pill array on the UI side means `MatchingObject` stays free of
//  any UI-layer type, while the rail still renders identically — the
//  shell asks the resolver for the pills at render time, by id.
//
//  This is a pure presentation hint store. There is no scoring, no
//  derivation from raw matcher output. The mapping is keyed by
//  `MatchingObject.id` and seeded from the same fixtures that used to
//  set `trustPills` directly on the struct.
//

import Foundation

/// Resolves the trust pills to render for a given `MatchingObject`.
/// The default implementation falls back to an empty array (collapses
/// the metadata row to zero height per inventory §2). Tests and
/// previews override the mapping by editing
/// `ActionCardTrustPillResolver.fixturePills`.
enum ActionCardTrustPillResolver {
    /// Pre-computed pill arrays for the recommendation fixtures. Keyed
    /// by `MatchingObject.id`. An object that is not in this map has
    /// no pills (empty row collapses).
    ///
    /// This map is the single source of truth for fixture-side pill
    /// data. Production matcher code (when it lands) will register its
    /// own ids alongside or replace this map.
    static let fixturePills: [String: [ActionCardTrustPillKind]] = [
        "place-pier-7-trusted": [.placeResolutionLive, .etaConfidenceEstimate],
        "route-bay":            [.distanceConfidenceEstimate]
    ]

    /// Returns the trust pills to render for `object`. Defaults to an
    /// empty array when no entry is registered for the object's id.
    static func pills(for object: MatchingObject) -> [ActionCardTrustPillKind] {
        fixturePills[object.id] ?? []
    }
}
