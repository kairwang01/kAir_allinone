# Continuation Transcript Blocks — I1-prep Component Layering Sketch

Status: implementation-side architecture, NOT a contract.
Authority: this doc describes how the I1-prep scaffolding lays out files and which existing components it borders. It introduces zero new normative rules. All rules live in:

- [`Contracts/Design/design-system-v1.md`](../Design/design-system-v1.md)
- [`Contracts/UX/continuation-runtime-v1.md`](continuation-runtime-v1.md)
- [`Contracts/UX/continuation-transcript-visual-v1.md`](continuation-transcript-visual-v1.md)
- [`Contracts/UX/post-return-and-continuation-ux-v1.md`](post-return-and-continuation-ux-v1.md)

If this doc disagrees with any of those, the contracts win.

---

## 1. File tree

```
kAir/Shared/Components/Conversation/Continuation/
├── ChatContinuationEvent.swift     — data envelope + sub-payloads + supporting enums
├── SystemSummaryBlock.swift         — SwiftUI view for runtime-v1 §3 payload
├── SystemEvidenceBlock.swift        — SwiftUI view for runtime-v1 §4 payload
├── NextStepPromptBlock.swift        — SwiftUI view for runtime-v1 §5 payload
└── ContinuationFixtures.swift       — preview / test fixtures

kAirTests/Continuation/
└── ContinuationContractTests.swift  — test scaffold (unregistered until I1 adds a target)
```

The folder lives alongside the existing `kAir/Shared/Components/Conversation/` siblings (`MessageBubble.swift`, `ComposerBar.swift`, `ConversationModels.swift`). It does NOT replace any of them in I1-prep.

## 2. Block composition

The three views compose as siblings inside an assistant message column. They share a leading edge and a fixed inter-block gap of `12pt` (visual-v1 §6).

```
┌─────────────────────────────────────────────┐
│ assistant message column                    │
│ ┌─────────────────────────────────────────┐ │
│ │ SystemSummaryBlock                      │ │  ← required when renderEligible
│ │   eyebrow + state-dot                   │ │
│ │   title                                 │ │
│ │   summary                               │ │
│ │   metric-grid (3 tiles)                 │ │
│ │   footer                                │ │
│ └─────────────────────────────────────────┘ │
│   ↕ 12pt                                    │
│ ┌─────────────────────────────────────────┐ │
│ │ SystemEvidenceBlock                     │ │  ← optional, sibling (NOT nested)
│ │   eyebrow                               │ │
│ │   pair-list                             │ │
│ └─────────────────────────────────────────┘ │
│   ↕ 12pt                                    │
│ ┌─────────────────────────────────────────┐ │
│ │ NextStepPromptBlock                     │ │  ← optional, no card chrome
│ │   eyebrow                               │ │
│ │   chip-strip (Mode A) OR primary+strip  │ │
│ │   (Mode B)                              │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

In I1-prep, each view renders standalone in its own `#Preview`. There is no parent composer or message-row view in this PR.

## 3. Boundary against existing components

| Existing component | Relationship in I1-prep | Relationship after I1 |
|---|---|---|
| [`MessageBubble`](../../kAir/Shared/Components/Conversation/MessageBubble.swift) | Untouched. The new blocks do NOT mount inside it. | I1 wires the blocks into `MessageBubble.body` for assistant messages that carry a `ChatContinuationEvent` payload. |
| `ConversationToolResultCard` (private inside `MessageBubble.swift`) | Untouched. | Eventually superseded by `SystemSummaryBlock` for continuation-runtime messages; non-continuation tool results may keep using it during the migration. See runtime-v1 §8 for the additive bridging rule. |
| [`ConversationModels`](../../kAir/Shared/Components/Conversation/ConversationModels.swift) | Untouched. `ChatContinuationEvent` is a separate, additive type — it does not extend `ConversationMessage` or `ConversationToolResult` in this PR. | I1 decides between (a) projecting events into a single `ConversationToolResult` or (b) extending `ConversationMessage` with a typed `continuationEvent` field. Both paths satisfy runtime-v1 §8.1. |
| [`ChatStore`](../../kAir/Features/Chat/Data/ChatStore.swift) | Untouched. No emit path is wired. | I1 wires `recordSurfaceReturn` / `recordMapReturn` / `dismissRecommendation` to construct and emit `ChatContinuationEvent` envelopes. |
| [`AppTheme`](../../kAir/DesignSystem/Tokens/AppTheme.swift) | Used only as a token source; not modified. | Same. The blocks remain bound to `AppTheme` tokens per design-system-v1 §3. |
| `KAirSurface`, `KAirPageChrome` | Not consumed by the three new blocks (the blocks construct their own surface chrome inline to match visual-v1 §5 exactly). | Same. |

## 4. Test surface map

Every method name in `ContinuationContractTests.swift` maps to a clause in the upstream contracts. The bodies are `// TODO(I1)` markers — no XCTest assertions are run in this PR.

| Test method | Maps to |
|---|---|
| `test_renderEligible_isTrue_forCompletion` | runtime-v1 §7.1 |
| `test_renderEligible_isTrue_forAbandon` | runtime-v1 §7.1 |
| `test_renderEligible_isFalse_forDismiss` | runtime-v1 §7.1 |
| `test_renderEligible_isFalse_forAcceptNoEntry` | runtime-v1 §7.1 |
| `test_renderEligibleEnvelope_requiresSummary` | runtime-v1 §7.2 |
| `test_dismissEnvelope_hasNoSubPayloads` | runtime-v1 §7.3 |
| `test_acceptNoEntryEnvelope_hasNoSubPayloads` | runtime-v1 §7.3 |
| `test_summary_hasExactlyThreeMetrics` | runtime-v1 §7.4 |
| `test_summary_continuityMetricIndexIsTwo` | runtime-v1 §7.5 |
| `test_summary_continuityMetricKeyInVocabulary` | runtime-v1 §7.6 |
| `test_summary_outcomeToneMatchesEnvelopeOutcome` | runtime-v1 §7.7 |
| `test_summary_titleWithinMaxCharacters` | runtime-v1 §7.8 |
| `test_summary_summaryWithinMaxCharacters` | runtime-v1 §7.8 |
| `test_evidence_pairCountInRange` | runtime-v1 §7.9 |
| `test_evidence_pairStringsWithinMaxCharacters` | runtime-v1 §7.10 |
| `test_nextStep_primaryWithSecondary_requiresPrimary` | runtime-v1 §7.11 |
| `test_nextStep_chipStrip_forbidsPrimary` | runtime-v1 §7.12 |
| `test_nextStep_totalChipCountInRange` | runtime-v1 §7.13 |
| `test_nextStep_abandon_forbidsPrimaryWithSecondary` | runtime-v1 §7.14 |
| `test_nextStep_sendPromptTextWithinMaxCharacters` | runtime-v1 §7.15 |
| `test_visual_dismissProducesZeroBlockViews` | visual-v1 §7 |
| `test_visual_acceptNoEntryProducesZeroBlockViews` | visual-v1 §7 |
| `test_visual_completion_stateDotIsSuccess` | visual-v1 §7 |
| `test_visual_abandon_stateDotIsWarning` | visual-v1 §7 |
| `test_visual_blockStackOrderIsSummaryEvidencePrompt` | visual-v1 §3 |

## 5. Fixture coverage map

| Fixture | Outcome | Sub-payloads present | Used in |
|---|---|---|---|
| `completionSummaryOnly` | `.completion` | summary | `SystemSummaryBlock` preview |
| `completionWithEvidence` | `.completion` | summary, evidence | `SystemEvidenceBlock` preview |
| `completionWithNextStepStrip` | `.completion` | summary, nextStep (Mode A) | `NextStepPromptBlock` preview |
| `completionWithNextStepPrimary` | `.completion` | summary, nextStep (Mode B) | `NextStepPromptBlock` preview |
| `completionFull` | `.completion` | all three | I1 composition test |
| `abandonSummaryOnly` | `.abandon` | summary | `SystemSummaryBlock` preview |
| `abandonWithStrip` | `.abandon` | summary, nextStep (Mode A) | I1 abandon-tone test |
| `dismissSuppressed` | `.dismiss` | none | I1 suppression test |
| `acceptNoEntrySuppressed` | `.acceptNoEntry` | none | I1 suppression test |

## 6. What this PR does NOT do

- Does NOT wire any block into `ChatHomeView`, `RootShellView`, or any existing screen.
- Does NOT modify `ChatStore`, `ConversationModels`, `MessageBubble`, or any runtime emission path.
- Does NOT introduce a new design token, status type, or feedback enum case.
- Does NOT implement the runtime-v1 §7 validation — the test bodies are TODO markers.
- Does NOT touch the mixed-rail (`Docs/design/mixed-recommendation-layout-v1.md`) or feedback-affordance (`Docs/design/negative-feedback-ux-v1.md`) specs or implementations.
- Does NOT add a new XCTest target. The test file exists on disk only.
- Does NOT promote this layering doc to contract status. Future architecture decisions go through the contracts in §1, not here.

## 7. What I1 will do (out of scope for this PR)

1. Implement the test bodies in `ContinuationContractTests.swift` (XCTest target added, validations asserted).
2. Wire `ChatContinuationEvent` into `ChatStore` emission paths (`recordSurfaceReturn`, `recordMapReturn`, `dismissRecommendation`, `recordSilentSurfaceExit`).
3. Decide and implement the runtime-v1 §8.1 projection (option a or b).
4. Mount the three blocks inside `MessageBubble.body` for continuation-runtime messages.
5. Migrate the existing post-return single-`ConversationToolResult` shape to the new envelope (incrementally per surface).

None of those land in this PR.
