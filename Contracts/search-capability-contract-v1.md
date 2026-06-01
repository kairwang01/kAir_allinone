# Search Capability Contract v1

Status: draft, normative for A8-A54.

This contract owns the first Search vertical adapter boundary. It is a
read-only public information lookup surface for cited web and life-service
facts. It does not own booking, ordering, payment, merchant messaging, or raw
in-app crawling.

A9 adds app-owned routing for this surface. Search is now a visible
`AppSection.search` route, an App Intent entity suggestion, and a possible
resolved recommendation handoff. That routing change does not loosen this
contract's provider/runtime safety model.

## 1. Scope

Search v1 may:

- classify a user query as public web, life-service, or menu/hours lookup;
- lower that request into `SearchProviderPolicy`;
- return a `NormalizedResult.webSearch` envelope with cited hits;
- preserve provider id, source URL, freshness, cost class, confidence,
  limitations, and provider trace metadata;
- show a read-only `ExecutionSurfaceShell` surface.
- open as a kAir-owned `AppSection.search` surface when the route is
  resolved and read-only.

Search v1 must not:

- fetch network data directly from the iOS app;
- run a crawler in-app;
- bypass robots/source/privacy/cost gates;
- book, order, pay, reserve, message merchants, or write external state;
- synthesize fake URLs or public facts through AI fallback;
- imply third-party app control from an App Intent route.

## 2. Domain Intent

`SearchIntent` is the Search vertical's input contract.

Required properties:

- `query`: normalized user query.
- `category`: `.publicWeb`, `.lifeService`, or `.menuOrHours`.
- `sourceMode`: `.searchAPI`, `.crawlerFetch`, or `.cacheOnly`.
- `privacyClass`: provider privacy class.
- `membershipTier`: cost-routing tier.
- `meteredProviderEntitlements`: paid provider entitlement set.
- `enabledExperimentalProviders`: explicit crawler/MCP-style enablement set.
- `freshness`: cached/live requirement.
- `robotsState`: crawler policy state.

Rules:

- Every `SearchIntent` is read-only.
- `SearchIntent` never requires confirmation because it cannot mutate state.
- `sourceMode == .crawlerFetch` only reserves a policy path. It does not mean
  the iOS app runs a crawler.
- Private or Health context must not route to remote search/crawler providers.

## 3. Adapter

`SearchCapabilityAdapter` conforms to `CapabilityAdapter` with
`capability == .webSearch`.

Rules:

- `isAvailable()` reflects configuration only; it must not call a provider.
- `resolve(_:)` accepts only `CapabilityRequest(kind: .webSearch, inputText:)`.
- Empty query is `.invalidRequest`.
- Resolution must evaluate `SearchProviderPolicy` first.
- Success must return `NormalizedResult` with `capability == .webSearch` and
  payload variant `.webSearch`.
- Blocked/empty policy decisions throw `.unavailable` or `.invalidRequest`;
  they do not fabricate results.

## 4. Provider And Crawler Policy

Search relies on `SearchProviderPolicy` for:

- source host allow/deny checks;
- robots state checks for crawler mode;
- privacy blocking for remote providers;
- membership and metered cost blocking;
- cache fallback with stale-result limitations.

Crawler mode is disabled by default and requires both:

- `enabledExperimentalProviders` containing `.crawler`;
- `robotsState == .allowed`.

Even when both are present, A8 provides no crawler runtime. It only proves that
the policy shape can represent crawler-safe public lookup.

A11 now provides the first server/provider transport envelope. Before any
runtime crawler exists, the next adapter must also prove: source
allowlist/denylist pass, RFC 9309 robots state, user-agent identity,
rate-limit class, retention policy, trace ID, and privacy class. The iOS
app must not contain provider secrets or crawler fetch code.

## 5. UI

`SearchHomeView` must use `ExecutionSurfaceShell`.

UI rules:

- Primary card state is disabled until a real adapter backend is wired.
- Copy may say "prepared", "found", "blocked", "cached", or "unavailable".
- Copy must not say "booked", "ordered", "reserved", "paid", or "completed".
- Source URL, confidence, cost/freshness, and limitations must remain visible
  in the surface or projection metadata.
- `RootShellView` may present Search, but the surface copy remains read-only.
- App Intents may open Search, but must not imply remote execution,
  crawling, third-party app control, or life-service write completion.

## 6. Dry-Run Status Source Handoff

`SearchCapabilityAdapter.dryRunProviderStatusSource(...)` is a value-packaging
seam for precomputed Search dry-run status. It may package caller-supplied
recommendation ids with precomputed `ServerProviderDryRunReport` or
`ServerProviderDryRunPresentation` values into a
`SearchDryRunProviderStatusStore`.

Allowed producers:

- recommendation/search composition code that already has explicit rendered
  recommendation ids and precomputed Search dry-run reports or presentations;
- tests that build the same explicit inputs.

Forbidden producers:

- `AppBootstrap`;
- `ChatStore`;
- `ChatHomeView`;
- SwiftUI views;
- provider runtime adapters;
- server transport code;
- crawler/MCP adapters;
- telemetry emitters;
- prompt/model execution paths.

Consumer rules:

- App/root/view layers consume only `ProviderStatusProviding` or a precomputed
  `SearchDryRunProviderStatusStore`.
- Rendering code must not call Search dry-run helpers.
- Recommendation ids are caller-owned. They must not be inferred from query
  strings, provider traces, `MatchingObject` mutation, transcript content, or
  model output.
- The handoff does not imply Search execution, provider contact, crawler/MCP
  runtime, network access, transport readiness, or life-service write access.
- Real Search/crawler/MCP/provider runtime remains blocked until explicit
  transport, security, policy, entitlement, and product gates are added.

## 7. Tests

The A8 gate must test:

- `SearchIntent` lowers to the correct provider capability.
- Adapter availability is configuration-driven.
- Successful fixture search returns a normalized `.webSearch` result.
- Paid remote search blocks without entitlement.
- Private context blocks remote providers.
- Crawler mode requires explicit enablement and robots allow.
- Cache fallback returns a local normalized result and stale limitation.
- Wrong capability or empty query is rejected.

The A9 gate must test:

- `SurfaceRouter.resolve(identifier: "search")` returns `.search`.
- Unknown or unbuilt surface identifiers still fall back to Chat.
- App Intent entity suggestions include Search only after Search is wired.
- Resolved search projections can carry `.search` as preferred section.
- Accepting a resolved Search recommendation opens `.search`.
