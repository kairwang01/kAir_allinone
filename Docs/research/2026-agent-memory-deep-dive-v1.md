# 2026 Agent-Memory Deep-Dive — Graph / Forgetting / On-Device

Status: research note (informational — NOT a contract, NOT a roadmap, NOT a
dependency list). Extends `kair-ai-model-memory-v1.md` §13 (hybrid indexing)
and `kair-architecture-redesign-v2.md` §5.5 (`MemoryConsolidationPolicy`).
Created: 2026-06-01.

Provenance: a fan-out deep-research run (104 agents, 22 primary sources, 109
extracted claims → 25 adversarially verified by 3-vote, **24 confirmed / 1
refuted**). This note is the durable distillation; it separates **SOURCED
FACT** from **kAir RECOMMENDATION**, and every recommendation is gated.

---

## 0. Bottom line up front (BLUF)

1. **kAir's memory baseline is already well-aligned with the 2023–2026
   literature.** Append-only + strict domain isolation + a
   `summarize / supersede / decay` consolidation policy maps directly onto the
   mechanisms the strongest papers validate (MemoryBank decay, RMM
   summarization, A-MEM supersede). A March-2026 survey explicitly frames
   forgetting as *"a feature, not a bug."*
2. **The knowledge graph (图谱) is NOT a free win on-device.** The single
   same-stack graph-vs-flat comparison (Mem0 vs Mem0^g, arXiv:2504.19413) shows
   the graph adds only ~2% overall, **regresses** on single-hop (−1.42) and
   multi-hop (−3.96), wins only on temporal (+2.62) / open-domain (+2.78), and
   costs more latency. Graph memory's clear wins are **temporal "knowledge-
   update" reasoning** (Zep) and **interactive/sequential agent tasks**
   (AriGraph) — not general recall.
3. **Every high-quality graph result is produced on server-grade hardware**
   (70B LLMs for entity extraction, 7B embedders, multi-GPU vLLM). What
   transfers to an iPhone is the **algorithm** (PPR over a sparse entity graph;
   Ebbinghaus decay; hierarchical summarization; a tiny learned reranker), **not
   the published implementation**. No retrieved source demonstrates any of these
   running within a real iPhone compute/battery budget.
4. **Highest-value, highest-certainty on-device additions** (in order):
   MemoryBank-style **parameterized decay** → RMM-style **hierarchical
   summarization** + **time-aware query expansion** → a small sparse
   **PPR-style entity graph** as a *higher-risk, lower-certainty* enhancement,
   adopted only behind a benchmark gate.

---

## 1. Axis (1) — Knowledge-graph-structured memory (图谱)

| Method | Paper (venue, arXiv, year) | What it concretely does | Measured result (SOURCED) | On-device? |
|---|---|---|---|---|
| **HippoRAG / HippoRAG 2** | NeurIPS 2024 `2405.14831`; ICML 2025 `2502.14802` ("From RAG to Memory") | LLM builds an entity KG; retrieval = **Personalized PageRank (PPR)** over it (hippocampal-indexing analogy) | Single-step PPR matches/beats iterative IRCoT at **10–30× cheaper, 6–13× faster** (MuSiQue/2Wiki/HotpotQA). HippoRAG 2: **+7%** on associative-memory tasks over a 7B SOTA embedder. Non-associative margins narrow (~+0.2 F1 NarrativeQA) | **Algorithm only.** Ref stack = Llama-3.3-70B + NV-Embed-v2 7B on 4×H100, *"not designed for CPU-only operation."* |
| **AriGraph** | IJCAI 2025 `2407.04363` (Anokhin et al.) | Agent maintains **one incrementally-updated graph fusing semantic + episodic** memory while acting | **Markedly outperforms** full-history / summarization / RAG **and** strong RL baselines on interactive text-games; scales where baselines fail. Only *competitive* (not superior) on static multi-hop QA | **Algorithm only.** GPT-4/4o-mini, best-3-of-5. Advantage is in **interactive/sequential** settings — kAir's actual use case |
| **Zep / Graphiti** | `2501.13956` (Rasmussen et al. 2025) | **Temporal** KG: time-versioned edges (`t_valid`/`t_invalid` **edge invalidation**) fusing conversational + structured data | **+18.5%** on LongMemEval (71.2% vs 60.2%), **−90% latency** | **Algorithm only** + a heavy caveat (below). Temporal versioning is the transferable idea |
| **Mem0 / Mem0^g** | `2504.19413` (Chhikara et al. 2025) | Flat memory-centric extraction/update; `^g` adds a graph layer | Flat Mem0 **+26%** vs OpenAI memory on LoCoMo. **Graph `^g` only +~2% overall, regresses multi-hop −3.96**, wins temporal/open-domain only; higher p95 latency | Flat variant is the most on-device-plausible shape; **graph not worth its cost** on this evidence |

**The decision-relevant fact (high confidence):** on the *only* apples-to-apples
graph-vs-flat measurement, the graph is a wash-to-slight-win overall and a
**loss on multi-hop**, at higher latency. Build a graph only for the abilities
it actually wins (temporal/knowledge-update), and only behind a gate.

---

## 2. Axis (2) — Abstraction / "fuzzification" / forgetting (模糊化)

| Method | Paper | Mechanism | Measured result (SOURCED) | Confidence |
|---|---|---|---|---|
| **MemoryBank** | AAAI 2024 `2305.10250` (Zhong et al.) | **Hierarchical summarization** (dialogue → daily summary → global summary + personality) **+ Ebbinghaus decay `R = e^(−t/S)`**, `S`↑ and `t`→0 on each recall | Self-described *"exploratory and highly simplified"*; the **mechanism**, not a benchmark number, is the contribution | high (mechanism) |
| **RMM** | ACL 2025 `2503.08026` (`2025.acl-long.413`) | **Prospective Reflection** (summarize across utterance/turn/session) + **Retrospective Reflection** (online-RL MLP reranker trained on whether the LLM *cited* each memory, ±1 reward, on top of a dense retriever) | **>10pp** on LongMemEval (best retriever: 70.4 vs 57.4); shrinks to +3.8–7.4pp on weaker retrievers | high (gain is retriever-dependent) |
| **FadeMem** | `2601.18642` (Jan 2026, **preprint**) | **Adaptive** exponential decay `v(t)=v(0)·exp(−λ(t−τ)^β)`, dual-layer (long β=0.8 / short β=1.2), rate modulated by importance (relevance + access-freq + recency), auto-prune below threshold | **45% storage reduction** with **no metric underperforming** baseline (LoCoMo F1 29.43 vs 28.37) | **medium** — single un-peer-reviewed preprint, modest margins, no significance tests |
| **Survey: "Memory for Autonomous LLM Agents"** | `2603.07670v1` (Du, Mar 2026) | Survey | *"Forgetting is not a bug; it is a feature — essential for robustness, privacy, and efficiency"*; inability to discard *"gradually poisons retrieval precision."* Warns **crude time/size eviction < learned selective forgetting** | high (framing) |

**Takeaway (high confidence):** active forgetting + hierarchical summarization
**bound unbounded growth without hurting** (often improving) personalization.
This is the strongest, most on-device-portable family — and it directly
validates kAir's existing `summarize / supersede / decay` actions. The open
nuance: prefer **importance-weighted** decay over crude age/size eviction.

---

## 3. Axis (3) — On-device feasibility & evaluation

**SOURCED — benchmarks.** `LongMemEval` (ICLR 2025 `2410.10813`, Wu et al.) is
the gating benchmark: 500 questions × **5 abilities** (info-extraction,
multi-session reasoning, temporal reasoning, knowledge-updates, **abstention**);
commercial assistants drop **~30%** accuracy. Indexing techniques measurably
move it — fact-augmented key expansion **+9.4% recall**, time-aware query
expansion **+11.3% recall**, session decomposition — **but gains are
reader-capability-dependent**: time-aware expansion *degrades* with a weak
reader (Llama-8B hallucinates time ranges), and aggressive value decomposition
can *hurt* QA. LoCoMo and MSC are the companion conversational benchmarks.
(`PerLTQA` was named in the question but no claim about it survived
verification.)

**SOURCED — on-device infra exists.** `sqlite-vec` (stable release) and
Alibaba's `zvec` (embedded SQLite-like vector DB for **on-device RAG**, Feb
2026) make local vector search practical; embedding quantization (int8/binary)
cuts the embedder's storage/latency. These are infra primitives, not memory
algorithms.

**The pervasive on-device gap (critical):** no retrieved source measures *any*
of these methods running fully on an iPhone-class SoC. Per-write/per-query
latency, battery, and SQLite storage-growth-over-months for a sparse entity
graph + small embedder are **unmeasured**. kAir must measure them itself before
adopting — this is the central open risk.

---

## 4. Critical caveats (the synthesis rests on these)

1. **Vendor self-reports.** Mem0 (`2504.19413`) and Zep (`2501.13956`) are
   commercial-author papers on self-run benchmarks; their cross-system rankings
   are **actively contested** (Zep disputes Mem0's LoCoMo methodology and
   vice-versa). Cite as *"X reports…"*, not neutral SOTA. The narrow internally-
   consistent deltas survive (Mem0 +26% vs OpenAI; `^g` +~2% vs flat; Zep +18.5%
   vs full-context).
2. **Misleading baselines.** The −90% latency wins (Mem0, Zep) are vs a
   **full-context** baseline (~26k / ~115k tokens), **not flat vector RAG** — so
   they do *not* directly answer "graph vs flat-RAG cost."
3. **FadeMem is a fresh preprint** (medium confidence) — promising direction,
   not an established result.
4. **Reader-capability dependence** — LongMemEval indexing gains and RMM's
   benefits shrink/backfire with small readers; a direct risk for kAir's small
   on-device LLM.
5. **Refuted & excluded:** "Zep beats MemGPT on DMR (94.8 vs 93.4)" was killed
   0-3 and is not relied upon.

---

## 5. kAir mapping — what's aligned, what memory-v2 should add

Current memory layer (verified in repo): `MemoryRecord` (rich value type,
`embeddingState` always `.none`), `MemoryDomain` (6 domains, health bidirection-
ally isolated), `MemoryWritePolicy`, `MemoryConsolidationPolicy`
(`keep/summarize/supersede/decay`), `MemoryStore` (in-memory; **`retrieve()`
ignores the `query` field** — domain-scope + sensitivity-cap + `prefix(N)` only,
no keyword/vector/graph, no persistence).

| Research mechanism | kAir status | Memory-v2 action (RECOMMENDATION, gated) |
|---|---|---|
| Ebbinghaus / importance-weighted decay (MemoryBank, FadeMem) | `MemoryConsolidationPolicy.decay` exists but is age+confidence only | **Add a parameterized `MemoryStrength` value** (`R=e^(−t/S)`, `S`↑ on recall; or FadeMem importance = relevance+freq+recency). Pure function; caller injects `now`. **Highest-certainty add.** |
| Hierarchical summarization (MemoryBank, RMM Prospective) | `.summarize` action exists; **no summary tier / no trigger** | Reserve a **summary tier** in `MemoryRecord` (`kind: dailySummary/globalSummary`, `provenanceIDs` → source records) + a pure trigger policy. Health summaries stay health-domain (already enforced). |
| Real query-based retrieval | **`retrieve()` ignores `query`** | Wire **FTS5 keyword retrieval first** (deterministic, debuggable — already the §13 plan), then a `VectorIndex` facade (sqlite-vec/zvec) behind the same seam. Time-aware query expansion is **gated on reader size** (can backfire). |
| Learned reranker (RMM Retrospective) | none | Reserve a `MemoryReranker` seam; a *tiny* on-device reranker is plausible, but the online-RL + citation-feedback loop is **deferred** (complexity, small-reader risk). |
| Entity/temporal graph (HippoRAG PPR, Zep edge-invalidation, AriGraph) | none | Reserve a `MemoryGraph` facade **but do not build first.** Adopt only behind a gate, and only for **temporal/knowledge-update** recall, where the same-stack evidence shows it wins. Temporal `supersede` (Zep-style edge invalidation) is the cheapest slice and overlaps kAir's existing `supersede`. |
| Forgetting as a feature (survey) | already the design intent | Keep; prefer **importance-weighted** over crude age/size eviction (survey caution). |

---

## 6. Ranked on-device shortlist (RECOMMENDATION) + biggest risk each

1. **Importance-weighted decay** (MemoryBank/FadeMem algorithm). *Risk:* tuning
   `S`/threshold blind without an on-device benchmark → either bloat or
   forgetting something the user wanted. → gate on storage-growth + a recall
   check.
2. **Hierarchical summarization tier** (MemoryBank/RMM Prospective). *Risk:* a
   **small** on-device LLM writes a lossy/wrong summary that then supersedes good
   records. → keep raw records until a summary is validated; never let a summary
   delete its sources within the abstention window.
3. **FTS5 keyword retrieval that actually uses `query`** (closes the current
   gap; §13 plan). *Risk:* low — deterministic, the safest first real step.
4. **`VectorIndex` facade** (sqlite-vec/zvec + quantized small embedder).
   *Risk:* storage/latency growth over months — **unmeasured on-device**; must
   profile before shipping.
5. **Sparse PPR entity graph / temporal edge-invalidation** (HippoRAG/Zep
   algorithm). *Risk:* highest — only ~2% same-stack win, regresses multi-hop,
   adds write-time + complexity, and **no on-device measurement exists**. Adopt
   *only* if a kAir benchmark shows a temporal-reasoning win that summarization
   + time-aware expansion can't match.

---

## 7. Open questions for PM 判断

1. **Graph or no graph?** The evidence says invest in decay + hierarchical
   summarization + time-aware query expansion *first* (same temporal/multi-
   session benefit, no graph cost), and treat a small entity graph as a gated,
   later, temporal-only enhancement. Confirm this ordering, or prioritize the
   graph for a specific feature (e.g. health-trend "knowledge updates")?
2. **CI gate triple.** Adopt **recall@k + end-to-end p95 latency +
   storage-growth-over-time** as the memory adoption gate, benchmarked on a
   LongMemEval-style local fixture (5 abilities incl. abstention). Agree?
3. **Fold into architecture docs?** Should these recommendations be folded into
   `kair-ai-model-memory-v1.md` §13 + the v2 redesign §5.5 as a memory-v2
   reservation (doc-only recheck → ratify), or stay an informational note until
   the kernel runtime work begins?
4. **On-device measurement first.** Before *any* memory-v2 Swift cut, do we
   want a throwaway on-device profiling spike (write/query latency, storage
   growth, battery) to replace the literature's missing on-device numbers?

---

## Appendix — verified sources

Primary (peer-reviewed / arXiv): `2405.14831` HippoRAG · `2502.14802` HippoRAG 2
· `2407.04363` AriGraph · `2504.19413` Mem0/Mem0^g · `2501.13956` Zep/Graphiti ·
`2305.10250` MemoryBank · `2025.acl-long.413` / `2503.08026` RMM · `2601.18642`
FadeMem (preprint) · `2410.10813` LongMemEval · `2603.07670v1` memory survey.
On-device infra: sqlite-vec (stable), Alibaba zvec (Feb 2026), embedding
quantization. Refuted (excluded): Zep>MemGPT on DMR.
