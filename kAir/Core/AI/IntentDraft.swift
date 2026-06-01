//
//  IntentDraft.swift
//  kAir
//
//  Pure value contract for the local router/planner's structured output.
//
//  A2 "pure value contracts" for the AI orchestration pipeline
//  (Docs/architecture/kair-ai-model-memory-v1.md §2; the ConversationEngine
//  flow, steps 5–8). Foundation only — no model runtime, no network, no
//  HealthKit, no SwiftUI.
//
//  Free-form text is NEVER an execution plan (§2). Only this typed, Codable
//  contract — the deserialized router output — drives routing and validation
//  downstream.
//

import Foundation

/// The structured output of the local router/planner (or a deterministic
/// parser fixture), per `kair-ai-model-memory-v1.md` §2. `Codable` so the
/// router's JSON output deserializes into it directly.
///
/// `capability` / `surface` are raw identifier strings (a `CapabilityKind` /
/// `SurfaceKind` rawValue, possibly absent or unrecognized) — the model emits
/// strings, and `CapabilityRouter` resolves them into the typed vocabulary.
/// This keeps the draft `Codable` without coupling the (intentionally
/// non-`Codable`) capability enums.
struct IntentDraft: Codable, Hashable, Sendable {
    /// Stable id for this intent (uuid or stable hash).
    let intentID: String
    /// BCP-47 language tag of the user input (e.g. "zh-Hans", "en").
    let language: String
    /// The capability the router classified — a `CapabilityKind` rawValue, or
    /// `nil` / an unrecognized value when the input could not be classified
    /// (§2 "unknown capability → clarification / recommendation").
    let capability: String?
    /// The router's surface hint — a `SurfaceKind` rawValue. Advisory; the
    /// authoritative surface is `CapabilityKind.surfaceFamily` once resolved.
    let surface: String?
    /// The risk class of the requested action (§2 risk).
    let risk: ActionRisk
    /// Router confidence; below the threshold the plan cannot execute (§2).
    let confidence: IntentConfidence
    /// The router's own confirmation flag (§2 requires_confirmation). Advisory
    /// — `PlanValidator` independently enforces confirmation for risky actions.
    let requiresConfirmation: Bool
    /// Extracted parameter slots (name → value). Swift stores these as an
    /// ordered array for stable equality; the router JSON contract serializes
    /// them as a `slots` object (`{ "origin": "..." }`) per architecture §2.
    let slots: [IntentSlot]
    /// Names of required slots the router could not fill (§2 missing_slots).
    let missingSlots: [String]
    /// One-line, user-visible summary (no diagnostics, §16).
    let userVisibleSummary: String

    init(
        intentID: String,
        language: String,
        capability: String?,
        surface: String? = nil,
        risk: ActionRisk,
        confidence: IntentConfidence,
        requiresConfirmation: Bool,
        slots: [IntentSlot] = [],
        missingSlots: [String] = [],
        userVisibleSummary: String
    ) {
        self.intentID = intentID
        self.language = language
        self.capability = capability
        self.surface = surface
        self.risk = risk
        self.confidence = confidence
        self.requiresConfirmation = requiresConfirmation
        self.slots = slots
        self.missingSlots = missingSlots
        self.userVisibleSummary = userVisibleSummary
    }

    private enum CodingKeys: String, CodingKey {
        case intentID = "intent_id"
        case language
        case capability
        case surface
        case risk
        case confidence
        case requiresConfirmation = "requires_confirmation"
        case slots
        case missingSlots = "missing_slots"
        case userVisibleSummary = "user_visible_summary"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let slotMap = try container.decodeIfPresent([String: String].self, forKey: .slots) ?? [:]

        intentID = try container.decode(String.self, forKey: .intentID)
        language = try container.decode(String.self, forKey: .language)
        capability = try container.decodeIfPresent(String.self, forKey: .capability)
        surface = try container.decodeIfPresent(String.self, forKey: .surface)
        risk = try container.decode(ActionRisk.self, forKey: .risk)
        confidence = try container.decode(IntentConfidence.self, forKey: .confidence)
        requiresConfirmation = try container.decode(Bool.self, forKey: .requiresConfirmation)
        slots = slotMap.keys.sorted().map { IntentSlot(name: $0, value: slotMap[$0] ?? "") }
        missingSlots = try container.decodeIfPresent([String].self, forKey: .missingSlots) ?? []
        userVisibleSummary = try container.decode(String.self, forKey: .userVisibleSummary)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var slotMap: [String: String] = [:]
        for slot in slots {
            slotMap[slot.name] = slot.value
        }

        try container.encode(intentID, forKey: .intentID)
        try container.encode(language, forKey: .language)
        try container.encodeIfPresent(capability, forKey: .capability)
        try container.encodeIfPresent(surface, forKey: .surface)
        try container.encode(risk, forKey: .risk)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(requiresConfirmation, forKey: .requiresConfirmation)
        try container.encode(slotMap, forKey: .slots)
        try container.encode(missingSlots, forKey: .missingSlots)
        try container.encode(userVisibleSummary, forKey: .userVisibleSummary)
    }
}

/// One extracted parameter slot. Pure key/value; meaning is interpreted by
/// the planner/adapter downstream, never here.
struct IntentSlot: Codable, Hashable, Sendable {
    let name: String
    let value: String

    init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

/// Action risk class (§2 risk; `ToolRegistry` risk classes). `read` is the
/// only non-risky class; the rest require a user confirmation artifact before
/// any execution (§2; `ToolRegistry` forbidden list).
enum ActionRisk: String, Codable, Hashable, Sendable, CaseIterable {
    case read
    case write
    case pay
    case share
    case externalOpen

    /// Whether an action of this risk class requires explicit user
    /// confirmation before dispatch. Only `read` is exempt.
    var requiresConfirmation: Bool {
        self != .read
    }
}

/// Router confidence (§2 confidence, `0.0...1.0`). Below `executionThreshold`
/// the plan cannot execute and must route to clarification (§2 "confidence
/// below threshold cannot execute"; §16 low-confidence UX).
struct IntentConfidence: Codable, Hashable, Sendable {
    /// `0.0` (no confidence) … `1.0` (full confidence).
    let score: Double

    /// Minimum score required to execute a plan without extra clarification.
    /// Plans below this are treated as low-confidence.
    static let executionThreshold: Double = 0.5

    init(score: Double) {
        self.score = score
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        score = try container.decode(Double.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(score)
    }

    /// `true` when the score meets the execution threshold.
    var canExecute: Bool {
        score >= Self.executionThreshold
    }

    /// `true` for a low-confidence draft that must ask for clarification.
    var isLow: Bool {
        canExecute == false
    }

    /// Convenience values for fixtures/tests.
    static let high = IntentConfidence(score: 0.95)
    static let low = IntentConfidence(score: 0.2)
}
