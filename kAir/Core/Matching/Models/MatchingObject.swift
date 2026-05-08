//
//  MatchingObject.swift
//  kAir
//
//  Domain model for one recommendation candidate.
//
//  Fields are the minimum the rail's UI layer needs to render an
//  ActionCardShell per visual contract §5 and inventory §2. No scoring
//  metadata, no provider hints, no per-vertical extension fields.
//
//  This struct is pure domain data and has NO dependency on the UI layer.
//  Card-presentation concerns such as the trust-pill vocabulary
//  (`ActionCardTrustPillKind`) live with the design system; the rail's
//  shell consults a UI-side adapter (`ActionCardShell.trustPills(for:)`)
//  to resolve a per-object pill array at render time. See
//  `kAir/DesignSystem/Components/ActionCardTrustPillResolver.swift`.
//

import Foundation

struct MatchingObject: Identifiable, Hashable {
    let id: String
    let kind: MatchingObjectKind
    let title: String
    /// Up to 2 metadata tokens per inventory §4.1. Joined with ` · ` at render.
    let subtitleTokens: [String]
    /// One short clause, ≤ 60 chars per inventory §4.2. Optional.
    let reasonText: String?
    /// Primary CTA button label (e.g., "Open route", "Play song").
    let primaryCTA: String
    /// Optional secondary CTA. nil means the secondary slot is omitted.
    let secondaryCTA: String?
}
