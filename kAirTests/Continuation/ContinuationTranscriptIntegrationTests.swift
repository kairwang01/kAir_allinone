//
//  ContinuationTranscriptIntegrationTests.swift
//  kAirTests
//
//  Integration tests for the I1.5 transcript wiring: a
//  ConversationMessage carrying a ChatContinuationEvent must produce
//  the correct ContinuationBlockKind sequence when rendered through
//  the single transcript entry point.
//
//  These tests do NOT introspect SwiftUI views; they pin the
//  contract at the data → render-decision boundary
//  (`ConversationMessage.continuationBlockKinds`), which is what the
//  ConversationInboxRow body branches on.
//

import XCTest
@testable import kAir

final class ContinuationTranscriptIntegrationTests: XCTestCase {
    // MARK: - Single render entry point: text-only messages unaffected

    func test_textOnlyAssistantMessage_yieldsZeroBlockKinds() throws {
        let message = ConversationMessage.assistant(text: "Hello.")
        XCTAssertNil(message.continuationEvent)
        XCTAssertEqual(message.continuationBlockKinds, [])
    }

    func test_textOnlyUserMessage_yieldsZeroBlockKinds() throws {
        let message = ConversationMessage.user(text: "Hi.")
        XCTAssertNil(message.continuationEvent)
        XCTAssertEqual(message.continuationBlockKinds, [])
    }

    func test_systemMessage_yieldsZeroBlockKinds() throws {
        let message = ConversationMessage.system(text: "Thread merged.")
        XCTAssertNil(message.continuationEvent)
        XCTAssertEqual(message.continuationBlockKinds, [])
    }

    func test_assistantMessage_withToolResults_butNoEvent_yieldsZeroBlockKinds() throws {
        let toolResult = ConversationToolResult(
            id: "x",
            title: "Legacy tool result",
            summary: "Legacy path — not a continuation event.",
            state: .ready,
            metrics: [],
            footer: nil
        )
        let message = ConversationMessage.assistant(
            text: "Done.",
            toolResults: [toolResult]
        )
        XCTAssertNil(message.continuationEvent)
        XCTAssertEqual(message.continuationBlockKinds, [])
    }

    // MARK: - Continuation messages: blocks appear in contract order

    func test_assistantMessage_withCompletionFullEvent_yieldsThreeBlocksInOrder() throws {
        let message = ConversationMessage.assistant(
            text: "",
            continuationEvent: ContinuationFixtures.completionFull
        )
        XCTAssertEqual(
            message.continuationBlockKinds,
            [.summary, .evidence, .nextStep]
        )
    }

    func test_assistantMessage_withCompletionSummaryOnly_yieldsOnlySummary() throws {
        let message = ConversationMessage.assistant(
            text: "",
            continuationEvent: ContinuationFixtures.completionSummaryOnly
        )
        XCTAssertEqual(message.continuationBlockKinds, [.summary])
    }

    func test_assistantMessage_withCompletionEvidence_yieldsSummaryThenEvidence() throws {
        let message = ConversationMessage.assistant(
            text: "",
            continuationEvent: ContinuationFixtures.completionWithEvidence
        )
        XCTAssertEqual(message.continuationBlockKinds, [.summary, .evidence])
    }

    func test_assistantMessage_withCompletionModeA_yieldsSummaryThenNextStep() throws {
        let message = ConversationMessage.assistant(
            text: "",
            continuationEvent: ContinuationFixtures.completionWithNextStepStrip
        )
        XCTAssertEqual(message.continuationBlockKinds, [.summary, .nextStep])
    }

    func test_assistantMessage_withCompletionModeB_yieldsSummaryThenNextStep() throws {
        let message = ConversationMessage.assistant(
            text: "",
            continuationEvent: ContinuationFixtures.completionWithNextStepPrimary
        )
        XCTAssertEqual(message.continuationBlockKinds, [.summary, .nextStep])
    }

    func test_assistantMessage_withAbandonSummaryOnly_yieldsOnlySummary() throws {
        let message = ConversationMessage.assistant(
            text: "",
            continuationEvent: ContinuationFixtures.abandonSummaryOnly
        )
        XCTAssertEqual(message.continuationBlockKinds, [.summary])
    }

    func test_assistantMessage_withAbandonStrip_yieldsSummaryThenNextStep() throws {
        let message = ConversationMessage.assistant(
            text: "",
            continuationEvent: ContinuationFixtures.abandonWithStrip
        )
        XCTAssertEqual(message.continuationBlockKinds, [.summary, .nextStep])
    }

    // MARK: - Suppressed outcomes: zero blocks regardless of envelope content

    func test_assistantMessage_withDismissEvent_yieldsZeroBlocks() throws {
        let message = ConversationMessage.assistant(
            text: "",
            continuationEvent: ContinuationFixtures.dismissSuppressed
        )
        XCTAssertEqual(message.continuationBlockKinds, [])
    }

    func test_assistantMessage_withAcceptNoEntryEvent_yieldsZeroBlocks() throws {
        let message = ConversationMessage.assistant(
            text: "",
            continuationEvent: ContinuationFixtures.acceptNoEntrySuppressed
        )
        XCTAssertEqual(message.continuationBlockKinds, [])
    }

    // MARK: - Stack order invariant

    func test_blockOrder_isAlwaysSummaryEvidenceNextStep() throws {
        let message = ConversationMessage.assistant(
            text: "",
            continuationEvent: ContinuationFixtures.completionFull
        )
        let kinds = message.continuationBlockKinds
        guard
            let summaryIndex = kinds.firstIndex(of: .summary),
            let evidenceIndex = kinds.firstIndex(of: .evidence),
            let nextStepIndex = kinds.firstIndex(of: .nextStep)
        else {
            return XCTFail("Expected all three block kinds for completionFull.")
        }
        XCTAssertLessThan(summaryIndex, evidenceIndex)
        XCTAssertLessThan(evidenceIndex, nextStepIndex)
    }

    // MARK: - Field carries through the assistant factory

    func test_assistantFactory_setsContinuationEvent() throws {
        let event = ContinuationFixtures.completionFull
        let message = ConversationMessage.assistant(text: "", continuationEvent: event)
        XCTAssertEqual(message.continuationEvent, event)
    }

    func test_assistantFactory_defaultsContinuationEventToNil() throws {
        let message = ConversationMessage.assistant(text: "Hi.")
        XCTAssertNil(message.continuationEvent)
    }

    // MARK: - Mixed-session sanity: continuation and non-continuation coexist

    func test_session_mixedMessages_onlyContinuationOnesProduceBlocks() throws {
        let messages: [ConversationMessage] = [
            ConversationMessage.user(text: "Where am I going?"),
            ConversationMessage.assistant(text: "Maps will route you."),
            ConversationMessage.assistant(
                text: "",
                continuationEvent: ContinuationFixtures.completionFull
            ),
            ConversationMessage.system(text: "Thread merged."),
            ConversationMessage.assistant(text: "Anything else?")
        ]

        let blockCounts = messages.map { $0.continuationBlockKinds.count }
        XCTAssertEqual(blockCounts, [0, 0, 3, 0, 0])
    }
}
