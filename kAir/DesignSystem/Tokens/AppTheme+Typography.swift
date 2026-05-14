//
//  AppTheme+Typography.swift
//  kAir
//
//  Frozen typography tokens per
//  `Contracts/Design/design-system-v1.md` §3.2.
//
//  Background (Design-System Token Migration Audit, PR #37): the
//  contract froze 9 typography token NAMES as public API, but no
//  `AppTheme.Typography` symbol existed — typography was applied
//  through ~194 inline `.font(.largeTitle)` / `.font(.title3)` / …
//  call sites. The §8.1 ratification box "all §3 frozen rows have a
//  production consumer" could not be checked for §3.2 because there
//  was nothing named to consume.
//
//  This file closes that gap by creating the missing public API
//  (Tier 1 of the audit's remediation backlog). It does NOT migrate
//  the ~194 existing call sites — that is later, separate work. It
//  wires ONE production consumer (`SystemEvidenceBlock`'s eyebrow)
//  so the §8.1 box has a real consumer to point at.
//
//  Per the contract §3.2 table:
//
//  | Token        | Source       | Weight     | Tracking |
//  |--------------|--------------|------------|----------|
//  | display      | .largeTitle  | .bold      | default  |
//  | sectionTitle | .title3      | .semibold  | default  |
//  | heading      | .headline    | .semibold  | default  |
//  | actionLabel  | .subheadline | .semibold  | default  |
//  | body         | .body        | .regular   | default  |
//  | meta         | .footnote    | .medium    | default  |
//  | chip         | .caption     | .semibold  | default  |
//  | eyebrow      | .caption     | .bold      | 1.2      |
//  | micro        | .caption2    | .regular   | default  |
//
//  "default" tracking is encoded as `0` (SwiftUI's `.tracking(0)` is
//  a no-op equivalent to not applying tracking). Only `eyebrow`
//  carries a non-zero tracking in v1.
//
//  The contract notes a rounded variant is permitted on
//  `sectionTitle` for numeric / hero displays only. v1 models the
//  base token; the rounded variant is a permitted call-site option,
//  not a separate token, and is intentionally not encoded here.
//

import SwiftUI

extension AppTheme {
    /// Frozen typography tokens per `design-system-v1.md` §3.2.
    ///
    /// Each token bundles a SwiftUI `Font` (dynamic-type ramp +
    /// weight) with a `tracking` value. Apply via the
    /// `View.kAirTypography(_:)` modifier so font and tracking land
    /// together.
    enum Typography {
        /// A single typography token: a `Font` plus its `tracking`.
        ///
        /// `Equatable` (via `Font`'s own `Hashable` conformance) so
        /// tests can pin token values and consumers can compare.
        struct Token: Equatable {
            /// The SwiftUI font (dynamic-type style + weight).
            let font: Font
            /// Letter spacing in points. `0` means "default" (no
            /// tracking applied beyond the font's own metrics).
            let tracking: CGFloat
        }

        /// Page hero title — exactly one per screen. `.largeTitle` / `.bold`.
        static let display = Token(font: .largeTitle.weight(.bold), tracking: 0)

        /// Card title, hero metric value, top-of-section heading.
        /// `.title3` / `.semibold`.
        static let sectionTitle = Token(font: .title3.weight(.semibold), tracking: 0)

        /// Inline section heading inside a card; list-row primary
        /// text. `.headline` / `.semibold`.
        static let heading = Token(font: .headline.weight(.semibold), tracking: 0)

        /// Button / capsule label, primary action text.
        /// `.subheadline` / `.semibold`.
        static let actionLabel = Token(font: .subheadline.weight(.semibold), tracking: 0)

        /// Paragraph copy, page summary, card body text.
        /// `.body` / `.regular`.
        static let body = Token(font: .body.weight(.regular), tracking: 0)

        /// Metric tile title, supporting label, list-row meta.
        /// `.footnote` / `.medium`.
        static let meta = Token(font: .footnote.weight(.medium), tracking: 0)

        /// Chip / pill label, status badge. `.caption` / `.semibold`.
        static let chip = Token(font: .caption.weight(.semibold), tracking: 0)

        /// Section eyebrow paired with a `display` or `sectionTitle`
        /// directly below. `.caption` / `.bold` / tracking `1.2`.
        static let eyebrow = Token(font: .caption.weight(.bold), tracking: 1.2)

        /// Smallest meta (timestamp, counter). `.caption2` / `.regular`.
        static let micro = Token(font: .caption2.weight(.regular), tracking: 0)
    }
}

extension View {
    /// Applies a frozen typography token — font + tracking together
    /// — per `Contracts/Design/design-system-v1.md` §3.2.
    ///
    /// Use this instead of bare `.font(...)` / `.tracking(...)` so a
    /// reviewer can `grep` for `kAirTypography` and find every
    /// typed-token consumer. (Migrating the ~194 legacy inline
    /// `.font(...)` call sites to this modifier is later, separate
    /// work — see the token-migration audit.)
    func kAirTypography(_ token: AppTheme.Typography.Token) -> some View {
        self
            .font(token.font)
            .tracking(token.tracking)
    }
}
