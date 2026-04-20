//
//  StructuredOutputParser.swift
//  kAir
//
//  Protocol: parse a raw model string into a frozen StructuredToolSelection.
//  Stub-only — no implementation is bound into the product flow yet.
//

import Foundation

enum StructuredOutputParserError: Error, Hashable, Sendable {
    case parseFailure(String)
    case schemaFailure(String)
    case unsupported(String)
}

protocol StructuredOutputParser: Sendable {
    func parse(_ rawText: String) -> Result<StructuredToolSelection, StructuredOutputParserError>
}
