//
//  HealthPaletteTier3_2MigrationTests.swift
//  kAirTests
//
//  Pins the Tier 3.2 bounded slice (audit §8.1 box 4): the
//  `HealthPalette` §6-alias call sites *inside `DataLibraryScreen`*
//  (in `DashboardSections.swift`) are migrated to the
//  `AppTheme.Palette` contract tokens they alias, and the
//  §7-out-of-scope `HealthPalette.sky` / `HealthPalette.plum`
//  references in that screen are pinned as intentional exceptions.
//
//  Scope note: this slice is ONE component domain — the
//  `DataLibraryScreen` struct (23 box-4 call sites). It is the
//  second box-4 slice; the first (`HealthDashboardStyle.swift`, 6
//  sites) shipped in PR #40 / `HealthPaletteTier3MigrationTests`.
//  The remaining box-4 sites in the other `DashboardSections.swift`
//  structs and in `ContentView.swift` are explicitly out of this
//  PR — see the PR description's running tally.
//
//  Three kinds of assertion (same shape as the Tier-3 slice tests):
//    1. Component wiring — `DataLibraryScreen` exposes 5 internal
//       `static`s for the contract colors it now uses; these tests
//       assert each equals the expected `AppTheme.Palette` token.
//    2. Visual-safety proof — the 5 migrated box-4 aliases (`ink`,
//       `mutedInk`, `mint`, `amber`, `coral`) are `==` to their
//       `AppTheme.Palette` targets, so the migration is a pure
//       rename with zero visual change.
//    3. §7 exception pin — `HealthPalette.plum` (used by the ECG
//       card fill) is NOT any box-4 alias target. (`HealthPalette.sky`,
//       used by the "Version" tile, is already pinned by
//       `HealthPaletteTier3MigrationTests` from PR #40.)
//

import XCTest
import SwiftUI
@testable import kAir

@MainActor
final class HealthPaletteTier3_2MigrationTests: XCTestCase {

    // MARK: - 1. Component wiring (DataLibraryScreen slice)

    func test_dataLibraryScreen_inkUsesContractTextPrimaryToken() {
        XCTAssertEqual(DataLibraryScreen.inkColor, AppTheme.Palette.textPrimary)
    }

    func test_dataLibraryScreen_mutedInkUsesContractTextSecondaryToken() {
        XCTAssertEqual(DataLibraryScreen.mutedInkColor, AppTheme.Palette.textSecondary)
    }

    func test_dataLibraryScreen_successAccentUsesContractSuccessToken() {
        XCTAssertEqual(DataLibraryScreen.successAccent, AppTheme.Palette.success)
    }

    func test_dataLibraryScreen_warningAccentUsesContractWarningToken() {
        XCTAssertEqual(DataLibraryScreen.warningAccent, AppTheme.Palette.warning)
    }

    func test_dataLibraryScreen_dangerAccentUsesContractDangerToken() {
        XCTAssertEqual(DataLibraryScreen.dangerAccent, AppTheme.Palette.danger)
    }

    // MARK: - 2. Visual-safety proof (box-4 alias equivalence)

    func test_box4Aliases_migratedInThisSlice_equalTheirContractTokens() {
        // The 5 box-4 aliases consumed by `DataLibraryScreen` are
        // DEFINED as their `AppTheme.Palette` targets, so swapping a
        // call site from the alias to the token is provably a pure
        // rename — zero rendered-color change.
        XCTAssertEqual(HealthPalette.ink, AppTheme.Palette.textPrimary)
        XCTAssertEqual(HealthPalette.mutedInk, AppTheme.Palette.textSecondary)
        XCTAssertEqual(HealthPalette.mint, AppTheme.Palette.success)
        XCTAssertEqual(HealthPalette.amber, AppTheme.Palette.warning)
        XCTAssertEqual(HealthPalette.coral, AppTheme.Palette.danger)
    }

    func test_dataLibraryScreenStatics_matchTheBox4AliasTheyReplaced() {
        // Cross-check: each screen `static` equals the `HealthPalette`
        // alias the call sites previously used. Proves the migration
        // changed the *symbol* without changing the *value*.
        XCTAssertEqual(DataLibraryScreen.inkColor, HealthPalette.ink)
        XCTAssertEqual(DataLibraryScreen.mutedInkColor, HealthPalette.mutedInk)
        XCTAssertEqual(DataLibraryScreen.successAccent, HealthPalette.mint)
        XCTAssertEqual(DataLibraryScreen.warningAccent, HealthPalette.amber)
        XCTAssertEqual(DataLibraryScreen.dangerAccent, HealthPalette.coral)
    }

    // MARK: - 3. §7 exception pin (HealthPalette.plum is NOT a box-4 alias)

    func test_healthPalettePlum_isIntentionalExceptionNotABox4Alias() {
        // `HealthPalette.plum` is a local `Color(0.43, 0.40, 0.50)`
        // with no `AppTheme.Palette` counterpart — `design-system-v1.md`
        // §7 out-of-scope, NOT a §6 box-4 alias. The `DataLibraryScreen`
        // ECG-card fill that uses it is left as a documented exception:
        // migrating it would require a new color token (a contract
        // change — forbidden in Tier 3) or substituting a different
        // contract color (a visual change — forbidden).
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
}
