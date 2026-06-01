# 2026 UI/UX & Market Deep-Dive for kAir

Status: research digest (durable source record). Informational, not runtime code.
Last updated: 2026-06-01.

Two parallel deep-dives — agent/chat-first mobile UI/UX patterns, and the 2026
AI-first local-services market — feeding `kair-architecture-redesign-v2.md` §9
(UI/UX) and §10 (Market). This file preserves the **sources** + **facts**; the
synthesis mapped to kAir's frozen primitives lives in the redesign doc.

---

## 1. Agent / chat-first mobile UI/UX (2025–2026)

### Findings
- **Composer**: docked bottom (not floating-over-content); grows to a scroll cap; 44pt Send/Stop; Gemini (2025–26) consolidated chips+overflow into one **"+" sheet** + a **Tools** button. Stop button must be visible during streaming.
- **Streaming**: first-token < 800 ms; skeleton shimmer (not spinners); blinking caret while generating; auto-scroll locks ~100px from bottom + "Jump to latest"; Arc Search uses a 3-step process animation + haptic tick + slow reveal.
- **Message vs card** (OpenAI Apps SDK decision tree): prose → full-width Markdown (no bubbles); options (≤8) → inline **carousel** (image + ≤3 metadata + 1 CTA); single action → inline card (≤2 actions, no internal scroll); immersive → fullscreen; parallel → PiP.
- **Action UX**: **Intent Preview** = plain-language preview + Proceed/Edit/Handle-myself (target >85% accept-without-edit); gate types = approve-plan / execution / output / exceptions; reversible → immediate + undo snackbar; **receipts + undo before expanding capabilities**; "Because X, I did Y" rationale + confidence signal.
- **Proactive**: Gemini Daily Brief + Spark (on-device); Siri 2026 proactive suggestions; **nudge-don't-nag** — dismissible, never persistent un-removable chips; cap carousel 3–8; suggestions fade on typing.
- **Provider/cost/trust**: Yuanbao user-selectable dual model; Perplexity numbered inline citations + freshness filters; ChatGPT model-name pill; Apple on-device vs PCC surfaced in Settings (not inline); no app yet has a clean inline local-vs-cloud badge (kAir opportunity).
- **Trust/regulatory**: CA AB 3030 (2025, AI-authorship + clinician disclosure), CA AB 489 (2026, no implying AI license), TX SB 1188 (2025, diagnostic disclosure). 92% of AI dashboards lack empty states, 78% lack error states (differentiator). 5-component error anatomy: summary / context / recovery / preserved-input / escalation.

### Sources
[Setproduct AI chat anatomy](https://www.setproduct.com/blog/ai-chat-interface-ui-design) ·
[OpenAI Apps SDK UI Guidelines](https://developers.openai.com/apps-sdk/concepts/ui-guidelines) ·
[Smashing — Designing for Agentic AI](https://www.smashingmagazine.com/2026/02/designing-agentic-ai-practical-ux-patterns/) ·
[Hatchworks Agent UX Patterns](https://hatchworks.com/blog/ai-agents/agent-ux-patterns/) ·
[9to5Google — Gemini Tools redesign](https://9to5google.com/2025/09/15/gemini-tools-redesign-android-ios/) ·
[Google — Gemini next evolution](https://blog.google/innovation-and-ai/products/gemini-app/next-evolution-gemini-app/) ·
[Arc Search blog](https://arc.net/blog/arc-search) ·
[UX Design Institute — Perplexity](https://www.uxdesigninstitute.com/blog/perplexity-ai-and-design-process/) ·
[Toolkit by AI — Perplexity review](https://toolkitbyai.com/perplexity-mobile-app-complete-review-2025/) ·
[UX Patterns Dev — AI error states](https://uxpatterns.dev/patterns/ai-intelligence/ai-error-states) ·
[Vibe Coder — empty/loading/error states](https://blog.vibecoder.me/empty-states-loading-states-error-states) ·
[Apple Intelligence](https://www.apple.com/apple-intelligence/) ·
[Fenwick — health AI regulation](https://www.fenwick.com/insights/publications/the-new-regulatory-reality-for-ai-in-healthcare-how-certain-states-are-reshaping-compliance) ·
[TMLT — Texas SB 1188](https://www.tmlt.org/resource/new-ai-disclosure-requirements-for-physicians-passed-into-texas-law) ·
[Bloomberg — Meituan Xiaomei](https://www.bloomberg.com/news/articles/2025-09-12/meituan-launches-ai-agent-to-boost-food-delivery-business) ·
[AIBase — Yuanbao dual model](https://www.aibase.com/news/15428)

---

## 2. 2026 AI-first local-services market

### Findings
- **Size**: AI assistant SW ~$9.8B (2025)→$35.7B (2033, 17.5%); on-device AI ~$17.6B→$185B (2035, ~27%); China O2O ~$150B (2024)→$300B (2033). Health & Lifestyle/Services = fastest-growing AI prompt categories.
- **Monetization**: $20/mo anchor (ChatGPT Plus, Perplexity Pro); ChatGPT $8 Go; Doubao RMB 68/200/500 (0.3–3% conv). RevenueCat 2026: trial-to-paid **42.5%** median vs cold freemium 2.1% D35; AI apps **+41% rev/payer but churn 30% faster**.
- **Competitors**: Doubao (345M MAU, agentic commerce, not privacy-first), Yuanbao (114M MAU, WeChat), **Meituan Xiaomei (life-services, platform-dependent, China-only, no privacy)**, Alibaba Quark, Apple/Google platform AI, Perplexity ($500M ARR). No incumbent = privacy-first + local-first + cross-market.
- **Privacy demand**: 81% fear AI data access; only 18% trust AI with data; 57% cite privacy as #1 assistant-trust driver. Tailwinds: China PIPL (CAC filing, local storage), EU AI Act (Aug 2026, ≤7% turnover fines), Apple Privacy Manifest. Apple Foundation Models = free/offline/on-device substrate.
- **Provider economics**: Google Maps Place Details $17/1k, Directions $5/1k → ~$2,549/mo @100K MAU (linear per-MAU); Gaode 2k req/day free then commercial. Search: Serper $0.30–1/1k · Brave ~$5/mo · Exa $1–5/1k · Tavily $8/1k. LLM: DeepSeek V3.2 $0.14/$0.28 per 1M tok; prices −80% in 2025. → premium tiers MUST be membership-gated.
- **Risks**: Apple 30% IAP; China legal entity + CAC filing; Google Maps 30-day cache ToS + no China; remote-model cost at scale → paywall; China/global bifurcation = first-class arch decision; AI churn 30% faster → offline utility is the antidote.

### Sources
[Grand View — AI assistant market](https://www.grandviewresearch.com/industry-analysis/ai-assistant-software-market-report) ·
[SNS Insider — on-device AI](https://www.globenewswire.com/news-release/2026/05/26/3301200/0/en/On-Device-AI-Market-Size-to-Hit-USD-185-23-Billion-by-2035-Research-by-SNS-Insider.html) ·
[Verified Market — O2O](https://www.verifiedmarketreports.com/product/online-to-offline-o2o-local-services-market-size-and-forecast/) ·
[Sensor Tower — State of AI Apps 2025](https://sensortower.com/blog/state-of-ai-apps-report-2025) ·
[RevenueCat — State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps/) ·
[TechNode — Doubao subscriptions](https://technode.com/2026/05/06/bytedance-tests-paid-subscriptions-for-ai-app-doubao-in-push-toward-monetization/) ·
[SCMP — China AI app rankings](https://www.scmp.com/tech/tech-trends/article/3337650/bytedance-other-major-chinese-tech-firms-dominate-local-consumer-ai-market-report) ·
[HBR — China AI agents in commerce](https://hbr.org/2026/04/research-what-chinas-ai-agents-reveal-about-the-future-of-commerce) ·
[Apple Newsroom — Foundation Models framework](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/) ·
[PPC.land — 81% fear AI data](https://ppc.land/81-of-consumers-fear-ai-data-access-but-daily-use-keeps-climbing/) ·
[Zendesk — AI trust survey](https://www.zendesk.com/newsroom/press-releases/global-survey-reveals-growing-consumer-trust-in-personal-ai-assistants/) ·
[Securiti — China AI regulation](https://securiti.ai/china-ai-regulatory-landscape/) ·
[MapAtlas — Google Maps pricing 2026](https://mapatlas.eu/blog/google-maps-api-pricing-2026) ·
[Awesome Agents — search API pricing](https://awesomeagents.ai/pricing/search-api-pricing/) ·
[Featherless — LLM pricing 2026](https://featherless.ai/blog/llm-api-pricing-comparison-2026-complete-guide-inference-costs)

---

## 3. Top implications for kAir (→ redesign §9–§10)

1. Privacy/local-first is the **acquisition hook**, not a feature (81% fear / 18% trust gap).
2. Single trial-first membership ≈ $9.99–14.99/mo, below the $20 anchor; unlocks maps/search/remote-model behind `MembershipTier` + metered ledger, never silent.
3. On-device default = unlimited/zero-marginal-cost (Apple FM); cap free remote calls.
4. China/global dual-provider (Gaode/Google) = structural moat + first-class arch decision.
5. Counter AI churn with persistent **offline daily utility**.
6. UI: dock composer + "+" sheet; carousel-vs-card by intent; 3-option Intent Preview + receipts/undo; disclosure-first permission/error states; cap RecommendedNext ~4 + fade-on-type; 3-tier provider badges; Arc-style process step-list; reusable "I need more info" escalation (health → clinician CTA, release-blocking).
7. Net-new UI surfaces require a **visual-system v2 bump**: model/provider chooser, memory-management screen, spatiotemporal grounding header (redesign §9.2).

## 4. A175 UI / Market Delta After Routing Status Stack

The A172-A174 stack proves that Search API routing status can move through
app-root and store lookup without leaking later source markers. From a product
and UI standpoint, that is necessary but not sufficient. The next user-visible
risk is not layout. It is a false status claim: a cost/membership route can
look acceptable while a downstream vendor-policy, payload-dispatch,
authorization, lease, entitlement, or fallback source would make the attempt
blocked, review-only, or not callable.

Sources rechecked for this A175 UI/market pass on 2026-06-01:

- [OpenAI Apps SDK UI guidelines](https://developers.openai.com/apps-sdk/concepts/ui-guidelines)
  for explicit component/action/status boundaries.
- [Tencent Marvis](https://marvis.qq.com/),
  [Tencent Hy3/Yuanbao](https://www.tencent.com/en-us/articles/2202320.html),
  and [Meituan LongCat](https://tech.meituan.com/2026/01/20/longcat-flash-thinking-2601.html)
  for local/remote mode, long tool workflows, product-specific evaluation, and
  life-service expectations.
- [Brave Search API](https://brave.com/search/api/),
  [Tavily Search API](https://docs.tavily.com/documentation/api-reference/endpoint/search),
  [Exa pricing](https://exa.ai/pricing), and
  [Perplexity pricing](https://docs.perplexity.ai/guides/pricing) for search
  cost, citation, context, raw-content, rate, and retention divergence.
- [Google Places policies](https://developers.google.com/maps/documentation/places/web-service/policies),
  [Google Maps pricing](https://mapsplatform.google.com/pricing/),
  [Gaode pricing](https://lbs.amap.com/pages/base_service_price), and
  [Gaode privacy protocol](https://lbs.amap.com/api/compliance-center/protocols/privacy_202410)
  for maps/local-life attribution, cache, quota/QPS, and privacy constraints.
- [MCP security best practices](https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices)
  plus [MCP threat modeling](https://arxiv.org/abs/2603.22489) and
  [Prompts Don't Protect](https://arxiv.org/abs/2605.18414) for descriptor,
  prompt-injection, token, and invocation-authorization risks.

### A175 UI decision

Can A176 start live provider/runtime work? **No.**

The current market direction supports kAir's chat-first shell, provider/status
badges, receipts, and local-first promise. It does not support hidden provider
calls or optimistic completion states. A176 should therefore verify the
status-copy contract that the UI will later rely on:

- Show included-quota, metered, blocked, review, and fallback postures only
  from the selected source.
- Never combine route/membership labels from one source with vendor, lease, or
  authorization labels from a lower-priority source.
- Keep rejected privacy/cost/region status visibly blocked or review-only
  without exposing downstream vendor/lease detail.
- Keep local/iOS-owned defaults separate from remote provider, Google/Gaode,
  crawler, MCP, StoreKit/payment, booking/order, and remote model runtime.

This keeps the next change aligned with the UI promise: users should see a
truthful provider/cost/source/freshness state before any workflow can claim a
real provider action.
