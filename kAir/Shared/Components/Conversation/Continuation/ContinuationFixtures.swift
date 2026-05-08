//
//  ContinuationFixtures.swift
//  kAir
//
//  Sample ChatContinuationEvent instances for previews and the I1
//  test scaffold. Covers the four terminal outcomes and Mode A / Mode B
//  variants per Contracts/UX/continuation-runtime-v1.md §6.
//
//  Fixtures are non-localized; *Localized fields stay nil.
//

import Foundation

enum ContinuationFixtures {
    // MARK: - Completion

    static let completionSummaryOnly = ChatContinuationEvent(
        id: "music-continuation-001",
        surface: .music,
        outcome: .completion,
        renderEligible: true,
        summary: makeMusicSummary(tone: .completion),
        evidence: nil,
        nextStep: nil,
        createdAt: Date(timeIntervalSince1970: 1_715_000_000)
    )

    static let completionWithEvidence = ChatContinuationEvent(
        id: "music-continuation-002",
        surface: .music,
        outcome: .completion,
        renderEligible: true,
        summary: makeMusicSummary(tone: .completion),
        evidence: makeMusicEvidence(),
        nextStep: nil,
        createdAt: Date(timeIntervalSince1970: 1_715_000_100)
    )

    static let completionWithNextStepStrip = ChatContinuationEvent(
        id: "music-continuation-003",
        surface: .music,
        outcome: .completion,
        renderEligible: true,
        summary: makeMusicSummary(tone: .completion),
        evidence: nil,
        nextStep: makeNextStepStrip(),
        createdAt: Date(timeIntervalSince1970: 1_715_000_200)
    )

    static let completionWithNextStepPrimary = ChatContinuationEvent(
        id: "music-continuation-004",
        surface: .music,
        outcome: .completion,
        renderEligible: true,
        summary: makeMusicSummary(tone: .completion),
        evidence: nil,
        nextStep: makeNextStepPrimary(),
        createdAt: Date(timeIntervalSince1970: 1_715_000_300)
    )

    static let completionFull = ChatContinuationEvent(
        id: "music-continuation-005",
        surface: .music,
        outcome: .completion,
        renderEligible: true,
        summary: makeMusicSummary(tone: .completion),
        evidence: makeMusicEvidence(),
        nextStep: makeNextStepPrimary(),
        createdAt: Date(timeIntervalSince1970: 1_715_000_400)
    )

    // MARK: - Abandon

    static let abandonSummaryOnly = ChatContinuationEvent(
        id: "music-continuation-101",
        surface: .music,
        outcome: .abandon,
        renderEligible: true,
        summary: makeMusicSummary(tone: .abandon),
        evidence: nil,
        nextStep: nil,
        createdAt: Date(timeIntervalSince1970: 1_715_001_000)
    )

    static let abandonWithStrip = ChatContinuationEvent(
        id: "music-continuation-102",
        surface: .music,
        outcome: .abandon,
        renderEligible: true,
        summary: makeMusicSummary(tone: .abandon),
        evidence: nil,
        nextStep: makeNextStepStrip(),
        createdAt: Date(timeIntervalSince1970: 1_715_001_100)
    )

    // MARK: - Suppressed (renderEligible == false)

    static let dismissSuppressed = ChatContinuationEvent(
        id: "store-continuation-201",
        surface: .store,
        outcome: .dismiss,
        renderEligible: false,
        summary: nil,
        evidence: nil,
        nextStep: nil,
        createdAt: Date(timeIntervalSince1970: 1_715_002_000)
    )

    static let acceptNoEntrySuppressed = ChatContinuationEvent(
        id: "ai-continuation-301",
        surface: .ai,
        outcome: .acceptNoEntry,
        renderEligible: false,
        summary: nil,
        evidence: nil,
        nextStep: nil,
        createdAt: Date(timeIntervalSince1970: 1_715_003_000)
    )

    // MARK: - Builders

    private static func makeMusicSummary(tone: OutcomeTone) -> SystemSummaryPayload {
        SystemSummaryPayload(
            eyebrow: EyebrowDescriptor(
                label: "Music",
                labelLocalized: nil,
                glyphName: "music.note"
            ),
            title: tone == .completion ? "Music wrote back to chat" : "Music closed without playing",
            summary: tone == .completion
                ? "Queued Sunset Drive on the focus mix and kept the original thread context."
                : "You opened Music but didn't start a track. Nothing was queued.",
            metrics: [
                Metric(
                    key: "Track",
                    value: tone == .completion ? "Sunset Drive" : "—",
                    keyLocalized: nil,
                    valueLocalized: nil
                ),
                Metric(
                    key: "Mode",
                    value: tone == .completion ? "Focus" : "Idle",
                    keyLocalized: nil,
                    valueLocalized: nil
                ),
                Metric(
                    key: "Thread",
                    value: "Original thread kept",
                    keyLocalized: nil,
                    valueLocalized: nil
                )
            ],
            continuityMetricIndex: 2,
            footer: tone == .completion
                ? "Continuity preserved. No surface forks."
                : "No session was created. The thread is unchanged.",
            outcomeTone: tone
        )
    }

    private static func makeMusicEvidence() -> SystemEvidencePayload {
        SystemEvidencePayload(
            eyebrow: "Detail",
            eyebrowLocalized: nil,
            pairs: [
                EvidencePair(
                    label: "Resolved",
                    value: "Sunset Drive — Aurora Skies",
                    labelLocalized: nil,
                    valueLocalized: nil
                ),
                EvidencePair(
                    label: "Mix",
                    value: "Focus · 42 minutes",
                    labelLocalized: nil,
                    valueLocalized: nil
                ),
                EvidencePair(
                    label: "Source",
                    value: "Local library",
                    labelLocalized: nil,
                    valueLocalized: nil
                )
            ]
        )
    }

    private static func makeNextStepStrip() -> NextStepPromptPayload {
        NextStepPromptPayload(
            eyebrow: "Pick up here",
            eyebrowLocalized: nil,
            mode: .chipStrip,
            primary: nil,
            secondaryChips: [
                NextStepChip(
                    label: "Save mix",
                    labelLocalized: nil,
                    glyphName: "bookmark",
                    action: .sendPrompt(text: "Save this mix to my library")
                ),
                NextStepChip(
                    label: "Skip track",
                    labelLocalized: nil,
                    glyphName: "forward.end",
                    action: .sendPrompt(text: "Skip the current track")
                ),
                NextStepChip(
                    label: "Share",
                    labelLocalized: nil,
                    glyphName: "square.and.arrow.up",
                    action: .sendPrompt(text: "Share this mix with a friend")
                )
            ]
        )
    }

    private static func makeNextStepPrimary() -> NextStepPromptPayload {
        NextStepPromptPayload(
            eyebrow: "Pick up here",
            eyebrowLocalized: nil,
            mode: .primaryWithSecondary,
            primary: NextStepChip(
                label: "Save to thread",
                labelLocalized: nil,
                glyphName: "bookmark.fill",
                action: .sendPrompt(text: "Save this mix to the current thread")
            ),
            secondaryChips: [
                NextStepChip(
                    label: "Skip track",
                    labelLocalized: nil,
                    glyphName: "forward.end",
                    action: .sendPrompt(text: "Skip the current track")
                ),
                NextStepChip(
                    label: "Share",
                    labelLocalized: nil,
                    glyphName: "square.and.arrow.up",
                    action: .sendPrompt(text: "Share this mix")
                )
            ]
        )
    }
}
