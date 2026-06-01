# kAir — iOS ↔ Server Integration & Go-Live Runbook v1

**Audience:** the server agent (and whoever flips the iOS flags).
**Date:** 2026-06-01.
**Companion docs (authoritative field-level detail):**
- `kair-backend-api-contract-v1.md` — `/v1` DTOs, Prisma schema, error model, `.env`.
- `kair-backend-server-architecture-v1.md` — NestJS 11 + Fastify 5 module layout, P0–P3.

This runbook is the **integration seam**: what the iOS client already implements,
exactly what the server must expose for the client to talk to it, the config to
set, and the precise steps to turn server features on. It does **not** restate
the field-level contract — follow the two companion docs for that.

---

## 0. TL;DR — what to do

1. Stand up the server per `kair-backend-server-architecture-v1.md` (continue P1→P3).
2. Implement the **client-consumed endpoints** in §2 below, byte-aligned with
   `kair-backend-api-contract-v1.md` §2/§4.
3. Tell me the **deployed base URL**; I set `KAIR_SERVER_BASE_URL` (§3).
4. When auth is live, flip `FeatureFlag.serverAuthEnabled = true` and inject the
   Keychain session store (§4). When the provider gateway is live, flip
   `FeatureFlag.serverProvidersEnabled = true` (§5).
5. Provision the credentials in §6 (server-side Secrets Manager only — never the client).

---

## 1. Current iOS client state (v1, shipping)

**v1 is local-first and ships WITHOUT the server.** Every shipped surface is
genuinely functional on-device; the server is additive.

| Area | State | Notes |
|---|---|---|
| On-device AI chat | **Live** | Apple Foundation Models + deterministic fallback (`KAirTextGenerator`). No prompt/health data leaves the device. |
| Health | **Live** | Apple HealthKit on-device; non-diagnostic. |
| Typed `/v1` API client | **Built, dormant** | `KAirServerAPIClient`: register/login/refresh/me/entitlements/deleteAccount/postMaps/postSearch. |
| Auth session | **Built, dormant** | `KAirAuthSessionManager`: Keychain token store, 401→refresh→retry, account deletion. |
| Login UI + account section | **Built, gated** | `AuthView` + Settings → Account; gated by `serverAuthEnabled` (off). |
| Provider routing / entitlements | **Value contracts built** | Cost/membership/privacy envelopes; runtime activates with `serverProvidersEnabled`. |
| Maps / Search / Store / AI surfaces | **Withheld from v1 nav** | Contract-first previews over stub data. Re-enabled per-surface when real (`FeatureFlag.v1EnabledSurfaces`). |

**Test gate:** 1292 tests / 0 failures. Flags default OFF; the suite exercises
the full (all-surfaces, server-on) behavior via dependency injection.

---

## 2. Endpoints the client actually calls (implement these first)

Bearer access token in `Authorization`. Optional App Attest assertion header is
sent when configured (`KAirAppAttestProvider`); a no-op provider ships by default,
so the server must treat the attestation header as **optional** until we enable it.

### 2.1 Identity (needed for `serverAuthEnabled`)
```
POST   /v1/auth/register   { email, password }   -> 201 { userId }
POST   /v1/auth/login      { email, password }   -> 200 { accessToken, refreshToken, expiresIn, tokenType }
POST   /v1/auth/refresh    { refreshToken }      -> 200 { accessToken, refreshToken, expiresIn, tokenType }   // rotates
GET    /v1/me                                     -> 200 { userId, tenant, email?, roles[], membershipTier, createdAt }
GET    /v1/me/entitlements                        -> 200 EntitlementSnapshot   // maps to ProviderAccessProfile + quota
DELETE /v1/me                                     -> 202   // App Store 5.1.1(v): erase all data (async job ok)
```

**v1 uses email/password only.** The client deliberately offers **no third-party
/ social login**, so **Sign in with Apple is _not_ required** (Guideline 4.8 only
triggers when other social logins exist). `POST /v1/auth/apple` in the contract is
**reserved** — implement it only when/if we add Apple/social login, at which point
SiwA + `revoke_tokens` on deletion become mandatory. Do **not** block v1 on it.

### 2.2 Provider gateway (needed for `serverProvidersEnabled`)
```
POST /v1/kair/maps     { envelope, query }   -> ProviderResult<MapsResult>
POST /v1/kair/search   { envelope, query }   -> ProviderResult<SearchHit[]>
```
`research` / `model` (`/v1/kair/research`, `/v1/kair/model`) are in the contract
and will be wired in a later iOS pass; not required for first provider go-live.

> **Vocabulary must match the iOS enums exactly** (`kair-backend-api-contract-v1.md`
> §2): `MembershipTier`, `ProviderFamily`, `ProviderCostClass`, `ProviderPrivacyClass`,
> `ProviderEnvelope`. A mismatch fails client decoding. Known gap to reconcile:
> the server vocabulary has `researchAPI`/`scholarlySearch` families that the iOS
> shared `ProviderFamily` does not yet enumerate — keep research quotas out of the
> entitlement snapshot until the iOS enum is extended (tracked, iOS side).

### 2.3 Response framing the client expects
- Errors: the §1.1 envelope `{ error: { code, message, traceId, details? } }` on
  every non-2xx. The client maps `401/403 → "Incorrect email or password."`,
  `409 → "An account with that email already exists."`
- A **200 response carrying a "blocked"/policy state is decoded as a normal value**
  (not an error) — see `ProviderResult`. Don't use HTTP error status for policy blocks.

---

## 3. Config the client needs from you

The base URL is **not hardcoded**. It is read from the Info.plist key
`KAIR_SERVER_BASE_URL` (`KAirServerConfiguration.default`), falling back to a
placeholder only when unset.

**To set it (one of):**
- Build setting: `INFOPLIST_KEY_KAIR_SERVER_BASE_URL = https://api.kair.app/v1`
  on the `kAir` app target (Debug + Release, or per-config via xcconfig).
- Or an `xcconfig` per environment (`Staging.xcconfig`, `Production.xcconfig`).

Give me the **deployed base URL(s)** and I wire this in. The path must include the
`/v1` prefix (the client appends `auth/login`, `me`, `kair/maps`, … to it).

---

## 4. Turning on auth (`serverAuthEnabled`)

When `/v1/auth/*` + `/v1/me*` are deployed and reachable:

1. `FeatureFlag.serverAuthEnabled = true` → reveals the **Account** section in
   Settings (sign in / create account / sign out / **Delete account**).
2. Inject a **Keychain-backed** session manager into the production composition
   (currently defaults to in-memory so tests/previews never touch the Keychain):
   in `ContentView.init`, pass
   `authSession: KAirAuthSessionManager(store: KeychainKAirSessionStore())`
   to `AppBootstrap(...)`.
3. Confirm `KAIR_SERVER_BASE_URL` (§3) is set.

That is the whole activation. Login/register/refresh/delete are already wired
through `AuthFormModel` → `KAirServerAPIClient` → `KAirAuthSessionManager`.

**Account deletion (5.1.1(v)) server contract:** `DELETE /v1/me` must erase all
account data (async job acceptable, return `202`) and revoke any third-party
tokens. With email/password-only v1 there are no Apple tokens to revoke yet.

---

## 5. Turning on remote providers (`serverProvidersEnabled`)

When `/v1/kair/maps` + `/v1/kair/search` are deployed:

1. `FeatureFlag.serverProvidersEnabled = true`.
2. Re-enable the relevant surface(s) in `FeatureFlag.v1EnabledSurfaces` **only when
   that surface is genuinely backed** (e.g. add `.search` when search is live).
   - Maps can alternatively be made real **on-device first** (MapKit / Apple Maps
     handoff) independent of the server — see iOS backlog.
3. Entitlements drive what's allowed: `GET /v1/me/entitlements` → the client's
   `ProviderAccessProfile` + quota. **Never** silently move a user free→paid; the
   client enforces cost-explicit envelopes.

---

## 6. Credentials checklist (server-side Secrets Manager ONLY)

The client holds **no secrets**. All of the following live server-side
(`.env.example` / Secrets Manager refs per contract §6/§7) and never ship in the app:

- **Auth:** JWT signing secret/keypair, refresh-token pepper.
- **Datastores:** Postgres URL, Redis URL.
- **LLM providers:** DeepSeek, OpenAI, Anthropic API keys.
- **Search:** Exa and/or Tavily API keys.
- **Maps tiers:** Google Maps and/or Gaode (高德) keys (membership-gated upgrade).
- **Research (later):** Scholar/IEEE/research-API keys.
- **App Store Server API:** issuer ID, key ID, `.p8` (for StoreKit verification +
  ASSN V2 webhook) — only when IAP is added.
- **APNs** key — only if/when push is added.

---

## 7. Invariants the server must respect (mirror of the client's)

1. **No secrets on the client** — all keys server-side.
2. **Health/private data stays on-device** in v1 — the client does not send Apple
   Health or private context to the server. Don't design endpoints that expect it.
3. **No silent free→paid** — entitlement changes are explicit and user-visible.
4. **Cost/privacy-explicit** — every provider call is a typed envelope with cost
   class + privacy class; honor them server-side.
5. **Non-diagnostic health** — if any server text ever surfaces health content, it
   must stay non-diagnostic (the on-device generator already enforces this).

---

## 8. App Store Connect metadata (user-side — not code)

Already handled in-code: app icon, privacy manifest (`PrivacyInfo.xcprivacy`),
HealthKit usage string, **export compliance** (`ITSAppUsesNonExemptEncryption = NO`
— standard HTTPS/Keychain only), portrait lock, non-diagnostic disclaimer.

Still to enter in App Store Connect before submission:
- Privacy Policy URL (required) + optional Terms URL.
- App name, subtitle, description, keywords, support URL, marketing URL.
- Screenshots (6.7" + 6.1" at minimum) of Chat + Health + Settings/Onboarding.
- Age rating questionnaire; primary category (Health & Fitness or Productivity).
- Data-collection disclosure: with v1 local-first + auth OFF, **no data collected**.
  When `serverAuthEnabled` ships, update to disclose email + account identifiers
  and expand `PrivacyInfo.xcprivacy` `NSPrivacyCollectedDataTypes` accordingly.

---

## 9. Sequencing recommendation

```
server: P1 metering → P2 entitlements → P3 gateway+fixtures   (architecture doc)
         │
         ├─ auth endpoints live  ──►  iOS: §4 (serverAuthEnabled + Keychain inject)
         └─ /v1/kair/* live      ──►  iOS: §5 (serverProvidersEnabled + re-enable surface)
```

Hand me the base URL + a note of which endpoint groups are live, and I flip the
corresponding flags and ship the next build.
