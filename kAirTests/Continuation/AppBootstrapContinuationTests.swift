//
//  AppBootstrapContinuationTests.swift
//  kAirTests
//
//  Main D integration tests: `AppBootstrap.recordSurfaceReturn(_:)`
//  is the FIRST real production seam that constructs and emits a
//  `ChatContinuationEvent` per `Contracts/UX/continuation-runtime-v1.md`
//  §6 + §8.1.
//
//  Coverage:
//    - Default runtime is NoOp; preview is NoOp; custom is identity-
//      stored.
//    - `.completion` from an open surface emits a renderEligible
//      event AND calls the `continuationHandler` for transcript
//      projection.
//    - `.abandon` from an open surface emits a renderEligible event
//      AND calls the handler.
//    - `.dismiss` / `.acceptNoEntry` emit non-renderEligible events
//      and do NOT call the handler (silent path per §8.1).
//    - After `recordSurfaceReturn`, `currentSection` resets to `.chat`
//      and `presentedSurface` is `nil`.
//    - Calling from `.chat` is a no-op (defensive guard).
//

import XCTest
@testable import kAir

@MainActor
final class AppBootstrapContinuationTests: XCTestCase {

    // MARK: - Composition

    func test_defaultInit_exposesNoOpContinuationRuntime() throws {
        let bootstrap = AppBootstrap()
        XCTAssertTrue(bootstrap.continuationRuntime is NoOpContinuationRuntime)
    }

    func test_previewBootstrap_exposesNoOpContinuationRuntime() throws {
        let bootstrap = AppBootstrap.preview
        XCTAssertTrue(bootstrap.continuationRuntime is NoOpContinuationRuntime)
    }

    func test_customContinuationRuntime_isStoredOnBootstrap() throws {
        let runtime = InMemoryContinuationRuntime()
        let bootstrap = AppBootstrap(continuationRuntime: runtime)
        XCTAssertTrue(bootstrap.continuationRuntime as? InMemoryContinuationRuntime === runtime)
    }

    func test_continuationHandler_defaultsToNil() throws {
        let bootstrap = AppBootstrap()
        XCTAssertNil(bootstrap.continuationHandler)
    }

    // MARK: - .completion real-path emit

    func test_recordSurfaceReturn_completion_emitsRenderEligibleEvent() async throws {
        let runtime = InMemoryContinuationRuntime()
        let bootstrap = AppBootstrap(continuationRuntime: runtime)
        bootstrap.openSurface(.maps)

        bootstrap.recordSurfaceReturn(.completion)
        await bootstrap.pendingContinuationEmit?.value

        let completionEvents = runtime.events(of: .completion)
        XCTAssertEqual(completionEvents.count, 1)
        XCTAssertEqual(completionEvents[0].surface, .maps)
        XCTAssertTrue(completionEvents[0].renderEligible)
    }

    func test_recordSurfaceReturn_completion_callsHandlerWithRenderEligibleEvent() async throws {
        let runtime = InMemoryContinuationRuntime()
        let bootstrap = AppBootstrap(continuationRuntime: runtime)
        bootstrap.openSurface(.ai)

        var captured: [ChatContinuationEvent] = []
        bootstrap.continuationHandler = { event in captured.append(event) }

        bootstrap.recordSurfaceReturn(.completion)
        await bootstrap.pendingContinuationEmit?.value

        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured[0].outcome, .completion)
        XCTAssertTrue(captured[0].renderEligible)
        XCTAssertEqual(captured[0].surface, .ai)
    }

    // MARK: - .abandon real-path emit

    func test_recordSurfaceReturn_abandon_emitsRenderEligibleEvent() async throws {
        let runtime = InMemoryContinuationRuntime()
        let bootstrap = AppBootstrap(continuationRuntime: runtime)
        bootstrap.openSurface(.maps)

        bootstrap.recordSurfaceReturn(.abandon)
        await bootstrap.pendingContinuationEmit?.value

        let abandonEvents = runtime.events(of: .abandon)
        XCTAssertEqual(abandonEvents.count, 1)
        XCTAssertEqual(abandonEvents[0].surface, .maps)
        XCTAssertTrue(abandonEvents[0].renderEligible)
    }

    func test_recordSurfaceReturn_abandon_callsHandler() async throws {
        let runtime = InMemoryContinuationRuntime()
        let bootstrap = AppBootstrap(continuationRuntime: runtime)
        bootstrap.openSurface(.store)

        var captured: [ChatContinuationEvent] = []
        bootstrap.continuationHandler = { event in captured.append(event) }

        bootstrap.recordSurfaceReturn(.abandon)
        await bootstrap.pendingContinuationEmit?.value

        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured[0].outcome, .abandon)
        XCTAssertTrue(captured[0].renderEligible)
    }

    // MARK: - Silent paths (§6 + §8.1)

    func test_recordSurfaceReturn_dismiss_emitsButDoesNotCallHandler() async throws {
        // `.dismiss` / `.acceptNoEntry` are recorded by the runtime
        // for telemetry/scorer but NOT projected to the transcript.
        let runtime = InMemoryContinuationRuntime()
        let bootstrap = AppBootstrap(continuationRuntime: runtime)
        bootstrap.openSurface(.maps)

        var captured: [ChatContinuationEvent] = []
        bootstrap.continuationHandler = { event in captured.append(event) }

        bootstrap.recordSurfaceReturn(.dismiss)
        await bootstrap.pendingContinuationEmit?.value

        XCTAssertEqual(runtime.events(of: .dismiss).count, 1)
        XCTAssertFalse(runtime.events(of: .dismiss)[0].renderEligible)
        // Silent path: handler is NOT invoked.
        XCTAssertTrue(captured.isEmpty)
    }

    func test_recordSurfaceReturn_acceptNoEntry_emitsButDoesNotCallHandler() async throws {
        let runtime = InMemoryContinuationRuntime()
        let bootstrap = AppBootstrap(continuationRuntime: runtime)
        bootstrap.openSurface(.ai)

        var captured: [ChatContinuationEvent] = []
        bootstrap.continuationHandler = { event in captured.append(event) }

        bootstrap.recordSurfaceReturn(.acceptNoEntry)
        await bootstrap.pendingContinuationEmit?.value

        XCTAssertEqual(runtime.events(of: .acceptNoEntry).count, 1)
        XCTAssertFalse(runtime.events(of: .acceptNoEntry)[0].renderEligible)
        XCTAssertTrue(captured.isEmpty)
    }

    // MARK: - State reset

    func test_recordSurfaceReturn_resetsBootstrapState() async throws {
        let runtime = InMemoryContinuationRuntime()
        let bootstrap = AppBootstrap(continuationRuntime: runtime)
        bootstrap.openSurface(.maps)
        XCTAssertEqual(bootstrap.presentedSurface, .maps)

        bootstrap.recordSurfaceReturn(.completion)
        await bootstrap.pendingContinuationEmit?.value

        XCTAssertEqual(bootstrap.currentSection, .chat)
        XCTAssertNil(bootstrap.presentedSurface)
    }

    // MARK: - Defensive guard

    func test_recordSurfaceReturn_fromChat_isNoOp() async throws {
        // Defensive: if currentSection is .chat there's no surface
        // to return from. Should not emit and not call handler.
        let runtime = InMemoryContinuationRuntime()
        let bootstrap = AppBootstrap(continuationRuntime: runtime)

        var captured: [ChatContinuationEvent] = []
        bootstrap.continuationHandler = { event in captured.append(event) }

        bootstrap.recordSurfaceReturn(.completion)
        await bootstrap.pendingContinuationEmit?.value

        XCTAssertTrue(runtime.emittedEvents.isEmpty)
        XCTAssertTrue(captured.isEmpty)
    }

    // MARK: - Default NoOp path doesn't crash

    func test_defaultBootstrap_recordSurfaceReturn_doesNotCrash() async throws {
        let bootstrap = AppBootstrap()
        bootstrap.openSurface(.ai)
        bootstrap.recordSurfaceReturn(.completion)
        await bootstrap.pendingContinuationEmit?.value
        XCTAssertEqual(bootstrap.currentSection, .chat)
    }
}
