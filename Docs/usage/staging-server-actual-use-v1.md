# kAir Staging Server Actual Use v1

Status: staging/test only. The current public server is addressed by IP until a
domain and HTTPS certificate are bound.

## 1. Server Endpoint

- Staging base URL: `http://64.227.6.173:3000/v1`
- iOS configuration key: `KAIR_SERVER_BASE_URL`
- Local artifact source: `/Users/kair/Projects/kAir-server-artifacts`

For a staging iOS run, set the app build setting / generated Info.plist value:

```text
KAIR_SERVER_BASE_URL=http://64.227.6.173:3000/v1
```

The app must not talk to vendor APIs directly. iOS calls only `/v1/auth/*`,
`/v1/me`, `/v1/me/entitlements`, and `/v1/kair/*`; vendor keys remain behind
the server gateway.

## 2. Auth Flow To Verify

1. `POST /v1/auth/register`
   Body: `{ "email": "...", "password": "..." }`
   Expected: `200 { "userId": "..." }`

2. `POST /v1/auth/login`
   Body: `{ "email": "...", "password": "..." }`
   Expected token pair: `accessToken`, `refreshToken`, `expiresIn`, `tokenType`.

3. `GET /v1/me`
   Header: `Authorization: Bearer <accessToken>`
   Expected: flat `Me` response with `userId`, `tenant`, `email`, `roles`,
   `membershipTier`, `createdAt`.

4. `POST /v1/auth/refresh`
   Body: `{ "refreshToken": "..." }`
   Expected: rotated token pair. Replaying the old refresh token must return
   `401`.

The iOS implementation path is:

- `AuthFormModel` validates form state.
- `KAirServerAPIClient` calls `/v1/auth/*`.
- `KAirAuthSessionManager` stores the current token pair and refreshes on
  authenticated 401.

## 3. Model Gateway Flow

The current staging model is a replaceable test model behind the server. iOS
uses the same chat seam as the local model path:

```text
ChatStore
  -> KAirTextGenerator
  -> KAirServerModelTextGenerator
  -> KAirServerAPIClient.postModel
  -> POST /v1/kair/model
```

Request envelope:

```json
{
  "envelope": {
    "traceId": "ios-model-<uuid>",
    "capability": "chatCompletion",
    "providerFamily": "modelGateway",
    "privacyClass": "general",
    "region": "northAmerica",
    "membershipTier": "pro",
    "costClass": "includedQuota",
    "freshness": "livePreferred",
    "preferredProvider": "modelGateway",
    "confirmationState": "notRequired"
  },
  "query": {
    "text": "System:\\n...\\n\\nUser:\\n...",
    "region": "northAmerica"
  },
  "estimatedUnits": 1
}
```

Expected response:

```json
{
  "result": {
    "message": "...",
    "model": "...",
    "finishReason": "stop",
    "usage": {
      "promptTokens": 1,
      "completionTokens": 1,
      "totalTokens": 2
    }
  },
  "blocked": null,
  "trace": {
    "traceId": "ios-model-<uuid>",
    "capability": "chatCompletion",
    "selectedProviderFamily": "modelGateway",
    "costClass": "includedQuota",
    "privacyClass": "general"
  }
}
```

`ChatStore` first appends the local baseline reply, then replaces that exact
assistant message when `KAirTextGenerator.generate(_:)` returns non-empty text.
That means the same UI path works for the future split:

- Local small model: intent routing, privacy classification, tool choice,
  decision confidence.
- Remote/server large model: final user-facing reply, work plan text, and
  card-ready summaries for search/maps/provider results.

Health and private prompts must not use `/v1/kair/model`; keep them on-device.

## 4. Blocked Gateway Responses

Provider gateway blocks are successful HTTP responses, not failures:

```json
{
  "result": null,
  "blocked": {
    "reason": "blockedByPrivacy",
    "message": "..."
  },
  "trace": { "failureReason": "..." }
}
```

iOS must decode `blocked.reason` as a gateway reason string. It is not a
`ProviderCostClass`; cost class stays in `trace.costClass`.

## 5. Local Memory Flow

Memory is local-only in the current app. The safe write path is:

```text
user message
  -> MemoryCandidateExtractor.extractExplicitSave
  -> MemoryStore.write
  -> MemoryWritePolicy
```

Only explicit user-save phrasing creates a candidate, for example:

- `Remember that I prefer concise replies.`
- `请记住我喜欢先看结论`

Non-explicit prompts do not write memory. Health-like explicit saves are
classified into the Health memory domain with sensitive classification; they do
not enter chat/social memory. Model output, unconfirmed plans, and hallucinated
content are still rejected by `MemoryWritePolicy`.

## 6. Current Verification Notes

Local repeatable gates:

```sh
xcodebuild test \
  -project kAir.xcodeproj \
  -scheme kAir \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Focused tests for this staging surface:

- `KAirServerAPIClientTests`
- `ChatStoreGenerationTests`
- `MemoryCandidateExtractorTests`
- `MemoryWritePolicyTests`

Public staging smoke attempted from this machine on 2026-06-01:

- `GET http://64.227.6.173:3000/healthz`
- `GET http://64.227.6.173:3000/readyz`
- `POST http://64.227.6.173:3000/v1/auth/register`

All three connected but did not return an HTTP response within the timeout, or
the remote closed the connection without a response. Treat that as a deployment
reachability issue before relying on公网测试.
