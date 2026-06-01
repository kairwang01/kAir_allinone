# kAir Backend Server — Architecture & Setup Instructions v1

Status: backend blueprint + step-by-step setup spec for the server agent.
Stack: **NestJS (TypeScript)** · **global-first** (AWS, Google Maps, GDPR;
China/PIPL reserved) · modular monolith, microservices-evolvable.
Last updated: 2026-06-01.

This server is the **server-mediated boundary** the kAir iOS provider track has
reserved all along (`kair-provider-routing-mcp-search-v1.md` §4–§7): provider
API keys live **only** here, StoreKit receipts are validated here, the metered
entitlement ledger is authoritative here, and every remote call passes a privacy
+ cost gate here. The iOS app never holds a secret and never calls a vendor
directly.

> Audience: a dedicated server agent executes this doc. It is intentionally
> concrete (directory tree, env, data model, endpoints, phased steps) so the
> agent can scaffold and deploy without further design decisions. Decision points
> the agent MAY adjust are marked **[choice]**.

---

## 0. Non-negotiables (carried from the kAir redesign)

1. **No secrets on the client.** Provider/API keys, OAuth tokens, App Store keys
   live server-side only (Secrets Manager). The iOS envelope never contains one.
2. **Server is the authority for entitlement + quota.** Membership tier and
   metered budget are decided here from a validated StoreKit receipt — never
   inferred from the client.
3. **Privacy gate before every remote call.** Health/private-classed context is
   never proxied to a remote provider/model (matches `PrivacyGuard`). PII is
   minimized; no raw health data is logged.
4. **Truthful, never-silent.** No faked completion; cost class + provider +
   freshness are returned so the app can show honest status. Free users are
   never silently upgraded to a metered provider.
5. **Cite-first + auditable.** Every provider response carries source/citation +
   a non-PII `ProviderTrace` persisted to the audit log.
6. **Read-only life-services in v1.** Search/compare/summarize/open only; no
   order/pay/booking writes (separate, confirmation-gated, later contracts).

---

## 1. Architectural Principles

- **Modular monolith, hexagonal per module.** One deployable today; each
  *business line* is a `modules/<context>` bounded context with its own
  `domain / application / infrastructure / interface` layers. Extract any module
  to its own service later without touching callers (they depend on the
  application layer's interface, not the implementation).
- **API-first, versioned.** `/v1/*` REST + OpenAPI. The iOS app is a client of
  a thin **BFF** (`apps/api`); heavy/slow work runs in `apps/worker`.
- **12-factor.** Config from env (typed + validated at boot); stateless API
  (JWT, no server sessions); attached resources (Postgres/Redis/S3) via URLs.
- **Dependency rule.** `apps/*` → `modules/*` → `libs/*`. `libs/*` hold no
  business logic. `modules/*` never import another module's `infrastructure` —
  only its `application` interface, or react to its domain events via the bus.
- **Multi-tenant / multi-business from day 1.** Every owned row carries
  `tenantId` (default `kair`); a new business line = a new module + (optionally)
  a new Postgres schema, reusing shared `identity` + `billing` + `observability`.

---

## 2. Tech Stack (recommended, pinned)

| Concern | Choice | Notes |
|---|---|---|
| Runtime | Node.js 22 LTS | |
| Framework | **NestJS 11** (monorepo: apps + libs) | DI, modules, guards, OpenAPI. (Started on 10; upgraded to 11 to clear high-severity Fastify/Nest transitive `npm audit` findings — security > version-pin on a greenfield repo.) |
| Language | TypeScript 5 (strict) | |
| HTTP | **Fastify 5** adapter | faster than Express; resolves the audit chain |
| DB | **PostgreSQL 16** | relational, ACID; primary store |
| ORM | **Prisma 5** | typed schema + migrations |
| Cache / rate-limit / locks | **Redis 7** | + idempotency keys |
| Queue | **BullMQ** (on Redis) | receipt re-verify, usage rollup, webhooks |
| Validation | `zod` (config) + `class-validator` (DTOs) | |
| AuthN | JWT (access+refresh) + **Sign in with Apple** | argon2id for passwords |
| Logging | **Pino** (JSON, redaction) | |
| Tracing/metrics | OpenTelemetry → OTLP | |
| Secrets | **AWS Secrets Manager** **[choice]** | or Doppler/Vault |
| Container | Docker (distroless) | |
| Edge | ALB **[choice: or Nginx/Caddy]** + TLS (ACM) | |
| Cloud | **AWS** **[choice]** — ECS Fargate, RDS, ElastiCache, S3, Secrets Mgr | GCP equiv. fine |
| CI/CD | GitHub Actions | lint → test → build → migrate → deploy |
| Tests | Jest (unit) + Supertest (e2e) + Testcontainers | |

Provider vendors (server-side keys): **Google Maps Platform** (maps), **Exa or
Tavily** (search) **[choice]**, **OpenAlex/Crossref/arXiv** + IEEE-API (research),
**OpenAI/Anthropic/DeepSeek** (model gateway) **[choice]**. Gaode + China hosting
are **reserved** behind the same provider interface (add later, no caller change).

---

## 3. Directory Architecture (the professional layout)

```text
kair-server/
├── apps/
│   ├── api/                      # HTTP BFF for the kAir app (REST /v1) — the only public surface
│   │   ├── src/
│   │   │   ├── main.ts           # Fastify bootstrap, helmet, CORS, versioning, OpenAPI
│   │   │   ├── app.module.ts     # imports module + libs; composition root
│   │   │   └── bootstrap/        # global ValidationPipe, ExceptionFilter, LoggingInterceptor, RequestId
│   │   └── test/                 # e2e (Supertest + Testcontainers)
│   └── worker/                   # BullMQ processors: receiptReverify, usageRollup, providerWebhook, gdprErase
│       └── src/
├── libs/                         # cross-cutting; NO business logic
│   ├── core/                     # Result<T,E>, DomainError, base Entity/ValueObject, Clock, Id
│   ├── config/                   # typed env (zod-validated) per service
│   ├── database/                 # PrismaService, BaseRepository, unit-of-work, tenant scoping
│   ├── auth/                     # JwtService, @CurrentUser, RolesGuard, AppleIdentityVerifier
│   ├── observability/            # logger, tracing, AuditLogger, metrics
│   ├── messaging/                # EventBus + transactional Outbox (cross-context events)
│   ├── http/                     # ProviderHttpClient (timeout, retry, circuit-breaker, redaction)
│   └── testing/                  # fixtures, builders, db reset
├── modules/                      # bounded contexts — one folder per business capability
│   ├── identity/                 # registration · login · Apple sign-in · users · sessions · RBAC
│   │   ├── domain/               # User, Identity, RefreshToken, Role — invariants
│   │   ├── application/          # use-cases: RegisterUser, AuthenticateWithApple, RotateRefreshToken, GetMe
│   │   ├── infrastructure/       # Prisma repos, Argon2Hasher, Apple JWKS verifier, mailer port
│   │   ├── interface/            # AuthController, UserController, DTOs, mappers
│   │   └── identity.module.ts
│   ├── billing/                  # StoreKit/Play receipt → membership → entitlements
│   │   ├── domain/               # Membership(free/plus/pro), Entitlement, EntitlementPolicy
│   │   ├── application/          # VerifyStoreKitTransaction, ResolveEntitlements, HandleAppStoreNotification
│   │   ├── infrastructure/       # AppStoreServerApiClient, EntitlementRepo
│   │   ├── interface/            # BillingController (/v1/billing/*), App Store Server Notifications webhook
│   │   └── billing.module.ts
│   ├── metering/                 # authoritative metered-entitlement ledger (mirrors iOS A117)
│   │   ├── domain/               # UsageRequest, UsageDecision, BudgetSnapshot, CostClass
│   │   ├── application/          # ReserveUsage (pre-call), CommitUsage (post-call), RollupUsage
│   │   ├── infrastructure/       # UsageLedgerRepo (append-only), Redis reservation lock
│   │   └── metering.module.ts
│   ├── providers/                # server-side adapters — provider keys live ONLY here
│   │   ├── shared/               # ProviderEnvelope, ProviderTrace, PrivacyGate, ProviderFamily, ProviderRouter
│   │   ├── maps/                 # GoogleMapsAdapter (+ reserved GaodeAdapter) behind MapsPort
│   │   ├── search/               # SearchAdapter (Exa/Tavily) behind SearchPort
│   │   ├── research/             # ResearchAdapter (OpenAlex/Crossref/arXiv/IEEE) behind ResearchPort
│   │   ├── model-gateway/        # ModelGatewayAdapter (OpenAI/Anthropic/DeepSeek), streaming + metered
│   │   └── providers.module.ts
│   ├── kair/                     # kAir-specific orchestration BFF (composes identity+billing+metering+providers)
│   │   ├── application/          # ExecuteProviderRequest (envelope → gate → meter → adapter → trace)
│   │   ├── interface/            # KairController (/v1/kair/*: profile, entitlements, maps, search, research, model)
│   │   └── kair.module.ts
│   ├── audit/                    # immutable ProviderTrace + security audit log; GDPR export/erase
│   └── notifications/            # email/push (verification, receipts) — reserved
├── prisma/
│   ├── schema.prisma             # single schema; per-context `@@schema` namespaces for isolation
│   └── migrations/
├── deploy/
│   ├── docker/                   # Dockerfile (multi-stage, distroless), .dockerignore
│   ├── compose/docker-compose.yml# local: api, worker, postgres, redis
│   ├── edge/                     # nginx/caddy config (TLS, security headers) [if not using ALB]
│   └── infra/                    # Terraform [choice]: VPC, RDS, ElastiCache, ECS Fargate, S3, Secrets, ALB, WAF
├── .github/workflows/ci.yml      # lint, typecheck, test, build, prisma migrate deploy, deploy
├── docs/                         # openapi.yaml (generated), adr/, runbooks/
├── .env.example
├── nest-cli.json                 # monorepo project map (apps + libs)
├── package.json · tsconfig.json · eslint/prettier · README.md
```

**Why this is extensible.** A new business line "X": add `modules/x/` (same 4
layers) + a Prisma `x` schema namespace; it reuses `modules/identity` (same
users), `modules/billing` (same membership), `libs/*` (auth, db, observability),
and emits/consumes domain events via `libs/messaging`. Public endpoints go under
`/v1/x/*`. No existing module changes. When X needs its own scale/SLA, extract
`modules/x` into `apps/x-service` — callers already depend on its application
interface, so only wiring changes.

---

## 4. Core Modules (responsibilities)

### 4.1 `identity` — users, registration, auth
- **Registration**: email+password (argon2id) **and** Sign in with Apple
  (verify Apple identity token against Apple JWKS; privacy-first default).
- **Tokens**: short-lived **access JWT** (~15 min) + rotating **refresh token**
  (opaque, hashed at rest, one-time-use with reuse detection → revoke family).
- **RBAC**: `user`, `support`, `admin`, plus per-tenant scopes.
- **Account lifecycle**: email/phone verification, password reset, soft-delete +
  GDPR hard-erase (fan-out to all modules via an `UserErased` event).

### 4.2 `billing` — receipts → membership → entitlements
- Validate StoreKit transactions via the **App Store Server API** (JWS), persist
  the entitlement; subscribe to **App Store Server Notifications V2** (webhook)
  for renew/cancel/refund/grace.
- Resolve a user's **membership tier** (free/plus/pro) + the **entitled provider
  families** + **included quotas**. This is the single source of truth the app's
  `ProviderAccessProfile`/`ServerProviderQuotaSnapshot` mirror.
- Never trust a client-sent entitlement.

### 4.3 `metering` — authoritative usage ledger (mirrors iOS A117)
- `ReserveUsage(traceId, providerFamily, capability, estimatedUnits, costClass,
  privacyClass)` → `accepted | rejected(reason)` with remaining/reserved units.
  Reasons mirror the iOS contract (missing snapshot, vendor disabled, membership
  missing, privacy blocked, over quota, stale snapshot, capability mismatch,
  already reserved). Append-only ledger; Redis lock for the reservation window;
  `CommitUsage` on success, auto-release on failure/timeout.

### 4.4 `providers` — the only place keys live
- One **Port** per family (`MapsPort`, `SearchPort`, `ResearchPort`,
  `ModelGatewayPort`); adapters implement them. Swap vendor or add Gaode/China
  with zero caller change.
- `PrivacyGate`: reject `health`/`private` privacy class for any remote family
  (only `appleLocal`/`cache` are exempt — and those run on the device, not here).
- Every call emits a `ProviderTrace` (non-PII) → `audit`.

### 4.5 `kair` — the BFF orchestration the app calls
- `ExecuteProviderRequest(envelope)` pipeline (one place, testable):
  `validate envelope → PrivacyGate → resolve entitlement (billing) → ReserveUsage
  (metering) → route to ProviderPort → normalize result + citation → CommitUsage
  → persist ProviderTrace → return UI-safe envelope`.
- Endpoints map 1:1 to the iOS provider-track seams (§6).

---

## 5. Data Model (Postgres, key tables)

```text
tenant(id, slug, name, created_at)                              -- 'kair' default; future business lines
app_user(id, tenant_id, status, created_at, deleted_at)
identity(id, user_id, provider['password'|'apple'], subject, email, email_verified, password_hash?, created_at)
refresh_token(id, user_id, family_id, token_hash, expires_at, used_at?, revoked_at?, ua, ip_hash)
role_assignment(user_id, role, scope)

membership(id, user_id, tier['free'|'plus'|'pro'], source['storekit'|...], status, current_period_end, updated_at)
storekit_transaction(id, user_id, original_transaction_id, product_id, environment, raw_jws_ref, status, verified_at)
entitlement(id, user_id, provider_family, capability, allowed bool, included_quota int, metered_eligible bool, updated_at)

usage_ledger(id, user_id, trace_id, provider_family, capability, cost_class, units, state['reserved'|'committed'|'released'], period_id, created_at)   -- append-only
budget_snapshot(user_id, provider_family, period_id, included_units, used_units, reserved_units, currency, source_at)

provider_trace(id, user_id?, trace_id, capability, provider_family, selected_provider_id, cost_class, privacy_class,
               membership_tier, freshness, latency_ms, result_count, failure_reason?, created_at)   -- audit; NO PII/prompt/raw payload
provider_credential(id, provider_family, secret_ref, region, enabled)   -- secret_ref = Secrets Manager ARN, NOT the key

audit_event(id, actor_user_id?, action, target, ip_hash, created_at, meta_jsonb)   -- security/compliance
```

Rules: no raw health data, prompt text, page bodies, API keys, or PII in
`provider_trace`/`audit_event`/logs. `ip` is stored hashed. Per-context tables go
in their own Postgres schema (`identity.*`, `billing.*`, …) for isolation.

---

## 6. Public API (v1) — what the kAir app calls

All under `/v1`, JSON, `Authorization: Bearer <accessJWT>` (except auth/health).
Idempotency-Key header on POSTs that spend budget.

```text
# Identity
POST /v1/auth/register            {email,password}            -> {userId}
POST /v1/auth/login               {email,password}            -> {access,refresh}
POST /v1/auth/apple               {identityToken,authCode}    -> {access,refresh}   # Sign in with Apple
POST /v1/auth/refresh             {refresh}                   -> {access,refresh}   # rotation
POST /v1/auth/logout              {refresh}                   -> 204
GET  /v1/me                       -> {user, roles}
DELETE /v1/me                     -> 202   # GDPR erase (async)

# Billing / entitlements  (the app's ProviderAccessProfile / QuotaSnapshot source)
POST /v1/billing/storekit/verify  {transactionJWS}            -> {membership, entitlements}
GET  /v1/me/entitlements          -> {membershipTier, entitlements[], quotas[]}
POST /v1/billing/apple/notifications   # App Store Server Notifications V2 webhook (Apple → server)

# kAir provider gateway  (envelope in, UI-safe envelope out; entitlement+privacy+meter enforced)
POST /v1/kair/maps                {envelope, query}           -> {result, providerTrace, costClass, freshness}
POST /v1/kair/search              {envelope, query}           -> {results[+citations], providerTrace}
POST /v1/kair/research            {envelope, query}           -> {citations[], providerTrace}   # Scholar/IEEE/arXiv
POST /v1/kair/model               {envelope, messages}        -> SSE stream | {completion}       # metered remote model

# Ops
GET  /healthz   /readyz   /metrics
```

**Envelope** (request) mirrors the iOS `ServerProviderEnvelope`:
`{ traceId, capability, providerFamily, privacyClass, membershipTier(advisory),
costClass(advisory), freshness, region, preferredProvider?, confirmationState }`.
The server **re-derives** membership/entitlement/cost authoritatively — client
fields are advisory only. Response includes the resolved `providerTrace` +
`costClass` + `freshness` + `limitations[]` so the app shows honest status, and
a `blocked{reason}` instead of a fake result when a gate fails.

---

## 7. Security & Privacy

- **Transport**: TLS 1.2+ only; HSTS; helmet security headers; strict CORS
  (allowlist the app's origins / none for native + bearer).
- **AuthN/Z**: argon2id (memory-hard); JWT signed with a rotated key (Secrets
  Mgr / JWKS); refresh-token rotation + reuse detection; RBAC guards.
- **Input**: `class-validator` DTOs on every route; reject unknown fields; body
  size limits; per-route + per-user rate limits (Redis) + global WAF.
- **Secrets**: only `secret_ref` ARNs in the DB; keys fetched at runtime from
  Secrets Manager with least-privilege IAM; never logged.
- **Privacy**: PrivacyGate blocks health/private → remote; PII minimization;
  `provider_trace` has no prompt/health/raw payload; IPs hashed; **GDPR** data
  export + erase endpoints; **PIPL** reserved (China region + data residency
  split when the China launch lands — same provider interface).
- **Idempotency** on budget-spending POSTs; **audit log** for auth + entitlement
  + provider events.
- **Supply chain**: lockfile, `npm audit`/Snyk in CI, distroless image, no root.

---

## 8. Infrastructure & Deployment

**Local (docker-compose):** `api`, `worker`, `postgres:16`, `redis:7`. One
command up; Prisma migrate on boot; seed a dev tenant + admin.

**AWS [choice] topology:**
```text
Route53 → CloudFront (optional) → ALB (TLS via ACM, WAF)
      → ECS Fargate service: api (2+ tasks, autoscale)   ┐
      → ECS Fargate service: worker (1+ task)            ├─ same VPC, private subnets
RDS PostgreSQL (Multi-AZ, encrypted, automated backups)  │
ElastiCache Redis (encrypted)                            │
S3 (receipts/raw artifacts, lifecycle)                   │
Secrets Manager (provider keys, JWT key, DB creds)       ┘
CloudWatch/OTel for logs+metrics+traces
```
**CI/CD (GitHub Actions):** PR → lint+typecheck+unit+e2e (Testcontainers) →
build image → push ECR → `prisma migrate deploy` → ECS rolling deploy → smoke
test `/readyz`. Migrations run before the new task set takes traffic; rollback =
previous task definition.

**Config**: 12-factor env; `.env.example` is the contract. Never bake secrets
into images.

---

## 9. Step-by-Step Instructions for the Server Agent

Execute in order; each phase ends green (tests + a smoke check). Do not put any
provider key in the repo or client.

**P0 — Skeleton + identity (auth)**
1. `nest new kair-server` as a **monorepo** (apps: `api`, `worker`; create
   `libs/{core,config,database,auth,observability,messaging,http,testing}`).
2. Add deps: Fastify adapter, Prisma, `@nestjs/config`+zod, argon2,
   `@nestjs/jwt`, `apple-signin-auth` (or verify JWKS manually), pino, helmet,
   class-validator, BullMQ, `@nestjs/swagger`.
3. `libs/config`: zod-validated env; fail fast on boot. Write `.env.example`.
4. `deploy/compose/docker-compose.yml`: postgres + redis; `prisma init`; define
   the §5 schema; `prisma migrate dev`.
5. Implement `modules/identity` (register, login, apple, refresh-rotation, /me)
   with unit + e2e tests. Global ValidationPipe + exception filter + request-id +
   audit logging. `/healthz` `/readyz`.
6. **Gate**: register → login → call `/v1/me` with the JWT; refresh rotates;
   reuse of an old refresh revokes the family.

**P1 — Billing + entitlements + metering**
7. `modules/billing`: App Store Server API client (JWS receipt verify) +
   notifications webhook; `entitlement` + `membership` resolution.
8. `modules/metering`: append-only `usage_ledger` + Redis reservation;
   `Reserve/Commit/Release`; budget snapshot.
9. **Gate**: a sandbox StoreKit transaction → `/v1/me/entitlements` reflects the
   tier; an over-quota `ReserveUsage` is rejected with the right reason.

**P2 — Provider gateway (kAir BFF)**
10. `modules/providers/shared`: `ProviderEnvelope`, `PrivacyGate`,
    `ProviderTrace`, ports. Implement `maps` (Google) + `search` (Exa/Tavily)
    first; `research` + `model-gateway` next. Keys from Secrets Manager.
11. `modules/kair`: the `ExecuteProviderRequest` pipeline + `/v1/kair/*`.
12. **Gate**: a `general`-class maps request as a `plus` user returns a real
    Google result + trace + cost class; a `health`-class request is blocked
    (never reaches the vendor); a free user over included quota gets
    `blocked{overQuota}`, not a fake result.

**P3 — Hardening + deploy**
13. Rate limits, WAF, structured logs + tracing, GDPR export/erase, OpenAPI doc,
    backups, alarms. Terraform the AWS topology; wire CI/CD; deploy; smoke test.
14. **Gate**: external HTTPS smoke (`/readyz`, register, entitlements, one
    provider call); secrets only in Secrets Manager; no key in image/logs.

---

## 10. kAir iOS ↔ Server Integration Contract

- The app gets a **base URL** + an **App Check / attestation** header
  (recommended: Apple App Attest) + the bearer JWT. No provider key ever ships.
- The app's existing seams map directly:
  `ProviderAccessProfile` / `ServerProviderQuotaSnapshot` ← `GET /v1/me/entitlements`;
  `ServerProviderEnvelope` → request body of `/v1/kair/*`;
  `ProviderStatusPresentation` ← the response `providerTrace` + `costClass` +
  `freshness` + `limitations`.
- On-device-first stays the default: the app only calls the server for
  **member-gated premium providers / metered remote model**; free + on-device
  paths never hit the server (zero marginal cost). Health/private never leaves
  the device, so those requests are never sent.

## 11. Reserved / later (same interface, no caller change)

- **China launch**: Gaode adapter + China region (Aliyun/Tencent Cloud) + PIPL
  data residency + CAC algorithm filing. Add behind `MapsPort` + a region router.
- **New business lines**: new `modules/<biz>` + `/v1/<biz>/*`, reusing identity +
  billing + observability (§3).
- **MCP / crawler / booking-writes**: stay disabled until their own
  discovery/consent/confirmation gates land (kAir provider doc §6–§8).
- **Microservice extraction** of any hot module when scale demands it.
