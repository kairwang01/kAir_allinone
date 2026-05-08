# Capability Registry and Adapter Contract — v1

Status: draft, normative
Authority split:
- This doc owns **the capability vocabulary** (`CapabilityKind`), **the adapter protocol** (`CapabilityAdapter`), **the normalized result envelope** (`NormalizedResult`), and **the registry surface** (`CapabilityRegistry`).
- Provider-specific implementation details (Maps adapter wiring, Music adapter wiring, on-device AI adapter wiring, etc.) belong to each adapter's own doc.
- Matching, ranking, and "which capability to use for this query" is owned by the matching kernel (see [`Docs/design/mixed-recommendation-layout-v1.md`](../Docs/design/mixed-recommendation-layout-v1.md) and downstream scoring contracts), not by this contract.
- Telemetry is owned by `telemetry-contract-v1` (planned). This contract names no telemetry events.
- Frozen object kinds rendered by the rail are owned by [`kAir/Core/Matching/Models/MatchingObjectKind.swift`](../kAir/Core/Matching/Models/MatchingObjectKind.swift) (9 cases). This contract maps `CapabilityKind` to the subset of `MatchingObjectKind`s each capability can produce; it does NOT introduce new object kinds.
- Surface families (chat / health / ai / maps / store / music / video / search) are owned by [`Contracts/UX/continuation-runtime-v1.md`](UX/continuation-runtime-v1.md) §2.1. This contract references that vocabulary by name; it does NOT redefine it.

---

## 1. Purpose, scope, non-goals

**Purpose.** Lock the capability vocabulary, the adapter protocol every concrete adapter MUST implement, the uniform `NormalizedResult` envelope every adapter MUST emit, and the registry that consumers query — so that callers (chat composer, recommendation provider, continuation runtime) bind to one shape regardless of whether the result came from a partner SDK, a local store, or AI synthesis.

**Scope.**
- The `CapabilityKind` frozen vocabulary.
- The `CapabilityAdapter` protocol — every adapter's required surface area and lifecycle.
- The `NormalizedResult` envelope every `resolve(...)` call MUST produce.
- The `isAvailable()` semantics — separate from `resolve(...)`, used for UI gating.
- The `CapabilityRegistry` — registration, lookup, snapshot.
- The partner-first principle that governs `source` honesty and forbids silent AI fallback.
- Versioning rules.

**Non-goals (v1).**
- Scoring or ranking which capability to invoke for a given user query — owned by the matching kernel.
- ML-based routing, intent classification, or query understanding — out of scope.
- Partner credentials, OAuth flows, key management, or auth handling — owned per-adapter.
- Telemetry events (`CapabilityResolved`, `CapabilityMissing`, etc.) — owned by `telemetry-contract-v1`.
- Caching strategy across resolves — adapter's choice; this contract names no caching primitive.
- Fallback chains across multiple adapters per `CapabilityKind` — explicitly v2. v1 is one adapter per kind.
- A SwiftUI implementation. v1 describes shapes and rules; concrete Swift code lands per-adapter.
- Persistence of `NormalizedResult` instances. The envelope is a wire shape between adapter and caller; how callers persist (or don't) is their concern.
- Localization of payload contents. `NormalizedResult` carries strings; their localization mechanics are out of scope, mirroring `continuation-runtime-v1.md` §1 non-goals.
- Streaming / progressive resolve — v1 envelopes are atomic. Adapters that expose progress do so out-of-band.

---

## 2. Dependencies

| Dep | Path | Authority |
|---|---|---|
| Object kinds | [`kAir/Core/Matching/Models/MatchingObjectKind.swift`](../kAir/Core/Matching/Models/MatchingObjectKind.swift) | The 9 frozen `MatchingObjectKind` cases each capability may produce. |
| Surface families | [`Contracts/UX/continuation-runtime-v1.md`](UX/continuation-runtime-v1.md) §2.1 | The 8 frozen `SurfaceKind` values (`.chat | .health | .ai | .maps | .store | .music | .video | .search`). |
| Existing recommendation provider | [`kAir/Core/Matching/RecommendationProvider.swift`](../kAir/Core/Matching/RecommendationProvider.swift) | The slate-level provider abstraction (separate from per-capability adapters). The registry feeds adapters; the rail consumes a `RecommendationProvider`. The two layers do not collapse in v1. |
| Local AI runtimes | [`Contracts/AIProviders/LocalModelProviderContract.md`](AIProviders/LocalModelProviderContract.md) | The runtime-family vocabulary used by the `aiCompletion` capability when its adapter delegates to an on-device model. |

**Authority resolution.** When this doc references a `MatchingObjectKind`, the enum file wins on cardinality. When this doc references a `SurfaceKind`, `continuation-runtime-v1.md` §2.1 wins. When this doc disagrees with a per-adapter doc on what an adapter does internally, the per-adapter doc wins; this doc's authority is bounded to the four surfaces in §1 scope.

---

## 3. `CapabilityKind` (frozen vocabulary)

v1 freezes the vocabulary at the values below. The v1 contract commits to **shipping** §3.1 only; §3.2 entries are reserved identifiers without an adapter commitment. Adding an eleventh case is a v2 change (see §10). The vocabulary is intentionally thin — one entry per partner-or-local resolution path the rail and composer can surface today.

### 3.1 Shipped in v1 scope

The capabilities the v1 contract requires at least one production adapter for. Every capability listed here MUST have a registered adapter in a shipping build before v1 is ratified (§11.1).

| `CapabilityKind` | Surface family | Primary `MatchingObjectKind` produced | Notes |
|---|---|---|---|
| `.aiCompletion` | `.ai` | `.answerCard` | Generates a textual answer / completion. Delegates to a local AI runtime per [`LocalModelProviderContract.md`](AIProviders/LocalModelProviderContract.md). The only capability where AI is the primary resolver, not a fallback. |
| `.threadLookup` | `.chat` | `.thread` | Locates a prior chat thread by topic / id. Backed by the in-app chat store; no external partner dependency. |
| `.localStoreLookup` | `.store` | `.toolEntry` | Looks up an item in the on-device app / capability store. Minimal external dependency. |

### 3.2 Reserved (vocabulary, not shipped)

These are reserved capability identifiers in the v1 vocabulary so concrete adapters can register against the same enum when they ship; v1 does NOT commit to an adapter for these. They are part of the closed enum so that a future build that adds an adapter for, e.g., `.placeSearch` does not require a vocabulary bump.

| `CapabilityKind` | Surface family | Primary `MatchingObjectKind` produced | Notes |
|---|---|---|---|
| `.placeSearch` | `.maps` | `.place` | Resolves a query string or location to one or more places. |
| `.routePlanning` | `.maps` | `.route` | Resolves an origin / destination pair to a route. |
| `.musicPlayback` | `.music` | `.song` | Resolves a song / artist / album reference to a playable track. |
| `.videoPlayback` | `.video` | `.video` | Resolves a video reference to a playable item. |
| `.healthRead` | `.health` | `.answerCard` | Reads a health metric or summary. v1 is read-only; write is a separate kind. |
| `.healthWrite` | `.health` | `.answerCard` | Logs / writes a health entry. Permission-gated; see §6. |
| `.webSearch` | `.search` | `.searchResult` | Issues a web search and returns results. |

### 3.3 Closed-set rules

- The 10 cases across §3.1 and §3.2 are the entire v1 vocabulary.
- Each `CapabilityKind` maps to **exactly one** `SurfaceKind` family. A capability does not span surfaces in v1.
- Each `CapabilityKind` declares **one primary** `MatchingObjectKind`. A capability MAY emit a `NormalizedResult` whose payload is convertible to an object of this kind; v1 forbids a capability declaring multiple primary kinds (that's a sign two capabilities are being collapsed and should be split before v2).
- The mapping from `CapabilityKind` to `MatchingObjectKind` is informative for callers wiring the rail. It does NOT bind the rail to refresh whenever an adapter resolves; refresh timing is owned by [`Contracts/UX/post-return-and-continuation-ux-v1.md`](UX/post-return-and-continuation-ux-v1.md) §3.4.
- The §3.1-vs-§3.2 split is a v1 *shipping* commitment, not a vocabulary distinction. A §3.2 entry that ships an adapter in a future minor version moves to §3.1 in that doc revision; the enum case itself does not change.

### 3.4 What is deliberately absent

- No `.friendsLookup` — Friends is out of contract scope (see §9).
- No `.calendar`, `.reminders`, `.mail`, `.contactsLookup` (beyond what `.threadLookup` covers for chat). Adding any of these is a v2 vocabulary bump.
- No `.translation`, `.summarization`, `.transcription` as standalone kinds — these are sub-cases of `.aiCompletion` in v1.
- No `.imageGeneration`, `.audioGeneration` — v1 is text / structured-result only.

---

## 4. `CapabilityAdapter` protocol

Every concrete adapter MUST conform to a single protocol with a fixed surface area. Adapters are reference types and MUST be safe to retain on `MainActor`-isolated callers (chat composer, registry).

### 4.1 Required surface

| Member | Kind | Notes |
|---|---|---|
| `static var capability: CapabilityKind` | static read-only | Identifies which `CapabilityKind` this adapter implements. v1 is one adapter per kind, so this value is also the adapter's registry key. |
| `func isAvailable() async -> Bool` | async instance | Cheap availability probe. MUST NOT block on a partner round-trip in the typical case; SHOULD return cached state. See §6. |
| `func resolve(_ request: CapabilityRequest) async throws -> NormalizedResult` | async throws instance | The single resolution entry point. MUST return a `NormalizedResult` whose `capability` field matches `Self.capability`. See §5. |

### 4.2 Lifecycle

1. **Construction.** Adapter is constructed at app boot, before the first registry lookup. Construction is synchronous; any I/O (permission prompts, partner SDK init) is deferred to first `isAvailable()` / `resolve(...)` call.
2. **Registration.** Adapter registers itself with `CapabilityRegistry` after construction. See §7.1.
3. **Availability probing.** UI gating MAY call `isAvailable()` zero or more times per session. The adapter SHOULD cache the result and invalidate on permission change, network change, or partner-SDK reinit.
4. **Resolution.** Callers invoke `resolve(...)` on demand. Each call is independent; v1 makes no concurrency or rate-limit guarantee on the adapter side.
5. **Teardown.** Adapter lifetime equals app lifetime in v1. There is no `unregister(...)` API; restart is the only path to swap an adapter.

### 4.3 Threading

- Adapters MUST be safe to call from `MainActor`. An adapter MAY hop off the main actor internally; the contract-level surface is `async` so callers do not need to know.
- Adapters MUST NOT require the caller to be on a specific non-main actor. The protocol is callable from any actor context.
- `isAvailable()` and `resolve(...)` MUST NOT block synchronously. Both are `async`.

### 4.4 Failure model

- `isAvailable()` returns `Bool` and MUST NOT throw. Errors during the probe (permission lookup failure, etc.) are folded into `false`.
- `resolve(...)` MAY throw. Errors are typed as `CapabilityError` (see §4.5).
- A successful `resolve(...)` returns a `NormalizedResult`. Returning a `NormalizedResult` whose payload is empty is permitted (e.g., a `webSearch` that returned zero hits) — emptiness is information, not an error.
- Callers MUST treat thrown errors as terminal for that resolve attempt; v1 specifies no automatic retry.

### 4.5 `CapabilityError` (frozen cases)

| Case | Meaning | Recovery |
|---|---|---|
| `.unavailable` | The adapter is not currently available (permission, offline, partner-SDK miss). Caller SHOULD have checked `isAvailable()` first; this case exists for the race window between probe and resolve. | Re-probe; surface a permission affordance to the user. |
| `.invalidRequest` | The `CapabilityRequest` was malformed or violated this kind's input shape. | Programming error; do not retry. |
| `.partnerFailure` | The partner / underlying SDK returned an error. | Caller MAY surface a soft "couldn't reach Maps" affordance; do not silently substitute AI synthesis (see §8). |
| `.timeout` | Resolve exceeded the adapter's internal deadline. | Caller MAY retry once; further retries are caller policy. |
| `.cancelled` | The structured-concurrency task was cancelled. | Standard Swift cancellation semantics; do not surface. |

The `CapabilityError` enum is closed at v1. Adding a case is a v2 change.

---

## 5. `NormalizedResult` envelope

Every `resolve(...)` returns a `NormalizedResult` with the same shape regardless of `CapabilityKind`. Callers do NOT branch on capability to read fields off the envelope.

### 5.1 Fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `String` | Yes | Stable identifier for this result. Format: `"<capability>-<sequence-or-hash>"`. Unique within a session. Caller MAY use it for deduplication. |
| `capability` | `CapabilityKind` | Yes | MUST equal `Self.capability` of the adapter that produced it. |
| `payload` | `CapabilityPayload` | Yes | Typed per capability. See §5.2. |
| `source` | `ResultSource` | Yes | Honest provenance. See §5.3 and §8. |
| `confidence` | `Double` | Yes | Range `[0.0, 1.0]`. Adapter's self-assessment. v1 does NOT define a calibration; values are comparable only within the same `(capability, source)` pair. |
| `createdAt` | `Date` (UTC, second precision) | Yes | When the adapter produced the result. |

### 5.2 `CapabilityPayload`

The payload is a typed sum: one variant per `CapabilityKind`. The variant that an envelope carries MUST match the envelope's `capability` field.

> **Normative scope of §5.2.** This contract is normative ONLY for: (a) the one-to-one mapping from `CapabilityKind` to `CapabilityPayload` variant, and (b) the requirement that the variant on the envelope matches the envelope's `capability` field. The per-capability field lists below are **illustrative**, not normative — concrete field schemas are owned by each per-adapter doc. Adapters MAY add fields; consumers that don't recognize them MUST ignore them.

The table below is illustrative — it sketches the *kind* of payload each variant carries so readers can orient themselves. Field names, optionality, and exact types are **not** locked here; the per-adapter doc is the source of truth.

| `capability` | Payload variant carries | Illustrative shape (NOT normative) |
|---|---|---|
| `.placeSearch` | A list of place candidates | id, name, coordinate, address, optional partner-attribution |
| `.routePlanning` | A route summary | origin, destination, distance, duration, optional polyline reference |
| `.musicPlayback` | A track reference | id, title, artist, optional album, partner-attribution |
| `.videoPlayback` | A video reference | id, title, optional thumbnail-id, partner-attribution |
| `.healthRead` | A health-metric snapshot | metric token, value, unit, sampled-at |
| `.healthWrite` | A write receipt | confirmed metric token, written-at |
| `.aiCompletion` | A completion | text, optional structured-output handle, runtime-family identifier |
| `.localStoreLookup` | An item summary | id, title, optional category |
| `.webSearch` | A list of search hits | title, url, snippet (no inline thumbnails per [`Contracts/UX/mixed-recommendation-rail-visual-v1.md`](UX/mixed-recommendation-rail-visual-v1.md) §8) |
| `.threadLookup` | A thread reference | thread id, last-touched-at, optional title |

The payload shapes above are illustrative — the per-adapter doc owns the exact field list. v1 only contracts the variant-to-capability one-to-one mapping.

### 5.3 `ResultSource` (frozen vocabulary)

```
.partner | .local | .aiSynthesized
```

| Case | Meaning |
|---|---|
| `.partner` | The result came from a partner SDK / native API (MapKit, MusicKit, AVKit, HealthKit, on-device search index, etc.). The partner may be a system framework (HealthKit, MapKit) or a third party; the distinction does not matter at this contract layer. |
| `.local` | The result came from the on-device app / store / cache without invoking a partner round-trip. Includes filesystem lookups, in-memory caches, and the local store. |
| `.aiSynthesized` | The result was produced by an AI runtime (per `aiCompletion` adapter or an explicit AI fallback inside another capability). |

### 5.4 Envelope invariants

- `payload`'s variant matches `capability`.
- `confidence ∈ [0.0, 1.0]`.
- `id` is unique within a session; consumers MAY rely on it.
- `createdAt` is non-future relative to the device clock at construction time.
- `source` is honest. An adapter that internally synthesized a result MUST set `source = .aiSynthesized`, even if the surface family is `.maps` or `.music` (see §8).

Violations are programming errors and MUST be rejected at the adapter level before returning the envelope.

### 5.5 Optionality and minor-version growth

- All fields above are required in v1.
- A v1.x adapter MAY embed adapter-specific fields inside its payload variant. Such fields are NOT contract; consumers that don't recognize them MUST ignore them.
- Adding a new optional field at the envelope level (e.g., `expiresAt: Date?`) is a minor version bump (§10). Adding a new required field is v2.

---

## 6. Availability semantics — `isAvailable()`

`isAvailable()` exists separately from `resolve(...)` because the registry's snapshot (§7.3) drives UI gating, and `resolve(...)` is too expensive to call just to discover whether a capability is reachable.

### 6.1 What `isAvailable()` MUST consider

Adapters MUST return `false` whenever any of the following hold:

1. **Permission denied or undetermined.** Adapters that depend on a system permission (HealthKit, location, Music, etc.) MUST return `false` until permission is granted. They MUST NOT silently prompt during `isAvailable()`; the prompt belongs in a user-initiated path.
2. **Offline when the adapter requires network.** Adapters that REQUIRE a network round-trip (e.g., `.webSearch`, partner-backed `.placeSearch` when the partner has no offline mode) MUST return `false` when offline. Adapters that have a meaningful offline mode (e.g., `.routePlanning` with cached map tiles) MAY return `true` offline.
3. **Partner SDK initialization failed or is missing.** `false`.
4. **The adapter is in a known-broken state** (e.g., partner returned a hard auth failure on last `resolve(...)`). Adapters MAY remember this and fail-fast availability until next launch / next manual reset.

### 6.2 What `isAvailable()` MUST NOT do

- MUST NOT trigger a permission prompt.
- MUST NOT block on a partner round-trip in the typical case. Cached state is the expected implementation.
- MUST NOT alter adapter state visible to other callers (no logging, no telemetry-side-effect guarantees made by this contract).
- MUST NOT throw — the return type is `Bool`, and any internal failure is folded into `false`.

### 6.3 UI contract

When `isAvailable()` returns `false`:

- The composer / rail MUST hide or grey out affordances that depend on this capability (e.g., a "Find a place" entry point bound to `.placeSearch`).
- The recommendation provider MUST NOT include `MatchingObject`s whose primary capability is unavailable. Exception: an `aiSynthesized` substitute MAY surface only when permitted by §8.
- The continuation runtime MUST NOT route a terminal-outcome handler through an unavailable adapter.

### 6.4 Cache invalidation

Adapters SHOULD invalidate cached availability when:
- The system reports a permission change.
- The system reports a network reachability change.
- The partner SDK signals a (re)initialization event.
- The app moves from background to foreground, if the adapter's reachability is suspect across that transition.

The frequency of re-probing is adapter policy. v1 makes no guarantee about cache-staleness windows.

---

## 7. `CapabilityRegistry`

A single registry per app process. The registry is the binding point between adapters and callers.

### 7.1 Registration

| Aspect | Rule |
|---|---|
| Registration timing | Adapters register once, at app boot, before the first registry lookup. |
| Registration API | `register(_ adapter: CapabilityAdapter)`. The registry derives the registry key from `type(of: adapter).capability`. |
| One adapter per kind | v1 forbids more than one adapter per `CapabilityKind`. A second `register(...)` for the same kind is a programming error and MUST be rejected (assertion / fatal in debug; last-write-wins is NOT permitted). |
| Re-registration | Forbidden in v1. The registry is write-once-per-key. |
| Unregistration | No public API. Adapter lifetime equals app lifetime. |

### 7.2 Lookup

| API | Returns | Notes |
|---|---|---|
| `adapter(for kind: CapabilityKind) -> CapabilityAdapter?` | The registered adapter or `nil`. | `nil` means no adapter has been registered for this kind in this build. Distinct from "registered but unavailable" — that is `adapter(for:) != nil && adapter.isAvailable() == false`. |

Callers MUST treat `nil` and `isAvailable() == false` as **distinct signals**:
- `nil`: this build does not ship the capability at all (e.g., `.musicPlayback` on a build that excludes the music adapter). UI MUST hide affordances permanently.
- `isAvailable() == false`: this build ships the capability but cannot use it right now. UI MAY surface a permission / connectivity affordance.

### 7.3 Snapshot

The registry exposes a snapshot for UI gating. The snapshot is point-in-time; consumers requery as needed.

| API | Returns | Notes |
|---|---|---|
| `availabilitySnapshot() async -> [CapabilityKind: Bool]` | A dictionary mapping every registered `CapabilityKind` to its current `isAvailable()` value. | Computed by calling each registered adapter's `isAvailable()`. Adapters with no registration are omitted (NOT present as `false`); callers that need the "not in build" signal use `adapter(for:) == nil`. |

The snapshot is async because each `isAvailable()` is async. The registry MAY parallelize the per-adapter probes; v1 does NOT contract a probe ordering or concurrency limit.

### 7.4 No fallback chain in v1

The registry holds **at most one adapter per `CapabilityKind`**. There is no priority list, no fallback chain, and no "try `.partner` first then `.aiSynthesized`" routing inside the registry. If a capability needs to fall back to AI synthesis, that fallback lives **inside the adapter** (per §8.3), not as a sibling registration.

Multi-adapter chains are explicitly v2.

### 7.5 Threading

- The registry is `MainActor`-isolated for v1. All registration, lookup, and snapshot calls happen on the main actor.
- This is an explicit simplification. v2 may relax it.

---

## 8. Partner-first principle

The single most load-bearing rule in this contract: **capabilities prefer partner / native APIs over AI synthesis, and the `source` field NEVER lies about which one produced the result.**

### 8.1 Resolution order inside an adapter

The steps below apply to capabilities **WITH** a partner / native backend distinct from AI (i.e., everything except `.aiCompletion`):

1. Adapter attempts the partner / native path first.
2. If the partner returns a result, the adapter returns it with `source = .partner` (or `.local` if served from local cache without a round-trip).
3. If the partner is unavailable, returns no result, or fails, the adapter MAY fall back to AI synthesis **only when permitted by §8.3 below**, and MUST set `source = .aiSynthesized`.

For `.aiCompletion`, the AI runtime IS the native path; steps 1–3 collapse into a single step that invokes the AI runtime and returns `source = .aiSynthesized` as honest provenance. There is no "partner first then AI" sequence to walk because there is no non-AI partner for this capability.

### 8.2 Honest provenance

An adapter MUST set `source` based on what actually produced the result:

- `.partner` — a partner / native SDK round-trip produced the result.
- `.local` — an on-device cache, store, or filesystem produced the result without a partner round-trip.
- `.aiSynthesized` — an AI runtime produced or substantially rewrote the result.

The `source` field is the audit trail. Downstream consumers (transcript, scorer, future `telemetry-contract-v1`) read it to reason about result quality and to surface trust pills correctly. **An adapter that returns a partner-shaped envelope but actually fabricated the content via AI is a contract violation**, even if the user-visible chrome is identical.

### 8.3 When AI fallback is permitted (and when it is forbidden)

| Capability | Has partner / native backend? | AI fallback permitted? | Notes |
|---|---|---|---|
| `.placeSearch` | Yes (MapKit / partner) | **Forbidden in v1.** | Returning AI-fabricated places risks hallucinated coordinates. Adapter MUST return an empty result or throw `.partnerFailure`. |
| `.routePlanning` | Yes (MapKit / partner) | **Forbidden in v1.** | Same reason — a synthesized route is unsafe. |
| `.musicPlayback` | Yes (MusicKit / partner) | **Forbidden in v1.** | Cannot fabricate playable track URIs. |
| `.videoPlayback` | Yes (AVKit / partner) | **Forbidden in v1.** | Same. |
| `.healthRead` | Yes (HealthKit) | **Forbidden in v1.** | Health values are never synthesized. |
| `.healthWrite` | Yes (HealthKit) | **Forbidden absolutely.** | Writes never go through AI. Programming error if attempted. |
| `.aiCompletion` | Yes — AI runtime is the native resolver | Not applicable — AI is the primary resolver, not a fallback. | `.aiCompletion` is not a fallback case; AI is the primary resolver for this capability. Resolved envelopes carry `source = .aiSynthesized` as the honest provenance of the AI runtime, not as a substitute for an unavailable partner. |
| `.localStoreLookup` | Yes (on-device store) | **Forbidden in v1.** | The store either has the entry or it doesn't. |
| `.webSearch` | Yes (search partner) | **Forbidden in v1.** | An AI-fabricated URL is unsafe to surface. |
| `.threadLookup` | Yes (local store) | **Forbidden in v1.** | A thread either exists or it doesn't. |

**Summary rule.** In v1, the only capability whose `NormalizedResult` carries `source = .aiSynthesized` is `.aiCompletion` — and there it is the *primary* provenance, not a substitution. Every other capability is partner-only or local-only; AI substitution is forbidden when the partner is unavailable. Adapters return empty results, throw `.unavailable`, or throw `.partnerFailure` instead.

### 8.4 Why no silent AI fallback

Two reasons:

1. **Trust.** A user who taps a `.place` card expects a real place. A user who reads a route ETA expects a real route. Silent AI substitution turns the rail into a hallucination surface for capabilities where hallucination is unsafe.
2. **Auditability.** Downstream contracts (`telemetry-contract-v1`, the scorer, the trust-pill vocabulary in [`action-card-component-inventory.md`](../Docs/design/action-card-component-inventory.md)) rely on `source` being honest. A silent fallback that lies about `source` poisons every downstream contract that consumes it.

The principle is **partner-first, honest-source**. AI is the primary resolver for `.aiCompletion` only; for every other capability in the v1 vocabulary, AI is not a universal substitute when the partner is unavailable.

### 8.5 Per-adapter docs MUST restate the rule

Every per-adapter doc MUST restate the §8.3 row for its capability and explicitly name which `source` values its adapter can produce. A per-adapter doc that does NOT name the `source` constraint is non-compliant with this contract.

---

## 9. Out-of-contract — what this doc does NOT do

- Does NOT specify which `CapabilityKind` the matching kernel chooses for a given user query. Routing belongs to the matching kernel.
- Does NOT specify a scoring / ranking algorithm across capabilities. The slate's order is the matching kernel's concern; the registry returns adapters, not scores.
- Does NOT define a partner-credentials format, OAuth flow, key rotation, or secrets-management strategy. Per-adapter.
- Does NOT define telemetry events for `register`, `resolve`, `isAvailable`. Owned by `telemetry-contract-v1`.
- Does NOT define caching primitives. Adapters may cache freely; v1 names no cache shape.
- Does NOT define a fallback chain across adapters. v1 is one adapter per kind.
- Does NOT define streaming / progressive resolve. v1 envelopes are atomic.
- Does NOT define a cancellation propagation guarantee beyond standard Swift structured concurrency. `resolve(...)` is `async throws`; cooperative cancellation applies.
- Does NOT cover Friends features. Friends is not a capability and never resolves through this registry (per [`Contracts/FriendsAPI/FriendsServiceContract.md`](FriendsAPI/FriendsServiceContract.md)).
- Does NOT define a UI for "browse all capabilities". The registry's snapshot is for gating, not for surfacing a directory.
- Does NOT define how `MatchingObject` instances are constructed from `NormalizedResult`. That bridge is owned by the matching kernel; v1 only declares the per-capability primary kind (§3).

---

## 10. Versioning

| Change | Version impact |
|---|---|
| Adding a new optional field to `NormalizedResult` (e.g., `expiresAt: Date?`) | Minor (v1.x). Adapters that don't set it leave it `nil`; consumers ignore unknown values. |
| Adding a new variant to `CapabilityPayload` for an existing capability (e.g., a new sub-shape for `.aiCompletion`) | Minor, provided the variant is additive and existing consumers can ignore it. Otherwise v2. |
| Tightening the `confidence` calibration to a documented scale | Minor. |
| Adding a new `CapabilityKind` case | **v2.** Vocabulary is closed at v1. |
| Removing a `CapabilityKind` case | **v2.** |
| Changing the `MatchingObjectKind` mapping for a `CapabilityKind` | **v2.** Coordinated bump with `MatchingObjectKind` if the kind itself changes. |
| Adding a new method to `CapabilityAdapter` | **v2.** Existing adapters would not conform. |
| Renaming `isAvailable()` / `resolve(...)` / `capability` | **v2.** |
| Adding a new `CapabilityError` case | **v2.** Callers that exhaustively switch would no longer be exhaustive. |
| Adding a new `ResultSource` case | **v2.** |
| Permitting more than one adapter per `CapabilityKind` (fallback chain) | **v2.** |
| Relaxing the §8 partner-first rule for any non-`.aiCompletion` capability | **v2 AND a coordinated bump of the trust-pill vocabulary in `action-card-component-inventory.md`.** |
| Allowing `MainActor` to be relaxed on the registry | **v2.** |

---

## 11. Change process & ratification

This document is contract; per-adapter implementations and the matching kernel lag.

1. **Adding a new optional `NormalizedResult` field.** Allowed; mark optional in §5.1. Update §5.4 only if a new invariant applies.
2. **Promoting a v2-only change into v1.** Forbidden. v1 is closed at the surfaces above.
3. **Adding a new `CapabilityKind` case.** Goes to v2. Open a v2 contract; v1 stays stable. Per-adapter doc in lockstep.
4. **Loosening §8 for a capability.** Forbidden in v1. v2 may permit it; until then, AI substitution stays forbidden for partner-backed capabilities.
5. **Re-tuning a value within an existing rule** (e.g., the `confidence` range narrowed from `[0,1]` to `[0,1]` with a documented sub-band semantic). Minor; update §5.1 in the same PR as the first consumer.
6. **Per-adapter docs.** Each adapter doc MUST cite §8.3 and restate the row for its capability before merging.

### 11.1 Ratification checklist

v1 is ratified when ALL of the following are true:

- [ ] Every `CapabilityKind` in §3.1 (shipped scope) has a registered adapter in production. §3.2 (reserved) entries do NOT need an adapter to ratify v1 — they are vocabulary placeholders, not shipping commitments.
- [ ] Every shipped adapter conforms to §4 — `static var capability`, `isAvailable()`, `resolve(...)` all present and correctly typed.
- [ ] Every shipped adapter's `resolve(...)` produces a `NormalizedResult` whose `source` field passes a partner-first audit (§8) — i.e., a partner-backed capability never returns `.aiSynthesized` from an AI-substitution path.
- [ ] `CapabilityRegistry` is implemented with at most one adapter per kind (§7.1). A second registration is rejected (assertion in debug).
- [ ] `availabilitySnapshot()` is wired into the rail / composer for UI gating, and at least one consumer hides an affordance based on it.
- [ ] At least one consumer distinguishes `adapter(for:) == nil` ("not in build") from `isAvailable() == false` ("not available right now") in its UI treatment (§7.2).
- [ ] No production code path performs silent AI fallback for a `.placeSearch`, `.routePlanning`, `.musicPlayback`, `.videoPlayback`, `.healthRead`, `.healthWrite`, `.localStoreLookup`, `.webSearch`, or `.threadLookup` capability (§8.3 audit).
- [ ] Per-adapter docs exist for every shipped `CapabilityKind`, each restating the §8.3 row for its capability.
- [ ] No consumer reads `payload` without first reading `capability` to learn the variant (§5.4 invariant enforced at the call site).
