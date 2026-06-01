//
//  SpatiotemporalContext.swift
//  kAir
//
//  Pure value contracts for life-service time/place grounding and the agent
//  loop budget.
//
//  Reserved interface R6 of `Docs/architecture/kair-architecture-redesign-v2.md`
//  §5.6. Meituan's LocalEval shows time/place grounding is a *required* input
//  for life-service tasks (not enrichment), and LocalSearchBench shows
//  correctness peaks at N≈5 tool rounds after an explicit plan. Both values are
//  caller-injected (no clock / location / weather SDK is read here) so policy
//  and tests stay deterministic — matching the `now:`-injection pattern used by
//  `MemoryStore` and `SearchProvider`.
//

import Foundation

/// Coarse time/place grounding every life-service capability request carries.
/// Coarse location only — never raw precise coordinates in memory or telemetry.
struct SpatiotemporalContext: Codable, Hashable, Sendable {
    /// Caller-injected timestamp (no clock read here).
    let timestamp: Date
    let dayOfWeek: DayOfWeek
    /// Coarse location label (neighborhood / district), never lat/long.
    let coarseLocation: String
    let region: ProviderRegion
    /// BCP-47 locale (e.g. "zh-Hans", "en-US").
    let locale: String
    let weather: WeatherSignal?

    init(
        timestamp: Date,
        dayOfWeek: DayOfWeek,
        coarseLocation: String,
        region: ProviderRegion = .global,
        locale: String,
        weather: WeatherSignal? = nil
    ) {
        self.timestamp = timestamp
        self.dayOfWeek = dayOfWeek
        self.coarseLocation = coarseLocation
        self.region = region
        self.locale = locale
        self.weather = weather
    }

    enum DayOfWeek: String, Codable, Hashable, Sendable, CaseIterable {
        case monday, tuesday, wednesday, thursday, friday, saturday, sunday

        var isWeekend: Bool {
            self == .saturday || self == .sunday
        }
    }

    enum WeatherSignal: String, Codable, Hashable, Sendable, CaseIterable {
        case clear, cloudy, rain, snow, extreme
    }

    /// City/locale prompt prefix. Meituan found city-specified prompts fix
    /// cross-region transfer degradation; this is the grounding token a
    /// life-service adapter prepends — coarse, never precise coordinates.
    var promptGroundingPrefix: String {
        "[\(coarseLocation) · \(locale) · \(region.rawValue) · \(dayOfWeek.rawValue)]"
    }
}

/// Bounds a life-service agent loop (redesign §5.6; LocalSearchBench: optimal
/// N≈5 tool rounds, and agents that retrieve before planning fail). Consumed by
/// the future `PlanGraph` executor.
struct AgentLoopBudget: Codable, Hashable, Sendable {
    let maxToolRounds: Int
    let requirePlanFirst: Bool
    let maxTokens: Int

    init(maxToolRounds: Int = 5, requirePlanFirst: Bool = true, maxTokens: Int = 8000) {
        self.maxToolRounds = maxToolRounds
        self.requirePlanFirst = requirePlanFirst
        self.maxTokens = maxTokens
    }

    /// Life-service default: 5 tool rounds, plan-first (LocalSearchBench).
    static let lifeServiceDefault = AgentLoopBudget()

    /// Whether another tool round may start given the rounds already used.
    func allowsRound(_ usedRounds: Int) -> Bool {
        usedRounds < maxToolRounds
    }

    /// Whether a tool call may proceed: a plan must exist first when
    /// `requirePlanFirst`, and the round budget must not be exhausted.
    func allowsToolCall(usedRounds: Int, hasPlan: Bool) -> Bool {
        guard allowsRound(usedRounds) else { return false }
        return requirePlanFirst ? hasPlan : true
    }
}
