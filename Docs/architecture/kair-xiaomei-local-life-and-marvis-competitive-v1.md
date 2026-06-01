# kAir — 小美 (Local-Life) + Marvis Competitive Read & Local-Life Direction v1

Status: product/strategy contract, value-only. Date: 2026-06-01.
Companion: `kair-marvis-overseas-market-directions-v1.md` (the 8 overseas lanes,
mirrored in `MarketCompanionCatalog`). This doc adds the **domestic local-life**
track (小美-style) and reconciles it with kAir's local-first + crawler model.

---

## 1. Competitive read (June 2026, sourced)

### Meituan 小美 (Xiaomei)
- Meituan's first AI Agent — an "AI 生活小秘书" for **local life** (外卖/到店/
  本地服务), in public beta, on Meituan's self-developed model (LongCat-2.0).
- **Yuanbao partnership (announced 2026-06-01, Q1 earnings call, Wang Xing):**
  users state a need in **腾讯元宝**, and 小美 fulfills the local-life leg
  (delivery etc.) — a seamless one-stop local-life transaction.
- Wang Xing's framing: beyond **To C / To B**, **"To A" (serving AI agents)** is
  the new surface — Meituan wants to be the *fulfillment layer* AI agents call.

### Marvis (Tencent, OS-level)
- OS-level assistant (Win/Mac/Android), **multi-agent** (a PM agent decomposes a
  one-sentence goal → routes to specialist agents), tasks across files / apps /
  system settings / cross-device.
- **Privacy Mode = on-device model, all local, nothing sent to cloud.**
- (Separately, the consumer "companion lanes" — 追星/游戏/情报/知识/打工/手机
  小管家/成长/生活艺术家 — are the 8 directions kAir mirrors for overseas.)

**Takeaway for kAir.** Marvis validates the kAir thesis (on-device privacy +
multi-agent + companion lanes). 小美 shows the *local-life* surface and the To-A
opportunity. kAir's wedge is to be **the privacy-first, local-first companion**
that does local-life **without owning the merchant network** — it discovers via
search/crawler + maps, then **hands off** to the user's existing app on confirm.

---

## 2. kAir local-life model (how 小美's surface maps onto kAir)

kAir is **not** Meituan and holds **no** merchant/transaction API. The local-life
capability is built from kAir's own primitives:

```
user intent ("late-night ramen near me", "pharmacy open now")
  → discover:  Apple Maps (MKLocalSearch) + public web search/crawler (read-only)
  → ground:    on-device model summarizes cited results, honest availability
  → confirm:   user picks a place / action
  → hand off:  open Apple Maps for navigation, or the merchant/booking app
               (Meituan / 大众点评 / Booking …) — kAir never books or pays itself
```

This is exactly the boundary model already encoded in `MarketCompanionCatalog`
(`.readOnlyMonitoring`, `.userConfirmedExternalHandoff`,
`.noPurchasePostOrSystemChangeWithoutConfirmation`, `.noCopyrightOrTermsBypass`).

**Maps:** Apple Maps now (MKLocalSearch + `MKMapItem.openInMaps`, no key, no
location entitlement needed for search). Google Maps / Gaode are a **membership
upgrade** in a later iteration (provider envelope already reserved). No fabricated
routes/ETAs — the current placeholder maps surface must be replaced with real
MKLocalSearch + handoff before `.maps` re-enters `FeatureFlag.v1EnabledSurfaces`.

**Crawler/search:** public-info only, cited, read-only; the server
`/v1/kair/search` + research providers carry this when `serverProvidersEnabled`.

---

## 3. In-phone integration status

- **Done (v1, in-phone):** the chat capability overview now names the companion
  lanes *and* the local-life concierge angle ("help with local life nearby —
  finding places, services, and routes, then handing off to your maps or booking
  app once you confirm; never buy/post/change a setting without asking")
  — `ChatStore.companionOverviewReply`. User-readable, honest, no fake cards.
- **Gated (activates later):** the Maps + Search surfaces carry the real
  local-life execution. They stay withheld from v1 (`enabledSurfaces`) until Maps
  is real (Apple Maps handoff) and Search has a live provider.

## 4. To-A reservation (kAir as a callable agent)

Mirror 小美↔元宝: kAir should be **invocable by other agents** for its strengths
(private health summarization, on-device companion tasks, local-life discovery).
The seam already exists — `/v1/kair/*` envelopes + App Intents
(`SurfaceRouter`). Reserve a future `/v1/agent/*` inbound contract so a partner
agent can hand kAir a scoped, consent-bound task. Not a v1 build; positioning.

## 5. Next concrete steps (for the local-life / maps work line)
1. Replace placeholder Maps with real **MKLocalSearch + Apple Maps handoff**
   (no fake ETAs); then add `.maps` back to v1 enabled surfaces.
2. Wire `/v1/kair/search` cited results into the Search surface (read-only).
3. Add 大众点评 / Meituan / Booking as **handoff targets** (open-in-app URLs),
   never as silent automation.
4. Keep every local-life action confirmation-gated and on-device-first.
