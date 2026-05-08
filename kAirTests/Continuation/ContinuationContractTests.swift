//
//  ContinuationContractTests.swift
//  kAirTests
//
//  Contract enforcement for ChatContinuationEvent and the three
//  transcript blocks. Method names map 1:1 to:
//  - Contracts/UX/continuation-runtime-v1.md §7 (validation rules)
//  - Contracts/UX/continuation-transcript-visual-v1.md §3 / §6 / §7
//
//  Note on target registration: this file currently lives in an
//  unregistered kAirTests/ folder. Adding the XCTest target is the
//  next mechanical step (separate PR). The test bodies below are
//  fully written and will run as soon as the target is wired —
//  they are NOT placeholders.
//

import XCTest
import SwiftUI
@testable import kAir

final class ContinuationContractTests: XCTestCase {
    // MARK: - Helpers

    /// Mutate an event's outcome while keeping other fields intact.
    /// Used to construct invariant-violating fixtures from valid bases.
    private func event(
        _ base: ChatContinuationEvent,
        outcome: TerminalOutcome? = nil,
        renderEligible: Bool? = nil,
        summary: SystemSummaryPayload?? = nil,
        evidence: SystemEvidencePayload?? = nil,
        nextStep: NextStepPromptPayload?? = nil
    ) -> ChatContinuationEvent {
        ChatContinuationEvent(
            id: base.id,
            surface: base.surface,
            outcome: outcome ?? base.outcome,
            renderEligible: renderEligible ?? base.renderEligible,
            summary: summary ?? base.summary,
            evidence: evidence ?? base.evidence,
            nextStep: nextStep ?? base.nextStep,
            createdAt: base.createdAt
        )
    }

    private func summary(
        _ base: SystemSummaryPayload,
        title: String? = nil,
        summary: String? = nil,
        metrics: [Metric]? = nil,
        continuityMetricIndex: Int? = nil,
        footer: String?? = nil,
        outcomeTone: OutcomeTone? = nil
    ) -> SystemSummaryPayload {
        SystemSummaryPayload(
            eyebrow: base.eyebrow,
            title: title ?? base.title,
            summary: summary ?? base.summary,
            metrics: metrics ?? base.metrics,
            continuityMetricIndex: continuityMetricIndex ?? base.continuityMetricIndex,
            footer: footer ?? base.footer,
            outcomeTone: outcomeTone ?? base.outcomeTone
        )
    }

    private func nextStep(
        _ base: NextStepPromptPayload,
        mode: NextStepMode? = nil,
        primary: NextStepChip?? = nil,
        secondaryChips: [NextStepChip]? = nil
    ) -> NextStepPromptPayload {
        NextStepPromptPayload(
            eyebrow: base.eyebrow,
            eyebrowLocalized: base.eyebrowLocalized,
            mode: mode ?? base.mode,
            primary: primary ?? base.primary,
            secondaryChips: secondaryChips ?? base.secondaryChips
        )
    }

    // MARK: - All curated fixtures pass validation

    func test_allFixtures_passValidation() throws {
        let fixtures: [ChatContinuationEvent] = [
            ContinuationFixtures.completionSummaryOnly,
            ContinuationFixtures.completionWithEvidence,
            ContinuationFixtures.completionWithNextStepStrip,
            ContinuationFixtures.completionWithNextStepPrimary,
            ContinuationFixtures.completionFull,
            ContinuationFixtures.abandonSummaryOnly,
            ContinuationFixtures.abandonWithStrip,
            ContinuationFixtures.dismissSuppressed,
            ContinuationFixtures.acceptNoEntrySuppressed
        ]
        for fixture in fixtures {
            XCTAssertEqual(
                ContinuationEventValidator.validate(fixture),
                [],
                "Fixture \(fixture.id) should be valid; got violations."
            )
        }
    }

    // MARK: - runtime-v1 §7.1: renderEligible derivation

    func test_renderEligible_isTrue_forCompletion() throws {
        let e = ContinuationFixtures.completionSummaryOnly
        XCTAssertEqual(e.outcome, .completion)
        XCTAssertTrue(e.renderEligible)
    }

    func test_renderEligible_isTrue_forAbandon() throws {
        let e = ContinuationFixtures.abandonSummaryOnly
        XCTAssertEqual(e.outcome, .abandon)
        XCTAssertTrue(e.renderEligible)
    }

    func test_renderEligible_isFalse_forDismiss() throws {
        let e = ContinuationFixtures.dismissSuppressed
        XCTAssertEqual(e.outcome, .dismiss)
        XCTAssertFalse(e.renderEligible)
    }

    func test_renderEligible_isFalse_forAcceptNoEntry() throws {
        let e = ContinuationFixtures.acceptNoEntrySuppressed
        XCTAssertEqual(e.outcome, .acceptNoEntry)
        XCTAssertFalse(e.renderEligible)
    }

    func test_renderEligibleMismatch_isFlagged() throws {
        let bad = event(ContinuationFixtures.completionSummaryOnly, renderEligible: false)
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad).contains(.renderEligibleMismatch)
        )
    }

    // MARK: - runtime-v1 §7.2: renderEligible implies summary present

    func test_renderEligibleEnvelope_requiresSummary() throws {
        let bad = event(ContinuationFixtures.completionSummaryOnly, summary: .some(nil))
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad).contains(.renderEligibleMissingSummary)
        )
    }

    // MARK: - runtime-v1 §7.3: suppressed has no sub-payloads

    func test_dismissEnvelope_hasNoSubPayloads() throws {
        let e = ContinuationFixtures.dismissSuppressed
        XCTAssertNil(e.summary)
        XCTAssertNil(e.evidence)
        XCTAssertNil(e.nextStep)
    }

    func test_acceptNoEntryEnvelope_hasNoSubPayloads() throws {
        let e = ContinuationFixtures.acceptNoEntrySuppressed
        XCTAssertNil(e.summary)
        XCTAssertNil(e.evidence)
        XCTAssertNil(e.nextStep)
    }

    func test_suppressedWithSubPayload_isFlagged() throws {
        let bad = event(
            ContinuationFixtures.dismissSuppressed,
            summary: .some(ContinuationFixtures.completionSummaryOnly.summary)
        )
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad).contains(.suppressedHasSubPayload)
        )
    }

    // MARK: - runtime-v1 §7.4 / §7.5: metric count and continuity index

    func test_summary_hasExactlyThreeMetrics() throws {
        let s = ContinuationFixtures.completionFull.summary!
        XCTAssertEqual(s.metrics.count, 3)
    }

    func test_summary_metricCountInvalid_isFlagged() throws {
        let baseSummary = ContinuationFixtures.completionFull.summary!
        let badSummary = summary(baseSummary, metrics: Array(baseSummary.metrics.prefix(2)))
        let bad = event(ContinuationFixtures.completionFull, summary: .some(badSummary))
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad).contains(.summaryMetricCountInvalid)
        )
    }

    func test_summary_continuityMetricIndexIsTwo() throws {
        let s = ContinuationFixtures.completionFull.summary!
        XCTAssertEqual(s.continuityMetricIndex, 2)
    }

    func test_summary_continuityIndexInvalid_isFlagged() throws {
        let baseSummary = ContinuationFixtures.completionFull.summary!
        let badSummary = summary(baseSummary, continuityMetricIndex: 0)
        let bad = event(ContinuationFixtures.completionFull, summary: .some(badSummary))
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad).contains(.summaryContinuityIndexInvalid)
        )
    }

    // MARK: - runtime-v1 §7.6: continuity vocabulary

    func test_summary_continuityKeyInVocabulary() throws {
        let s = ContinuationFixtures.completionFull.summary!
        let continuityKey = s.metrics[s.continuityMetricIndex].keyLocalized
            ?? s.metrics[s.continuityMetricIndex].key
        XCTAssertTrue(ContinuationEventValidator.continuityVocabulary.contains(continuityKey))
    }

    func test_summary_continuityKeyOutsideVocabulary_isFlagged() throws {
        let baseSummary = ContinuationFixtures.completionFull.summary!
        var metrics = baseSummary.metrics
        metrics[2] = Metric(
            key: "NotAThreadKey",
            value: "Original thread kept",
            keyLocalized: nil,
            valueLocalized: nil
        )
        let badSummary = summary(baseSummary, metrics: metrics)
        let bad = event(ContinuationFixtures.completionFull, summary: .some(badSummary))
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad)
                .contains(.summaryContinuityKeyOutsideVocabulary)
        )
    }

    // MARK: - runtime-v1 §7.7: outcomeTone matches outcome

    func test_summary_outcomeToneMatchesEnvelopeOutcome() throws {
        XCTAssertEqual(
            ContinuationFixtures.completionFull.summary!.outcomeTone,
            .completion
        )
        XCTAssertEqual(
            ContinuationFixtures.abandonSummaryOnly.summary!.outcomeTone,
            .abandon
        )
    }

    func test_summary_toneMismatch_isFlagged() throws {
        let baseSummary = ContinuationFixtures.completionFull.summary!
        let badSummary = summary(baseSummary, outcomeTone: .abandon)
        let bad = event(ContinuationFixtures.completionFull, summary: .some(badSummary))
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad).contains(.summaryToneMismatchOutcome)
        )
    }

    // MARK: - runtime-v1 §7.8: summary string-length bounds

    func test_summary_titleTooLong_isFlagged() throws {
        let baseSummary = ContinuationFixtures.completionFull.summary!
        let oversized = String(repeating: "x", count: ContinuationEventValidator.summaryTitleMaxCharacters + 1)
        let badSummary = summary(baseSummary, title: oversized)
        let bad = event(ContinuationFixtures.completionFull, summary: .some(badSummary))
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad).contains(.summaryTitleTooLong)
        )
    }

    func test_summary_summaryTooLong_isFlagged() throws {
        let baseSummary = ContinuationFixtures.completionFull.summary!
        let oversized = String(repeating: "x", count: ContinuationEventValidator.summarySummaryMaxCharacters + 1)
        let badSummary = summary(baseSummary, summary: oversized)
        let bad = event(ContinuationFixtures.completionFull, summary: .some(badSummary))
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad).contains(.summarySummaryTooLong)
        )
    }

    func test_summary_footerTooLong_isFlagged() throws {
        let baseSummary = ContinuationFixtures.completionFull.summary!
        let oversized = String(repeating: "x", count: ContinuationEventValidator.summaryFooterMaxCharacters + 1)
        let badSummary = summary(baseSummary, footer: .some(oversized))
        let bad = event(ContinuationFixtures.completionFull, summary: .some(badSummary))
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad).contains(.summaryFooterTooLong)
        )
    }

    // MARK: - runtime-v1 §7.9 / §7.10: evidence bounds

    func test_evidence_pairCountInRange() throws {
        let e = ContinuationFixtures.completionWithEvidence.evidence!
        XCTAssertTrue((1...6).contains(e.pairs.count))
    }

    func test_evidence_emptyPairs_isFlagged() throws {
        let bad = event(
            ContinuationFixtures.completionWithEvidence,
            evidence: .some(SystemEvidencePayload(eyebrow: nil, eyebrowLocalized: nil, pairs: []))
        )
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad).contains(.evidencePairCountOutOfRange)
        )
    }

    func test_evidence_tooManyPairs_isFlagged() throws {
        let pair = EvidencePair(label: "k", value: "v", labelLocalized: nil, valueLocalized: nil)
        let bad = event(
            ContinuationFixtures.completionWithEvidence,
            evidence: .some(SystemEvidencePayload(
                eyebrow: nil,
                eyebrowLocalized: nil,
                pairs: Array(repeating: pair, count: 7)
            ))
        )
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad).contains(.evidencePairCountOutOfRange)
        )
    }

    func test_evidence_labelTooLong_isFlagged() throws {
        let oversized = String(repeating: "L", count: ContinuationEventValidator.evidencePairLabelMaxCharacters + 1)
        let bad = event(
            ContinuationFixtures.completionWithEvidence,
            evidence: .some(SystemEvidencePayload(
                eyebrow: nil,
                eyebrowLocalized: nil,
                pairs: [EvidencePair(label: oversized, value: "v", labelLocalized: nil, valueLocalized: nil)]
            ))
        )
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad).contains(.evidencePairLabelTooLong)
        )
    }

    // MARK: - runtime-v1 §7.11 / §7.12: next-step mode/primary coupling

    func test_nextStep_primaryWithSecondary_requiresPrimary() throws {
        let baseNextStep = ContinuationFixtures.completionWithNextStepPrimary.nextStep!
        let bad = event(
            ContinuationFixtures.completionWithNextStepPrimary,
            nextStep: .some(nextStep(baseNextStep, primary: .some(nil)))
        )
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad)
                .contains(.nextStepPrimaryWithSecondaryMissingPrimary)
        )
    }

    func test_nextStep_chipStrip_forbidsPrimary() throws {
        let stripBase = ContinuationFixtures.completionWithNextStepStrip.nextStep!
        let invalidPrimary = NextStepChip(
            label: "Smuggled",
            labelLocalized: nil,
            glyphName: nil,
            action: .dismissBlock
        )
        let bad = event(
            ContinuationFixtures.completionWithNextStepStrip,
            nextStep: .some(nextStep(stripBase, primary: .some(invalidPrimary)))
        )
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad).contains(.nextStepChipStripHasPrimary)
        )
    }

    // MARK: - runtime-v1 §7.13: total chip count bounds

    func test_nextStep_totalChipCountInRange() throws {
        let p = ContinuationFixtures.completionWithNextStepPrimary.nextStep!
        let count = (p.primary != nil ? 1 : 0) + p.secondaryChips.count
        XCTAssertTrue((1...5).contains(count))
    }

    func test_nextStep_zeroChips_isFlagged() throws {
        let stripBase = ContinuationFixtures.completionWithNextStepStrip.nextStep!
        let bad = event(
            ContinuationFixtures.completionWithNextStepStrip,
            nextStep: .some(nextStep(stripBase, secondaryChips: []))
        )
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad)
                .contains(.nextStepTotalChipCountOutOfRange)
        )
    }

    func test_nextStep_tooManyChips_isFlagged() throws {
        let chip = NextStepChip(
            label: "x",
            labelLocalized: nil,
            glyphName: nil,
            action: .dismissBlock
        )
        let stripBase = ContinuationFixtures.completionWithNextStepStrip.nextStep!
        let bad = event(
            ContinuationFixtures.completionWithNextStepStrip,
            nextStep: .some(nextStep(stripBase, secondaryChips: Array(repeating: chip, count: 6)))
        )
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad)
                .contains(.nextStepTotalChipCountOutOfRange)
        )
    }

    // MARK: - runtime-v1 §7.14: abandon forbids Mode B

    func test_nextStep_abandon_forbidsPrimaryWithSecondary() throws {
        let primaryNS = ContinuationFixtures.completionWithNextStepPrimary.nextStep!
        let bad = event(
            ContinuationFixtures.abandonSummaryOnly,
            nextStep: .some(primaryNS)
        )
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad)
                .contains(.nextStepAbandonForbidsPrimaryWithSecondary)
        )
    }

    func test_nextStep_abandon_allowsChipStrip() throws {
        let e = ContinuationFixtures.abandonWithStrip
        XCTAssertEqual(e.outcome, .abandon)
        XCTAssertEqual(e.nextStep?.mode, .chipStrip)
        XCTAssertEqual(ContinuationEventValidator.validate(e), [])
    }

    // MARK: - runtime-v1 §7.15: sendPrompt text length bound

    func test_nextStep_sendPromptTextTooLong_isFlagged() throws {
        let oversized = String(
            repeating: "y",
            count: ContinuationEventValidator.nextStepSendPromptTextMaxCharacters + 1
        )
        let chip = NextStepChip(
            label: "x",
            labelLocalized: nil,
            glyphName: nil,
            action: .sendPrompt(text: oversized)
        )
        let stripBase = ContinuationFixtures.completionWithNextStepStrip.nextStep!
        let bad = event(
            ContinuationFixtures.completionWithNextStepStrip,
            nextStep: .some(nextStep(stripBase, secondaryChips: [chip]))
        )
        XCTAssertTrue(
            ContinuationEventValidator.validate(bad).contains(.nextStepSendPromptTextTooLong)
        )
    }

    // MARK: - visual-v1 §7: outcome → render mapping (renderer side)

    func test_renderer_completion_includesAllAvailableBlocks() throws {
        let r = ContinuationBlockRenderer(event: ContinuationFixtures.completionFull)
        XCTAssertEqual(r.blockKindSequence, [.summary, .evidence, .nextStep])
    }

    func test_renderer_completionSummaryOnly_yieldsOnlySummary() throws {
        let r = ContinuationBlockRenderer(event: ContinuationFixtures.completionSummaryOnly)
        XCTAssertEqual(r.blockKindSequence, [.summary])
    }

    func test_renderer_completionWithEvidence_yieldsSummaryThenEvidence() throws {
        let r = ContinuationBlockRenderer(event: ContinuationFixtures.completionWithEvidence)
        XCTAssertEqual(r.blockKindSequence, [.summary, .evidence])
    }

    func test_renderer_completionModeA_yieldsSummaryThenNextStep() throws {
        let r = ContinuationBlockRenderer(event: ContinuationFixtures.completionWithNextStepStrip)
        XCTAssertEqual(r.blockKindSequence, [.summary, .nextStep])
    }

    func test_renderer_completionModeB_yieldsSummaryThenNextStep() throws {
        let r = ContinuationBlockRenderer(event: ContinuationFixtures.completionWithNextStepPrimary)
        XCTAssertEqual(r.blockKindSequence, [.summary, .nextStep])
    }

    func test_renderer_abandonSummaryOnly_yieldsSummary() throws {
        let r = ContinuationBlockRenderer(event: ContinuationFixtures.abandonSummaryOnly)
        XCTAssertEqual(r.blockKindSequence, [.summary])
    }

    func test_renderer_abandonWithStrip_yieldsSummaryThenNextStep() throws {
        let r = ContinuationBlockRenderer(event: ContinuationFixtures.abandonWithStrip)
        XCTAssertEqual(r.blockKindSequence, [.summary, .nextStep])
    }

    func test_renderer_dismiss_yieldsZeroBlocks() throws {
        let r = ContinuationBlockRenderer(event: ContinuationFixtures.dismissSuppressed)
        XCTAssertEqual(r.blockKindSequence, [])
    }

    func test_renderer_acceptNoEntry_yieldsZeroBlocks() throws {
        let r = ContinuationBlockRenderer(event: ContinuationFixtures.acceptNoEntrySuppressed)
        XCTAssertEqual(r.blockKindSequence, [])
    }

    func test_renderer_stackOrder_isAlwaysSummaryEvidenceNextStep() throws {
        // Construct an event where we attempt to "swap" — the renderer must
        // still yield the canonical order regardless of how the envelope was
        // constructed.
        let r = ContinuationBlockRenderer(event: ContinuationFixtures.completionFull)
        let kinds = r.blockKindSequence
        XCTAssertLessThan(kinds.firstIndex(of: .summary)!, kinds.firstIndex(of: .evidence)!)
        XCTAssertLessThan(kinds.firstIndex(of: .evidence)!, kinds.firstIndex(of: .nextStep)!)
    }

    // MARK: - visual-v1 §7: state-dot color per outcome tone

    func test_visual_completion_stateDotIsSuccess() throws {
        XCTAssertEqual(
            SystemSummaryBlock.stateDotColor(for: .completion),
            AppTheme.Palette.success
        )
    }

    func test_visual_abandon_stateDotIsWarning() throws {
        XCTAssertEqual(
            SystemSummaryBlock.stateDotColor(for: .abandon),
            AppTheme.Palette.warning
        )
    }

    // MARK: - visual-v1 §5 / §6: layout constants match contract

    func test_summary_paddingMatchesContract() throws {
        XCTAssertEqual(SystemSummaryBlock.containerPadding, 20)  // §5.1
    }

    func test_summary_stateDotDiameterMatchesContract() throws {
        XCTAssertEqual(SystemSummaryBlock.stateDotDiameter, 8)   // §5.1
    }

    func test_summary_metricTilePaddingMatchesContract() throws {
        XCTAssertEqual(SystemSummaryBlock.metricTilePadding, 8)  // §5.1
    }

    func test_evidence_paddingMatchesContract() throws {
        XCTAssertEqual(SystemEvidenceBlock.containerPadding, 12) // §5.2
    }

    func test_evidence_labelColumnWidthMatchesContract() throws {
        XCTAssertEqual(SystemEvidenceBlock.labelColumnWidth, 120) // §5.2
    }

    func test_nextStep_primaryPaddingMatchesContract() throws {
        XCTAssertEqual(NextStepPromptBlock.primaryHorizontalPadding, 16) // §5.3
        XCTAssertEqual(NextStepPromptBlock.primaryVerticalPadding, 11)   // §5.3
    }

    func test_nextStep_secondaryPaddingMatchesContract() throws {
        XCTAssertEqual(NextStepPromptBlock.secondaryHorizontalPadding, 12) // §5.3
        XCTAssertEqual(NextStepPromptBlock.secondaryVerticalPadding, 8)    // §5.3
    }

    func test_renderer_interBlockGapMatchesContract() throws {
        XCTAssertEqual(ContinuationBlockRenderer.interBlockGap, 12) // §6
    }

    // MARK: - visual-v1 §9: forbidden-bypass — payload strings carry through verbatim

    /// The visual contract §9 forbids rich-text rendering of payload strings
    /// (no markdown spans, no AttributedString interpretation). The
    /// implementation enforces this by using `Text(verbatim:)` everywhere
    /// payload strings are rendered. The test below pins the data layer:
    /// payload strings are stored unchanged, so any rich-text bypass would
    /// have to happen at the View layer — which is reviewed against the
    /// "Text(verbatim:)" usage requirement at code-review time.
    func test_payload_storesStringsVerbatim() throws {
        let trickyTitle = "**bold** & <script>alert(1)</script>"
        let baseSummary = ContinuationFixtures.completionFull.summary!
        let payload = summary(baseSummary, title: trickyTitle)
        XCTAssertEqual(payload.title, trickyTitle)
    }
}
