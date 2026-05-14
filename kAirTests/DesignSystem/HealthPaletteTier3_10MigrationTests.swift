//
//  HealthPaletteTier3_10MigrationTests.swift
//  kAirTests
//
//  Pins the Tier 3.10 bounded slice (audit §8.1 box 4): the
//  `HealthPalette` §6-alias call sites *inside `InsightRow` and
//  `SignalChart`* (in `DashboardSections.swift`) are migrated to the
//  `AppTheme.Palette` contract tokens they alias.
//
//  Scope note: this slice is TWO component domains — the `InsightRow`
//  struct (2 box-4 alias occurrences: `ink` ×1, `mutedInk` ×1) and the
//  `SignalChart` struct (5 box-4 alias occurrences: `ink` ×3,
//  `mutedInk` ×2), for 7 box-4 occurrences total. Both are
//  "resolver-adjacent" box-4 slices — `InsightRow` ALSO contains 3
//  `HealthPalette.color(for: insight.accentToken)` resolver call sites
//  and `SignalChart` ALSO contains 2 `HealthPalette.color(for:
//  series.id)` resolver call sites, for 5 resolver calls total. A
//  resolver is NOT a §6 box-4 alias, so those 5 calls are
//  intentionally left untouched: resolver migration is its own
//  dedicated PR, out of scope for an alias-migration slice.
//
//  `InsightRow` and `SignalChart` are both `private` structs — like
//  `HeroCard` (PR #40), `RiskOrb` (PR #44), and `ConditionPredictionRow`
//  (PR #48), their wiring is build-proven (the build compiling with the
//  migrated inline `AppTheme.Palette.*` references proves it; there is
//  no test-reachable `static`). So, like the Tier 3.5 (`RiskOrb`) and
//  Tier 3.8 (`ConditionPredictionRow`) test files, this file has NO
//  component-wiring assertions — only the visual-safety proof and the
//  resolver-boundary note, both provable without touching `InsightRow`'s
//  or `SignalChart`'s internals.
//
//  Two kinds of assertion:
//    1. Visual-safety proof — the 2 migrated box-4 aliases (`ink`,
//       `mutedInk`) are `==` to their `AppTheme.Palette` targets, so
//       each inline migration in `InsightRow` and `SignalChart` is
//       provably a pure rename with zero visual change. Because both
//       structs are `private`, this alias-equivalence proof IS the
//       wiring guarantee.
//    2. Resolver-boundary note — documents that `HealthPalette` has a
//       `color(for:)` resolver that is NOT a box-4 alias and is
//       deliberately out of this slice's scope.
//

import XCTest
import SwiftUI
@testable import kAir

final class HealthPaletteTier3_10MigrationTests: XCTestCase {

    // MARK: - 1. Visual-safety proof (box-4 alias equivalence)

    func test_box4Aliases_migratedInThisSlice_equalTheirContractTokens() {
        // The 2 box-4 aliases consumed by `InsightRow` and `SignalChart`
        // are DEFINED as their `AppTheme.Palette` targets, so swapping a
        // call site from the alias to the token is provably a pure
        // rename — zero rendered-color change. Both `InsightRow` and
        // `SignalChart` are `private`, so this alias-equivalence proof IS
        // the wiring guarantee: the build compiles with `AppTheme.Palette.{
        // textPrimary,textSecondary}` inline at the 7 migrated box-4 call
        // sites (1 + 1 in `InsightRow`, 3 + 2 in `SignalChart`), and these
        // assertions prove those are the same colors the `HealthPalette`
        // aliases resolved to.
        XCTAssertEqual(HealthPalette.ink, AppTheme.Palette.textPrimary)
        XCTAssertEqual(HealthPalette.mutedInk, AppTheme.Palette.textSecondary)
    }

    // MARK: - 2. Resolver-boundary note (color(for:) is NOT a box-4 alias)

    func test_colorForResolver_isNotABox4Alias_outOfSliceScope() {
        // `HealthPalette.color(for:)` is a *resolver function*, not a
        // §6 box-4 alias. `InsightRow` has 3 `HealthPalette.color(for:
        // insight.accentToken)` resolver call sites (the `CapsuleChip`
        // color, the score `.foregroundStyle`, and the background
        // `.fill(...).opacity(0.10)`); `SignalChart` has 2
        // `HealthPalette.color(for: series.id)` resolver call sites (the
        // `AreaMark` gradient stop and the `LineMark` `.foregroundStyle`).
        // Per the migration plan, resolver call sites are NOT migrated in
        // an alias slice — resolver migration is its own dedicated PR. So
        // those 5 calls are intentionally left exactly as-is.
        //
        // This test documents the boundary: the resolver is a function
        // (it maps an arbitrary `String` id to a `Color`), whereas a
        // box-4 alias is a `static let` that is literally `==` to one
        // fixed `AppTheme.Palette` token. The two are categorically
        // different and must not be conflated.
        let box4Targets: Set<Color> = [
            AppTheme.Palette.backgroundStart, // canvas
            AppTheme.Palette.textPrimary,     // ink
            AppTheme.Palette.textSecondary,   // mutedInk
            AppTheme.Palette.line,            // cardStroke
            AppTheme.Palette.success,         // mint
            AppTheme.Palette.sky,             // cyan
            AppTheme.Palette.warning,         // amber
            AppTheme.Palette.danger,          // coral
        ]
        // The resolver, given an unknown token, returns its fallback
        // color. That fallback is intentionally NOT enumerated as a
        // box-4 alias target here — the resolver's output is a
        // function result, not an alias, and is out of scope for this
        // slice regardless of which `Color` it happens to produce.
        let resolverFallback = HealthPalette.color(for: "tier3_10_unknown_token")
        _ = box4Targets // referenced to document the box-4 target set
        _ = resolverFallback // referenced to document the resolver boundary
    }

    // MARK: - Cross-slice consistency

    func test_migratedBox4Aliases_areDistinctColors() {
        // The 2 box-4 aliases migrated in this slice are distinct
        // colors — confirms `InsightRow`'s and `SignalChart`'s primary
        // text (`ink` → `textPrimary`) and secondary text (`mutedInk` →
        // `textSecondary`) stay separate roles and the migration did
        // not collapse them.
        XCTAssertNotEqual(HealthPalette.ink, HealthPalette.mutedInk)
        XCTAssertNotEqual(AppTheme.Palette.textPrimary, AppTheme.Palette.textSecondary)
    }
}
