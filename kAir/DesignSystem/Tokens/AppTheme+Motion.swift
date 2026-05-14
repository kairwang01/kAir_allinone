//
//  AppTheme+Motion.swift
//  kAir
//
//  Frozen motion tiers per
//  `Contracts/Design/design-system-v1.md` §3.6.
//
//  Background (Design-System Token Migration Audit, PR #37): the
//  contract froze 2 motion tiers, but no `AppTheme.Motion` symbol
//  existed. The whole codebase had only 2 inline animation call
//  sites, so there was almost nothing to migrate — but also no
//  token for the §8.1 ratification box "all §3 frozen rows have a
//  production consumer" to point at for §3.6.
//
//  This file closes that gap (Tier 1 of the audit's backlog). It
//  wires ONE production consumer (`ChatHomeView.scrollToBottom`,
//  already `.easeInOut(duration: 0.24)` = `.standard`) so the §8.1
//  box has a real consumer to point at.
//
//  Per the contract §3.6 table:
//
//  | Token             | Curve                                          | Duration / Response |
//  |-------------------|------------------------------------------------|---------------------|
//  | motion.standard   | .easeInOut                                     | 0.24s               |
//  | motion.emphasized | .spring(response: 0.42, dampingFraction: 0.82) | response 0.42s      |
//
//  Reduce-motion handling (the contract says both tiers collapse to
//  a 0.12s linear fade when the system flag is on) is a per-component
//  concern, NOT encoded in the token — same as the contract's §3.6
//  note. The tokens here are the un-reduced values.
//

import SwiftUI

extension AppTheme {
    /// Frozen motion tiers per `design-system-v1.md` §3.6.
    ///
    /// These are SwiftUI `Animation` values, applied directly via
    /// `withAnimation(_:)` or `.animation(_:value:)`. `Animation`
    /// conforms to `Equatable`, so tests can pin the tier values.
    enum Motion {
        /// Layout shifts, opacity fades, color transitions, idle
        /// micro-state. `.easeInOut`, 0.24s.
        ///
        /// Forbidden for affirmative state change (accepted,
        /// dismissed, refresh) — use `emphasized` there.
        static let standard = Animation.easeInOut(duration: 0.24)

        /// Accepted / dismissed state, modal present / dismiss,
        /// content refresh entry & exit, "preserve / suppress"
        /// affordances. `.spring(response: 0.42, dampingFraction: 0.82)`.
        ///
        /// Forbidden for continuous loops (spinners, shimmer) and
        /// idle hover / press.
        static let emphasized = Animation.spring(response: 0.42, dampingFraction: 0.82)
    }
}
