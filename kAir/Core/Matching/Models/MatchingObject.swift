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
//  This struct lives in the domain layer; its `trustPills` field
//  references `ActionCardTrustPillKind`, which is a UI-side enum
//  declared in `kAir/DesignSystem/Components/ActionCardTrustPillKind.swift`.
//  The cross-layer reference is acknowledged (UI vocabulary is shipped
//  with the domain model so the matcher can pre-compute per-card
//  pill arrays) and is consistent with action-card-component-inventory §5
//  treating the pill set as a frozen part of the card contract.
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
    /// Trust pills rendered in the card's metadata row. Empty array
    /// collapses the row to zero height per inventory §2.
    let trustPills: [ActionCardTrustPillKind]
}
