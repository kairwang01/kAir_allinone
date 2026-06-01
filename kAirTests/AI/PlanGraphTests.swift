//
//  PlanGraphTests.swift
//  kAirTests
//
//  Reserved interface R4 (kair-architecture-redesign-v2.md §5.4): multi-step
//  plan DAG. Coverage: topological validation, empty/duplicate/unknown-dep/
//  cycle rejection, the N≤5 loop budget, and dependency-before-dependent order.
//

import XCTest
@testable import kAir

final class PlanGraphTests: XCTestCase {

    func test_validLinearChain_isValidWithTopoOrder() {
        let graph = PlanGraph(nodes: [
            Self.node("a"),
            Self.node("b", dependsOn: ["a"]),
            Self.node("c", dependsOn: ["b"]),
        ])
        XCTAssertEqual(graph.validate(), .valid(order: ["a", "b", "c"]))
    }

    func test_empty_isInvalid() {
        XCTAssertEqual(PlanGraph(nodes: []).validate().error, .emptyGraph)
    }

    func test_duplicateID_isInvalid() {
        let graph = PlanGraph(nodes: [Self.node("a"), Self.node("a")])
        XCTAssertEqual(graph.validate().error, .duplicateNodeID)
    }

    func test_unknownDependency_isInvalid() {
        let graph = PlanGraph(nodes: [Self.node("a", dependsOn: ["ghost"])])
        XCTAssertEqual(graph.validate().error, .unknownDependency)
    }

    func test_cycle_isInvalid() {
        let graph = PlanGraph(nodes: [
            Self.node("a", dependsOn: ["b"]),
            Self.node("b", dependsOn: ["a"]),
        ])
        XCTAssertEqual(graph.validate().error, .cycleDetected)
    }

    func test_exceedsLoopBudget_isInvalid() {
        let nodes = (0..<6).map { Self.node("n\($0)") }   // 6 > default 5
        XCTAssertEqual(PlanGraph(nodes: nodes).validate().error, .exceedsLoopBudget)
    }

    func test_withinCustomBudget_isValid() {
        let nodes = (0..<6).map { Self.node("n\($0)") }
        let result = PlanGraph(nodes: nodes).validate(budget: AgentLoopBudget(maxToolRounds: 10))
        XCTAssertTrue(result.isValid)
    }

    func test_independentNodes_topoOrderIsSortedById() {
        let graph = PlanGraph(nodes: [Self.node("c"), Self.node("a"), Self.node("b")])
        XCTAssertEqual(graph.validate(), .valid(order: ["a", "b", "c"]))
    }

    func test_diamond_dependenciesPrecedeDependents() {
        // a → b, a → c, b → d, c → d
        let graph = PlanGraph(nodes: [
            Self.node("a"),
            Self.node("b", dependsOn: ["a"]),
            Self.node("c", dependsOn: ["a"]),
            Self.node("d", dependsOn: ["b", "c"]),
        ])
        guard case .valid(let order) = graph.validate() else {
            return XCTFail("diamond DAG should be valid")
        }
        func index(_ id: String) -> Int { order.firstIndex(of: id)! }
        XCTAssertLessThan(index("a"), index("b"))
        XCTAssertLessThan(index("a"), index("c"))
        XCTAssertLessThan(index("b"), index("d"))
        XCTAssertLessThan(index("c"), index("d"))
    }

    // MARK: - Fixture

    private static func node(_ id: String, dependsOn: [String] = []) -> PlanGraphNode {
        PlanGraphNode(id: id, plan: plan(), dependsOn: dependsOn)
    }

    private static func plan() -> ActionPlan {
        ActionPlan(
            intentID: "intent",
            capability: .threadLookup,
            slots: [],
            missingSlots: [],
            risk: .read,
            confidence: .high,
            modelExecution: .onDevice,
            userVisibleSummary: "step"
        )
    }
}
