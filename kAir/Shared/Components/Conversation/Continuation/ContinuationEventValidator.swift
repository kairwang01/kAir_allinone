//
//  ContinuationEventValidator.swift
//  kAir
//
//  Pure-function validator for ChatContinuationEvent invariants.
//  One-to-one with Contracts/UX/continuation-runtime-v1.md §7.
//
//  No side effects; no UI dependency. Used by the contract tests and may
//  be reused by the runtime emit path in a later iteration.
//

import Foundation

enum ContinuationEventViolation: Hashable {
    case renderEligibleMismatch                       // §7.1
    case renderEligibleMissingSummary                 // §7.2
    case suppressedHasSubPayload                      // §7.3
    case summaryMetricCountInvalid                    // §7.4
    case summaryContinuityIndexInvalid                // §7.5
    case summaryContinuityKeyOutsideVocabulary        // §7.6
    case summaryToneMismatchOutcome                   // §7.7
    case summaryTitleTooLong                          // §7.8
    case summarySummaryTooLong                        // §7.8
    case summaryFooterTooLong                         // §7.8
    case evidencePairCountOutOfRange                  // §7.9
    case evidencePairLabelTooLong                     // §7.10
    case evidencePairValueTooLong                     // §7.10
    case nextStepPrimaryWithSecondaryMissingPrimary   // §7.11
    case nextStepChipStripHasPrimary                  // §7.12
    case nextStepTotalChipCountOutOfRange             // §7.13
    case nextStepAbandonForbidsPrimaryWithSecondary   // §7.14
    case nextStepSendPromptTextTooLong                // §7.15
}

enum ContinuationEventValidator {
    /// Locked vocabulary for the continuity-metric key, per
    /// Contracts/UX/post-return-and-continuation-ux-v1.md §2.2.
    static let continuityVocabulary: Set<String> = ["Thread", "线程"]

    static let summaryTitleMaxCharacters: Int = 80
    static let summarySummaryMaxCharacters: Int = 240
    static let summaryFooterMaxCharacters: Int = 120
    static let evidencePairLabelMaxCharacters: Int = 32
    static let evidencePairValueMaxCharacters: Int = 240
    static let nextStepSendPromptTextMaxCharacters: Int = 200
    static let evidencePairCountRange: ClosedRange<Int> = 1...6
    static let nextStepTotalChipRange: ClosedRange<Int> = 1...5

    static func validate(_ event: ChatContinuationEvent) -> [ContinuationEventViolation] {
        var violations: [ContinuationEventViolation] = []

        // §7.1 renderEligible derivation
        let expectedRenderEligible = (event.outcome == .completion || event.outcome == .abandon)
        if event.renderEligible != expectedRenderEligible {
            violations.append(.renderEligibleMismatch)
        }

        if event.renderEligible {
            // §7.2 renderEligible implies summary present
            if event.summary == nil {
                violations.append(.renderEligibleMissingSummary)
            }
        } else {
            // §7.3 suppressed event carries no sub-payloads
            if event.summary != nil || event.evidence != nil || event.nextStep != nil {
                violations.append(.suppressedHasSubPayload)
            }
        }

        if let summary = event.summary {
            violations.append(contentsOf: validateSummary(summary, outcome: event.outcome))
        }

        if let evidence = event.evidence {
            violations.append(contentsOf: validateEvidence(evidence))
        }

        if let nextStep = event.nextStep {
            violations.append(contentsOf: validateNextStep(nextStep, outcome: event.outcome))
        }

        return violations
    }

    private static func validateSummary(
        _ summary: SystemSummaryPayload,
        outcome: TerminalOutcome
    ) -> [ContinuationEventViolation] {
        var violations: [ContinuationEventViolation] = []

        // §7.4
        if summary.metrics.count != 3 {
            violations.append(.summaryMetricCountInvalid)
        }
        // §7.5
        if summary.continuityMetricIndex != 2 {
            violations.append(.summaryContinuityIndexInvalid)
        }
        // §7.6 (only checked when index is valid)
        if summary.metrics.count == 3,
           summary.continuityMetricIndex >= 0,
           summary.continuityMetricIndex < summary.metrics.count {
            let continuity = summary.metrics[summary.continuityMetricIndex]
            let key = continuity.keyLocalized ?? continuity.key
            if !continuityVocabulary.contains(key) {
                violations.append(.summaryContinuityKeyOutsideVocabulary)
            }
        }
        // §7.7
        let expectedTone: OutcomeTone? = {
            switch outcome {
            case .completion: return .completion
            case .abandon: return .abandon
            case .dismiss, .acceptNoEntry: return nil
            }
        }()
        if let expectedTone, summary.outcomeTone != expectedTone {
            violations.append(.summaryToneMismatchOutcome)
        }
        // §7.8
        if summary.title.count > summaryTitleMaxCharacters {
            violations.append(.summaryTitleTooLong)
        }
        if summary.summary.count > summarySummaryMaxCharacters {
            violations.append(.summarySummaryTooLong)
        }
        if let footer = summary.footer, footer.count > summaryFooterMaxCharacters {
            violations.append(.summaryFooterTooLong)
        }

        return violations
    }

    private static func validateEvidence(
        _ evidence: SystemEvidencePayload
    ) -> [ContinuationEventViolation] {
        var violations: [ContinuationEventViolation] = []

        // §7.9
        if evidencePairCountRange.contains(evidence.pairs.count) == false {
            violations.append(.evidencePairCountOutOfRange)
        }
        // §7.10
        if evidence.pairs.contains(where: { $0.label.count > evidencePairLabelMaxCharacters }) {
            violations.append(.evidencePairLabelTooLong)
        }
        if evidence.pairs.contains(where: { $0.value.count > evidencePairValueMaxCharacters }) {
            violations.append(.evidencePairValueTooLong)
        }

        return violations
    }

    private static func validateNextStep(
        _ nextStep: NextStepPromptPayload,
        outcome: TerminalOutcome
    ) -> [ContinuationEventViolation] {
        var violations: [ContinuationEventViolation] = []

        // §7.11
        if nextStep.mode == .primaryWithSecondary && nextStep.primary == nil {
            violations.append(.nextStepPrimaryWithSecondaryMissingPrimary)
        }
        // §7.12
        if nextStep.mode == .chipStrip && nextStep.primary != nil {
            violations.append(.nextStepChipStripHasPrimary)
        }
        // §7.13
        let totalChips = (nextStep.primary != nil ? 1 : 0) + nextStep.secondaryChips.count
        if nextStepTotalChipRange.contains(totalChips) == false {
            violations.append(.nextStepTotalChipCountOutOfRange)
        }
        // §7.14
        if outcome == .abandon && nextStep.mode == .primaryWithSecondary {
            violations.append(.nextStepAbandonForbidsPrimaryWithSecondary)
        }
        // §7.15
        let allChips = (nextStep.primary.map { [$0] } ?? []) + nextStep.secondaryChips
        let exceedsSendPromptLimit = allChips.contains { chip in
            if case .sendPrompt(let text) = chip.action {
                return text.count > nextStepSendPromptTextMaxCharacters
            }
            return false
        }
        if exceedsSendPromptLimit {
            violations.append(.nextStepSendPromptTextTooLong)
        }

        return violations
    }
}
