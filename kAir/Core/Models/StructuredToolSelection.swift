//
//  StructuredToolSelection.swift
//  kAir
//
//  Frozen output shape for structured tool selection. Parser, router, replay,
//  and any future local / cloud adapter MUST produce and consume this exact
//  type. Do not extend in-place — add a new versioned type if the shape
//  needs to change.
//

import Foundation

enum StructuredToolSelectionReasonCode: String, Codable, CaseIterable, Hashable, Sendable {
    case directMatch
    case ambiguous
    case insufficientContext
    case belowConfidence
    case unsupported
    case parseFailure
    case clarificationRequested
    case unknown
}

struct StructuredToolSelection: Codable, Hashable, Sendable {
    let tool: String
    let args: [String: String]
    let needsClarification: Bool
    let clarificationQuestion: String?
    let confidence: Double
    let reasonCode: StructuredToolSelectionReasonCode

    init(
        tool: String,
        args: [String: String] = [:],
        needsClarification: Bool = false,
        clarificationQuestion: String? = nil,
        confidence: Double = 0,
        reasonCode: StructuredToolSelectionReasonCode = .unknown
    ) {
        self.tool = tool
        self.args = args
        self.needsClarification = needsClarification
        self.clarificationQuestion = clarificationQuestion
        self.confidence = confidence
        self.reasonCode = reasonCode
    }

    static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func jsonDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    func encodeJSONData() throws -> Data {
        try Self.jsonEncoder().encode(self)
    }

    static func decode(from data: Data) throws -> StructuredToolSelection {
        try jsonDecoder().decode(StructuredToolSelection.self, from: data)
    }
}
