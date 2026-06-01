//
//  PlanGraph.swift
//  kAir
//
//  Pure value contract for a multi-step plan as a typed DAG.
//
//  Reserved interface R4 of `Docs/architecture/kair-architecture-redesign-v2.md`
//  §5.4. LLMCompiler (arXiv:2312.04511) shows a planner that emits a dependency
//  DAG of tool calls can run independent branches in parallel. So "find a route
//  near my gym AND add a reminder" becomes one validated plan, not free text.
//
//  v1 is the value type + topological validation + the N≤5 loop-budget check
//  (Meituan LocalSearchBench). There is NO executor here, and each node's
//  `ActionPlan` is still individually gated by `PlanValidator` before dispatch.
//

import Foundation

/// One node in a multi-step plan: a typed `ActionPlan` (A2) plus its id and the
/// ids it depends on. Independent nodes (no shared dependency) may later run in
/// parallel.
struct PlanGraphNode: Hashable, Sendable {
    let id: String
    let plan: ActionPlan
    let dependsOn: [String]

    init(id: String, plan: ActionPlan, dependsOn: [String] = []) {
        self.id = id
        self.plan = plan
        self.dependsOn = dependsOn
    }
}

/// Why a `PlanGraph` failed validation.
enum PlanGraphError: String, Codable, Hashable, Sendable, CaseIterable {
    case emptyGraph
    case duplicateNodeID
    case unknownDependency
    case cycleDetected
    case exceedsLoopBudget
}

/// Validation outcome. `valid` carries a deterministic topological order the
/// executor can follow (independent nodes appear in sorted id order).
enum PlanGraphValidation: Hashable, Sendable {
    case valid(order: [String])
    case invalid(PlanGraphError)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var error: PlanGraphError? {
        if case .invalid(let error) = self { return error }
        return nil
    }
}

/// A multi-step plan as a DAG (redesign §5.4). Pure value + validation only.
struct PlanGraph: Hashable, Sendable {
    let nodes: [PlanGraphNode]

    init(nodes: [PlanGraphNode]) {
        self.nodes = nodes
    }

    /// Validate the DAG: non-empty, unique ids, known dependencies, within the
    /// loop budget, and acyclic. Returns a topological order on success.
    func validate(budget: AgentLoopBudget = .lifeServiceDefault) -> PlanGraphValidation {
        guard nodes.isEmpty == false else {
            return .invalid(.emptyGraph)
        }

        let ids = nodes.map(\.id)
        guard Set(ids).count == ids.count else {
            return .invalid(.duplicateNodeID)
        }

        let idSet = Set(ids)
        for node in nodes {
            for dependency in node.dependsOn where idSet.contains(dependency) == false {
                return .invalid(.unknownDependency)
            }
        }

        // N≤5 loop budget: a plan with more steps than the budget allows is
        // rejected before any execution (LocalSearchBench noise threshold).
        guard nodes.count <= budget.maxToolRounds else {
            return .invalid(.exceedsLoopBudget)
        }

        guard let order = topologicalOrder() else {
            return .invalid(.cycleDetected)
        }
        return .valid(order: order)
    }

    /// Kahn's algorithm with deterministic (sorted) tie-breaking. Returns `nil`
    /// when a cycle prevents a complete ordering.
    private func topologicalOrder() -> [String]? {
        var indegree: [String: Int] = [:]
        var dependents: [String: [String]] = [:]
        for node in nodes {
            indegree[node.id] = 0
        }
        for node in nodes {
            for dependency in node.dependsOn {
                dependents[dependency, default: []].append(node.id)
                indegree[node.id, default: 0] += 1
            }
        }

        var ready = indegree.filter { $0.value == 0 }.map(\.key).sorted()
        var order: [String] = []
        while ready.isEmpty == false {
            let id = ready.removeFirst()
            order.append(id)
            for dependent in (dependents[id] ?? []).sorted() {
                indegree[dependent, default: 0] -= 1
                if indegree[dependent] == 0 {
                    ready.append(dependent)
                }
            }
            ready.sort()
        }

        return order.count == nodes.count ? order : nil
    }
}
