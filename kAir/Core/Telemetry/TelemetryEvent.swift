//
//  TelemetryEvent.swift
//  kAir
//
//  Event-name constants for the v1 telemetry vocabulary.
//
//  Per Contracts/telemetry-contract-v1.md §4 (span / event naming):
//  - Names are dotted-lowercase ASCII; segments separate by `.`.
//  - The first segment is the lifecycle stage (chat, intent, rail,
//    surface, transcript, feedback). The second segment is the
//    subject. The third segment is the action.
//  - Per §4.3, a closed list of forbidden event names (no
//    `rail.card.click`, no `rail.refresh`, etc.) is in force.
//
//  Per Contracts/telemetry-contract-v1.md §5.2, each event carries a
//  specific subset of the seven identifiers from §3 (the propagation
//  matrix). The matrix itself is implemented in
//  TelemetryPropagationMatrix.swift; this file enumerates the names.
//
//  About `surface.<kind>.enter` / `surface.<kind>.return`: the
//  contract spells these as templates with a `<kind>` placeholder
//  filled by one of the eight surfaces. Swift `String` raw values must
//  be static, so the enum cases store the un-templated stems
//  (`surface.enter`, `surface.return`) and the static helpers
//  `surfaceEnterName(for:)` / `surfaceReturnName(for:)` produce the
//  fully-formed dotted name at emit time.
//

import Foundation

enum TelemetryEvent: String, Hashable, CaseIterable {
    /// Per §4.1: the user commits a prompt in chat home. The composer
    /// fires this exactly once per committed prompt.
    case chatPromptSubmit = "chat.prompt.submit"

    /// Per §4.1: the `ConversationIntentEngine` produces a decision
    /// (intent kind, surface routing, whether to surface a slate).
    /// Fires once per `chat.prompt.submit`.
    case intentDecide = "intent.decide"

    /// Per §4.1: the recommendation provider produces a slate for the
    /// rail (1, 2, or 3 cards). Fires once per slate render — either
    /// as the first slate after `chat.prompt.submit` or as a refresh
    /// after a downstream event.
    case railSlateMaterialize = "rail.slate.materialize"

    /// Per §4.1: a card is rendered in the rail. Fires once per
    /// (slate, slot) when the card first becomes visible.
    case railCardImpression = "rail.card.impression"

    /// Per §4.1: the user taps the primary `Accept` action on a card.
    /// Fires once per acceptance.
    case railCardAccept = "rail.card.accept"

    /// Per §4.1: the user taps `✕` or selects a `MatchingFeedbackKind`
    /// from `⋯`. Fires alongside `feedback.event`, never as a
    /// standalone event (per §4.4 co-fire invariant).
    case railCardDismiss = "rail.card.dismiss"

    /// Stem for `surface.<kind>.enter`. The full dotted name is
    /// produced via `surfaceEnterName(for:)`. Per §4.1 the contract
    /// names this `surface.<kind>.enter`; the un-templated form
    /// `surface.enter` is used as the Swift raw value because the
    /// `<kind>` placeholder is filled at emit time.
    case surfaceEnter = "surface.enter"

    /// Stem for `surface.<kind>.return`. The full dotted name is
    /// produced via `surfaceReturnName(for:)`. Same templating note
    /// as `surfaceEnter`.
    case surfaceReturn = "surface.return"

    /// Per §4.1: the continuation runtime emits a render-eligible
    /// `ChatContinuationEvent` (`outcome ∈ {.completion, .abandon}`)
    /// AND the transcript appends the projected `ConversationMessage`.
    case transcriptContinuationAppend = "transcript.continuation.append"

    /// Per §4.1: the continuation runtime emits a non-render-eligible
    /// `ChatContinuationEvent` (`outcome ∈ {.dismiss, .acceptNoEntry}`).
    /// The transcript appends nothing; this event records the silent
    /// decision for telemetry.
    case transcriptContinuationSilent = "transcript.continuation.silent"

    /// Per §4.1: the user submits feedback (the `✕` button or any
    /// `⋯` menu entry). Fires once per submission. Always co-fires
    /// with `rail.card.dismiss` (per §4.4).
    case feedbackEvent = "feedback.event"

    // MARK: - Surface name helpers

    /// Produces the fully-formed `surface.<kind>.enter` dotted name
    /// per Contracts/telemetry-contract-v1.md §4 (the `<kind>`
    /// placeholder is filled with the surface's raw value).
    static func surfaceEnterName(for kind: SurfaceKind) -> String {
        "surface.\(kind.rawValue).enter"
    }

    /// Produces the fully-formed `surface.<kind>.return` dotted name
    /// per Contracts/telemetry-contract-v1.md §4 (the `<kind>`
    /// placeholder is filled with the surface's raw value).
    static func surfaceReturnName(for kind: SurfaceKind) -> String {
        "surface.\(kind.rawValue).return"
    }
}
