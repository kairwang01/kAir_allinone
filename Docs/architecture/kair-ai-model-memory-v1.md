# kAir AI Model and Memory Architecture v1

Status: target architecture, comment-only.
Last updated: 2026-05-30.

This document owns the future shape of kAir's self-developed local model,
market model selection, model downloads, command execution, and memory.

## 1. Model Roles

The app must not treat every model as a generic chatbot. Each model has
a role.

| Role | Name | Default runtime | Responsibility |
|---|---|---|---|
| Router | `local-router` | self-developed lightweight model | classify intent, pick capability, produce structured plan |
| Planner | `local-planner` | same model or small specialist | break instruction into safe tool calls |
| Embedder | `local-embedder` | Core ML / small embedding model | local semantic memory vectors |
| Health | `health-local-specialist` | Core ML / local runtime | health summaries only, no remote path |
| Premium | `market-large-model` | server-gated paid provider | optional hard reasoning / long context / high-quality generation |

The self-developed lightweight fine-tuned model ships first as a router
and planner. It does not need to be a strong general assistant in v1.

## 2. Local Router Output Contract

Router output must be structured:

```json
{
  "intent_id": "uuid-or-stable-hash",
  "language": "zh-Hans",
  "surface": "maps|health|ai|store|music|video|search|chat|social|food",
  "capability": "routePlanning",
  "risk": "read|write|pay|share|externalOpen",
  "confidence": 0.0,
  "requires_confirmation": true,
  "slots": {
    "origin": "current_location",
    "destination": "Union Station"
  },
  "missing_slots": [],
  "user_visible_summary": "准备打开路线规划"
}
```

Rules:

- Free-form text is not accepted as an execution plan.
- Unknown capability routes to clarification or recommendation.
- Confidence below threshold cannot execute.
- Any `pay`, `write`, `share`, or `externalOpen` action requires
  confirmation.
- Health context cannot route to remote providers.

## 3. Model Provider Abstraction

Target shape:

```swift
// Comments for future implementation:
// protocol ModelProvider
// - var descriptor: LocalModelDescriptor { get }
// - func availability() async -> ModelAvailability
// - func generate(_ request: ModelRequest) async throws -> ModelResponse
// - func cancel(requestID: ModelRequestID) async
//
// The protocol is runtime-agnostic. Foundation Models, Core ML, MLX,
// llama.cpp, and remote gateways all conform behind separate adapters.
```

Provider rules:

- A provider only generates or embeds.
- A provider does not choose app capability.
- A provider does not know StoreKit products.
- A provider does not write memory directly.
- A provider reports latency, token count if available, memory pressure,
  and structured-output validity.

## 4. Runtime Families

| Runtime family | Use in kAir | Notes |
|---|---|---|
| Foundation Models | preferred Apple-native on-device text tasks where available | tool calling and guided generation are a strong fit; guard with OS availability |
| Core ML | compiled local classifiers, embeddings, compact specialists | best for predictable local inference and dynamic model download/compile |
| MLX | research, Apple Silicon experiments, local fine-tuning path | do not hard-wire app runtime to MLX until iOS packaging and perf gates pass |
| llama.cpp / GGUF | optional local generative runtime with grammar constraints | useful for structured local routing experiments; abstract behind provider |
| ExecuTorch | edge classifiers/rerankers/specialists | useful for non-generative models; not first chat runtime |
| Remote provider gateway | premium market models | server-side only, StoreKit entitlement required |

## 5. Model Catalog

Target catalog fields:

```text
ModelCatalogEntry
  id
  displayName
  role
  runtimeFamily
  version
  languageSupport
  taskSupport
  diskSizeBytes
  estimatedMemoryBytes
  minimumDeviceClass
  minimumOS
  downloadURL
  checksum
  signature
  license
  priceProductID
  privacyClassAllowed
  supportsStreaming
  supportsStructuredOutput
  supportsToolCalling
  statusCopy
```

Rules:

- Catalog metadata is not entitlement proof.
- Download URL is not trusted without checksum/signature.
- A model can be visible but not installable on the current device.
- The Model Library UI must distinguish bundled, installed,
  downloadable, paid, unavailable, downloading, compiling, failed, and
  active.

## 6. Model Download State Machine

States:

```text
notInstalled
eligible
requiresPurchase
purchasing
downloadQueued
downloading(progress)
downloaded
verifying
compiling
installed
active
paused
failed(reason)
deleting
deleted
unavailable(reason)
```

Rules:

- Download starts only after user action.
- Paid model download starts only after entitlement.
- Compile/install failures are recoverable and visible.
- Disk quota is checked before download.
- Uninstall removes model files and catalog state but keeps purchase
  entitlement.
- Health specialist models cannot be deleted while Health surface is
  using them unless a safe fallback exists.

## 7. Paid Market Model Path

The paid model path is not "download any big model from the internet".
It is a curated marketplace:

```text
StoreKit product
  -> EntitlementState
  -> ModelCatalog unlock
  -> DownloadManager or RemoteModelGateway
  -> Provider availability
  -> Router policy
```

For remote market models:

- iOS app never stores provider API keys.
- Server validates StoreKit receipt or transaction.
- Server maps entitlement to allowed provider/model IDs.
- Request includes privacy class and domain.
- Server rejects health/private data classes unless policy explicitly
  allows in a future version.
- User can set monthly budget or "local only" mode.

## 8. Router Policy

Model selection uses a policy graph:

```text
Task class
  + privacy class
  + user model setting
  + entitlement
  + network status
  + local model availability
  + cost budget
  + confidence threshold
  -> selected provider or fallback
```

Default policy:

- Local router handles intent classification.
- Local model handles Health.
- Premium model can be suggested for long/hard non-sensitive tasks.
- Premium model cannot silently run because it may cost money.
- If no valid model exists, use deterministic fallback copy and ask for
  setup.

## 9. Memory Domains

Memory is split by domain:

| Domain | Examples | Remote allowed in v1 |
|---|---|---|
| chat | thread summaries, user preferences, active tasks | no by default |
| health | local trends, coverage, user-entered notes | never |
| model | installed models, benchmark metrics, failure diagnostics | no sensitive context |
| capability | action receipts, route outcomes, partner errors | no raw secrets |
| social | friend metadata, invite state | no health data |
| commerce | purchases, entitlement state | StoreKit/server receipt only |

## 10. Memory Record Shape

Target fields:

```text
MemoryRecord
  id
  domain
  kind
  title
  body
  source
  provenanceIDs
  createdAt
  updatedAt
  expiresAt
  sensitivity
  retentionPolicy
  embeddingState
  userEditable
  userDeleted
  confidence
```

Records must be inspectable. A user-facing memory management screen
should be possible without decoding model internals.

## 11. Memory Write Policy

Allowed write sources:

- Explicit user save.
- Completed action receipt.
- Stable preference repeated across interactions.
- User setting changes.
- Local health summary generated inside Health domain.

Blocked write sources:

- Failed model hallucination.
- Unconfirmed plan.
- Sensitive context outside domain policy.
- External partner data without allowed retention purpose.
- Health-to-chat or health-to-social derived context.

## 12. Retrieval Policy

Retrieval must be scoped:

```text
request(domain, purpose, query, maxRecords, maxTokens, sensitivityLimit)
```

Rules:

- Health requests retrieve only Health memory.
- General chat cannot retrieve Health memory.
- Social requests cannot retrieve Health memory.
- Retrieval returns provenance and reason.
- If retrieval is slow, fail closed and continue without memory rather
  than blocking UI.

## 13. Hybrid Indexing

Recommended path:

1. Start with in-memory records for contract tests.
2. Move to SQLite/GRDB for durable local records.
3. Add FTS5 for keyword retrieval.
4. Add `VectorIndex` facade.
5. Plug in sqlite-vec only behind the facade after build packaging and
   migration tests pass.

Why hybrid:

- Keyword search is deterministic and easy to debug.
- Vector search helps paraphrase and fuzzy recall.
- Local-first memory research now favors scoped, hybrid retrieval with
  diagnostics rather than raw top-k vector dumps.

### 13.1 Memory-v2 direction (research-backed, 2026-06-01)

A verified deep-dive (`Docs/research/2026-agent-memory-deep-dive-v1.md`;
24/25 claims 3-vote-confirmed) refines this path. SOURCED FACT is separated
from kAir RECOMMENDATION; every step is gated. This is the comment-first
memory-v2 plan — **not ratified**, pending PM 判断.

**SOURCED FACT.** (a) Hierarchical summarization + Ebbinghaus-style decay
bound memory growth *without* hurting personalization — MemoryBank
(`R = e^(−t/S)`, AAAI 2024), RMM (ACL 2025, +>10pp LongMemEval), FadeMem
(2026 preprint, −45% storage, no measured regression); a 2026 survey frames
forgetting as "a feature, not a bug" and warns crude age/size eviction is
inferior to importance-weighted forgetting. (b) Knowledge-graph memory is
**not** a free on-device win: the only same-stack comparison (Mem0 vs Mem0^g,
arXiv:2504.19413) shows ~+2% overall, a multi-hop **regression**, and higher
latency; the graph wins only on temporal/knowledge-update reasoning (Zep) and
interactive/sequential tasks (AriGraph). (c) Every high-quality graph result
uses 70B LLMs + 7B embedders on GPUs (HippoRAG 2 is "not designed for CPU-only
operation"); only the **algorithm** (PPR / temporal edge-invalidation / decay /
summarization) transfers to an iPhone — no source measures these on-device.
(d) Gains are reader-capability-dependent and can backfire with a small
on-device LLM (LongMemEval; time-aware expansion degrades on Llama-8B).

**kAir RECOMMENDATION (ranked, gated — extends steps 1–5 above):**
1. Importance-weighted **decay** — a `MemoryStrength` value (`R = e^(−t/S)`,
   `S`↑ and `t`→0 on recall; or FadeMem importance = relevance + access-freq +
   recency). Pure, `now:`-injected. Highest certainty; binds to the existing
   `MemoryConsolidationPolicy.decay` action.
2. Hierarchical **summary tier** — `MemoryRecord.kind` ∈ {`dailySummary`,
   `globalSummary`}, `provenanceIDs` → source records. A summary never deletes
   its sources within the abstention window; keep raw records until validated.
   Health summaries stay health-domain (already enforced by `MemoryWritePolicy`).
3. Make `MemoryStore.retrieve()` actually **use `query`** — FTS5 keyword first
   (steps 3 above). Deterministic; the safest first real retrieval step (today
   `query` is ignored — domain-scope + sensitivity-cap + prefix only).
4. `VectorIndex` facade (sqlite-vec / Alibaba zvec + a quantized small embedder)
   behind the same seam (step 4–5 above).
5. `MemoryGraph` facade **last, gated, temporal-only** — adopt only if a kAir
   on-device benchmark shows a temporal-reasoning win that summarization +
   time-aware query expansion cannot match. Temporal `supersede` (Zep-style edge
   invalidation) overlaps the existing `MemoryConsolidationPolicy.supersede`.

**Adoption gate (CI):** recall@k + end-to-end p95 latency + storage-growth-
over-time, on a LongMemEval-style local fixture (5 abilities incl. abstention).
**Measure on-device first** — the literature has no iPhone-budget numbers; this
is the central open risk.

## 14. Context Assembly

The model context packet should be explicit:

```text
ContextPacket
  userInput
  activeSurface
  activeThreadSummary
  relevantMemories[]
  capabilityAvailability[]
  modelPolicy
  privacyRestrictions[]
  outputSchema
```

Never send the entire transcript by default. The engine assembles only
what is necessary for the current task.

## 15. Evaluation Gates

Local router promotion requires:

- Structured parse success rate.
- Tool-match accuracy.
- Surface-match accuracy.
- Refusal accuracy for blocked actions.
- Confirmation requirement accuracy.
- Privacy violation count = 0.
- Latency under budget on target device.
- No regression against deterministic router baseline.

Use gate-driven adaptive rounds. Do not continue many training rounds
when a candidate regresses against the baseline.

## 16. Failure UX

Every failure state needs user-visible copy:

- Model missing: "需要先安装本地模型".
- Model unavailable: "当前设备不支持这个模型".
- Download failed: "下载中断，可重试".
- Paid locked: "这个模型需要购买后使用".
- Privacy blocked: "这类内容只能在本地处理".
- Permission missing: "需要你授权后才能继续".
- Low confidence: "我需要你补充一个条件".

Do not show stack traces, provider names, or token diagnostics in the
main user flow.

