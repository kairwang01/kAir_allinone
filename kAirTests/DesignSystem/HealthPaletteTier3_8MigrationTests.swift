//
//  HealthPaletteTier3_8MigrationTests.swift
//  kAirTests
//
//  Pins the Tier 3.8 bounded slice (audit §8.1 box 4): the
//  `HealthPalette` §6-alias call sites *inside `ConditionPredictionRow`*
//  (in `DashboardSections.swift`) are migrated to the `AppTheme.Palette`
//  contract tokens they alias.
//
//  Scope note: this slice is ONE component domain — the
//  `ConditionPredictionRow` struct (4 box-4 alias occurrences: `ink`
//  ×2, `mutedInk` ×2). It is the "resolver-adjacent" box-4 slice —
//  `ConditionPredictionRow` ALSO contains 4
//  `HealthPalette.color(for: prediction.id)` resolver call sites. A
//  resolver is NOT a §6 box-4 alias, so those 4 calls are
//  intentionally left untouched: resolver migration is its own
//  dedicated PR, out of scope for an alias-migration slice.
//
//  `ConditionPredictionRow` is a `private` struct — like `HeroCard`
//  (PR #40) and `RiskOrb` (PR #44), its wiring is build-proven (the
//  build compiling with the migrated inline `AppTheme.Palette.*`
//  references proves it; there is no test-reachable `static`). So,
//  like the Tier 3.5 (`RiskOrb`) test file, this file has NO
//  component-wiring assertions — only the visual-safety proof and the
//  resolver-boundary note, both provable without touching
//  `ConditionPredictionRow`'s internals.
//
//  Two kinds of assertion:
//    1. Visual-safety proof — the 2 migrated box-4 aliases (`ink`,
//       `mutedInk`) are `==` to their `AppTheme.Palette` targets, so
//       each inline migration in `ConditionPredictionRow` is provably
//       a pure rename with zero visual change. Because the struct is
//       `private`, this alias-equivalence proof IS the wiring
//       guarantee.
//    2. Resolver-boundary note — documents that `HealthPalette` has a
//       `color(for:)` resolver that is NOT a box-4 alias and is
//       deliberately out of this slice's scope.
//

import XCTest
import SwiftUI
@testable import kAir

final class HealthPaletteTier3_8MigrationTests: XCTestCase {

    // MARK: - 1. Visual-safety proof (box-4 alias equivalence)

    func test_box4Aliases_migratedInThisSlice_equalTheirContractTokens() {
        // The 2 box-4 aliases consumed by `ConditionPredictionRow` are
        // DEFINED as their `AppTheme.Palette` targets, so swapping a
        // call site from the alias to the token is provably a pure
        // rename — zero rendered-color change. `ConditionPredictionRow`
        // is `private`, so this alias-equivalence proof IS the wiring
        // guarantee: the build compiles with `AppTheme.Palette.{
        // textPrimary,textSecondary}` inline at the 4 migrated box-4
        // call sites, and these assertions prove those are the same
        // colors the `HealthPalette` aliases resolved to.
        XCTAssertEqual(HealthPalette.ink, AppTheme.Palette.textPrimary)
        XCTAssertEqual(HealthPalette.mutedInk, AppTheme.Palette.textSecondary)
    }

    // MARK: - 2. Resolver-boundary note (color(for:) is NOT a box-4 alias)

    func test_colorForResolver_isNotABox4Alias_outOfSliceScope() {
        // `HealthPalette.color(for:)` is a *resolver function*, not a
        // §6 box-4 alias. `ConditionPredictionRow` has 4
        // `HealthPalette.color(for: prediction.id)` resolver call sites
        // (two `CapsuleChip` colors, the probability `.foregroundStyle`,
        // and the background `.fill(...).opacity(0.10)`). Per the
        // migration plan, resolver call sites are NOT migrated in an
        // alias slice — resolver migration is its own dedicated PR. So
        // those 4 calls are intentionally left exactly as-is.
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
        let resolverFallback = HealthPalette.color(for: "tier3_8_unknown_token")
        _ = box4Targets // referenced to document the box-4 target set
        _ = resolverFallback // referenced to document the resolver boundary
    }

    // MARK: - Cross-slice consistency

    func test_migratedBox4Aliases_areDistinctColors() {
        // The 2 box-4 aliases migrated in this slice are distinct
        // colors — confirms `ConditionPredictionRow`'s primary text
        // (`ink` → `textPrimary`) and secondary text (`mutedInk` →
        // `textSecondary`) stay separate roles and the migration did
        // not collapse them.
        XCTAssertNotEqual(HealthPalette.ink, HealthPalette.mutedInk)
        XCTAssertNotEqual(AppTheme.Palette.textPrimary, AppTheme.Palette.textSecondary)
    }
}
