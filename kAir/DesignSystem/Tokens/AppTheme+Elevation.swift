//
//  AppTheme+Elevation.swift
//  kAir
//
//  Frozen elevation tiers per
//  `Contracts/Design/design-system-v1.md` §3.5.
//
//  Background (Design-System Token Migration Audit, PR #37): the
//  contract froze 3 elevation tiers with normative shadow-α / blur /
//  y-offset values, but no `AppTheme.Elevation` symbol existed.
//  Components that happened to be on-grid restated the values via
//  local per-component constants (`ActionCardShell.shadowOpacity`,
//  `SystemSummaryBlock.shadowBlur`, …) rather than a shared token.
//  The §8.1 ratification box "all §3 frozen rows have a production
//  consumer" could not be checked for §3.5.
//
//  This file closes that gap (Tier 1 of the audit's backlog). It
//  does NOT migrate the off-grid shadows (`KAirSurface.hero/.sunken`,
//  `GlassCard`, `KAirActionCapsule` non-emphasized, the 3 ChatHomeView
//  sites) — that is Tier 2, separate work. It wires ONE on-grid
//  production consumer (`ActionCardShell`, already α 0.06 / r 12 /
//  y 6 = `.raised`) so the §8.1 box has a real consumer to point at.
//
//  Per the contract §3.5 table:
//
//  | Token              | Shadow α | Blur | Y-offset |
//  |--------------------|----------|------|----------|
//  | elevation.flat     | 0.00     | 0    | 0        |
//  | elevation.raised   | 0.06     | 12   | +6       |
//  | elevation.floating | 0.08     | 14   | +6       |
//
//  Shadow color is pure black for `raised` / `floating` (`flat` has
//  no shadow). X-offset is `0` for all three. Blur and α are
//  absolute, not multiplied by a system factor.
//

import SwiftUI

extension AppTheme {
    /// Frozen elevation tiers per `design-system-v1.md` §3.5.
    ///
    /// Apply via the `View.kAirElevation(_:)` modifier so the shadow
    /// color / opacity / radius / offset land together as one tier.
    enum Elevation {
        /// A single elevation tier: shadow opacity + blur radius +
        /// vertical offset. Shadow color is always pure black;
        /// x-offset is always `0` (per §3.5). `Hashable` so tests
        /// can pin tier values, compare, and collect tiers in a
        /// `Set`.
        struct Token: Hashable {
            /// Shadow opacity applied to pure black. `0` means "no
            /// shadow" (the `flat` tier).
            let shadowOpacity: Double
            /// Shadow blur radius in points.
            let radius: CGFloat
            /// Shadow vertical offset in points. X-offset is always
            /// `0` and is not stored.
            let yOffset: CGFloat
        }

        /// In-flow content, chips, status pills, anything nested
        /// inside an already-raised surface. No shadow.
        static let flat = Token(shadowOpacity: 0.0, radius: 0, yOffset: 0)

        /// Top-level cards (`KAirSurface` default), sheets at rest,
        /// page sections. α 0.06 / blur 12 / y +6.
        static let raised = Token(shadowOpacity: 0.06, radius: 12, yOffset: 6)

        /// Primary emphasized action, modal entry, sheet in motion.
        /// α 0.08 / blur 14 / y +6.
        static let floating = Token(shadowOpacity: 0.08, radius: 14, yOffset: 6)
    }
}

extension View {
    /// Applies a frozen elevation tier (shadow) per
    /// `Contracts/Design/design-system-v1.md` §3.5.
    ///
    /// Shadow color is always pure black at the tier's opacity;
    /// x-offset is always `0`. The `flat` tier applies a
    /// zero-opacity / zero-radius shadow, which renders identically
    /// to no shadow.
    ///
    /// Use this instead of bare `.shadow(...)` so a reviewer can
    /// `grep` for `kAirElevation` and find every typed-tier
    /// consumer. (Migrating the off-grid `.shadow(...)` call sites
    /// to one of the three tiers is later, separate work — see the
    /// token-migration audit Tier 2.)
    func kAirElevation(_ token: AppTheme.Elevation.Token) -> some View {
        self.shadow(
            color: Color.black.opacity(token.shadowOpacity),
            radius: token.radius,
            x: 0,
            y: token.yOffset
        )
    }
}
