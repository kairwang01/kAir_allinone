//
//  LiveResidualLedgerEntry.swift
//  kAir
//
//  Authoritative machine-readable live residual ledger for matching replay.
//  Replaces markdown-as-source-of-truth for near-miss / candidate-miss / weak-trace accounting.
//  Replay summary, residual counts, direct-slot audit, and weak-trace breakdown all read from this.
//

import Foundation

enum ResidualType: String, Codable, Hashable, Sendable {
    case directMatch = "direct_match"
    case recoveredDirectSlot = "recovered_direct_slot"
    case nearMiss = "near_miss"
    case candidateMiss = "candidate_miss"
    case weakTrace = "weak_trace"
}

enum ResidualRootCause: String, Codable, Hashable, Sendable {
    case scorer
    case composerDiversifier = "composer_diversifier"
    case provider
    case unknown
}

struct LiveResidualLedgerEntry: Codable, Hashable, Sendable {
    let caseId: String
    let sessionId: String
    let objectType: String
    let surface: String
    let expectedCandidateId: String
    let top1CandidateId: String?
    let expectedRank: Int?
    let isInTopK: Bool
    let isDirectSlot: Bool
    let residualType: ResidualType
    let rootCause: ResidualRootCause
    let dominantBucket: String?
    let scoreBreakdownExpected: ScoreContributionBreakdown?
    let scoreBreakdownTop1: ScoreContributionBreakdown?
    let policyVersion: String
}

struct LiveResidualLedger: Codable, Hashable, Sendable {
    let baselineArtifactVersion: String
    let policyVersion: MatchingPolicyVersion
    let generatedAt: Date
    let entries: [LiveResidualLedgerEntry]

    var nearMissCount: Int { entries.filter { $0.residualType == .nearMiss }.count }
    var candidateMissCount: Int { entries.filter { $0.residualType == .candidateMiss }.count }
    var weakTraceCount: Int { entries.filter { $0.residualType == .weakTrace }.count }
    var recoveredCount: Int { entries.filter { $0.residualType == .recoveredDirectSlot }.count }
    var directMatchCount: Int { entries.filter { $0.residualType == .directMatch }.count }

    static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func encodeJSONData() throws -> Data {
        try Self.jsonEncoder().encode(self)
    }

    static func decode(from data: Data) throws -> LiveResidualLedger {
        try jsonDecoder().decode(LiveResidualLedger.self, from: data)
    }
}
