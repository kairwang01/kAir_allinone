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

/// The closed-catalog surfaces a recommendation can activate on accept
/// (V1 step 2 — chat-home §3.5). Domain-pure: its raw values mirror the
/// App-layer `AppSection`, so the chat layer bridges via
/// `AppSection(rawValue:)` without this Core model importing `AppSection`.
enum RecommendedSurface: String, Hashable, CaseIterable {
    case health
    case ai
    case maps
    case search
    case store
}

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
    /// V1 step 2 (accept bridge): the prompt written into the thread when the
    /// user accepts this recommendation (chat-home §3.5). Empty means "no
    /// activation prompt" (the accept writes nothing). This is **explicit
    /// data** — the view never derives it from `title` / `primaryCTA`.
    let activationPrompt: String
    /// V1 step 2: the closed-catalog surface this recommendation opens on
    /// accept, or `nil` when the route is not resolvable (the accept writes
    /// the thread only — no guessing). Domain-pure `RecommendedSurface`.
    let preferredSection: RecommendedSurface?

    nonisolated init(
        id: String,
        kind: MatchingObjectKind,
        title: String,
        subtitleTokens: [String],
        reasonText: String?,
        primaryCTA: String,
        secondaryCTA: String?,
        activationPrompt: String = "",
        preferredSection: RecommendedSurface? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitleTokens = subtitleTokens
        self.reasonText = reasonText
        self.primaryCTA = primaryCTA
        self.secondaryCTA = secondaryCTA
        self.activationPrompt = activationPrompt
        self.preferredSection = preferredSection
    }
}
