# kAir Backend — API Contract & Data Model v1

Status: the field-level interface contract for `kair-backend-server-architecture-v1.md`.
Locks the `/v1` HTTP surface, DTOs, error model, and Prisma schema so the server
agent implements to spec and the **real interface (handed over later) is a diff,
not a redesign**. Vocabularies are **byte-aligned with the iOS provider track**
so JSON serializes 1:1.
Last updated: 2026-06-01.

---

## 1. Conventions

- **Base**: `https://api.kair.app/v1` (env-configurable). JSON in/out, UTF-8.
- **Auth**: `Authorization: Bearer <accessJWT>` on all routes except
  `/v1/auth/*`, `/v1/billing/apple/notifications`, `/healthz`, `/readyz`.
- **App attestation** (recommended): `X-App-Attest: <assertion>` (Apple App
  Attest) verified at the edge; reject unattested clients in prod.
- **Idempotency**: `Idempotency-Key: <uuid>` REQUIRED on every budget-spending
  POST (`/v1/kair/*`, `/v1/billing/storekit/verify`). Server caches the response
  for 24 h keyed by `(userId, key)`.
- **Tracing**: client sends `X-Trace-Id` (== envelope `traceId`); server echoes
  it and uses it for the `provider_trace`.
- **Versioning**: URI-versioned (`/v1`). Breaking change → `/v2`; never mutate
  `/v1` shapes.
- **Time**: RFC 3339 UTC. **IDs**: UUID v7 (sortable). **Money/units**: integers
  (no floats for budget).
- **Pagination** (list endpoints): cursor — `?limit=&cursor=` → `{items,nextCursor}`.

### 1.1 Error model (every non-2xx)
```ts
interface ApiError {
  error: {
    code: string;        // stable machine code, see §5
    message: string;     // human, non-sensitive
    traceId: string;
    details?: object;     // field errors etc.
  };
}
```
HTTP: 400 validation · 401 unauthenticated · 403 forbidden/entitlement ·
404 · 409 conflict/idempotency · 422 policy-blocked · 429 rate/quota ·
5xx server. **Never** leak prompt text, raw provider payloads, secrets, or
health data in an error.

---

## 2. Shared vocabularies (MUST equal the iOS enums)

```ts
type MembershipTier   = 'free' | 'plus' | 'pro' | 'developerInternal';
type ProviderFamily   = 'appleLocal' | 'gaode' | 'googleMaps' | 'searchAPI'
                      | 'researchAPI' | 'crawler' | 'mcp' | 'cache';
type ProviderCapability = 'mapDisplay' | 'placeSearch' | 'routePlanning'
                      | 'webSearch' | 'localServiceSearch' | 'scholarlySearch'
                      | 'citationLookup' | 'aiCompletion' | 'crawlerFetch' | 'mcpTool';
type ProviderPrivacyClass = 'general' | 'private' | 'health';
type ProviderCostClass = 'freeLocal' | 'includedQuota' | 'meteredPremium'
                      | 'blockedByCost' | 'blockedByPrivacy' | 'blockedByTerms';
type ProviderFreshness = 'cachedOK' | 'livePreferred' | 'liveRequired';
type ProviderRegion   = 'global' | 'china' | 'northAmerica' | 'europe' | 'other';
type ConfirmationState = 'notRequired' | 'required' | 'confirmed';
```
Rule: `privacyClass ∈ {private, health}` ⇒ any remote `providerFamily` is
**rejected** server-side (`blockedByPrivacy`) before the vendor is contacted.

### 2.1 ProviderEnvelope (request) — mirrors iOS `ServerProviderEnvelope`
```ts
interface ProviderEnvelope {
  traceId: string;
  capability: ProviderCapability;
  providerFamily: ProviderFamily;       // preferred family; server may downgrade
  privacyClass: ProviderPrivacyClass;   // authoritative gate input
  region: ProviderRegion;
  membershipTier?: MembershipTier;       // ADVISORY — server re-derives
  costClass?: ProviderCostClass;         // ADVISORY
  freshness: ProviderFreshness;
  preferredProvider?: ProviderFamily;
  confirmationState: ConfirmationState;
}
```

### 2.2 ProviderResult (response) — feeds iOS `ProviderStatusPresentation`
```ts
interface ProviderTrace {              // non-PII; persisted to audit
  traceId: string;
  capability: ProviderCapability;
  selectedProviderId: string | null;
  selectedProviderFamily: ProviderFamily | null;
  costClass: ProviderCostClass;
  privacyClass: ProviderPrivacyClass;
  membershipTier: MembershipTier;
  freshness: ProviderFreshness;
  latencyMs: number;
  resultCount: number;
  failureReason: string | null;
}
interface ProviderResult<T> {
  result: T | null;                    // null when blocked
  blocked?: { reason: ProviderCostClass; message: string };
  citations?: Citation[];              // required for search/research
  limitations?: string[];              // e.g. "Result is from cache and may be stale."
  trace: ProviderTrace;
}
interface Citation { title: string; url: string; sourceId: string; doi?: string; publishedAt?: string; }
```

---

## 3. Prisma schema (authoritative data model)

> `prisma/schema.prisma`. Multi-schema for context isolation. No PII / health /
> prompt / raw payload / key material in any audit or trace table; IPs hashed.

```prisma
generator client { provider = "prisma-client-js" }
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
  schemas  = ["identity", "billing", "metering", "providers", "audit", "core"]
}

// ---------- core ----------
model Tenant {
  id        String   @id @default(uuid()) @db.Uuid
  slug      String   @unique           // 'kair' default; future business lines
  name      String
  createdAt DateTime @default(now())
  users     AppUser[]
  @@schema("core")
}

// ---------- identity ----------
model AppUser {
  id        String     @id @default(uuid()) @db.Uuid
  tenantId  String     @db.Uuid
  tenant    Tenant     @relation(fields: [tenantId], references: [id])
  status    String     @default("active")           // active | suspended | deleted
  createdAt DateTime   @default(now())
  deletedAt DateTime?
  identities    Identity[]
  refreshTokens RefreshToken[]
  roles         RoleAssignment[]
  membership    Membership?
  @@index([tenantId])
  @@schema("identity")
}
model Identity {
  id            String   @id @default(uuid()) @db.Uuid
  userId        String   @db.Uuid
  user          AppUser  @relation(fields: [userId], references: [id], onDelete: Cascade)
  provider      String                                   // 'password' | 'apple'
  subject       String                                   // apple sub, or email for password
  email         String?
  emailVerified Boolean  @default(false)
  passwordHash  String?                                  // argon2id; null for apple
  createdAt     DateTime @default(now())
  @@unique([provider, subject])
  @@schema("identity")
}
model RefreshToken {
  id        String    @id @default(uuid()) @db.Uuid
  userId    String    @db.Uuid
  user      AppUser   @relation(fields: [userId], references: [id], onDelete: Cascade)
  familyId  String    @db.Uuid                           // rotation family; reuse → revoke family
  tokenHash String    @unique                            // sha-256 of opaque token
  expiresAt DateTime
  usedAt    DateTime?
  revokedAt DateTime?
  ipHash    String?
  ua        String?
  createdAt DateTime  @default(now())
  @@index([userId, familyId])
  @@schema("identity")
}
model RoleAssignment {
  userId String  @db.Uuid
  user   AppUser @relation(fields: [userId], references: [id], onDelete: Cascade)
  role   String                                          // user | support | admin
  scope  String  @default("kair")
  @@id([userId, role, scope])
  @@schema("identity")
}

// ---------- billing ----------
model Membership {
  id               String   @id @default(uuid()) @db.Uuid
  userId           String   @unique @db.Uuid
  user             AppUser  @relation(fields: [userId], references: [id], onDelete: Cascade)
  tier             String   @default("free")             // free | plus | pro
  source           String   @default("storekit")
  status           String   @default("active")           // active | grace | expired
  currentPeriodEnd DateTime?
  updatedAt        DateTime @updatedAt
  @@schema("billing")
}
model StoreKitTransaction {
  id                    String   @id @default(uuid()) @db.Uuid
  userId                String   @db.Uuid
  originalTransactionId String
  productId             String
  environment           String                            // Production | Sandbox
  rawJwsRef             String                            // S3 key, not the JWS
  status                String
  verifiedAt            DateTime @default(now())
  @@unique([originalTransactionId])
  @@index([userId])
  @@schema("billing")
}
model Entitlement {
  id             String  @id @default(uuid()) @db.Uuid
  userId         String  @db.Uuid
  providerFamily String
  capability     String
  allowed        Boolean @default(false)
  includedQuota  Int     @default(0)
  meteredEligible Boolean @default(false)
  updatedAt      DateTime @updatedAt
  @@unique([userId, providerFamily, capability])
  @@schema("billing")
}

// ---------- metering (append-only) ----------
model UsageLedger {
  id             String   @id @default(uuid()) @db.Uuid
  userId         String   @db.Uuid
  traceId        String
  providerFamily String
  capability     String
  costClass      String
  units          Int
  state          String                                   // reserved | committed | released
  periodId       String
  createdAt      DateTime @default(now())
  @@index([userId, providerFamily, periodId])
  @@index([traceId])
  @@schema("metering")
}

// ---------- providers / audit ----------
model ProviderCredential {
  id             String  @id @default(uuid()) @db.Uuid
  providerFamily String
  secretRef      String                                   // Secrets Manager ARN — NOT the key
  region         String  @default("global")
  enabled        Boolean @default(true)
  @@unique([providerFamily, region])
  @@schema("providers")
}
model ProviderTrace {
  id                     String   @id @default(uuid()) @db.Uuid
  userId                 String?  @db.Uuid
  traceId                String
  capability             String
  providerFamily         String
  selectedProviderId     String?
  costClass              String
  privacyClass           String
  membershipTier         String
  freshness              String
  latencyMs              Int
  resultCount            Int
  failureReason          String?
  createdAt              DateTime @default(now())
  @@index([userId, createdAt])
  @@index([traceId])
  @@schema("audit")
}
model AuditEvent {
  id          String   @id @default(uuid()) @db.Uuid
  actorUserId String?  @db.Uuid
  action      String                                      // auth.login, entitlement.changed, provider.call ...
  target      String?
  ipHash      String?
  meta        Json?
  createdAt   DateTime @default(now())
  @@index([actorUserId, createdAt])
  @@schema("audit")
}
```

---

## 4. `/v1` endpoints (request → response DTOs)

### 4.1 Identity
```ts
POST /v1/auth/register   { email, password }              -> 201 { userId }
POST /v1/auth/login      { email, password }              -> 200 TokenPair
POST /v1/auth/apple      { identityToken, authorizationCode, fullName? } -> 200 TokenPair   // PRIMARY
POST /v1/auth/refresh    { refreshToken }                 -> 200 TokenPair                  // rotates
POST /v1/auth/logout     { refreshToken }                 -> 204
POST /v1/auth/verify-email { token }                      -> 204
POST /v1/auth/password/reset-request { email }            -> 202
POST /v1/auth/password/reset { token, password }          -> 204
GET  /v1/me                                               -> 200 Me
DELETE /v1/me                                             -> 202   // GDPR erase (async job)

interface TokenPair { accessToken: string; refreshToken: string; expiresIn: number; tokenType: 'Bearer'; }
interface Me { userId: string; tenant: string; email?: string; roles: string[]; membershipTier: MembershipTier; createdAt: string; }
```
**Auth decisions:** Sign in with Apple is the **primary/recommended** path
(privacy-first, best global App Store conversion); email+password is the
fallback. Access JWT ≈ 15 min; refresh ≈ 60 d, rotating + reuse-detected.

### 4.2 Billing / entitlements
```ts
POST /v1/billing/storekit/verify { transactionJWS }       -> 200 EntitlementSnapshot
GET  /v1/me/entitlements                                  -> 200 EntitlementSnapshot
POST /v1/billing/apple/notifications  (Apple → server; signed)   -> 200   // ASSN V2 webhook

interface EntitlementSnapshot {            // the source for iOS ProviderAccessProfile / QuotaSnapshot
  membershipTier: MembershipTier;
  status: 'active' | 'grace' | 'expired';
  currentPeriodEnd?: string;
  entitlements: { providerFamily: ProviderFamily; capability: ProviderCapability; allowed: boolean; includedQuota: number; meteredEligible: boolean; }[];
  quotas: { providerFamily: ProviderFamily; periodId: string; includedUnits: number; usedUnits: number; remainingUnits: number; }[];
  sourceAt: string;
}
```

### 4.3 kAir provider gateway (envelope in → ProviderResult out)
```ts
POST /v1/kair/maps     { envelope: ProviderEnvelope, query: MapsQuery }      -> ProviderResult<MapsResult>
POST /v1/kair/search   { envelope, query: { text, maxResults?, region? } }   -> ProviderResult<SearchHit[]>
POST /v1/kair/research { envelope, query: { text, source?, capability } }    -> ProviderResult<Citation[]>
POST /v1/kair/model    { envelope, messages: ChatMessage[], stream?: bool }  -> SSE | ProviderResult<Completion>
```
Pipeline (server): `validate → PrivacyGate → resolve entitlement → ReserveUsage
→ ProviderPort → normalize + cite → CommitUsage → ProviderTrace → respond`.
On a gate failure return `200 { result:null, blocked:{reason}, trace }` (truthful,
not an error) so the app can render a disabled-premium / privacy-blocked state.
`/v1/kair/model` streams via SSE (`text/event-stream`) for first-token latency.

### 4.4 Ops
```ts
GET /healthz -> 200 'ok'      // liveness
GET /readyz  -> 200 { db, redis, secrets }   // readiness (deep)
GET /metrics -> Prometheus    // internal only
```

---

## 5. Stable error codes
```
auth.invalid_credentials · auth.token_expired · auth.refresh_reuse_detected ·
auth.email_taken · auth.unverified · attest.required ·
billing.receipt_invalid · billing.no_entitlement ·
quota.over_budget · quota.metered_not_entitled ·
privacy.remote_blocked · privacy.health_local_only ·
provider.unavailable · provider.upstream_error ·
request.validation · request.idempotency_conflict · rate.limited
```

---

## 6. `.env.example` (config contract)
```bash
NODE_ENV=production
PORT=8080
APP_BASE_URL=https://api.kair.app
# Postgres / Redis
DATABASE_URL=postgresql://kair:***@db:5432/kair?schema=public
REDIS_URL=redis://redis:6379
# Auth
JWT_ISSUER=https://api.kair.app
JWT_ACCESS_TTL=900            # 15m
JWT_REFRESH_TTL=5184000       # 60d
JWT_SIGNING_KEY_REF=arn:aws:secretsmanager:...:jwt-signing   # ref, not the key
APPLE_BUNDLE_ID=app.kair.ios
APPLE_TEAM_ID=XXXXXXXXXX
# StoreKit / App Store Server API
APP_STORE_ISSUER_ID=...
APP_STORE_KEY_ID=...
APP_STORE_PRIVATE_KEY_REF=arn:aws:secretsmanager:...:appstore-key
# Provider keys — ALL via Secrets Manager refs, never inline
GOOGLE_MAPS_KEY_REF=arn:aws:secretsmanager:...:google-maps
SEARCH_API_KEY_REF=arn:aws:secretsmanager:...:search           # Exa/Tavily
MODEL_GATEWAY_KEY_REF=arn:aws:secretsmanager:...:model         # OpenAI/Anthropic/DeepSeek
# Observability
OTEL_EXPORTER_OTLP_ENDPOINT=...
LOG_LEVEL=info
# Security
CORS_ALLOWED_ORIGINS=                 # empty for native+bearer
RATE_LIMIT_PER_MIN=120
APP_ATTEST_REQUIRED=true
```

---

## 7. iOS ↔ server seam mapping (so both sides agree)

| iOS type / seam | Server endpoint / DTO |
|---|---|
| `ProviderAccessProfile`, `ServerProviderQuotaSnapshot` | `GET /v1/me/entitlements` → `EntitlementSnapshot` |
| `ServerProviderEnvelope` | request body `envelope: ProviderEnvelope` |
| `ServerProviderMeteredUsageRequest/Decision` (A117) | server `ReserveUsage` over `UsageLedger` |
| `ProviderStatusPresentation` (badges/cost/freshness) | response `ProviderTrace` + `blocked` + `limitations` |
| `MapProviderDescriptor` / `SearchProvider` / `ResearchProvider` | `POST /v1/kair/{maps,search,research}` |
| `ModelTierRouter` paid-remote tier | `POST /v1/kair/model` |
| `PrivacyGuard` health-local-only | server `PrivacyGate` (`privacy.health_local_only`) |

**Reconciliation plan:** when the real implemented interface arrives, diff it
against §2–§4 here; any divergence is resolved by (a) updating this contract +
the iOS DTOs together, or (b) a server adapter — never by leaking a secret or a
silent cost/privacy change to the client.

---

## 8. Open decisions (default chosen; flag to change)
- **Sign in with Apple = primary** (email/password fallback). [default]
- **Search vendor**: Exa (semantic) for Pro, Tavily/Serper for Plus. [choice]
- **Model gateway**: DeepSeek V3.2 (cost) default, Claude/GPT for Pro. [choice]
- **SSE vs WebSocket** for model streaming: SSE (simpler, HTTP/2-friendly). [default]
