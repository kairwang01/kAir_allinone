//
//  DesignSystemBox7SevenStateCoverageTests.swift
//  kAirTests
//
//  Pins design-system-v1 §8.1 box 7 — "§4.4 component-state mapping
//  has at least one component implementing each of the seven states
//  end-to-end." `ActionCardShell` is that reference component.
//
//  Before this slice it covered 4 of the 7 §4.4 states (`default`,
//  `accepted`, `dismissed`, `loading`). This slice adds the remaining
//  three — `empty`, `error`, `disabled` — so the §4.4 table is proven
//  buildable end-to-end on one real component.
//
//  Scope note: this is box-7 IMPLEMENTATION coverage only. It does
//  NOT tick the §8.1 checklist and does NOT change design-system-v1's
//  `Status:` line — ratification is a separate, deliberate recheck PR.
//
//  Four kinds of assertion:
//    1. Enum completeness — `ActionCardState` is exactly the seven
//       §4.4 states, and the view is constructable in every one.
//    2. Per-state §4.4 mapping — each state's container opacity,
//       background overlay, border, headline color, header glyph +
//       color, and interactivity match its §4.4 row.
//    3. New-state distinctness — `empty` / `error` / `disabled` are
//       each provably NOT just an enum case: each renders or behaves
//       verifiably differently from `default`.
//    4. §4.4 invariants — the overlay-exclusivity note ("accepted and
//       error are the ONLY states that tint the background") holds,
//       and `disabled` owns a unique container dim.
//

import XCTest
import SwiftUI
@testable import kAir

@MainActor
final class DesignSystemBox7SevenStateCoverageTests: XCTestCase {

    // MARK: - 1. Enum completeness

    func test_actionCardState_isExactlyTheSevenSection44States() {
        XCTAssertEqual(ActionCardState.allCases.count, 7)
        XCTAssertEqual(
            Set(ActionCardState.allCases),
            [.default, .accepted, .dismissed, .loading, .empty, .error, .disabled]
        )
    }

    func test_everySection44State_canConstructActionCardShellEndToEnd() {
        // "end-to-end" per §8.1 box 7: the reference component must be
        // constructable in every one of the seven states. A `body`
        // that referenced a state helper missing a case would fail to
        // compile — so iterating `allCases` here is the build-proven
        // coverage guarantee.
        for state in ActionCardState.allCases {
            _ = ActionCardShell(object: RecommendationFixtures.placeRoute, state: state)
        }
    }

    // MARK: - 2. Per-state §4.4 mapping (one test per §4.4 row)

    func test_default_matchesSection44Row() {
        XCTAssertEqual(ActionCardShell.opacity(for: .default), 1.0)
        XCTAssertEqual(ActionCardShell.backgroundOverlayColor(for: .default), Color.clear)
        XCTAssertEqual(ActionCardShell.borderColor(for: .default), AppTheme.Palette.line)
        XCTAssertEqual(ActionCardShell.headlineColor(for: .default), AppTheme.Palette.textPrimary)
        XCTAssertEqual(ActionCardShell.headerForegroundColor(for: .default), AppTheme.Palette.accentStrong)
        XCTAssertEqual(ActionCardShell.headerGlyph(for: .default, objectGlyph: "star"), "star")
        XCTAssertFalse(ActionCardShell.isInteractionDisabled(for: .default))
    }

    func test_accepted_matchesSection44Row() {
        XCTAssertEqual(ActionCardShell.opacity(for: .accepted), 1.0)
        XCTAssertEqual(ActionCardShell.backgroundOverlayColor(for: .accepted), AppTheme.Palette.success.opacity(0.10))
        XCTAssertEqual(ActionCardShell.borderColor(for: .accepted), AppTheme.Palette.success.opacity(0.18))
        XCTAssertEqual(ActionCardShell.headlineColor(for: .accepted), AppTheme.Palette.textPrimary)
        XCTAssertEqual(ActionCardShell.headerForegroundColor(for: .accepted), AppTheme.Palette.accentStrong)
        XCTAssertFalse(ActionCardShell.isInteractionDisabled(for: .accepted))
    }

    func test_dismissed_matchesSection44Row() {
        XCTAssertEqual(ActionCardShell.opacity(for: .dismissed), 0.0)
        XCTAssertEqual(ActionCardShell.backgroundOverlayColor(for: .dismissed), Color.clear)
        XCTAssertEqual(ActionCardShell.borderColor(for: .dismissed), AppTheme.Palette.line)
        XCTAssertFalse(ActionCardShell.isInteractionDisabled(for: .dismissed))
    }

    func test_loading_matchesSection44Row() {
        XCTAssertEqual(ActionCardShell.opacity(for: .loading), 1.0)
        XCTAssertEqual(ActionCardShell.backgroundOverlayColor(for: .loading), Color.clear)
        XCTAssertEqual(ActionCardShell.borderColor(for: .loading), AppTheme.Palette.line)
        // §4.4 loading blocks taps while content resolves.
        XCTAssertTrue(ActionCardShell.isInteractionDisabled(for: .loading))
    }

    func test_empty_matchesSection44Row() {
        // §4.4 row 5 — NEW in box 7.
        XCTAssertEqual(ActionCardShell.opacity(for: .empty), 1.0)
        XCTAssertEqual(ActionCardShell.backgroundOverlayColor(for: .empty), Color.clear)
        XCTAssertEqual(ActionCardShell.borderColor(for: .empty), AppTheme.Palette.line)
        XCTAssertEqual(ActionCardShell.headlineColor(for: .empty), AppTheme.Palette.textSecondary)
        XCTAssertEqual(ActionCardShell.headerForegroundColor(for: .empty), AppTheme.Palette.textMuted)
        XCTAssertEqual(ActionCardShell.headerGlyph(for: .empty, objectGlyph: "star"), "tray")
        XCTAssertFalse(ActionCardShell.isInteractionDisabled(for: .empty))
    }

    func test_error_matchesSection44Row() {
        // §4.4 row 6 — NEW in box 7.
        XCTAssertEqual(ActionCardShell.opacity(for: .error), 1.0)
        XCTAssertEqual(ActionCardShell.backgroundOverlayColor(for: .error), AppTheme.Palette.danger.opacity(0.06))
        XCTAssertEqual(ActionCardShell.borderColor(for: .error), AppTheme.Palette.danger.opacity(0.18))
        XCTAssertEqual(ActionCardShell.headlineColor(for: .error), AppTheme.Palette.textPrimary)
        XCTAssertEqual(ActionCardShell.headerForegroundColor(for: .error), AppTheme.Palette.danger)
        XCTAssertEqual(ActionCardShell.headerGlyph(for: .error, objectGlyph: "star"), "exclamationmark.triangle")
        XCTAssertFalse(ActionCardShell.isInteractionDisabled(for: .error))
    }

    func test_disabled_matchesSection44Row() {
        // §4.4 row 7 — NEW in box 7.
        XCTAssertEqual(ActionCardShell.opacity(for: .disabled), 0.5)
        XCTAssertEqual(ActionCardShell.backgroundOverlayColor(for: .disabled), Color.clear)
        XCTAssertEqual(ActionCardShell.borderColor(for: .disabled), AppTheme.Palette.line)
        XCTAssertEqual(ActionCardShell.headlineColor(for: .disabled), AppTheme.Palette.textMuted)
        XCTAssertEqual(ActionCardShell.headerForegroundColor(for: .disabled), AppTheme.Palette.textMuted)
        XCTAssertEqual(ActionCardShell.headerGlyph(for: .disabled, objectGlyph: "star"), "star")
        // §4.4 disabled "does NOT animate hover / press / focus" — CTAs off.
        XCTAssertTrue(ActionCardShell.isInteractionDisabled(for: .disabled))
    }

    // MARK: - 3. New-state distinctness (the "not just an enum case" proof)

    func test_empty_rendersVerifiablyDifferentlyFromDefault() {
        // §4.4 empty differs from default on three rendered axes:
        // headline color, header glyph color, and the icon swap.
        XCTAssertNotEqual(
            ActionCardShell.headlineColor(for: .empty),
            ActionCardShell.headlineColor(for: .default)
        )
        XCTAssertNotEqual(
            ActionCardShell.headerForegroundColor(for: .empty),
            ActionCardShell.headerForegroundColor(for: .default)
        )
        XCTAssertNotEqual(
            ActionCardShell.headerGlyph(for: .empty, objectGlyph: "star"),
            ActionCardShell.headerGlyph(for: .default, objectGlyph: "star")
        )
    }

    func test_error_rendersVerifiablyDifferentlyFromDefault() {
        // §4.4 error differs from default on four rendered axes:
        // background overlay, border, header glyph, header glyph color.
        XCTAssertNotEqual(
            ActionCardShell.backgroundOverlayColor(for: .error),
            ActionCardShell.backgroundOverlayColor(for: .default)
        )
        XCTAssertNotEqual(
            ActionCardShell.borderColor(for: .error),
            ActionCardShell.borderColor(for: .default)
        )
        XCTAssertNotEqual(
            ActionCardShell.headerGlyph(for: .error, objectGlyph: "star"),
            ActionCardShell.headerGlyph(for: .default, objectGlyph: "star")
        )
        XCTAssertNotEqual(
            ActionCardShell.headerForegroundColor(for: .error),
            ActionCardShell.headerForegroundColor(for: .default)
        )
    }

    func test_disabled_rendersAndBehavesVerifiablyDifferentlyFromDefault() {
        // §4.4 disabled differs from default on rendered opacity and
        // headline color, AND on behavior: its CTAs are non-interactive.
        XCTAssertNotEqual(
            ActionCardShell.opacity(for: .disabled),
            ActionCardShell.opacity(for: .default)
        )
        XCTAssertNotEqual(
            ActionCardShell.headlineColor(for: .disabled),
            ActionCardShell.headlineColor(for: .default)
        )
        XCTAssertNotEqual(
            ActionCardShell.isInteractionDisabled(for: .disabled),
            ActionCardShell.isInteractionDisabled(for: .default)
        )
    }

    // MARK: - 4. §4.4 invariants

    func test_overlayExclusivity_onlyAcceptedAndErrorTintTheBackground() {
        // §4.4 note: "The `accepted` and `error` states are the only
        // states allowed to introduce a colored alpha overlay on top
        // of `surface`. No other state may tint the background."
        for state in ActionCardState.allCases {
            let overlay = ActionCardShell.backgroundOverlayColor(for: state)
            if state == .accepted || state == .error {
                XCTAssertNotEqual(overlay, Color.clear, "\(state) must tint the background")
            } else {
                XCTAssertEqual(overlay, Color.clear, "\(state) must NOT tint the background")
            }
        }
    }

    func test_disabledIsTheOnlyStateThatDimsTheStillVisibleContainer() {
        // §4.4: `disabled` container alpha is 0.5; `dismissed` fades to
        // 0 (removed, not dimmed); every other state is fully opaque.
        // Confirms `disabled`'s dim is a unique, identifiable value.
        XCTAssertEqual(ActionCardShell.opacity(for: .disabled), 0.5)
        for state in ActionCardState.allCases where state != .disabled && state != .dismissed {
            XCTAssertEqual(ActionCardShell.opacity(for: state), 1.0, "\(state) should be fully opaque")
        }
    }
}
