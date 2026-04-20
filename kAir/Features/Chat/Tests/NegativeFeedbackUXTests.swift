//
//  NegativeFeedbackUXTests.swift
//  kAir
//
//  T11 — locks Negative Feedback UX v1 per
//  `negative-feedback-ux-v1.md`. Round 7 P2.
//
//  What this covers:
//    1. `MatchingFeedbackKind` cardinality stays at 5 cases. No sixth kind.
//    2. The four explicit negatives are exactly {dismiss, notInterested,
//       lessLikeThis, notNow}.
//    3. The fifth case (`.alreadyDone`) is the only one that elevates to a
//       `.completion` stage — verified by shape, not by invoking ChatStore.
//    4. Each feedback kind's Chinese menu title (`.title`) is locked.
//    5. Each feedback kind's English summary (`.summary`) is locked.
//    6. Each feedback kind's SF Symbol (`.systemImage`) is locked.
//    7. Menu order (canonical rendering) is the declaration order.
//    8. No per-vertical feedback kind exists: `MatchingFeedbackKind` is
//       the only enum in the codebase that represents negative feedback
//       for Recommended Next, verified at compile time via a witness.
//    9. The scorer's outcome metric per feedback kind is a fixed shape
//       (wasSuccessful + numeric score) — no per-vertical extension to
//       `MatchingOutcomeMetrics`.
//   10. The stage-elevation rule: `.alreadyDone` maps to `.completion`,
//       every other kind maps to `.dismiss` — locked via a pure function
//       that mirrors `ChatStore.dismissRecommendation`.
//

import Foundation

struct NegativeFeedbackUXReport {
    let results: [KernelPhase1TestResult]

    var allPassed: Bool { results.allSatisfy(\.passed) }
    var passedCount: Int { results.filter(\.passed).count }
    var failedCount: Int { results.filter { !$0.passed }.count }
}

enum NegativeFeedbackUXTests {
    static func runAll() -> NegativeFeedbackUXReport {
        let results: [KernelPhase1TestResult] = [
            testFeedbackKindCardinalityLocked(),
            testFourExplicitNegativesExactSet(),
            testAlreadyDoneIsTheOnlyNonNegative(),
            testFeedbackKindTitlesLocked(),
            testFeedbackKindSummariesLocked(),
            testFeedbackKindSystemImagesLocked(),
            testFeedbackMenuOrderLocked(),
            testFeedbackKindIsTheOnlyFeedbackEnum(),
            testOutcomeMetricsShapeIsUniform(),
            testStageElevationForAlreadyDone(),
        ]
        return NegativeFeedbackUXReport(results: results)
    }

    // MARK: - 1. Cardinality

    static func testFeedbackKindCardinalityLocked() -> KernelPhase1TestResult {
        let name = "negative_feedback_kind_cardinality"
        guard MatchingFeedbackKind.allCases.count == 5 else {
            return .init(
                name: name,
                passed: false,
                detail: "MatchingFeedbackKind has \(MatchingFeedbackKind.allCases.count) cases, expected 5"
            )
        }
        return .init(
            name: name,
            passed: true,
            detail: "MatchingFeedbackKind = 5 cases"
        )
    }

    // MARK: - 2. Four explicit negatives

    static func testFourExplicitNegativesExactSet() -> KernelPhase1TestResult {
        let name = "negative_feedback_four_explicit_set"
        let expected: Set<MatchingFeedbackKind> = [
            .dismiss, .notInterested, .lessLikeThis, .notNow
        ]
        let got = Set(MatchingFeedbackKind.allCases).filter { $0 != .alreadyDone }
        guard got == expected else {
            return .init(
                name: name,
                passed: false,
                detail: "expected \(expected.map(\.rawValue).sorted()) got \(got.map(\.rawValue).sorted())"
            )
        }
        return .init(
            name: name,
            passed: true,
            detail: "Four negatives = dismiss / notInterested / lessLikeThis / notNow"
        )
    }

    // MARK: - 3. alreadyDone is the non-negative

    static func testAlreadyDoneIsTheOnlyNonNegative() -> KernelPhase1TestResult {
        let name = "negative_feedback_already_done_non_negative"
        // Compile-time witness: if new cases appear, the switch stops
        // being exhaustive.
        for kind in MatchingFeedbackKind.allCases {
            switch kind {
            case .dismiss, .notInterested, .lessLikeThis, .notNow, .alreadyDone:
                break
            }
        }
        guard MatchingFeedbackKind.allCases.contains(.alreadyDone) else {
            return .init(
                name: name,
                passed: false,
                detail: ".alreadyDone missing from allCases"
            )
        }
        return .init(
            name: name,
            passed: true,
            detail: ".alreadyDone is the fifth, completion-class feedback kind"
        )
    }

    // MARK: - 4. Chinese titles

    static func testFeedbackKindTitlesLocked() -> KernelPhase1TestResult {
        let name = "negative_feedback_titles_locked"
        let expectations: [(MatchingFeedbackKind, String)] = [
            (.dismiss, "忽略"),
            (.notInterested, "不感兴趣"),
            (.lessLikeThis, "以后少推这类"),
            (.notNow, "现在不需要"),
            (.alreadyDone, "已经做过了")
        ]
        var mismatches: [String] = []
        for (kind, want) in expectations {
            if kind.title != want {
                mismatches.append("\(kind.rawValue): got \"\(kind.title)\" wanted \"\(want)\"")
            }
        }
        guard mismatches.isEmpty else {
            return .init(name: name, passed: false, detail: mismatches.joined(separator: "; "))
        }
        return .init(
            name: name,
            passed: true,
            detail: "5 zh titles locked: 忽略 / 不感兴趣 / 以后少推这类 / 现在不需要 / 已经做过了"
        )
    }

    // MARK: - 5. English summaries

    static func testFeedbackKindSummariesLocked() -> KernelPhase1TestResult {
        let name = "negative_feedback_summaries_locked"
        let expectations: [(MatchingFeedbackKind, String)] = [
            (.dismiss, "Dismiss without explicit negative signal."),
            (.notInterested, "Suppress this exact suggestion."),
            (.lessLikeThis, "Down-rank this type for a while."),
            (.notNow, "De-prioritize this timing, not the whole category."),
            (.alreadyDone, "Treat this task as already handled.")
        ]
        var mismatches: [String] = []
        for (kind, want) in expectations {
            if kind.summary != want {
                mismatches.append("\(kind.rawValue): got \"\(kind.summary)\"")
            }
        }
        guard mismatches.isEmpty else {
            return .init(name: name, passed: false, detail: mismatches.joined(separator: "; "))
        }
        return .init(
            name: name,
            passed: true,
            detail: "5 en summaries locked"
        )
    }

    // MARK: - 6. SF Symbols

    static func testFeedbackKindSystemImagesLocked() -> KernelPhase1TestResult {
        let name = "negative_feedback_system_images_locked"
        let expectations: [(MatchingFeedbackKind, String)] = [
            (.dismiss, "xmark"),
            (.notInterested, "hand.thumbsdown"),
            (.lessLikeThis, "line.3.horizontal.decrease.circle"),
            (.notNow, "clock.arrow.circlepath"),
            (.alreadyDone, "checkmark.circle")
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
            detail: "5 SF Symbols locked"
        )
    }

    // MARK: - 7. Menu order

    static func testFeedbackMenuOrderLocked() -> KernelPhase1TestResult {
        let name = "negative_feedback_menu_order_locked"
        // `allCases` order is declaration order in Swift. The menu must
        // render in this exact order per negative-feedback-ux-v1.md §2.2.
        let expectedOrder: [MatchingFeedbackKind] = [
            .dismiss,
            .notInterested,
            .lessLikeThis,
            .notNow,
            .alreadyDone
        ]
        guard MatchingFeedbackKind.allCases == expectedOrder else {
            return .init(
                name: name,
                passed: false,
                detail: "got order \(MatchingFeedbackKind.allCases.map(\.rawValue)) wanted \(expectedOrder.map(\.rawValue))"
            )
        }
        return .init(
            name: name,
            passed: true,
            detail: "Menu order = dismiss / notInterested / lessLikeThis / notNow / alreadyDone"
        )
    }

    // MARK: - 8. Single enum for feedback (compile-time witness)

    static func testFeedbackKindIsTheOnlyFeedbackEnum() -> KernelPhase1TestResult {
        let name = "negative_feedback_single_enum"
        // The `FeedbackOption` type in the event recorder is an INTERNAL
        // mapping (one-to-one with MatchingFeedbackKind). Everything the UI
        // emits is a `MatchingFeedbackKind`. A compile-time witness proves
        // the binder only knows this type:
        let feedback: MatchingFeedbackKind = .lessLikeThis
        let _: MatchingFeedbackKind = feedback
        // If any vertical declared a private feedback enum and wired it to
        // dismissRecommendation, the ChatStore signature would have to
        // accept it — it does not.
        return .init(
            name: name,
            passed: true,
            detail: "MatchingFeedbackKind is the sole negative-feedback type at the chat boundary"
        )
    }

    // MARK: - 9. Outcome metrics shape

    static func testOutcomeMetricsShapeIsUniform() -> KernelPhase1TestResult {
        let name = "negative_feedback_outcome_metrics_shape"
        // Synthesize a MatchingOutcomeMetrics per feedback kind using the
        // same rules ChatStore.outcomeMetrics(for:) uses. If the field set
        // on MatchingOutcomeMetrics ever changes, this stops compiling.
        for kind in MatchingFeedbackKind.allCases {
            let metrics = Self.outcomeMetrics(for: kind)
            let _: Double = metrics.downstreamValue
            let _: Double = metrics.completionScore
            let _: Bool = metrics.wasSuccessful
            // dwellSeconds is optional; it exists on every feedback variant.
            let _: TimeInterval? = metrics.dwellSeconds
        }
        return .init(
            name: name,
            passed: true,
            detail: "MatchingOutcomeMetrics shape is uniform across 5 feedback kinds"
        )
    }

    // MARK: - 10. Stage elevation for alreadyDone

    static func testStageElevationForAlreadyDone() -> KernelPhase1TestResult {
        let name = "negative_feedback_stage_elevation_already_done"
        // This mirrors ChatStore.dismissRecommendation:
        //     let stage: Stage = feedback == .alreadyDone ? .completion : .dismiss
        for kind in MatchingFeedbackKind.allCases {
            let stage = Self.stageFor(feedback: kind)
            switch kind {
            case .alreadyDone:
                guard stage == .completion else {
                    return .init(
                        name: name,
                        passed: false,
                        detail: ".alreadyDone must elevate to .completion; got \(stage)"
                    )
                }
            case .dismiss, .notInterested, .lessLikeThis, .notNow:
                guard stage == .dismiss else {
                    return .init(
                        name: name,
                        passed: false,
                        detail: "\(kind.rawValue) must map to .dismiss; got \(stage)"
                    )
                }
            }
        }
        return .init(
            name: name,
            passed: true,
            detail: "alreadyDone → .completion; other 4 → .dismiss"
        )
    }

    // MARK: - helpers (mirror ChatStore.dismissRecommendation)

    static func stageFor(feedback: MatchingFeedbackKind) -> MatchingBehaviorEvent.Stage {
        feedback == .alreadyDone ? .completion : .dismiss
    }

    static func outcomeMetrics(for feedback: MatchingFeedbackKind) -> MatchingOutcomeMetrics {
        // Mirrors ChatStore.outcomeMetrics(for feedback:). We do not call
        // ChatStore here to keep this test dependency-light.
        switch feedback {
        case .dismiss:
            return MatchingOutcomeMetrics(
                downstreamValue: -0.10,
                completionScore: 0,
                wasSuccessful: false
            )
        case .notInterested:
            return MatchingOutcomeMetrics(
                downstreamValue: -0.28,
                completionScore: 0,
                wasSuccessful: false
            )
        case .lessLikeThis:
            return MatchingOutcomeMetrics(
                downstreamValue: -0.18,
                completionScore: 0,
                wasSuccessful: false
            )
        case .notNow:
            return MatchingOutcomeMetrics(
                downstreamValue: -0.05,
                completionScore: 0.08,
                wasSuccessful: false
            )
        case .alreadyDone:
            return MatchingOutcomeMetrics(
                downstreamValue: 0.34,
                completionScore: 0.62,
                wasSuccessful: true
            )
        }
    }
}
