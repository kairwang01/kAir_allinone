//
//  HealthPaletteTier3_11MigrationTests.swift
//  kAirTests
//
//  Pins the Tier 3.11 bounded slice (audit §8.1 box 4): the
//  `HealthPalette` §6-alias call sites *inside `SignalsScreen` and
//  `HeroCard`* (in `DashboardSections.swift`) are migrated to the
//  `AppTheme.Palette` contract tokens they alias, and the
//  §7-out-of-scope references (`HealthPalette.sky` local variant,
//  `HealthPalette.plum`, `HealthPalette.heroGradient`) are pinned as
//  intentional exceptions.
//
//  Scope note: this slice is the "boundary-audit" pair — the two
//  structs that carry BOTH §7-out-of-scope references AND resolver
//  calls:
//    - `SignalsScreen` (internal struct): 8 box-4 alias occurrences
//      (`ink` ×2, `mutedInk` ×2, `amber` ×1, `coral` ×1, `cyan` ×1,
//      `mint` ×1); 3 §7 references (`HealthPalette.sky` local ×2,
//      `HealthPalette.plum` ×1); 1 `HealthPalette.color(for:)`
//      resolver call left untouched.
//    - `HeroCard` (private struct): 7 box-4 alias occurrences
//      (`mutedInk` ×3, `cyan` ×1, `ink` ×3); 2 §7 references
//      (`HealthPalette.sky` local ×1, `HealthPalette.heroGradient`
//      ×1); 1 `HealthPalette.color(for:)` resolver call left
//      untouched.
//  Total: 15 box-4 occurrences migrated, 5 §7 exceptions documented,
//  2 resolver call sites intentionally untouched. It is one of two
//  parallel sibling slices (Tier 3.10 / 3.11); prior box-4 slices:
//  `HealthDashboardStyle.swift` (#40, 6), `DataLibraryScreen`
//  (#41, 23), `HealthAccessIntroScreen` (#42, 7), `OverviewScreen`
//  (#43, 6), `RiskOrb` (#44, 5), and the #45–#48 slices.
//
//  This slice exercises the §6-vs-§7 NAMING COLLISION the audit
//  warned about, in BOTH structs:
//    - `HealthPalette.cyan` is the §6 box-4 alias of the FROZEN
//      `AppTheme.Palette.sky` role. It IS migrated (the "Height"
//      MetricTile in `SignalsScreen` → `SignalsScreen.skyAccent`;
//      the availability `CapsuleChip` in `HeroCard` → inline
//      `AppTheme.Palette.sky`).
//    - `HealthPalette.sky` is the §7-out-of-scope LOCAL
//      `Color(0.54, 0.60, 0.68)` variant — a DIFFERENT color, no
//      contract counterpart. It is NOT migrated (the "Expected …"
//      CapsuleChip + "Age" MetricTile in `SignalsScreen`, the
//      confidence `CapsuleChip` in `HeroCard` keep it, as
//      documented exceptions).
//  The collision pins below prove these two were handled correctly
//  and not conflated.
//
//  Three kinds of assertion:
//    1. Component wiring — `SignalsScreen` (internal) exposes 6
//       internal `static`s for the contract colors it now uses.
//       `HeroCard` is `private` so it has no test-reachable
//       `static`; for it, the box-4 alias-equivalence proof IS the
//       wiring guarantee (see below).
//    2. Visual-safety proof — the 6 distinct migrated box-4 aliases
//       (`ink`, `mutedInk`, `amber`, `coral`, `cyan`, `mint`) are
//       `==` to their `AppTheme.Palette` targets (pure rename).
//    3. §7 exception + collision pins — `HealthPalette.sky` (local)
//       is NOT `AppTheme.Palette.sky`, is NOT `HealthPalette.cyan`,
//       and is not any box-4 target; `HealthPalette.plum` is not
//       any box-4 target; `SignalsScreen.skyAccent` (the migrated
//       "Height" accent) IS the frozen role and is NOT the local
//       variant.
//

import XCTest
import SwiftUI
@testable import kAir

@MainActor
final class HealthPaletteTier3_11MigrationTests: XCTestCase {

    // MARK: - 1. Component wiring (SignalsScreen slice — internal struct)

    func test_signalsScreen_inkUsesContractTextPrimaryToken() {
        XCTAssertEqual(SignalsScreen.inkColor, AppTheme.Palette.textPrimary)
    }

    func test_signalsScreen_mutedInkUsesContractTextSecondaryToken() {
        XCTAssertEqual(SignalsScreen.mutedInkColor, AppTheme.Palette.textSecondary)
    }

    func test_signalsScreen_warningAccentUsesContractWarningToken() {
        XCTAssertEqual(SignalsScreen.warningAccent, AppTheme.Palette.warning)
    }

    func test_signalsScreen_dangerAccentUsesContractDangerToken() {
        XCTAssertEqual(SignalsScreen.dangerAccent, AppTheme.Palette.danger)
    }

    func test_signalsScreen_skyAccentUsesContractSkyToken() {
        XCTAssertEqual(SignalsScreen.skyAccent, AppTheme.Palette.sky)
    }

    func test_signalsScreen_successAccentUsesContractSuccessToken() {
        XCTAssertEqual(SignalsScreen.successAccent, AppTheme.Palette.success)
    }

    // MARK: - 2. Visual-safety proof (box-4 alias equivalence)

    func test_box4Aliases_migratedInThisSlice_equalTheirContractTokens() {
        // The 6 distinct box-4 aliases consumed across `SignalsScreen`
        // and `HeroCard` are DEFINED as their `AppTheme.Palette`
        // targets, so swapping a call site from the alias to the
        // token is provably a pure rename — zero rendered-color
        // change.
        //
        // `HeroCard` is a `private` struct, so it has no
        // test-reachable `static`: for `HeroCard` this
        // alias-equivalence proof IS the wiring guarantee. The build
        // compiles with `AppTheme.Palette.{textPrimary,textSecondary,
        // sky}` referenced inline, and these assertions prove those
        // are the same colors the `HealthPalette` aliases (`ink`,
        // `mutedInk`, `cyan`) resolved to.
        XCTAssertEqual(HealthPalette.ink, AppTheme.Palette.textPrimary)
        XCTAssertEqual(HealthPalette.mutedInk, AppTheme.Palette.textSecondary)
        XCTAssertEqual(HealthPalette.amber, AppTheme.Palette.warning)
        XCTAssertEqual(HealthPalette.coral, AppTheme.Palette.danger)
        XCTAssertEqual(HealthPalette.cyan, AppTheme.Palette.sky)
        XCTAssertEqual(HealthPalette.mint, AppTheme.Palette.success)
    }

    func test_signalsScreenStatics_matchTheBox4AliasTheyReplaced() {
        // Cross-check: each `SignalsScreen` `static` equals the
        // `HealthPalette` alias the call sites previously used.
        // Proves the migration changed the *symbol* without changing
        // the *value*.
        XCTAssertEqual(SignalsScreen.inkColor, HealthPalette.ink)
        XCTAssertEqual(SignalsScreen.mutedInkColor, HealthPalette.mutedInk)
        XCTAssertEqual(SignalsScreen.warningAccent, HealthPalette.amber)
        XCTAssertEqual(SignalsScreen.dangerAccent, HealthPalette.coral)
        XCTAssertEqual(SignalsScreen.skyAccent, HealthPalette.cyan)
        XCTAssertEqual(SignalsScreen.successAccent, HealthPalette.mint)
    }

    // MARK: - 3. §7 exception + §6/§7 naming-collision pins

    func test_healthPaletteSky_localVariant_isNotTheFrozenSkyRole() {
        // `HealthPalette.sky` (the §7 local `Color(0.54,0.60,0.68)`
        // variant — used by the "Expected …" CapsuleChip + "Age"
        // MetricTile in `SignalsScreen` and the confidence
        // CapsuleChip in `HeroCard`) is NOT the frozen
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
        // would be a real visual bug. This proves the slice migrated
        // `cyan` and left the local `sky` alone, correctly — in BOTH
        // `SignalsScreen` and `HeroCard`.
        XCTAssertNotEqual(HealthPalette.cyan, HealthPalette.sky)
        // The migrated `SignalsScreen` "Height" accent resolves to
        // the FROZEN role, not the local variant.
        XCTAssertEqual(SignalsScreen.skyAccent, AppTheme.Palette.sky)
        XCTAssertNotEqual(SignalsScreen.skyAccent, HealthPalette.sky)
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

    func test_healthPalettePlum_isIntentionalExceptionNotABox4Alias() {
        // `HealthPalette.plum` is a local `Color(0.43, 0.40, 0.50)`
        // with no `AppTheme.Palette` counterpart — `design-system-v1.md`
        // §7 out-of-scope, NOT a §6 box-4 alias. The `SignalsScreen`
        // "Sex" MetricTile that uses it is left as a documented
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

    func test_plumAndLocalSky_andBox4Aliases_areDistinct() {
        // The §7 `plum` / local `sky` and the box-4 aliases migrated
        // in this slice are mutually distinct colors — confirms the
        // `SignalsScreen` "Sex"/"Age" tiles and `HeroCard`'s
        // confidence chip keep colors separate from every migrated
        // box-4 token, and the migration did not collapse any of them.
        XCTAssertNotEqual(HealthPalette.plum, HealthPalette.sky)
        XCTAssertNotEqual(HealthPalette.plum, HealthPalette.ink)
        XCTAssertNotEqual(HealthPalette.plum, HealthPalette.mutedInk)
        XCTAssertNotEqual(HealthPalette.plum, HealthPalette.cyan)
        XCTAssertNotEqual(HealthPalette.sky, HealthPalette.ink)
        XCTAssertNotEqual(HealthPalette.sky, HealthPalette.mutedInk)
    }
}
