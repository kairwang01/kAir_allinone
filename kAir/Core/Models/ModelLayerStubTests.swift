//
//  ModelLayerStubTests.swift
//  kAir
//
//  P2 stub-only tests for the model layer. Verify:
//   1. A mock StructuredOutputParser parses legal JSON into the frozen type.
//   2. Illegal JSON returns a parse failure.
//   3. A mock ModelRouter can emit local / cloud / directFail targets.
//   4. The product main flow still compiles and boots without depending on
//      any of these stub interfaces (AppBootstrap.preview stays pure).
//

import Foundation

struct ModelLayerStubTestReport {
    let results: [KernelPhase1TestResult]

    var allPassed: Bool { results.allSatisfy(\.passed) }
    var passedCount: Int { results.filter(\.passed).count }
    var failedCount: Int { results.filter { !$0.passed }.count }
}

enum ModelLayerStubTests {
    @MainActor
    static func runAll() -> ModelLayerStubTestReport {
        let results: [KernelPhase1TestResult] = [
            testParserAcceptsLegalJSON(),
            testParserRejectsIllegalJSON(),
            testRouterEmitsAllTargets(),
            testMainFlowDoesNotDependOnStubs(),
        ]
        return ModelLayerStubTestReport(results: results)
    }

    // MARK: - Test 1: legal JSON round-trips through a mock parser

    static func testParserAcceptsLegalJSON() -> KernelPhase1TestResult {
        let parser: StructuredOutputParser = MockJSONStructuredOutputParser()
        let json = """
        {
          "tool": "maps.navigate",
          "args": {"destination": "home"},
          "needsClarification": false,
          "clarificationQuestion": null,
          "confidence": 0.92,
          "reasonCode": "directMatch"
        }
        """

        switch parser.parse(json) {
        case .success(let selection):
            guard selection.tool == "maps.navigate" else {
                return KernelPhase1TestResult(
                    name: "parser_legal_json",
                    passed: false,
                    detail: "wrong tool: \(selection.tool)"
                )
            }
            guard selection.args["destination"] == "home" else {
                return KernelPhase1TestResult(
                    name: "parser_legal_json",
                    passed: false,
                    detail: "missing arg destination"
                )
            }
            guard selection.reasonCode == .directMatch else {
                return KernelPhase1TestResult(
                    name: "parser_legal_json",
                    passed: false,
                    detail: "reasonCode expected directMatch, got \(selection.reasonCode.rawValue)"
                )
            }
            guard selection.needsClarification == false,
                  selection.clarificationQuestion == nil else {
                return KernelPhase1TestResult(
                    name: "parser_legal_json",
                    passed: false,
                    detail: "clarification fields not preserved"
                )
            }
            guard abs(selection.confidence - 0.92) < 0.0001 else {
                return KernelPhase1TestResult(
                    name: "parser_legal_json",
                    passed: false,
                    detail: "confidence lost: \(selection.confidence)"
                )
            }
            return KernelPhase1TestResult(
                name: "parser_legal_json",
                passed: true,
                detail: "parsed tool=\(selection.tool) reason=\(selection.reasonCode.rawValue) conf=\(selection.confidence)"
            )
        case .failure(let error):
            return KernelPhase1TestResult(
                name: "parser_legal_json",
                passed: false,
                detail: "expected success, got failure \(error)"
            )
        }
    }

    // MARK: - Test 2: illegal JSON surfaces a parse failure

    static func testParserRejectsIllegalJSON() -> KernelPhase1TestResult {
        let parser: StructuredOutputParser = MockJSONStructuredOutputParser()
        let illegal = "{ not json at all"

        switch parser.parse(illegal) {
        case .success(let selection):
            return KernelPhase1TestResult(
                name: "parser_illegal_json",
                passed: false,
                detail: "expected parseFailure, got tool=\(selection.tool)"
            )
        case .failure(let error):
            guard case .parseFailure = error else {
                return KernelPhase1TestResult(
                    name: "parser_illegal_json",
                    passed: false,
                    detail: "expected .parseFailure, got \(error)"
                )
            }
            return KernelPhase1TestResult(
                name: "parser_illegal_json",
                passed: true,
                detail: "illegal JSON mapped to .parseFailure"
            )
        }
    }

    // MARK: - Test 3: router mock emits all three targets

    static func testRouterEmitsAllTargets() -> KernelPhase1TestResult {
        let router: ModelRouter = MockModelRouter()

        let localReq = ModelRoutingRequest(
            requestId: "req-local",
            prompt: "local please",
            preferLocal: true,
            maxLatencyMs: 2000
        )
        let cloudReq = ModelRoutingRequest(
            requestId: "req-cloud",
            prompt: "cloud please",
            preferLocal: false,
            maxLatencyMs: 8000
        )
        let failReq = ModelRoutingRequest(
            requestId: "req-fail",
            prompt: "",
            preferLocal: true,
            maxLatencyMs: nil
        )

        let localDecision = router.route(localReq)
        let cloudDecision = router.route(cloudReq)
        let failDecision = router.route(failReq)

        guard localDecision.target == .local,
              localDecision.requestId == "req-local" else {
            return KernelPhase1TestResult(
                name: "router_all_targets",
                passed: false,
                detail: "local branch wrong: target=\(localDecision.target.rawValue) id=\(localDecision.requestId)"
            )
        }
        guard cloudDecision.target == .cloud,
              cloudDecision.requestId == "req-cloud" else {
            return KernelPhase1TestResult(
                name: "router_all_targets",
                passed: false,
                detail: "cloud branch wrong: target=\(cloudDecision.target.rawValue) id=\(cloudDecision.requestId)"
            )
        }
        guard failDecision.target == .directFail,
              failDecision.requestId == "req-fail" else {
            return KernelPhase1TestResult(
                name: "router_all_targets",
                passed: false,
                detail: "fail branch wrong: target=\(failDecision.target.rawValue) id=\(failDecision.requestId)"
            )
        }

        return KernelPhase1TestResult(
            name: "router_all_targets",
            passed: true,
            detail: "router emitted local/cloud/directFail as expected"
        )
    }

    // MARK: - Test 4: main flow is unaffected by the stubs

    @MainActor
    static func testMainFlowDoesNotDependOnStubs() -> KernelPhase1TestResult {
        // AppBootstrap.preview must construct with no model-layer wiring.
        // If any main-flow code started consuming these protocols, the
        // initializer signature or dependencies would have to change.
        let bootstrap = AppBootstrap.preview

        guard bootstrap.currentSection == .chat else {
            return KernelPhase1TestResult(
                name: "main_flow_untouched",
                passed: false,
                detail: "unexpected initial section \(bootstrap.currentSection.rawValue)"
            )
        }
        guard bootstrap.presentedSurface == nil else {
            return KernelPhase1TestResult(
                name: "main_flow_untouched",
                passed: false,
                detail: "unexpected presentedSurface at boot"
            )
        }
        guard bootstrap.lastSurfaceEntryRequest == nil else {
            return KernelPhase1TestResult(
                name: "main_flow_untouched",
                passed: false,
                detail: "unexpected lastSurfaceEntryRequest at boot"
            )
        }
        return KernelPhase1TestResult(
            name: "main_flow_untouched",
            passed: true,
            detail: "AppBootstrap.preview still constructs without model-layer injection"
        )
    }
}

// MARK: - Mocks (test-only — not used by product flow)

private struct MockJSONStructuredOutputParser: StructuredOutputParser {
    func parse(_ rawText: String) -> Result<StructuredToolSelection, StructuredOutputParserError> {
        guard let data = rawText.data(using: .utf8) else {
            return .failure(.parseFailure("not utf8"))
        }
        do {
            let selection = try StructuredToolSelection.decode(from: data)
            return .success(selection)
        } catch {
            return .failure(.parseFailure("decode error: \(error)"))
        }
    }
}

private struct MockModelRouter: ModelRouter {
    func route(_ request: ModelRoutingRequest) -> ModelRoutingDecision {
        if request.prompt.isEmpty {
            return ModelRoutingDecision(
                requestId: request.requestId,
                target: .directFail,
                reason: "empty prompt"
            )
        }
        if request.preferLocal {
            return ModelRoutingDecision(
                requestId: request.requestId,
                target: .local,
                reason: "caller prefers local"
            )
        }
        return ModelRoutingDecision(
            requestId: request.requestId,
            target: .cloud,
            reason: "caller opted into cloud"
        )
    }
}
