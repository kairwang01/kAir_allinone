# kAir v1.1 — Pre-ship /review Findings v1

Date: 2026-06-01. Scope: changes since `990d58b` (companion lanes, server model
gateway + "AI Runtime" card, MemoryCandidateExtractor, Odera onboarding, overview
copy) + the AuthView registration terms acknowledgment. Two independent reviewers
(correctness/concurrency + detail/honesty/a11y). Suite remains 1314/0.

## Fixed in this pass (safe, reachable, in-scope)
- **AuthView** — moved the register-mode terms acknowledgment **above** the
  submit button (consent precedes the action).
- **OnboardingView** — decorative `sparkles` glyph marked `accessibilityHidden`
  (was announced by VoiceOver before the title).
(Reverted a `region` default change — see flagged item below.)

## Flagged — MUST fix before flipping `serverProvidersEnabled` (gated off in v1)
These live in the server-model path and are **not reachable in the shipped v1**
(the flag is `false`, so no server call happens). Fix before staging/flip:

1. **Blocked / quota / membership state is silently swallowed**
   (`KAirServerModelTextGenerator.message(from:)` throws `.unavailable` on a
   200-with-blocked; `FallbackTextGenerator` catches *every* error and substitutes
   the on-device reply). A user who hits `overQuota` / `membershipMissing` /
   `blockedByPrivacy` gets a normal-looking local answer with zero signal.
   **Fix:** distinguish a typed `.blocked(reason, message)` that the fallback does
   NOT mask for policy/quota; surface it as a quota/membership card or the
   server's `blocked.message`.

2. **Prompt text routing for health/personal queries.** When the flag is on, the
   server generator is the blanket primary, so the user's *prompt text* (e.g.
   "how is my sleep") is sent to `/v1/kair/model` labeled `privacyClass: .general`.
   NOTE: the Apple Health **data** never leaves the device (only the static
   on-device baseline reply uses it; the request carries only system instructions
   + the raw prompt) — so this is prompt-text exposure, not a health-data leak.
   Still, kAir's principle is health/private context stays on-device.
   **Fix before flip:** classify each prompt (the codebase already has
   health-intent detection in `route(for:)` / `withheldSurfaceContent`); route
   health-intent prompts to the on-device generator and never construct a server
   request. Do not rely solely on the server's `.blockedByPrivacy` refusal.

## Flagged — product decisions (left as-is; need your call)
- **Overview lane names are Chinese (`追星好搭子…`) in an otherwise-English reply**
  (`ChatStore.companionOverviewReply`, ratified by `SurfaceGatingTests`). For an
  English-first build this reads as mixed-script and lists 8 not-yet-built lanes.
  Intentional per the user-marked test — left unchanged. *If the product is
  English/overseas-first, switch to the catalog's English `headline` and soften
  to "examples over time"; if bilingual/CN-first, keep as is.*
- **kAir vs Odera naming.** Onboarding introduces "Odera" (assistant), but the
  system prompt, overview, empty state, and settings all say "kAir". The split
  (app = kAir, assistant = Odera) is reasonable but only half-realized. *Decide:
  commit Odera everywhere (system prompt + overview + empty state) or revert
  onboarding to "kAir".* Left unchanged to avoid thrashing another agent's call.
- **Server generator `region` default is `.northAmerica`** while the envelope
  defaults `.global`; for a global-first product (and a China-hosted TokenHub
  model) `.global`/`.china` is more apt. A server-agent test pins `.northAmerica`
  (`KAirServerAPIClientTests:374`), so left unchanged — server agent to reconcile
  the default + its test together.
- **Register terms not tappable** (plain `Text`). Gated off in v1; make the
  Privacy Policy + Terms tappable `Link`s (the `Website/privacy.html` +
  `terms.html` pages exist) before `serverAuthEnabled` flips.

## Clean (verified, no action)
Sendable/@MainActor correctness of the new generator + ChatStore task (weak-self,
prior-task cancel); card attach/replace preserves baseline tool cards; usage/model
decode is fully optional-safe and byte-aligns with the real server shape
(`promptTokens/completionTokens/reasoningTokens/totalTokens`, `trace.latencyMs`);
`MemoryCandidateExtractor` explicit-save detection + Health isolation are sound
(verified empirically: mixed-case prefixes, prefix-only → nil, mid-string no
false-positive, injection stored verbatim with no execution path); auth form is
exemplary (focus order, blur-gated validation, password reveal, no account
enumeration, iPad width, a11y identifiers); FeatureFlag changes are comment-only
and accurate (both flags remain `false`).
