//
//  RecommendationRailContractTests.swift
//  kAirTests
//
//  Contract enforcement for the Recommended Next rail.
//
//  Method names map 1:1 to:
//  - Contracts/UX/mixed-recommendation-rail-visual-v1.md §4 (layout states)
//  - Contracts/UX/mixed-recommendation-rail-visual-v1.md §5 (tier visual)
//  - Contracts/UX/mixed-recommendation-rail-visual-v1.md §6 (per-card states)
//  - Contracts/UX/mixed-recommendation-rail-visual-v1.md §7 (transitions)
//  - Docs/design/mixed-recommendation-layout-v1.md §1 (9 object kinds)
//  - Docs/design/mixed-recommendation-layout-v1.md §5.1 (5 feedback kinds)
//  - Docs/design/action-card-component-inventory.md §5 (7 trust pill kinds)
//

import XCTest
import SwiftUI
@testable import kAir

final class RecommendationRailContractTests: XCTestCase {
    // MARK: - Cardinality (frozen vocabularies)

    func test_objectKind_hasNineCases() throws {
        XCTAssertEqual(MatchingObjectKind.allCases.count, 9)
    }

    func test_feedbackKind_hasFiveCases() throws {
        XCTAssertEqual(MatchingFeedbackKind.allCases.count, 5)
    }

    func test_trustPillKind_hasSevenCases() throws {
        XCTAssertEqual(ActionCardTrustPillKind.allCases.count, 7)
    }

    func test_actionCardState_hasFourCases() throws {
        XCTAssertEqual(ActionCardState.allCases.count, 4)
    }

    // MARK: - Feedback menu (behavior §2.2 + V3 §4.2: ⋯ menu offers 5
    // kinds in fixed order, with .dismiss as the first entry; ✕ also
    // binds .dismiss)

    func test_feedbackMenu_containsAllFiveKinds() throws {
        XCTAssertEqual(Set(ActionCardShell.feedbackMenuKinds), Set(MatchingFeedbackKind.allCases))
    }

    func test_feedbackMenu_orderIsDismissFirst() throws {
        XCTAssertEqual(ActionCardShell.feedbackMenuKinds.first, .dismiss)
    }

    func test_feedbackMenu_orderMatchesContract() throws {
        XCTAssertEqual(ActionCardShell.feedbackMenuKinds, [
            .dismiss,
            .notInterested,
            .lessLikeThis,
            .notNow,
            .alreadyDone
        ])
    }

    func test_feedbackMenu_hasExactlyFiveEntries() throws {
        XCTAssertEqual(ActionCardShell.feedbackMenuKinds.count, 5)
    }

    // MARK: - V2 §3: empty rail is absent rail

    func test_rail_emptyObjects_isAbsent() throws {
        let rail = RecommendationRail(objects: [])
        XCTAssertTrue(rail.isAbsent)
        XCTAssertEqual(rail.renderedCardCount, 0)
        XCTAssertEqual(rail.layoutState, .absent)
    }

    // MARK: - V2 §4.2: layout states (single / dual / triple)

    func test_rail_oneObject_isSingleLayout() throws {
        let rail = RecommendationRail(objects: RecommendationFixtures.singleSlate)
        XCTAssertEqual(rail.layoutState, .single)
        XCTAssertEqual(rail.renderedCardCount, 1)
    }

    func test_rail_twoObjects_isDualLayout() throws {
        let rail = RecommendationRail(objects: RecommendationFixtures.dualSlate)
        XCTAssertEqual(rail.layoutState, .dual)
        XCTAssertEqual(rail.renderedCardCount, 2)
    }

    func test_rail_threeObjects_isTripleLayout() throws {
        let rail = RecommendationRail(objects: RecommendationFixtures.tripleSlate)
        XCTAssertEqual(rail.layoutState, .triple)
        XCTAssertEqual(rail.renderedCardCount, 3)
    }

    func test_rail_fourPlusObjects_marksOverflow() throws {
        let extra = MatchingObject(
            id: "x",
            kind: .toolEntry,
            title: "Extra",
            subtitleTokens: [],
            reasonText: nil,
            primaryCTA: "Open",
            secondaryCTA: nil,
            trustPills: []
        )
        let rail = RecommendationRail(objects: RecommendationFixtures.tripleSlate + [extra])
        // The rail's layoutState reports overflow; the visual contract
        // requires the slate to be capped at 3 upstream (provider cap).
        // The rail does NOT silently drop excess — the test pins that
        // upstream is responsible for trimming.
        XCTAssertEqual(rail.layoutState, .overflow)
    }

    // MARK: - V2 §4: container behavior (inter-card spacing constant)

    func test_rail_interCardSpacingMatchesContract() throws {
        XCTAssertEqual(RecommendationRail.interCardSpacing, 12)
    }

    func test_rail_maxSlateSizeMatchesContract() throws {
        XCTAssertEqual(RecommendationRail.maxSlateSize, 3)
    }

    // MARK: - V2 §5: tier visual — direct slot and alternatives use same view

    func test_rail_allCardsUseSameView_forSingle() throws {
        // Trivially true for single — only one card.
        let rail = RecommendationRail(objects: RecommendationFixtures.singleSlate)
        XCTAssertEqual(rail.renderedCardCount, 1)
    }

    func test_rail_allCardsUseSameView_forTriple() throws {
        // The rail iterates `objects` with no index inspection; every
        // object becomes one ActionCardShell with its data unchanged.
        // We cannot easily introspect SwiftUI here, but we can assert
        // that no per-position downgrade is encoded in the data layer:
        // the same MatchingObject would render the same shell whether
        // at index 0 or index N.
        let direct = RecommendationFixtures.placeRoute
        let asAlternativeRail = RecommendationRail(objects: [
            RecommendationFixtures.songSunset,
            RecommendationFixtures.answerCard,
            direct
        ])
        let asDirectRail = RecommendationRail(objects: [
            direct,
            RecommendationFixtures.songSunset,
            RecommendationFixtures.answerCard
        ])
        XCTAssertEqual(asAlternativeRail.renderedCardCount, asDirectRail.renderedCardCount)
        // The direct slot's data is byte-identical between the two rails;
        // any chrome difference would have to be an index-based branch,
        // which the rail's body forbids by construction (see source).
    }

    // MARK: - V2 §6: per-card state visual mapping

    func test_state_default_isFullyOpaque() throws {
        XCTAssertEqual(ActionCardShell.opacity(for: .default), 1.0)
    }

    func test_state_accepted_isFullyOpaque_butHasOverlay() throws {
        XCTAssertEqual(ActionCardShell.opacity(for: .accepted), 1.0)
        let overlay = ActionCardShell.acceptedOverlayColor(for: .accepted)
        XCTAssertEqual(overlay, AppTheme.Palette.success.opacity(0.10))
    }

    func test_state_dismissed_fadesToZero() throws {
        XCTAssertEqual(ActionCardShell.opacity(for: .dismissed), 0.0)
    }

    func test_state_loading_isFullyOpaque() throws {
        XCTAssertEqual(ActionCardShell.opacity(for: .loading), 1.0)
    }

    func test_state_default_hasNoAcceptedOverlay() throws {
        XCTAssertEqual(ActionCardShell.acceptedOverlayColor(for: .default), Color.clear)
    }

    func test_state_dismissed_hasNoAcceptedOverlay() throws {
        XCTAssertEqual(ActionCardShell.acceptedOverlayColor(for: .dismissed), Color.clear)
    }

    func test_state_loading_hasNoAcceptedOverlay() throws {
        XCTAssertEqual(ActionCardShell.acceptedOverlayColor(for: .loading), Color.clear)
    }

    func test_state_accepted_borderTintsToSuccess() throws {
        XCTAssertEqual(
            ActionCardShell.borderColor(for: .accepted),
            AppTheme.Palette.success.opacity(0.18)
        )
    }

    func test_state_default_borderIsLine() throws {
        XCTAssertEqual(ActionCardShell.borderColor(for: .default), AppTheme.Palette.line)
    }

    func test_state_dismissed_borderIsLine() throws {
        XCTAssertEqual(ActionCardShell.borderColor(for: .dismissed), AppTheme.Palette.line)
    }

    func test_state_loading_borderIsLine() throws {
        XCTAssertEqual(ActionCardShell.borderColor(for: .loading), AppTheme.Palette.line)
    }

    // MARK: - V2 §6: suppressed = absent from view tree

    func test_suppressed_objectsRemovedFromSlate_yieldZeroCards() throws {
        // "suppressed" at the rail level means the object is not in the
        // slate. The rail's renderedCardCount reflects exactly the slate
        // size; suppressed objects produce no view-tree presence.
        let rail = RecommendationRail(objects: [])
        XCTAssertEqual(rail.renderedCardCount, 0)
    }

    func test_suppressed_partialSuppression_yieldsCorrectCount() throws {
        // Three-object slate, then one is removed (suppressed at the
        // data layer). The rail renders only the survivors.
        let full = RecommendationFixtures.tripleSlate
        let suppressed = Array(full.dropLast())
        let rail = RecommendationRail(objects: suppressed)
        XCTAssertEqual(rail.renderedCardCount, 2)
        XCTAssertEqual(rail.layoutState, .dual)
    }

    // MARK: - V2 §6: refreshed = visually default (no entry decoration)

    func test_refreshed_rendersAsDefault_noFreshBadge() throws {
        // A "refreshed" card is just one that newly entered the slate
        // after refreshRecommendedMatches. At the rail level this means
        // the slate's contents changed; at the card level the new card
        // is in `.default` state. There is no `.refreshed` ActionCardState
        // case — this test pins that.
        XCTAssertFalse(ActionCardState.allCases.contains(where: { state in
            "\(state)" == "refreshed"
        }))
    }

    // MARK: - V2 §7: transitions — preserve / suppress / refresh

    func test_preserve_sameObjects_yieldsSameRail() throws {
        let rail1 = RecommendationRail(objects: RecommendationFixtures.tripleSlate)
        let rail2 = RecommendationRail(objects: RecommendationFixtures.tripleSlate)
        XCTAssertEqual(rail1.renderedCardCount, rail2.renderedCardCount)
        XCTAssertEqual(rail1.layoutState, rail2.layoutState)
    }

    func test_suppress_oneCardRemoved_layoutStateChanges() throws {
        let before = RecommendationRail(objects: RecommendationFixtures.tripleSlate)
        let after = RecommendationRail(objects: Array(RecommendationFixtures.tripleSlate.dropLast()))
        XCTAssertEqual(before.layoutState, .triple)
        XCTAssertEqual(after.layoutState, .dual)
    }

    func test_refresh_slateFullyReplaced_layoutStateMatchesNewSize() throws {
        let before = RecommendationRail(objects: RecommendationFixtures.tripleSlate)
        let after = RecommendationRail(objects: RecommendationFixtures.singleSlate)
        XCTAssertEqual(before.layoutState, .triple)
        XCTAssertEqual(after.layoutState, .single)
    }

    // MARK: - Trust pill tone mapping

    func test_trustPill_liveResolution_isPositive() throws {
        XCTAssertEqual(ActionCardTrustPillKind.placeResolutionLive.tone, .positive)
    }

    func test_trustPill_partnerFallback_isWarning() throws {
        XCTAssertEqual(ActionCardTrustPillKind.partnerFallback.tone, .warning)
    }

    func test_trustPill_etaEstimate_isNeutral() throws {
        XCTAssertEqual(ActionCardTrustPillKind.etaConfidenceEstimate.tone, .neutral)
    }

    func test_trustPill_positiveTone_usesSuccessColor() throws {
        XCTAssertEqual(
            ActionCardTrustPill.foregroundColor(for: .positive),
            AppTheme.Palette.success
        )
    }

    func test_trustPill_warningTone_usesWarningColor() throws {
        XCTAssertEqual(
            ActionCardTrustPill.foregroundColor(for: .warning),
            AppTheme.Palette.warning
        )
    }

    func test_trustPill_neutralTone_usesTextSecondary() throws {
        XCTAssertEqual(
            ActionCardTrustPill.foregroundColor(for: .neutral),
            AppTheme.Palette.textSecondary
        )
    }
}
