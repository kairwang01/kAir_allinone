//
//  HealthPaletteTier3_5MigrationTests.swift
//  kAirTests
//
//  Pins the Tier 3.5 bounded slice (audit §8.1 box 4): the
//  `HealthPalette` §6-alias call sites *inside `RiskOrb`* (in
//  `DashboardSections.swift`) are migrated to the `AppTheme.Palette`
//  contract tokens they alias, and the one §7-out-of-scope
//  `HealthPalette.plum` reference is pinned as an intentional
//  exception.
//
//  Scope note: this slice is ONE component domain — the `RiskOrb`
//  struct (5 box-4 alias occurrences). It is the fifth box-4 slice;
//  prior slices: `HealthDashboardStyle.swift` (#40, 6),
//  `DataLibraryScreen` (#41, 23), `HealthAccessIntroScreen` (#42, 7),
//  `OverviewScreen` (#43, 6).
//
//  `RiskOrb` is a `private` struct — like `HeroCard` (PR #40), its
//  wiring is build-proven (the build compiling with the migrated
//  inline `AppTheme.Palette.*` references proves it; there is no
//  test-reachable `static`). So unlike the internal-struct slices,
//  this test file has NO component-wiring assertions — only the
//  visual-safety proof and the §7 exception pin, both of which are
//  provable without touching `RiskOrb`'s internals.
//
//  Two kinds of assertion:
//    1. Visual-safety proof — the 4 migrated box-4 aliases (`ink`,
//       `mutedInk`, `mint`, `cyan`) are `==` to their
//       `AppTheme.Palette` targets, so each inline migration in
//       `RiskOrb` is provably a pure rename with zero visual change.
//    2. §7 exception pin — `HealthPalette.plum` (used by the
//       `RiskOrb` AngularGradient) is NOT any box-4 alias target.
//

import XCTest
import SwiftUI
@testable import kAir

final class HealthPaletteTier3_5MigrationTests: XCTestCase {

    // MARK: - 1. Visual-safety proof (box-4 alias equivalence)

    func test_box4Aliases_migratedInThisSlice_equalTheirContractTokens() {
        // The 4 box-4 aliases consumed by `RiskOrb` are DEFINED as
        // their `AppTheme.Palette` targets, so swapping a call site
        // from the alias to the token is provably a pure rename —
        // zero rendered-color change. `RiskOrb` is `private`, so this
        // alias-equivalence proof IS the wiring guarantee: the build
        // compiles with `AppTheme.Palette.{textPrimary,textSecondary,
        // success,sky}` inline, and these assertions prove those are
        // the same colors the `HealthPalette` aliases resolved to.
        XCTAssertEqual(HealthPalette.ink, AppTheme.Palette.textPrimary)
        XCTAssertEqual(HealthPalette.mutedInk, AppTheme.Palette.textSecondary)
        XCTAssertEqual(HealthPalette.mint, AppTheme.Palette.success)
        XCTAssertEqual(HealthPalette.cyan, AppTheme.Palette.sky)
    }

    // MARK: - 2. §7 exception pin (HealthPalette.plum is NOT a box-4 alias)

    func test_healthPalettePlum_isIntentionalExceptionNotABox4Alias() {
        // `HealthPalette.plum` is a local `Color(0.43, 0.40, 0.50)`
        // with no `AppTheme.Palette` counterpart — `design-system-v1.md`
        // §7 out-of-scope, NOT a §6 box-4 alias. The `RiskOrb`
        // AngularGradient stop that uses it is left as a documented
        // exception: migrating it would require a new color token
        // (a contract change — forbidden in Tier 3) or substituting
        // a different contract color (a visual change — forbidden).
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
        XCTAssertFalse(
            box4Targets.contains(HealthPalette.plum),
            "HealthPalette.plum unexpectedly matches a box-4 alias target — "
                + "if a contract token now fits, it should be migrated, not kept as an exception"
        )
    }

    // MARK: - Cross-slice consistency

    func test_plumAndBox4Aliases_areDistinct() {
        // The §7 `plum` and the 4 box-4 aliases migrated in this
        // slice are mutually distinct colors — confirms `RiskOrb`'s
        // gradient (`success`, `sky`, `plum`) keeps three separate
        // stops, and the migration did not collapse any of them.
        XCTAssertNotEqual(HealthPalette.plum, HealthPalette.mint)
        XCTAssertNotEqual(HealthPalette.plum, HealthPalette.cyan)
        XCTAssertNotEqual(HealthPalette.plum, HealthPalette.ink)
        XCTAssertNotEqual(HealthPalette.plum, HealthPalette.mutedInk)
    }
}
