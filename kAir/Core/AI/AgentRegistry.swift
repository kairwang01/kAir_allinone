//
//  AgentRegistry.swift
//  kAir
//
//  Planned path for virtual company agent registration.
//

import Foundation

// Architecture note:
// `AgentRegistry` is the role catalog for kAir's internal agent system.
// It is not the execution engine and it must not call models, tools,
// network transports, HealthKit, or SwiftUI directly.
//
// Future responsibilities:
// - Declare agent roles such as router, planner, memory-curator,
//   health-local-specialist, model-librarian, and surface-copywriter.
// - Attach each role to an allowed model role from
//   `Docs/architecture/kair-ai-model-memory-v1.md` §1.
// - Attach each role to a minimal tool allowlist declared by
//   `ToolRegistry`.
// - Define handoff rules: which role can ask another role for help,
//   which context fields are allowed, and which domains are blocked.
// - Provide test fixtures for deterministic agent graphs.
//
// Forbidden:
// - No direct provider selection. `ModelProvider` / router policy owns
//   runtime selection.
// - No direct tool execution. `ToolExecutor` owns dispatch after
//   `PlanValidator` approves an action plan.
// - No hidden cross-domain memory. Health context must never be handed
//   to general chat, social, or remote roles in v1.
// - No "one giant agent" that can access every tool by default.
//
// First implementation gate:
// - Add pure value types only: `AgentRole`, `AgentPermissionScope`,
//   and `AgentGraph`.
// - Add tests proving health role isolation, paid-model role gating,
//   and deterministic role lookup.
