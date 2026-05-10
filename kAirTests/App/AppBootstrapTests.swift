//
//  AppBootstrapTests.swift
//  kAirTests
//
//  Composition-root tests for `AppBootstrap.feedbackRuntime` (Main A.1).
//
//  These tests pin the architectural contract: the feedback runtime
//  instance is composed by `AppBootstrap`, not by `ChatStore`. The
//  default is `NoOpFeedbackRuntime` per
//  `Contracts/UX/feedback-runtime-v1.md` §5; production builds will
//  swap this default at the composition root once telemetry / scorer
//  sinks are wired (Main B onward).
//

import XCTest
@testable import kAir

@MainActor
final class AppBootstrapTests: XCTestCase {
    // MARK: - Default composition

    func test_defaultInit_exposesNoOpFeedbackRuntime() throws {
        let bootstrap = AppBootstrap()

        // The runtime is non-optional (always composed) and defaults
        // to NoOp per Main A.1 contract.
        XCTAssertTrue(bootstrap.feedbackRuntime is NoOpFeedbackRuntime)
    }

    func test_previewBootstrap_exposesFeedbackRuntime() throws {
        let bootstrap = AppBootstrap.preview
        XCTAssertTrue(bootstrap.feedbackRuntime is NoOpFeedbackRuntime)
    }

    // MARK: - Custom composition

    func test_customRuntime_isStoredOnBootstrap() throws {
        let spy = SpyFeedbackRuntimeForBootstrap()
        let bootstrap = AppBootstrap(feedbackRuntime: spy)

        // Identity check: AppBootstrap stores the exact runtime
        // instance the composition root passed in.
        XCTAssertTrue(bootstrap.feedbackRuntime as? SpyFeedbackRuntimeForBootstrap === spy)
    }

    // MARK: - End-to-end composition smoke test
    //
    // Verifies the runtime flows from `AppBootstrap` through the same
    // construction path `ChatHomeView.init(bootstrap:)` uses, and that
    // a dismiss on the resulting `ChatStore` reaches the bootstrap-
    // composed runtime exactly once. This is the architectural pin for
    // Main A.1: the composition root owns the runtime; `ChatStore` is
    // a consumer.

    func test_compositionRoot_dismissCallsBootstrapRuntimeOnce() async throws {
        let spy = SpyFeedbackRuntimeForBootstrap()
        let bootstrap = AppBootstrap(feedbackRuntime: spy)

        // Mirror what `ChatHomeView.init(bootstrap:)` does.
        let store = ChatStore(feedbackRuntime: bootstrap.feedbackRuntime)
        let target = store.recommendedMatches[0]

        store.dismissRecommendation(target, feedback: .dismiss)
        await store.pendingFeedbackEmit?.value

        XCTAssertEqual(spy.emittedEvents.count, 1)
        XCTAssertEqual(spy.emittedEvents[0].recommendationId, target.id)
        XCTAssertEqual(spy.emittedEvents[0].feedbackKind, .dismiss)
    }

    func test_compositionRoot_unchangedAcrossDismisses() async throws {
        // The runtime instance is `let` on `AppBootstrap`; multiple
        // dismisses in the same session reach the same instance.
        let spy = SpyFeedbackRuntimeForBootstrap()
        let bootstrap = AppBootstrap(feedbackRuntime: spy)
        let store = ChatStore(feedbackRuntime: bootstrap.feedbackRuntime)

        let snapshot = store.recommendedMatches
        for object in snapshot {
            store.dismissRecommendation(object, feedback: .dismiss)
            await store.pendingFeedbackEmit?.value
        }

        XCTAssertEqual(spy.emittedEvents.count, snapshot.count)
        for (i, object) in snapshot.enumerated() {
            XCTAssertEqual(spy.emittedEvents[i].recommendationId, object.id)
        }
    }

    func test_defaultBootstrapRuntime_doesNotCrashOnDismiss() async throws {
        // Sanity: the default NoOp path completes without throwing.
        // Uses `.alreadyDone` so we don't trigger the refresh-restores-
        // dismissed-card behavior of the default StubRecommendationProvider
        // (the stub does not respect a suppression log; that gap is
        // tracked in `feedback-runtime-v1.md` §13).
        let bootstrap = AppBootstrap()
        let store = ChatStore(feedbackRuntime: bootstrap.feedbackRuntime)
        let target = store.recommendedMatches[0]

        store.dismissRecommendation(target, feedback: .alreadyDone)
        await store.pendingFeedbackEmit?.value

        // .alreadyDone exits the negative-feedback flow and does NOT
        // call refresh per feedback-runtime §4.1. The card is removed
        // from the slate AND the recommendation id is logged in
        // completedRecommendations.
        XCTAssertFalse(store.recommendedMatches.contains(target))
        XCTAssertEqual(store.completedRecommendations, [target.id])
    }
}

// MARK: - Test double

/// Local spy for AppBootstrap composition tests. Class identity is used
/// to verify the bootstrap stores the exact instance the caller passed
/// in (see `test_customRuntime_isStoredOnBootstrap`). A separate spy
/// type lives in `RecommendationRailIntegrationTests`; that one is
/// fileprivate, so this file declares its own to avoid coupling.
@MainActor
private final class SpyFeedbackRuntimeForBootstrap: FeedbackRuntime {
    var emittedEvents: [FeedbackEvent] = []

    func emit(_ event: FeedbackEvent) async throws {
        emittedEvents.append(event)
    }
}
