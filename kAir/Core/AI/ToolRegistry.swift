//
//  ToolRegistry.swift
//  kAir
//
//  Planned path for local tool registration.
//

import Foundation

// Architecture note:
// `ToolRegistry` declares the only tool calls a model-generated plan is
// allowed to request. A tool declaration is not an implementation. It is
// a typed permission surface used by `PlanValidator` and `ToolExecutor`.
//
// Future tool families:
// - `capability.resolve`: invokes a `CapabilityAdapter` through the
//   `CapabilityRegistry`.
// - `memory.read`: scoped retrieval through `MemoryStore`.
// - `memory.writeCandidate`: policy-gated memory candidate write.
// - `model.status`: installed/downloadable/active model state.
// - `surface.open`: opens a kAir-owned `AppSection`.
// - `external.prepareHandoff`: prepares URL, universal link, ShareSheet,
//   or App Intent handoff, but does not claim completion.
// - `health.readSummary`: Health-only, local-only, permission-gated.
//
// Required metadata per future tool:
// - stable id
// - human-readable display name
// - owning capability or service
// - read/write/pay/share/external-open risk class
// - allowed memory domains
// - confirmation requirement
// - availability resolver
// - test fixture payload
//
// Forbidden:
// - No arbitrary Swift selector names exposed to the model.
// - No private API or UI automation tool in production.
// - No tool that sends Health data to remote providers in v1.
// - No tool that performs purchase, order, post, send, or share without
//   an explicit user confirmation artifact.
//
// First implementation gate:
// - Add pure declarations for tool id, risk, and confirmation need.
// - Tests must prove risky tools require confirmation and health tools
//   are unavailable to non-health roles.
