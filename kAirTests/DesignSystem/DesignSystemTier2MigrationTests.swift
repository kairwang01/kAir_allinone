//
//  DesignSystemTier2MigrationTests.swift
//  kAirTests
//
//  Pins the Tier 2 token migration (audit §8.1 box 2 + box 3): every
//  component whose off-grid shadow or off-spec eyebrow tracking was
//  migrated in this PR now resolves to an `AppTheme.Elevation` /
//  `AppTheme.Typography` token, and no longer carries a local
//  shadow / tracking magic value as its source of truth.
//
//  Strategy:
//    - Each migrated, test-reachable component exposes an internal
//      `static` for the token it is wired to. These tests assert
//      that `static` equals the expected `AppTheme` token. The build
//      compiling with `.kAirElevation(...)` / `.kAirTypography(...)`
//      applied proves the modifier is used; the `static` makes the
//      *which token* assertion a unit test.
//    - `HeroCard` (in `DashboardSections.swift`) is a `private`
//      struct and is intentionally not covered here — its wiring is
//      build-proven only.
//    - `ComposerBar`'s mode label is an INTENTIONAL exception (not a
//      missed migration): it is `.caption2.weight(.bold)`, which
//      matches no §3.2 token. The exception is pinned by
//      `test_composerBar_modeLabel_isIntentionalExceptionNotMissedEyebrowMigration`
//      below so a future reviewer cannot mistake it for an
//      oversight.
//

import XCTest
import SwiftUI
@testable import kAir

@MainActor
final class DesignSystemTier2MigrationTests: XCTestCase {

    // MARK: - Box 2: off-grid shadows → AppTheme.Elevation

    func test_kAirSurface_usesRaisedElevationTier() {
        // §6: "Off-grid shadows in KAirSurface.hero, KAirSurface.sunken
        // … reroute to elevation.raised." All three styles now resolve
        // to `.raised` (the per-style `shadowColor` switch is gone).
        // `KAirSurface` is generic, so the static is referenced
        // through a concrete specialization.
        XCTAssertEqual(KAirSurface<EmptyView>.elevation, AppTheme.Elevation.raised)
    }

    func test_glassCard_usesRaisedElevationTier() {
        // §6: "Off-grid shadows in … GlassCard … reroute to
        // elevation.raised."
        XCTAssertEqual(GlassCard<EmptyView>.elevation, AppTheme.Elevation.raised)
    }

    func test_kAirActionCapsule_emphasizedUsesFloatingTier() {
        // Emphasized capsule was already α 0.08 / blur 14 / y 6 =
        // `.floating` exactly — an on-grid swap.
        XCTAssertEqual(
            KAirActionCapsule.emphasizedElevation,
            AppTheme.Elevation.floating
        )
    }

    func test_kAirActionCapsule_plainUsesRaisedTier() {
        // §6: "Off-grid shadows in … KAirActionCapsule non-emphasized
        // … reroute to elevation.raised."
        XCTAssertEqual(
            KAirActionCapsule.plainElevation,
            AppTheme.Elevation.raised
        )
    }

    func test_chatHomeView_surfacesUseRaisedElevationTier() {
        // The 3 previously off-grid (and §6-un-enumerated) ChatHomeView
        // shadows now resolve to `.raised` per §6's blanket rule.
        XCTAssertEqual(ChatHomeView.surfaceElevation, AppTheme.Elevation.raised)
    }

    // MARK: - Box 3: off-spec eyebrow tracking → AppTheme.Typography

    func test_kAirPageHeader_eyebrowUsesEyebrowTypographyToken() {
        // §6: "Eyebrow tracking 1.0 (existing in KAirPageHeader) —
        // Migrate to eyebrow token (1.2)."
        XCTAssertEqual(
            KAirPageHeader.eyebrowTypography,
            AppTheme.Typography.eyebrow
        )
    }

    func test_actionCardShell_headerLabelUsesEyebrowTypographyToken() {
        // The kind-label `Text` was `.caption.weight(.bold)` +
        // `.tracking(1.0)` — eyebrow font, off-spec tracking.
        XCTAssertEqual(
            ActionCardShell.headerLabelTypography,
            AppTheme.Typography.eyebrow
        )
    }

    func test_todayHomeView_sectionEyebrowsUseEyebrowTypographyToken() {
        // All 4 section labels ("TODAY" / "WHAT CHANGED" / "NEXT STEP"
        // / "RECENT CONTEXT") were `.caption.weight(.bold)` +
        // `.tracking(1.1)` — eyebrow font, off-spec tracking. They
        // share one token reference.
        XCTAssertEqual(
            TodayHomeView.eyebrowTypography,
            AppTheme.Typography.eyebrow
        )
    }

    // MARK: - Box 3 scope correction: ComposerBar is an intentional exception

    func test_composerBar_modeLabel_isIntentionalExceptionNotMissedEyebrowMigration() {
        // The composer mode label was listed under "eyebrow tracking"
        // by the audit (PR #37 §4) but is INTENTIONALLY excluded from
        // box-3's migration scope. This test pins WHY, so the
        // exception cannot be mistaken for an oversight in a future
        // review:
        //
        //   - The label font is `.caption2.weight(.bold)`.
        //   - `AppTheme.Typography.eyebrow` is `.caption.weight(.bold)`.
        //   - These are DIFFERENT fonts (`.caption2` ≠ `.caption`).
        //     Migrating the label to the `eyebrow` token would
        //     enlarge it — a visual redesign, forbidden by Tier 2.
        //
        // The mode label is a composer micro-emphasis label, not a
        // section eyebrow. Whether a dedicated micro-emphasis token
        // should exist is deferred to a future Typography semantic
        // audit (a contract decision, not a Tier-2 migration).

        // The label font is genuinely NOT the eyebrow token's font.
        XCTAssertNotEqual(
            ComposerBar.modeLabelFont,
            AppTheme.Typography.eyebrow.font,
            "ComposerBar mode label must remain distinct from the eyebrow token font"
        )
        // It is specifically `.caption2.weight(.bold)`.
        XCTAssertEqual(ComposerBar.modeLabelFont, Font.caption2.weight(.bold))

        // The label tracking is genuinely NOT the eyebrow token's
        // tracking (1.2) — it is the composer's own 0.8.
        XCTAssertNotEqual(
            ComposerBar.modeLabelTracking,
            AppTheme.Typography.eyebrow.tracking,
            "ComposerBar mode label tracking must remain distinct from the eyebrow token"
        )
        XCTAssertEqual(ComposerBar.modeLabelTracking, 0.8)
    }

    func test_composerBar_modeLabel_isNotAnyFrozenTypographyToken() {
        // Stronger pin: the composer mode label's (font, tracking)
        // pair matches NONE of the 9 frozen §3.2 tokens. This is the
        // factual basis for "no §3.2 token fits this site" — the
        // reason a 10th token would be required to migrate it, which
        // is a contract expansion out of Tier-2 scope.
        let labelToken = AppTheme.Typography.Token(
            font: ComposerBar.modeLabelFont,
            tracking: ComposerBar.modeLabelTracking
        )
        let frozen: Set<AppTheme.Typography.Token> = [
            AppTheme.Typography.display,
            AppTheme.Typography.sectionTitle,
            AppTheme.Typography.heading,
            AppTheme.Typography.actionLabel,
            AppTheme.Typography.body,
            AppTheme.Typography.meta,
            AppTheme.Typography.chip,
            AppTheme.Typography.eyebrow,
            AppTheme.Typography.micro,
        ]
        XCTAssertFalse(
            frozen.contains(labelToken),
            "ComposerBar mode label unexpectedly matches a frozen §3.2 token — "
                + "if a token now fits, it should be migrated, not kept as an exception"
        )
    }

    // MARK: - No new magic values introduced

    func test_migratedElevationTiers_areExactlyTheContractTiers() {
        // Every elevation `static` a migrated component exposes must
        // be one of the 3 frozen §3.5 tiers — never a fresh `Token(...)`
        // with off-grid numbers. (Pins "no new shadow magic values".)
        let frozen: Set<AppTheme.Elevation.Token> = [
            AppTheme.Elevation.flat,
            AppTheme.Elevation.raised,
            AppTheme.Elevation.floating,
        ]
        XCTAssertTrue(frozen.contains(KAirSurface<EmptyView>.elevation))
        XCTAssertTrue(frozen.contains(GlassCard<EmptyView>.elevation))
        XCTAssertTrue(frozen.contains(KAirActionCapsule.emphasizedElevation))
        XCTAssertTrue(frozen.contains(KAirActionCapsule.plainElevation))
        XCTAssertTrue(frozen.contains(ChatHomeView.surfaceElevation))
    }

    func test_migratedTypographyTokens_areExactlyTheContractTokens() {
        // Every typography `static` a migrated component exposes must
        // be one of the 9 frozen §3.2 tokens. (Pins "no new tracking
        // magic values".)
        let frozen: Set<AppTheme.Typography.Token> = [
            AppTheme.Typography.display,
            AppTheme.Typography.sectionTitle,
            AppTheme.Typography.heading,
            AppTheme.Typography.actionLabel,
            AppTheme.Typography.body,
            AppTheme.Typography.meta,
            AppTheme.Typography.chip,
            AppTheme.Typography.eyebrow,
            AppTheme.Typography.micro,
        ]
        XCTAssertTrue(frozen.contains(KAirPageHeader.eyebrowTypography))
        XCTAssertTrue(frozen.contains(ActionCardShell.headerLabelTypography))
        XCTAssertTrue(frozen.contains(TodayHomeView.eyebrowTypography))
    }
}
