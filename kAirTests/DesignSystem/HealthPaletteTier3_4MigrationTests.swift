//
//  HealthPaletteTier3_4MigrationTests.swift
//  kAirTests
//
//  Pins the Tier 3.4 bounded slice (audit §8.1 box 4): the
//  `HealthPalette` §6-alias call sites *inside `OverviewScreen`*
//  (in `DashboardSections.swift`) are migrated to the
//  `AppTheme.Palette` contract tokens they alias, and the one
//  §7-out-of-scope `HealthPalette.sky` reference is pinned as an
//  intentional exception.
//
//  Scope note: this slice is ONE component domain — the
//  `OverviewScreen` struct (6 box-4 alias occurrences). It is the
//  fourth box-4 slice; prior slices were `HealthDashboardStyle.swift`
//  (PR #40, 6), `DataLibraryScreen` (PR #41, 23), and
//  `HealthAccessIntroScreen` (PR #42, 7). The remaining box-4 sites
//  in the other `DashboardSections.swift` structs and in
//  `ContentView.swift` are out of this PR — see the PR description.
//
//  This slice exercises the §6-vs-§7 NAMING COLLISION the audit
//  warned about:
//    - `HealthPalette.cyan` is the §6 box-4 alias of the FROZEN
//      `AppTheme.Palette.sky` role. It IS migrated (the "Latest
//      Night" MetricTile → `OverviewScreen.skyAccent`).
//    - `HealthPalette.sky` is the §7-out-of-scope LOCAL
//      `Color(0.54, 0.60, 0.68)` variant — a DIFFERENT color, no
//      contract counterpart. It is NOT migrated (the "Nights"
//      MetricTile keeps it, as a documented exception).
//  The collision pin below proves these two were handled
//  correctly and not conflated.
//
//  Three kinds of assertion:
//    1. Component wiring — `OverviewScreen` exposes 5 internal
//       `static`s for the contract colors it now uses.
//    2. Visual-safety proof — the 5 migrated box-4 aliases are `==`
//       to their `AppTheme.Palette` targets (pure rename).
//    3. §7 exception + collision pin — `HealthPalette.sky` (local)
//       is NOT `AppTheme.Palette.sky`, is NOT `HealthPalette.cyan`,
//       and is not any box-4 target; `OverviewScreen.skyAccent`
//       (the migrated "Latest Night" accent) IS the frozen role
//       and is NOT the local variant.
//

import XCTest
import SwiftUI
@testable import kAir

@MainActor
final class HealthPaletteTier3_4MigrationTests: XCTestCase {

    // MARK: - 1. Component wiring (OverviewScreen slice)

    func test_overviewScreen_inkUsesContractTextPrimaryToken() {
        XCTAssertEqual(OverviewScreen.inkColor, AppTheme.Palette.textPrimary)
    }

    func test_overviewScreen_mutedInkUsesContractTextSecondaryToken() {
        XCTAssertEqual(OverviewScreen.mutedInkColor, AppTheme.Palette.textSecondary)
    }

    func test_overviewScreen_successAccentUsesContractSuccessToken() {
        XCTAssertEqual(OverviewScreen.successAccent, AppTheme.Palette.success)
    }

    func test_overviewScreen_skyAccentUsesContractSkyToken() {
        XCTAssertEqual(OverviewScreen.skyAccent, AppTheme.Palette.sky)
    }

    func test_overviewScreen_warningAccentUsesContractWarningToken() {
        XCTAssertEqual(OverviewScreen.warningAccent, AppTheme.Palette.warning)
    }

    // MARK: - 2. Visual-safety proof (box-4 alias equivalence)

    func test_box4Aliases_migratedInThisSlice_equalTheirContractTokens() {
        // The 5 box-4 aliases consumed by `OverviewScreen` are
        // DEFINED as their `AppTheme.Palette` targets, so swapping a
        // call site from the alias to the token is provably a pure
        // rename — zero rendered-color change.
        XCTAssertEqual(HealthPalette.ink, AppTheme.Palette.textPrimary)
        XCTAssertEqual(HealthPalette.mutedInk, AppTheme.Palette.textSecondary)
        XCTAssertEqual(HealthPalette.mint, AppTheme.Palette.success)
        XCTAssertEqual(HealthPalette.cyan, AppTheme.Palette.sky)
        XCTAssertEqual(HealthPalette.amber, AppTheme.Palette.warning)
    }

    func test_overviewScreenStatics_matchTheBox4AliasTheyReplaced() {
        // Cross-check: each screen `static` equals the `HealthPalette`
        // alias the call sites previously used. Proves the migration
        // changed the *symbol* without changing the *value*.
        XCTAssertEqual(OverviewScreen.inkColor, HealthPalette.ink)
        XCTAssertEqual(OverviewScreen.mutedInkColor, HealthPalette.mutedInk)
        XCTAssertEqual(OverviewScreen.successAccent, HealthPalette.mint)
        XCTAssertEqual(OverviewScreen.skyAccent, HealthPalette.cyan)
        XCTAssertEqual(OverviewScreen.warningAccent, HealthPalette.amber)
    }

    // MARK: - 3. §7 exception + §6/§7 naming-collision pin

    func test_healthPaletteSky_localVariant_isNotTheFrozenSkyRole() {
        // `HealthPalette.sky` (the §7 local `Color(0.54,0.60,0.68)`
        // variant, used by the "Nights" MetricTile) is NOT the frozen
        // `AppTheme.Palette.sky` role. This is exactly why it cannot
        // be migrated — it has no contract counterpart.
        XCTAssertNotEqual(HealthPalette.sky, AppTheme.Palette.sky)
    }

    func test_box4Cyan_andLocalSky_areDistinctColors_collisionHandled() {
        // The §6/§7 naming-collision pin. `HealthPalette.cyan` (the
        // box-4 alias, migrated → `AppTheme.Palette.sky`) and
        // `HealthPalette.sky` (the §7 local variant, NOT migrated)
        // are DIFFERENT colors. If they were equal, the collision
        // would be harmless; because they differ, conflating them
        // would be a real visual bug. This proves the slice
        // migrated `cyan` and left the local `sky` alone, correctly.
        XCTAssertNotEqual(HealthPalette.cyan, HealthPalette.sky)
        // The migrated "Latest Night" accent resolves to the FROZEN
        // role, not the local variant.
        XCTAssertEqual(OverviewScreen.skyAccent, AppTheme.Palette.sky)
        XCTAssertNotEqual(OverviewScreen.skyAccent, HealthPalette.sky)
    }

    func test_healthPaletteSky_isNotAnyBox4AliasTarget() {
        // `HealthPalette.sky` (local) matches NONE of the
        // `AppTheme.Palette` colors the §6 box-4 aliases map to —
        // the factual basis for "no contract token fits this site,
        // so it's a documented exception, not a missed migration".
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
        XCTAssertFalse(box4Targets.contains(HealthPalette.sky))
    }
}
