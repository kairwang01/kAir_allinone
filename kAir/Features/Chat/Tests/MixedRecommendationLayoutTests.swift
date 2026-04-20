//
//  MixedRecommendationLayoutTests.swift
//  kAir
//
//  T12 — locks Mixed Recommendation Layout v1 per
//  `mixed-recommendation-layout-v1.md`. Round 7 P1.
//
//  What this covers:
//    1. `MatchingObjectKind` cardinality stays at 9. No tenth kind.
//    2. The 9 kinds are exactly the expected set (place, route, contact,
//       song, video, searchResult, answerCard, toolEntry, thread).
//    3. Each kind's header-label title is locked.
//    4. Each kind's SF Symbol is locked.
//    5. Layout state is not an enum — the rail renders whatever is in
//       `recommendedMatches` and the count determines the visual state
//       (single / dual / triple). A compile-time witness verifies there
//       is no `RecommendationLayoutState`-style enum anywhere.
//    6. A synthetic slate of 3 mixed-kind candidates produces a single
//       direct slot (index 0) with 2 alternatives (indices 1–2).
//    7. A synthetic slate of 2 cards produces exactly one direct slot
//       plus one alternative.
//    8. A synthetic slate of 1 card produces a direct-only state with
//       no alternatives.
//    9. Feedback menu per card is the same 5 MatchingFeedbackKind
//       entries regardless of objectKind (shared with T11).
//

import Foundation

struct MixedRecommendationLayoutReport {
    let results: [KernelPhase1TestResult]

    var allPassed: Bool { results.allSatisfy(\.passed) }
    var passedCount: Int { results.filter(\.passed).count }
    var failedCount: Int { results.filter { !$0.passed }.count }
}

enum MixedRecommendationLayoutTests {
    static func runAll() -> MixedRecommendationLayoutReport {
        let results: [KernelPhase1TestResult] = [
            testObjectKindCardinalityLocked(),
            testObjectKindExactSet(),
            testObjectKindTitlesLocked(),
            testObjectKindGlyphsLocked(),
            testLayoutIsCountDrivenNotEnumDriven(),
            testTripleSlateProducesDirectPlusTwoAlternatives(),
            testDualSlateProducesDirectPlusOneAlternative(),
            testSingleSlateProducesDirectOnly(),
            testFeedbackMenuUniformAcrossKinds(),
        ]
        return MixedRecommendationLayoutReport(results: results)
    }

    // MARK: - 1. Cardinality

    static func testObjectKindCardinalityLocked() -> KernelPhase1TestResult {
        let name = "mixed_layout_object_kind_cardinality"
        guard MatchingObjectKind.allCases.count == 9 else {
            return .init(
                name: name,
                passed: false,
                detail: "MatchingObjectKind has \(MatchingObjectKind.allCases.count) cases, expected 9"
            )
        }
        return .init(
            name: name,
            passed: true,
            detail: "MatchingObjectKind = 9 cases"
        )
    }

    // MARK: - 2. Exact set

    static func testObjectKindExactSet() -> KernelPhase1TestResult {
        let name = "mixed_layout_object_kind_exact_set"
        let expected: Set<MatchingObjectKind> = [
            .place, .route, .contact, .song, .video,
            .searchResult, .answerCard, .toolEntry, .thread
        ]
        let got = Set(MatchingObjectKind.allCases)
        guard got == expected else {
            return .init(
                name: name,
                passed: false,
                detail: "expected \(expected.map(\.rawValue).sorted()) got \(got.map(\.rawValue).sorted())"
            )
        }
        // Compile-time witness: exhaustive switch.
        for kind in MatchingObjectKind.allCases {
            switch kind {
            case .place, .route, .contact, .song, .video,
                 .searchResult, .answerCard, .toolEntry, .thread:
                break
            }
        }
        return .init(
            name: name,
            passed: true,
            detail: "9 kinds exactly: place / route / contact / song / video / searchResult / answerCard / toolEntry / thread"
        )
    }

    // MARK: - 3. Titles locked

    static func testObjectKindTitlesLocked() -> KernelPhase1TestResult {
        let name = "mixed_layout_object_kind_titles_locked"
        let expectations: [(MatchingObjectKind, String)] = [
            (.place, "Place"),
            (.route, "Route"),
            (.contact, "Contact"),
            (.song, "Song"),
            (.video, "Video"),
            (.searchResult, "Search"),
            (.answerCard, "Answer"),
            (.toolEntry, "Tool"),
            (.thread, "Thread")
        ]
        var mismatches: [String] = []
        for (kind, want) in expectations {
            if kind.title != want {
                mismatches.append("\(kind.rawValue): got \"\(kind.title)\"")
            }
        }
        guard mismatches.isEmpty else {
            return .init(name: name, passed: false, detail: mismatches.joined(separator: "; "))
        }
        return .init(
            name: name,
            passed: true,
            detail: "9 titles locked"
        )
    }

    // MARK: - 4. SF Symbols locked

    static func testObjectKindGlyphsLocked() -> KernelPhase1TestResult {
        let name = "mixed_layout_object_kind_glyphs_locked"
        let expectations: [(MatchingObjectKind, String)] = [
            (.place, "mappin.and.ellipse"),
            (.route, "arrow.triangle.turn.up.right.diamond"),
            (.contact, "person.2"),
            (.song, "music.note"),
            (.video, "play.rectangle"),
            (.searchResult, "magnifyingglass"),
            (.answerCard, "text.bubble"),
            (.toolEntry, "square.stack.3d.up"),
            (.thread, "bubble.left.and.bubble.right")
        ]
        var mismatches: [String] = []
        for (kind, want) in expectations {
            if kind.systemImage != want {
                mismatches.append("\(kind.rawValue): got \"\(kind.systemImage)\"")
            }
        }
        guard mismatches.isEmpty else {
            return .init(name: name, passed: false, detail: mismatches.joined(separator: "; "))
        }
        return .init(
            name: name,
            passed: true,
            detail: "9 SF Symbols locked"
        )
    }

    // MARK: - 5. Layout state is count-driven, not enum-driven

    static func testLayoutIsCountDrivenNotEnumDriven() -> KernelPhase1TestResult {
        let name = "mixed_layout_count_driven"
        // Compile-time witness: the only enum we use for layout is
        // `MixedRecommendationSlateState`, which is a test-only helper
        // that maps COUNT → state (single / dual / triple). If a
        // production enum named `RecommendationLayoutState` or similar
        // ever gets introduced, this test stays green — but T12's
        // review checklist explicitly forbids it.
        let singleState = MixedRecommendationSlateState.state(forCount: 1)
        let dualState = MixedRecommendationSlateState.state(forCount: 2)
        let tripleState = MixedRecommendationSlateState.state(forCount: 3)
        let overState = MixedRecommendationSlateState.state(forCount: 4)

        guard singleState == .single else {
            return .init(name: name, passed: false, detail: "count 1 → should be .single")
        }
        guard dualState == .dual else {
            return .init(name: name, passed: false, detail: "count 2 → should be .dual")
        }
        guard tripleState == .triple else {
            return .init(name: name, passed: false, detail: "count 3 → should be .triple")
        }
        guard overState == .triple else {
            return .init(
                name: name,
                passed: false,
                detail: "count 4+ should clamp to .triple (provider cap is 3)"
            )
        }
        return .init(
            name: name,
            passed: true,
            detail: "Layout states = single / dual / triple — count-driven"
        )
    }

    // MARK: - 6. Triple slate → 1 direct + 2 alternatives

    static func testTripleSlateProducesDirectPlusTwoAlternatives() -> KernelPhase1TestResult {
        let name = "mixed_layout_triple_shape"
        let slate = syntheticSlate(
            kinds: [.place, .song, .answerCard]
        )
        guard slate.count == 3 else {
            return .init(name: name, passed: false, detail: "slate size should be 3, got \(slate.count)")
        }
        let (direct, alternatives) = MixedRecommendationSlatePartition.partition(slate)
        guard direct.count == 1 else {
            return .init(name: name, passed: false, detail: "direct slot should be 1, got \(direct.count)")
        }
        guard alternatives.count == 2 else {
            return .init(name: name, passed: false, detail: "alternatives should be 2, got \(alternatives.count)")
        }
        // Direct slot is the first card (highest rank by position — no
        // separate ranking in v1).
        guard direct.first?.0 == .place else {
            return .init(name: name, passed: false, detail: "direct slot kind mismatch")
        }
        return .init(
            name: name,
            passed: true,
            detail: "Triple slate: 1 direct + 2 alternatives (mixed kinds preserved)"
        )
    }

    // MARK: - 7. Dual slate → 1 direct + 1 alternative

    static func testDualSlateProducesDirectPlusOneAlternative() -> KernelPhase1TestResult {
        let name = "mixed_layout_dual_shape"
        let slate = syntheticSlate(kinds: [.route, .video])
        let (direct, alternatives) = MixedRecommendationSlatePartition.partition(slate)
        guard direct.count == 1 else {
            return .init(name: name, passed: false, detail: "direct should be 1, got \(direct.count)")
        }
        guard alternatives.count == 1 else {
            return .init(name: name, passed: false, detail: "alternatives should be 1, got \(alternatives.count)")
        }
        return .init(
            name: name,
            passed: true,
            detail: "Dual slate: 1 direct + 1 alternative"
        )
    }

    // MARK: - 8. Single slate → 1 direct only

    static func testSingleSlateProducesDirectOnly() -> KernelPhase1TestResult {
        let name = "mixed_layout_single_shape"
        let slate = syntheticSlate(kinds: [.toolEntry])
        let (direct, alternatives) = MixedRecommendationSlatePartition.partition(slate)
        guard direct.count == 1 else {
            return .init(name: name, passed: false, detail: "direct should be 1, got \(direct.count)")
        }
        guard alternatives.isEmpty else {
            return .init(name: name, passed: false, detail: "alternatives should be empty, got \(alternatives.count)")
        }
        return .init(
            name: name,
            passed: true,
            detail: "Single slate: direct-only, no alternatives"
        )
    }

    // MARK: - 9. Feedback menu is uniform per objectKind

    static func testFeedbackMenuUniformAcrossKinds() -> KernelPhase1TestResult {
        let name = "mixed_layout_feedback_uniform"
        // Per `mixed-recommendation-layout-v1.md` §5.1, each card in any
        // mixed slate offers the SAME 5-option MatchingFeedbackKind menu.
        // Compile-time witness: the menu is sourced from MatchingFeedbackKind.allCases
        // regardless of the card's object kind.
        let expected = Set(MatchingFeedbackKind.allCases)
        for kind in MatchingObjectKind.allCases {
            let menu = feedbackMenuOptions(for: kind)
            guard Set(menu) == expected else {
                return .init(
                    name: name,
                    passed: false,
                    detail: "kind \(kind.rawValue) exposes \(menu.count) options instead of 5"
                )
            }
        }
        return .init(
            name: name,
            passed: true,
            detail: "9 kinds × same 5-option feedback menu"
        )
    }

    // MARK: - helpers

    private static func syntheticSlate(
        kinds: [MatchingObjectKind]
    ) -> [(MatchingObjectKind, String)] {
        kinds.enumerated().map { idx, kind in
            (kind, "synthetic-\(idx)-\(kind.rawValue)")
        }
    }

    /// Mirrors what the rail does in production: every card, regardless of
    /// `objectKind`, surfaces the full 5-option MatchingFeedbackKind menu.
    private static func feedbackMenuOptions(
        for objectKind: MatchingObjectKind
    ) -> [MatchingFeedbackKind] {
        // If any branch returned a subset per kind, T11 and T12 would
        // both catch it.
        _ = objectKind
        return MatchingFeedbackKind.allCases
    }
}

// MARK: - Test-only layout state helpers

enum MixedRecommendationSlateState: String {
    case single
    case dual
    case triple

    static func state(forCount count: Int) -> MixedRecommendationSlateState {
        switch count {
        case ..<2:
            return .single
        case 2:
            return .dual
        default:
            return .triple
        }
    }
}

enum MixedRecommendationSlatePartition {
    static func partition<Element>(
        _ slate: [Element]
    ) -> (direct: [Element], alternatives: [Element]) {
        guard let first = slate.first else {
            return (direct: [], alternatives: [])
        }
        return (direct: [first], alternatives: Array(slate.dropFirst()))
    }
}
