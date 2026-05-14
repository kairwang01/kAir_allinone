//
//  HealthPaletteTier3MigrationTests.swift
//  kAirTests
//
//  Pins the Tier 3 bounded slice (audit §8.1 box 4): the
//  `HealthPalette` §6-alias call sites *inside `HealthDashboardStyle.swift`*
//  are migrated to the `AppTheme.Palette` contract tokens they
//  alias, and the §7-out-of-scope `HealthPalette.sky` default-param
//  references are pinned as intentional exceptions.
//
//  Scope note: this slice is ONE file (`HealthDashboardStyle.swift`).
//  The ~76 remaining box-4 call sites in `DashboardSections.swift`
//  and `ContentView.swift` are explicitly out of this PR — see the
//  PR description's inventory.
//
//  Three kinds of assertion:
//    1. Component wiring — each migrated helper component exposes an
//       internal `static` for the contract color it now uses; these
//       tests assert it equals the expected `AppTheme.Palette` token.
//    2. Visual-safety proof — the migrated box-4 aliases (`ink`,
//       `mutedInk`, `cardStroke`) are `==` to their `AppTheme.Palette`
//       targets, so the migration is a pure rename with zero visual
//       change.
//    3. §7 exception pin — `HealthPalette.sky` (the local variant)
//       is NOT equal to `AppTheme.Palette.sky`, which is exactly why
//       it cannot be migrated without a contract change or a visual
//       change. This pins the exception as intentional, not missed.
//

import XCTest
import SwiftUI
@testable import kAir

final class HealthPaletteTier3MigrationTests: XCTestCase {

    // MARK: - 1. Component wiring (HealthDashboardStyle.swift slice)

    func test_glassCard_strokeUsesContractLineToken() {
        XCTAssertEqual(GlassCard<EmptyView>.strokeColor, AppTheme.Palette.line)
    }

    func test_capsuleChip_inkUsesContractTextPrimaryToken() {
        XCTAssertEqual(CapsuleChip.inkColor, AppTheme.Palette.textPrimary)
    }

    func test_metricTile_titleUsesContractTextSecondaryToken() {
        XCTAssertEqual(MetricTile.titleColor, AppTheme.Palette.textSecondary)
    }

    func test_metricTile_valueUsesContractTextPrimaryToken() {
        XCTAssertEqual(MetricTile.valueColor, AppTheme.Palette.textPrimary)
    }

    func test_sectionEyebrow_titleUsesContractTextSecondaryToken() {
        XCTAssertEqual(SectionEyebrow.titleColor, AppTheme.Palette.textSecondary)
    }

    func test_sectionEyebrow_subtitleUsesContractTextPrimaryToken() {
        XCTAssertEqual(SectionEyebrow.subtitleColor, AppTheme.Palette.textPrimary)
    }

    // MARK: - 2. Visual-safety proof (box-4 alias equivalence)

    func test_box4Aliases_migratedInThisSlice_equalTheirContractTokens() {
        // The 3 box-4 aliases consumed by HealthDashboardStyle.swift
        // are DEFINED as their `AppTheme.Palette` targets, so swapping
        // a call site from the alias to the token is provably a pure
        // rename — zero rendered-color change. This is the safety
        // basis for the migration.
        XCTAssertEqual(HealthPalette.ink, AppTheme.Palette.textPrimary)
        XCTAssertEqual(HealthPalette.mutedInk, AppTheme.Palette.textSecondary)
        XCTAssertEqual(HealthPalette.cardStroke, AppTheme.Palette.line)
    }

    func test_migratedComponentStatics_matchTheBox4AliasTheyReplaced() {
        // Cross-check: each component `static` equals the
        // `HealthPalette` alias the call site previously used. Proves
        // the migration changed the *symbol* without changing the
        // *value*.
        XCTAssertEqual(GlassCard<EmptyView>.strokeColor, HealthPalette.cardStroke)
        XCTAssertEqual(CapsuleChip.inkColor, HealthPalette.ink)
        XCTAssertEqual(MetricTile.titleColor, HealthPalette.mutedInk)
        XCTAssertEqual(MetricTile.valueColor, HealthPalette.ink)
        XCTAssertEqual(SectionEyebrow.titleColor, HealthPalette.mutedInk)
        XCTAssertEqual(SectionEyebrow.subtitleColor, HealthPalette.ink)
    }

    // MARK: - 3. §7 exception pin (HealthPalette.sky is NOT a box-4 alias)

    func test_healthPaletteSky_isIntentionalExceptionNotABox4Alias() {
        // `HealthPalette.sky` is the local `Color(0.54, 0.60, 0.68)`
        // variant. `design-system-v1.md` §7 lists it as out-of-scope
        // — it is NOT a §6 box-4 alias. The proof: it is NOT equal to
        // `AppTheme.Palette.sky` (the frozen role). Because it has no
        // contract-token counterpart, the `CapsuleChip.color` and
        // `MetricTile.accent` default params that use it are left
        // as documented exceptions — migrating them would require a
        // contract change or a visual change, both forbidden in
        // Tier 3.
        XCTAssertNotEqual(
            HealthPalette.sky,
            AppTheme.Palette.sky,
            "HealthPalette.sky must remain distinct from the frozen Palette.sky role — "
                + "if they were equal it would be a migratable box-4 alias, not a §7 exception"
        )
    }

    func test_healthPaletteSky_isNotAnyBox4AliasTarget() {
        // Stronger pin: the local `HealthPalette.sky` matches NONE of
        // the `AppTheme.Palette` colors that the §6 box-4 aliases map
        // to. This is the factual basis for "no contract token fits
        // this site" — the reason it is an exception rather than a
        // migration.
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
            box4Targets.contains(HealthPalette.sky),
            "HealthPalette.sky unexpectedly matches a box-4 alias target — "
                + "if a contract token now fits, it should be migrated, not kept as an exception"
        )
    }
}
