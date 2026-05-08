//
//  ChatContinuationEvent.swift
//  kAir
//
//  Data shapes for transcript continuation blocks.
//  Mirrors Contracts/UX/continuation-runtime-v1.md §2–§5.
//
//  I1-prep: pure data types only. Validation, emission, and bridging
//  to ConversationMessage are I1's concern (see runtime-v1 §7, §8).
//

import Foundation

// MARK: - Envelope

struct ChatContinuationEvent: Hashable {
    let id: String
    let surface: SurfaceKind
    let outcome: TerminalOutcome
    let renderEligible: Bool
    let summary: SystemSummaryPayload?
    let evidence: SystemEvidencePayload?
    let nextStep: NextStepPromptPayload?
    let createdAt: Date
}

// MARK: - Vocabularies

enum TerminalOutcome: String, Hashable, CaseIterable {
    case completion
    case abandon
    case dismiss
    case acceptNoEntry
}

enum OutcomeTone: String, Hashable, CaseIterable {
    case completion
    case abandon
}

// MARK: - systemSummary

struct SystemSummaryPayload: Hashable {
    let eyebrow: EyebrowDescriptor?
    let title: String
    let summary: String
    let metrics: [Metric]
    let continuityMetricIndex: Int
    let footer: String?
    let outcomeTone: OutcomeTone
}

struct EyebrowDescriptor: Hashable {
    let label: String
    let labelLocalized: String?
    let glyphName: String?
}

struct Metric: Hashable {
    let key: String
    let value: String
    let keyLocalized: String?
    let valueLocalized: String?
}

// MARK: - systemEvidence

struct SystemEvidencePayload: Hashable {
    let eyebrow: String?
    let eyebrowLocalized: String?
    let pairs: [EvidencePair]
}

struct EvidencePair: Hashable {
    let label: String
    let value: String
    let labelLocalized: String?
    let valueLocalized: String?
}

// MARK: - nextStepPrompt

struct NextStepPromptPayload: Hashable {
    let eyebrow: String?
    let eyebrowLocalized: String?
    let mode: NextStepMode
    let primary: NextStepChip?
    let secondaryChips: [NextStepChip]
}

enum NextStepMode: String, Hashable {
    case chipStrip
    case primaryWithSecondary
}

struct NextStepChip: Hashable {
    let label: String
    let labelLocalized: String?
    let glyphName: String?
    let action: NextStepAction
}

enum NextStepAction: Hashable {
    case sendPrompt(text: String)
    case navigate(intent: NavigationIntent)
    case dismissBlock
}

struct NavigationIntent: Hashable {
    let identifier: String
}
