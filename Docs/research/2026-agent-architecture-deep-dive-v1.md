# 2026 Agent Architecture Deep-Dive for kAir

Status: A181 research digest (durable source record). Informational, not runtime code.
Last updated: 2026-06-01.

Four parallel deep-dives — academic papers, on-device runtime (Marvis/MLX),
Tencent Yuanbao, Meituan LongCat — feeding `kair-architecture-redesign-v2.md`.
This file preserves the **sources** and the **facts**; design implications live
in the redesign doc §3.

---

## 1. Agent-architecture papers (2023–2026)

| # | Paper | Year/Venue | URL | Takeaway |
|---|---|---|---|---|
| P1 | MemGPT | 2023 | https://arxiv.org/abs/2310.08560 | Context = RAM, external store = disk; OS-style paging. |
| P2 | Generative Agents | UIST 2023 | https://arxiv.org/abs/2304.03442 | observation → retrieval(recency+importance+relevance) → reflection. |
| P3 | A-MEM | NeurIPS 2025 | https://arxiv.org/abs/2502.12110 | Zettelkasten notes that co-evolve (edit prior notes), not append-only. |
| P4 | AgeMem | 2026 | https://arxiv.org/abs/2601.01885 | Memory ops (store/retrieve/update/discard) as typed tool-calls, RL-trained. |
| P5 | ReAct | ICLR 2023 | https://arxiv.org/abs/2210.03629 | Interleave reasoning + tool actions; canonical agent loop. |
| P6 | Reflexion | NeurIPS 2023 | https://arxiv.org/abs/2303.11366 | Verbal self-critique into episodic memory; in-context improvement. |
| P7 | LLMCompiler | ICML 2024 | https://arxiv.org/abs/2312.04511 | Planner emits tool-call DAG; parallel dispatch → 3.7× faster, 6.7× cheaper. |
| P8 | Plan-and-Solve | ACL 2023 | https://arxiv.org/abs/2305.04091 | Explicit "plan then execute" beats "think step by step". |
| P9 | FrugalGPT | TMLR 2024 | https://arxiv.org/abs/2305.05176 | LLM cascade w/ confidence threshold; up to 98% cost cut. |
| P10 | RouteLLM | 2024 | https://arxiv.org/abs/2406.18665 | Preference-trained router; 95% quality routing 85% to cheap models. |
| P11 | xRouter | 2025 | https://arxiv.org/abs/2510.08439 | RL router, reward = quality − λ·cost. |
| P12 | MCP Landscape & Threats | 2025 | https://arxiv.org/abs/2503.23278 | 4 attacker types, 16 threat scenarios across server lifecycle. |
| P13 | MCP Safety Audit | 2025 | https://arxiv.org/abs/2504.03767 | "No single defense covers >34%"; prompt-injection/cred-theft/RCE demonstrated. |
| P14 | MCPSHIELD | 2026 | https://arxiv.org/abs/2604.05969 | Capability access control + attestation + info-flow + runtime policy → 91% coverage. |
| P15 | MobileLLM | ICML 2024 | https://arxiv.org/abs/2402.14905 | Deep-thin sub-1B SLMs; API-calling near LLaMA-7B. |
| P16 | TinyLLM | 2025 | https://arxiv.org/abs/2511.22138 | 1–3B viable for agents; <1B fails multi-turn. |
| P17 | PhoneLM | 2024 | https://arxiv.org/abs/2411.05046 | Architecture-search-for-hardware first; invokes Android Intents. |
| P18 | Mobile Edge Intelligence survey | IEEE 2024 | https://arxiv.org/abs/2407.18921 | on-device → edge → cloud as a continuous optimization. |

Supporting: MemoryBank (arXiv:2305.10250), Mem0 (arXiv:2504.19413), memory
survey (arXiv:2603.07670), Apple PCC analysis (arXiv:2605.24239).

---

## 2. On-device runtime — Marvis / MLX

- "Marvis" = a **TTS model** family (Apache-2.0, MLX, CSM-1B distillation,
  Kyutai Mimi codec), **not** a full voice agent. 250M / 100M backbone + 60M
  audio decoder. [model card](https://huggingface.co/Marvis-AI/marvis-tts-250m-v0.2),
  [intro](https://huggingface.co/blog/prince-canuma/introducing-marvis-tts).
- **MLX** is the Apple-Silicon generative-inference path (streaming, dynamic
  shapes); Core ML stays best for classifiers/embedders. Metal shaders require
  Xcode build. [mlx-audio-swift](https://github.com/Blaizzy/mlx-audio-swift).
- Stream (don't chunk text); cap prefill ~512 tok ([SwiftLM](https://github.com/SharpAI/SwiftLM));
  3-tier context (frozen system / compressed summary / recent buffer) to bound
  KV cache ([arXiv:2511.03728](https://arxiv.org/pdf/2511.03728)).
- License interaction (Apache-2.0 weights vs non-commercial upstream CSM-1B) is
  a **release gate** → make `ModelCatalogEntry.license` policy-checked.

---

## 3. Tencent Yuanbao

- **2×2 model grid**: speed×depth × provider (Hunyuan Turbo S / T1 × DeepSeek
  V3 / R1); **user-controlled** selection, no disclosed silent auto-routing.
  [AIBase](https://www.aibase.com/news/15424),
  [TechNode](https://technode.com/2025/03/26/tencent-upgrades-yuanbao-ai-with-self-developed-model-hunyuan-t1/).
- **Agentic RAG / DeepSearch**: planning → search → reading → reflection; plugin
  APIs vectorized, top-k recall → rank → top-n in token budget; rankers distilled
  to 0.5B INT8. [Tencent Cloud](https://cloud.tencent.com/developer/article/2556938).
- Memory deliberately **shallow**: Favorites = user-curated scrapbook recalled by
  @-mention; deeper MemOS (episodic+semantic+procedural) remains research.
  [Favorites](https://www.aibase.com/news/16855),
  [MemOS](https://cloud.tencent.com/developer/article/2538523).
- **Sandbox discipline**: PAI / Groups debut in a contained surface before WeChat.
  [TechNode](https://technode.com/2026/01/27/ai-gets-social-in-china-tencent-tests-yuanbao-groups-for-ai-powered-social-interaction/).
- Hy3 (295B/21B MoE agent foundation model, MCP orchestration, ≤495 steps), led
  by ReAct author. [Tencent](https://www.tencent.com/en-us/articles/2202320.html).

---

## 4. Meituan LongCat / life-services

- **LongCat-Flash** (560B MoE, ~27B active, MIT); agentic training = 80k mock
  tools / 1600 apps / 40 domains; VitaBench (30+ tools, 60+ rounds).
  [arXiv:2509.01322](https://arxiv.org/abs/2509.01322).
- **LocalSearchBench**: optimal **N≈5 tool rounds**; failures = unstable tool
  strategy 38.6%, missing planning 30.9%, query-gen 11.8%, long-context noise
  18.7%. [arXiv:2512.07436](https://arxiv.org/html/2512.07436).
- **LocalEval/LocalGPT**: spatiotemporal-context is its own task category; 7B
  instruction-tuned ≈ 72B; city-specified prompts fix cross-region transfer.
  [arXiv:2506.02720](https://arxiv.org/html/2506.02720).
- **MTGR** production ranker: LLM emits feature tags → efficient ranker scores at
  scale (not LLM-as-ranker). +1.90% PV_CTR. [arXiv:2505.18654](https://arxiv.org/abs/2505.18654).
- **Xiaomei** agent app: NL/voice → intent → spatiotemporal anchoring → merchant
  DB query → booking API → confirm → multi-turn.
  [Bloomberg](https://www.bloomberg.com/news/articles/2025-09-12/meituan-launches-ai-agent-to-boost-food-delivery-business).
- Serving: LongCat $0.70/M output tokens; PD-disaggregation, speculative decode
  (>90% accept). [LMSYS](https://www.lmsys.org/blog/2025-09-01-sglang-longcat-flash/).

---

## 5. Consolidated implications for kAir

1. **Hard domain gate before cost gate** (health = local-only first) — already in `PlanValidator`.
2. **Health-specialist ≥1B params**; router/planner/embedder ≤1.5B viable; 7B life-service tuned ≈ 72B.
3. **Co-evolving + tiered memory** (A-MEM/MemGPT) → `MemoryConsolidationPolicy`; but **explicit-save-first** (Yuanbao Favorites) before ambient auto-memory.
4. **Planner emits a typed DAG** (LLMCompiler) bounded at **N≈5 rounds, plan-first** (LocalSearchBench) → `PlanGraph` + `AgentLoopBudget`.
5. **Cost-aware model cascade** (FrugalGPT/RouteLLM/xRouter), **user-visible** choice (Yuanbao 2×2) → `ModelTierRouter`.
6. **Capability adapter layer = MCP trust boundary** (MCPSHIELD); MCP runtime stays disabled until discovery+call-time gates harden.
7. **Spatiotemporal context as a required slot** + city/locale prompt (Meituan) → `SpatiotemporalContext`.
8. **LLM-as-feature-generator + simple ranker** for recommendations (MTGR), not LLM-as-ranker.
9. **MLX for generative on-device, Core ML for classifiers**; license is a bundling gate → `ModelRuntime`.
10. **App Intents + typed adapters + visible receipts** over hidden cross-app tapping (vs MARVIS-class).

## 6. A121 Delta After Metered Entitlement Status Stack

A117-A120 moved the repo beyond "cost can be represented" into "metered
entitlement status composes deterministically at app root and ChatStore." The
remaining pre-runtime architecture gap is narrower: A112 transport lease
issuance must be proven to depend on an accepted A117 metered entitlement
decision, not just any explicit quota snapshot.

Updated source read:

- FrugalGPT, RouteLLM, and LLMCompiler still support explicit cost-aware routing
  and compiled tool/provider dispatch before execution.
- MCP specification and MCP security papers still argue for descriptor filtering
  and call-time authorization before any MCP runtime.
- Apple App Intents/Foundation Models/Core Location docs keep the iOS path
  local, structured, and privacy-explicit.
- Google/Gaode/Search API provider docs keep cost, attribution, quota, source,
  raw-content, and privacy policy as provider-specific runtime constraints.
- VitaBench, LocalSearchBench, Tencent Hy3/Yuanbao, and Meituan LongCat keep
  life-service quality tied to multi-step search/tool traces and verified
  receipts, not unsupported booking/order/payment claims.

A121 implication: A122 should be a Search API metered-entitlement transport
lease handoff proof. It should not start live provider runtime; it should prove
that accepted A117 decisions can issue A112 leases and rejected/mismatched
budget decisions cannot.

## 7. A125 Delta After Metered Lease Composition

A122-A124 closed the previous pre-runtime gap: accepted metered entitlement
decisions can issue Search API transport leases, lease status reaches
provider-status copy, and that copy composes deterministically with the other
provider-status layers through AppBootstrap and ChatStore.

Updated source read:

- Cost-aware routing work still argues for explicit dispatch inputs and
  request-level cost/quality controls before execution.
- MCP specification/security work still requires descriptor filtering,
  authorization, consent, and call-time gates before runtime MCP clients.
- Apple App Intents/Foundation Models/Core Location still favor structured,
  local-first, privacy-explicit iOS surfaces.
- Google/Gaode/Search provider docs still make pricing, quota, attribution,
  caching, raw-content, region, and privacy constraints provider-specific.
- Tencent Yuanbao/Hy3, Meituan LongCat, LocalSearchBench/VitaBench, and
  MARVIS-style mobile-assistant positioning still support transparent,
  receipt-backed workflows over hidden universal automation.

A125 implication: A126 should not be live provider runtime. It should be a
Search API transport request contract proof that binds an issued A122 lease to
the exact request, payload, dispatch, vendor policy, authorization, result
shape, source, citation, freshness, cost, and metered entitlement metadata that
a future server adapter would consume. The request can be an internal
metadata-only value; it must not contain endpoint URLs, credentials, SDK/client
handles, raw page/provider payloads, payment/order data, crawler/MCP metadata,
maps SDK metadata, or execution claims.

## 8. A130 Delta After Request Status Composition

A126-A129 closed the A125 gap: a lease-bound Search API transport request can
be prepared, its status can be rendered for visible recommendation ids, and it
can compose with the earlier metered entitlement, vendor policy, payload
dispatch, dispatch authorization, and lease status layers without stale detail
mixing.

Updated source read:

- FrugalGPT, RouteLLM, LLMCompiler, BaRP, and budget-aware routing papers still
  support explicit cost/quality/latency routing before execution. They do not
  argue for hiding provider cost or dispatch state inside a runtime call.
- Search API vendor docs still diverge on answer generation, raw-content
  controls, source/citation metadata, query/search-depth pricing, context
  retrieval, and latency knobs.
- Google Maps/Places and Gaode/AMap docs still keep attribution, storage,
  display, region, quota, QPS, key management, privacy, and paid-usage policy
  provider-specific.
- MCP specification and security papers still require descriptor trust,
  authorization scope, prompt-injection resistance, credential protection,
  attestation/sandboxing, and call-time policy before runtime use.
- Apple App Intents, Foundation Models, and Core Location still support
  structured local-first iOS actions and explicit privacy handling over hidden
  third-party control.
- Mobile GUI-agent papers, Tencent Hy3/Yuanbao, Meituan LongCat, and
  LocalSearchBench-style life-service work raise user expectations for
  multi-step assistance, but the credible product pattern is still visible
  receipts and user confirmation, not unverified booking/order/payment
  completion.

A130 implication: A131 should still not be live provider runtime. It should be
a Search API transport response receipt contract proof that accepts a
normalized/cited adapter result receipt only when it belongs to the prepared
A126 transport request and preserves the full request/payload/dispatch/vendor/
authorization/lease/budget/metered/source/citation/cost/freshness chain. The
contract can carry normalized cited result metadata for future UI/result
handoff, but it must not add endpoint URLs, credentials, URLSession, SDK/client
handles, crawler/MCP clients, Google/Gaode SDKs, StoreKit/payment, booking,
raw page/provider payloads, hidden app-control claims, or real provider
execution.

## 9. A139 Delta After External Provider Status Composition

A131-A138 now prove the value-only status chain from Search API response
receipt through generic external provider adapter preflight, app-root handoff,
ChatStore lookup, and cross-stage first-source-wins composition. The open
architecture problem is no longer "can provider state be shown"; it is "can a
future provider attempt be audited, evaluated, and rejected safely before any
runtime call exists."

Updated source read:

- Agent-routing and tool-agent literature still treats cost, latency, quality,
  plan/tool trace, and evaluation feedback as explicit deployment variables.
  The strongest fit for kAir is not live execution yet; it is a typed
  audit/evaluation record that can later compare provider behavior without
  exposing raw payloads.
- MCP has continued to formalize protocol surfaces such as authorization,
  elicitation, tasks, tools, prompts, and resources, while MCP security work
  keeps descriptor trust, prompt injection, tool poisoning, credential scope,
  parameter visibility, and call-time policy as unresolved runtime risks.
- Apple App Intents, Foundation Models, Core ML, and Core Location still map to
  structured, local-first, permissioned iOS capabilities. They do not justify a
  hidden cross-app-control layer.
- Google Maps/Places, Gaode/AMap, Search API vendors, and crawler policy still
  diverge on cost, quota, QPS, attribution, storage/cache, region, privacy,
  raw-content/citation shape, and source policy.
- Marvis-style mobile-agent positioning, Tencent Yuanbao/Hy3, and Meituan
  LongCat/life-service signals support visible, multi-step assistance with
  receipts and sources. They do not support kAir claiming booking, ordering,
  payment, or third-party app completion before user confirmation and provider
  receipts exist.

A139 implication: A140 should remain value-only. It should introduce an
external provider transport audit trace and evaluation contract that can bind
future Search API, Google/Gaode, crawler, MCP, and remote model attempts to the
existing preflight/status stack. The contract should encode provider family,
capability, membership/cost/privacy class, source/citation/attribution policy,
selected status-source rank, expected evaluation dimensions, and deterministic
rejection reasons. It must not add URLSession, endpoints, credentials, SDK
clients, crawler/MCP runtime, Google/Gaode SDKs, raw query/page/provider
payloads, StoreKit/payment/order data, hidden app control, or real provider
execution.

## 10. A149 Delta After Readiness Cross-Stage Composition

A140-A148 closed the audit, boundary, readiness, status, app-root, and
cross-stage composition proofs for the Search API live-transport boundary. The
stack can now prove that a future live path is still disabled, but it still
does not prove that a vendor candidate can be chosen under current market
pricing, citation/source policy, privacy, latency, retention, and UI-safe status
constraints.

Sources refreshed for A149 on 2026-05-31:

- Agent architecture: [Agentic AI taxonomy](https://arxiv.org/abs/2601.12560)
  frames modern agents around perception, brain/planning, action, tool use,
  collaboration, evaluation, MCP, and computer use, with open risks around
  prompt injection, action hallucination, and loops.
- Memory: [Memory for Autonomous LLM Agents](https://arxiv.org/abs/2603.07670)
  formalizes agent memory as write-manage-read, with privacy governance,
  contradiction handling, latency budgets, and learned forgetting still open.
- MCP security: [MCP threat modeling](https://arxiv.org/abs/2603.22489)
  identifies tool poisoning in metadata as a client-side risk; [Prompts Don't
  Protect](https://arxiv.org/abs/2605.18414) shows discovery filtering plus
  invocation-time ABAC is needed because prompt-only restrictions leave risk.
- Open-source agent frameworks: [LangGraph](https://docs.langchain.com/oss/python/langgraph/overview)
  emphasizes durable execution, human-in-the-loop, persistence, memory, and
  tracing; [AutoGen](https://microsoft.github.io/autogen/stable/) separates
  AgentChat/Core/Extensions and includes MCP/Docker/runtime extensions;
  [CrewAI](https://docs.crewai.com/en/introduction) separates Flows, Crews,
  tools, memory, planning, testing, checkpointing, MCP integration, HITL, and
  observability. IEEE Access 2026 work on hybrid multi-agent coordination
  (DOI `10.1109/ACCESS.2026.3683900`) reports framework tradeoffs across
  CrewAI, AutoGen, and LangGraph/LangChain-style orchestration and supports
  framework-agnostic interfaces plus deterministic fallbacks over a single
  framework runtime.
- Market signals: [Tencent Hy3/Yuanbao](https://www.tencent.com/en-us/articles/2202320.html)
  ties product integration, authentic evaluation, cost efficiency, 495-step
  workflows, search execution, and MCP orchestration; [Meituan
  LongCat-Flash-Thinking-2601](https://tech.meituan.com/2026/01/20/longcat-flash-thinking-2601.html)
  emphasizes agentic search, tool use, noisy tool environments, random complex
  tasks, and open-source deployment; [Tencent Marvis](https://marvis.qq.com/)
  presents a local/端云协同 assistant with local-file privacy, remote takeover
  visibility, local knowledge, and device-setting actions.
- Search providers: [Brave Search API](https://brave.com/search/api/) separates
  Search and Answers plans, QPS, citations, streaming, zero-data-retention
  enterprise terms, and API-key headers; [Tavily Search](https://docs.tavily.com/documentation/api-reference/endpoint/search)
  exposes `search_depth`, raw-content inclusion, answer generation, country,
  latency/relevance tradeoffs, and credit use; [Exa pricing](https://exa.ai/pricing)
  separates Search, Deep Search, Agent, Contents, livecrawl policy, and
  endpoint pricing; [Perplexity pricing](https://docs.perplexity.ai/docs/getting-started/pricing)
  separates tool invocation cost, search context size, citation tokens, search
  queries, and reasoning tokens.
- Map providers: [Google Maps Platform March 2025 changes](https://developers.google.com/maps/billing-and-pricing/march-2025)
  splits offerings into Essentials/Pro/Enterprise; [Google Places
  policies](https://developers.google.com/maps/documentation/places/web-service/policies)
  require Terms/Privacy, caching limits, visible Google Maps attribution, and
  third-party/photo/review attribution; [Google Maps pricing](https://mapsplatform.google.com/pricing/)
  lists Maps Grounding Lite as an MCP-oriented fresh Maps data surface. [Gaode
  pricing](https://lbs.amap.com/pages/base_service_price) exposes monthly
  quota, QPS, and paid traffic behavior; [Gaode privacy protocol](https://lbs.amap.com/api/compliance-center/protocols/privacy_202410)
  keeps compliance as a first-class provider constraint.

### A149 decision matrix

| Topic | Adopt now | Monitor | Reject for next gate |
|---|---|---|---|
| Agent architecture | Keep typed plan/policy/adapter/receipt/status boundaries. Add vendor selection as another explicit value decision before execution. | Durable graph runtimes and HITL patterns from LangGraph/AutoGen/CrewAI as later orchestration references. | Replacing kAir's typed gates with a generic agent framework runtime. |
| Market UX | Show provider/cost/source/freshness status and user-visible limitations. Keep local-first iOS and explicit receipts. | Marvis-style local/remote takeover UI and LongCat/Yuanbao long workflow expectations. | Hidden cross-app control, fake booking/order/payment/completion, or silent provider switching. |
| Search API | Normalize vendor candidate selection by capability, cost unit, citation/source support, raw-content policy, retention, freshness, latency, and quota before live calls. | Vendor-specific server adapters after A150-style selection is value-proven. | Choosing a vendor endpoint or key in A150. |
| Maps | Keep Apple/local default. Represent Google/Gaode as future provider families with cost, region, attribution, cache, privacy, and membership requirements. | Google Maps Grounding Lite / AMap MCP-style surfaces as future provider candidates behind MCP/provider gates. | Client-side provider API keys or direct SDK/API runtime in this stage. |
| MCP/crawler | Keep disabled. Use MCP research to require discovery filtering, invocation gate, attestation/sandboxing, and prompt-injection tests before runtime. | A future MCP descriptor-selection proof after Search API candidate selection. | Exposing MCP prompt/resource/tool descriptors to model context as trusted text. |
| Memory/UI | Keep public search facts as memory candidates only after citation/source/privacy policy passes. | Learned memory and durable task traces after write-policy and eval gates mature. | Remote memory for private/Health/location-sensitive data. |

Can A150 start live Search API transport? **No.**

The missing proof is not another app-root/status handoff; A148 has that. The
missing proof is **vendor candidate selection under mutable cost and policy**.
Search providers expose materially different pricing, answer-vs-result shape,
raw-content controls, citation/source fields, context/search-depth billing,
latency, rate/QPS, and retention terms. A150 should therefore add a pure
value-only vendor selection and cost-policy matrix before any endpoint,
credential, URLSession, SDK/client, crawler/MCP runtime, map SDK, or provider
execution can exist.

## 11. A164 Delta After Invocation Preflight Composition

A150-A163 filled the vendor-selection, adapter-interface, invocation-preflight,
status-source, app-root, and cross-stage composition gaps described above. The
Search API stack can now represent a future live-provider attempt as a
non-callable preflight and prove that its user-facing status does not leak
stale or later-source detail.

Current research conclusion on 2026-06-01:

- The architecture is aligned with current agent systems because it keeps
  planning, policy, adapter shape, status projection, and audit records
  explicit.
- Current market signals reward long, tool-heavy workflows, but only when
  users can see mode, source, cost, and failure state.
- Current MCP/security evidence still blocks default connector execution and
  still requires descriptor filtering plus invocation-time authorization.
- Current Apple, Search API, Google, and Gaode docs still favor server-owned
  provider secrets, explicit entitlement, policy-aware attribution/cache rules,
  and no hidden third-party app control.

### A164 refreshed source notes

| Source cluster | 2026-06-01 note | kAir implication |
|---|---|---|
| LangGraph / OpenAI Agents SDK / AutoGen / CrewAI / smolagents | Frameworks expose state, tools, handoffs, tracing, HITL, memory, sessions, and deployment as separate concerns. | Keep kAir framework-agnostic. Add one more typed server-provider value before any runtime adapter. |
| Budgeted-agent routing / RouteLLM / LLMCompiler / Agent Lightning | Cost, latency, parallelism, tool choice, and traces are deployment variables, not incidental logs. | The next provider attempt must carry budget, cost unit, selected vendor, and audit ids in a frozen envelope. |
| Tencent Hy3/Yuanbao / Meituan LongCat / Marvis | Public products emphasize product-specific evaluation, search/tool execution, local/remote visibility, and robust life-service behavior. | UI should remain receipt-led and local-first. Do not claim booking, payment, third-party action, or provider completion before a signed receipt exists. |
| MCP 2025-11-25 spec and security work | Authorization discovery, scope minimization, token protection, SSRF/session risks, local-server compromise, and prompt/tool poisoning remain active concerns. | MCP descriptors can be reserved as metadata only. No client/runtime bridge should exist in A165. |
| Apple App Intents / Foundation Models / Core Location | iOS action and local model surfaces are structured, availability-bound, and permission-sensitive. | kAir should keep App Intents/local providers as the default and treat remote provider attempts as explicit server-mediated envelopes. |
| Brave / Tavily / Exa / Perplexity | Vendors split search, answer, agent, contents, raw-content, citation, context, QPS, and retention controls differently. | A single generic URL request is the wrong next abstraction; a policy-rich invocation envelope is the smaller safer step. |
| Google Maps / Google Places / Gaode / RFC 9309 | Maps providers carry attribution, caching, SKU, quota, QPS, privacy, and region duties; crawler rules are policy input but not auth. | Maps/crawler families remain later. A165 may reserve common policy fields but must not instantiate these runtimes. |

### A164 decision matrix

| Topic | Adopt now | Monitor | Reject for next gate |
|---|---|---|---|
| Agent architecture | Add a prepared-only invocation envelope that binds accepted preflight, vendor, budget, source, retention, region, lease, request, and audit ids. | Durable workflow execution and training/eval trace export after live attempts exist. | Jumping from preflight status directly to URLSession or SDK runtime. |
| Market UX | Keep provider mode, cost/source/freshness, and limitation copy visible. | Marvis-style local/remote mode controls and LongCat/Yuanbao workflow expectations. | Hidden app takeover, fake task completion, or unverified booking/order/payment claims. |
| Search API | Freeze attempt metadata before transport. | Server adapter implementation after envelope, redaction, and status handoff are proven. | Client-side API keys, raw queries in debug copy, uncited public facts, or hidden metered calls. |
| Maps | Preserve Apple/local default and reserve Google/Gaode as explicit provider families. | Server-mediated maps adapters after attribution/cache/quota/privacy contracts. | Direct Google/Gaode SDK/API runtime in this stage. |
| MCP/crawler | Keep disabled and model hostile descriptor/source assumptions. | A future descriptor-selection and invocation-gate proof. | Runtime MCP/crawler clients or prompt-trusted descriptors. |
| Memory/evaluation | Keep envelope fields suitable for later evaluation while redacting raw payloads. | Post-provider execution eval once real receipts exist. | Logging raw provider pages, credentials, or private Health/location data. |

Can A165 start live Search API transport? **No.**

A165 should not be a network adapter. The smallest safe next move is a
metadata-only Search API live-provider invocation envelope contract. It should
accept only an already accepted A160 preflight and produce a prepared-only,
non-executable, UI-safe attempt envelope with expiry, source/citation,
retention, cost, region, lease, request, and audit metadata. That envelope
gives a later live adapter a clear contract to satisfy without leaking
credentials, endpoints, raw queries, raw provider payloads, MCP/crawler detail,
maps SDK detail, StoreKit/payment/order data, hidden app control, or execution
claims.

## 12. A175 Delta After Routing Status Stack Composition

A165-A174 closed the prepared-envelope, status-source, app-root, stack-plan,
cost/membership routing, decision, routing status-source, root handoff, and
status-stack composition loop. The codebase can now prove first-wins source
order and copy equality across routing and existing Search API provider-status
sources. The architecture gap has narrowed to policy compatibility between
upstream cost/membership routing and downstream provider policy/dispatch/
authorization/lease state.

Sources refreshed for A175 on 2026-06-01:

- Agent frameworks:
  [LangGraph](https://docs.langchain.com/oss/python/langgraph/overview),
  [OpenAI Agents SDK](https://openai.github.io/openai-agents-python/),
  [AutoGen](https://microsoft.github.io/autogen/stable/),
  [CrewAI](https://docs.crewai.com/en/introduction), and
  [smolagents](https://huggingface.co/docs/smolagents/index) continue to
  separate tools, state, memory, handoffs, tracing, and execution controls.
- UI status surface:
  [OpenAI Apps SDK UI guidelines](https://developers.openai.com/apps-sdk/concepts/ui-guidelines)
  continue to separate text, cards, iframes, actions, and status-bearing
  components, reinforcing kAir's explicit shell/status-copy approach.
- Cost and routing papers:
  [FrugalGPT](https://arxiv.org/abs/2305.05176),
  [RouteLLM](https://arxiv.org/abs/2406.18665),
  [LLMCompiler](https://arxiv.org/abs/2312.04511),
  [Agentic AI taxonomy](https://arxiv.org/abs/2601.12560),
  [Memory for Autonomous LLM Agents](https://arxiv.org/abs/2603.07670), and
  [SwitchCraft](https://arxiv.org/abs/2605.07112) support explicit routing,
  cost, tool choice, trace, and memory-governance boundaries.
- MCP security:
  [MCP 2025-11-25 security guidance](https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices),
  [MCP threat modeling](https://arxiv.org/abs/2603.22489),
  [Prompts Don't Protect](https://arxiv.org/abs/2605.18414), and
  [Beyond the Protocol](https://arxiv.org/abs/2604.05969) reinforce discovery
  filtering, invocation-time authorization, token protection, SSRF defenses,
  and local-server risk controls.
- Provider policy:
  [Brave Search API](https://brave.com/search/api/),
  [Tavily Search API](https://docs.tavily.com/documentation/api-reference/endpoint/search),
  [Exa pricing](https://exa.ai/pricing),
  [Perplexity pricing](https://docs.perplexity.ai/guides/pricing),
  [Google Maps March 2025 billing](https://developers.google.com/maps/billing-and-pricing/march-2025),
  [Google Places policies](https://developers.google.com/maps/documentation/places/web-service/policies),
  [Gaode pricing](https://lbs.amap.com/pages/base_service_price),
  [Gaode privacy protocol](https://lbs.amap.com/api/compliance-center/protocols/privacy_202410),
  and [RFC 9309](https://www.rfc-editor.org/rfc/rfc9309) keep cost unit,
  quota/QPS, attribution, retention, raw-content, region, crawler, and privacy
  policy divergent.
- Apple/local-first:
  [App Intents](https://developer.apple.com/documentation/appintents),
  [Foundation Models](https://developer.apple.com/documentation/foundationmodels/),
  and [Core Location permissions](https://developer.apple.com/documentation/corelocation/configuring-your-app-to-use-location-services)
  keep device actions structured, availability-bound, and consent-aware.

### A175 architecture decision

Can A176 start live provider/runtime work? **No.**

The current stack is directionally aligned with modern agent systems because it
uses typed, inspectable layers instead of hidden tool execution. But current
research does not justify crossing into provider runtime. The risky gap is
semantic mismatch: a cost/membership route can be selected while downstream
policy, entitlement, dispatch, authorization, or lease state would later block
or revise the attempt. If that mismatch is not explicitly tested, UI status can
mix stale lower-priority markers or imply that a route is callable when it is
only advisory.

The next value-only gate should be:

**A176 Search API Cost/Membership Routing Cross-Stage Policy Compatibility
Proof**

A176 should stay in `AppBootstrapTests` and compose A172 routing-decision
status with representative metered entitlement, vendor policy, payload
dispatch, dispatch authorization, transport lease, and fallback sources. It
should prove:

- Included-quota and metered routes preserve source -> root -> store copy
  equality without stale downstream marker mixing.
- Cost/privacy/region rejected routing copy does not leak later vendor,
  payload, authorization, lease, or fallback detail.
- Downstream-first order does not leak routing route, cost, quota, membership,
  or entitlement markers.
- Hidden/missing ids stay nil, fallback-after-miss remains explicit, and every
  selected copy remains value-only with `isRuntimeCallable false`.

A176 must not add production defaults, endpoint URLs, API keys, OAuth, SDK
clients, URLSession/networking, crawler/MCP runtime, Google/Gaode runtime,
StoreKit/payment, booking/order, remote model runtime, concrete vendor
selection, or real provider execution.

## 13. A181 Delta After Route-Policy Status Composition

A176-A180 moved the Search API path from "provider-status layers compose" to
"route-policy compatibility status composes with the whole earlier status
stack." The remaining architecture gap is no longer a Search-only handoff gap.
It is a cross-service product architecture gap: kAir needs one value contract
that names which lanes are local, which are server-mediated, which are reserved
behind crawler/MCP gates, and which facts must be visible in UI before any
future provider runtime can be considered.

Sources rechecked for A181 on 2026-06-01:

- Frameworks: LangGraph, OpenAI Agents SDK, AutoGen, CrewAI, and smolagents
  still split state, tools, memory, sessions, HITL, tracing, deployment, and
  MCP/tool extensions. This supports kAir's typed contract stack and argues
  against replacing it with a generic agent runtime.
- UI surfaces: OpenAI Apps SDK UI guidelines reinforce explicit components,
  action boundaries, and status-bearing UI. This matches kAir's provider-status
  copy and `ExecutionSurfaceShell` direction.
- Papers: Agentic AI taxonomy, memory surveys, FrugalGPT, RouteLLM,
  LLMCompiler, SwitchCraft, and tool-use surveys keep the same design pressure:
  explicit planning, tool selection, cost/latency routing, traceability, memory
  governance, and environment feedback before execution.
- MCP/security: MCP 2025-11-25 security guidance plus MCP threat-modeling,
  ABAC/discovery-filtering, and MCPSHIELD-style work keep descriptor poisoning,
  prompt injection, token theft, SSRF, local-server risk, and call-time
  authorization as design blockers for default runtime MCP.
- Market/life service: Tencent Hy3/Yuanbao, Tencent Marvis, Meituan LongCat,
  VitaBench, and LocalSearchBench support long search/tool workflows and
  life-service grounding, but the product lesson is visible mode/source/cost
  and reliable receipts, not hidden universal control.
- Providers: Brave/Tavily/Exa/Perplexity, Google Maps/Places, Gaode, RFC 9309,
  and Apple App Intents/Foundation Models/Core Location keep provider behavior
  divergent across pricing, raw content, citation/source, attribution/cache,
  region, quota/QPS, privacy, robots/source policy, and local permission
  handling.

### A181 architecture decision

Can A182 start live provider/runtime work? **No.**

The current repo already contains many value-only provider/routing/status
pieces: `ProviderAccessProfile`, `ServerProviderQuotaSnapshot`,
`ServerProviderEnvelopeFactory`, runtime adapter/readiness/dispatch value
contracts, Search API vendor/policy/lease/request/response/status layers, and
MCP/crawler reservations. What is missing is a compact product-facing cut-plan
contract that sits above provider-family mechanics and below UI copy:

```text
service intent
  -> service lane: local iOS / server-mediated / reserved-disabled
  -> membership + region + cost posture
  -> source/citation/raw-content or attribution/cache/display posture
  -> MCP/crawler descriptor/source/authorization posture
  -> decision: local-ready / server-reserved / blocked / unsupported
  -> UI-safe status copy, still non-executable
```

This should be A182. It is deliberately comment-programming first because the
next implementation risk is not algorithmic complexity; it is vocabulary drift.
Without a frozen service cut-plan, later agents may accidentally treat local
maps, Google/Gaode, Search API, crawler, and MCP as interchangeable "provider
calls." They are not interchangeable:

- local Apple/iOS maps are the default, permission-bound, non-metered path;
- Google/Gaode are server-mediated membership upgrades with map display,
  attribution, cache, quota/QPS, region, and privacy obligations;
- Search API is a public-info lane with source/citation/raw-content/retention
  and cost-unit obligations;
- crawler is a reserved source lane with robots, source, rate, retention,
  sandbox, and audit gates;
- MCP is a reserved tool/resource/prompt lane with descriptor verification,
  discovery filtering, call-time authorization, confirmation, token, and audit
  gates.

### A181 adopt / reserve / reject

| Area | Adopt now | Reserve | Reject for A182 |
|---|---|---|---|
| Agent architecture | A provider service cut-plan value contract with comments/tests as the next bridge from research to code. | Durable graph execution, learned routers, hosted tracing, and multi-agent orchestration after receipts and eval exist. | Generic framework runtime, raw prompt tool loops, or hidden provider switching. |
| UI logic | Local/server/reserved lane, selected provider family, membership/cost, source/freshness, attribution/cache/display, and blocked reason as status vocabulary. | Visual refinements after vocabulary freezes. | UI that claims provider call, booking, payment, order, app takeover, execution, or completion. |
| Maps | Apple/local first; Google/Gaode as future server-mediated upgrades. | Provider-specific adapters after cut-plan, display/cache policy, and receipt tests. | Client-side keys, direct SDK/API runtime, or silent premium maps route. |
| Search/crawler | Search API public-info lane remains the first server-mediated candidate; crawler remains reserved. | Crawler after robots/source/rate/retention/sandbox/audit gates. | Raw page payloads in copy, uncited life-service facts, paywall/login bypass, or runtime crawler. |
| MCP | Descriptor verification, discovery filtering, call-time authorization, confirmation, token protection, and audit as required vocabulary. | Runtime MCP after hostile-descriptor and invocation-gate tests. | Prompt-trusted MCP descriptors or default MCP client execution. |
| Cost/privacy | Membership, quota, metered eligibility, privacy class, region, and server-secret posture in every non-local lane. | Vendor-specific cost adapters after service cut-plan. | One generic paid API path that ignores region, privacy, source, or entitlement. |

### A182 implication

A182 should add a pure `ServerProviderServiceCutPlan` contract and focused
tests. It should not wire production defaults, create UI, add provider
adapters, call Search/Google/Gaode/crawler/MCP, or claim execution. The goal is
to freeze the service-lane vocabulary before the next agent writes runtime or
UI code against the wrong abstraction.
