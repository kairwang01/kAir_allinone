# Design-System v1 — Token Migration Audit

Status: audit report (informational, not a contract).
Audited contract: [`Contracts/Design/design-system-v1.md`](../../Contracts/Design/design-system-v1.md)
Audited at: repo `be6c908` (post-#36, main, 307/0 green).
Method: static `grep` / `Read` sweep of `kAir/` (85 Swift files). No
code was changed by this audit — see §8.

This document answers one question: **what is between the current
codebase and a ratifiable `design-system-v1.md`?** It walks the §8.1
ratification checklist box by box, then enumerates the §3 consumer
state and the §6 alias call sites with exact locations, then makes
the one decision the checklist explicitly requires (the
`tint(for:)` / `statusTint(for:)` signature ruling). It ends with a
sequenced list of follow-up implementation PRs — none of which are
performed here.

---

## 1. §8.1 ratification checklist — box-by-box

| §8.1 box | Status | One-line finding |
|---|---|---|
| 1. All §3 frozen rows have a production consumer | **PARTIAL FAIL** | §3.1 color, §3.3 spacing, §3.4 radius all pass. §3.2 typography, §3.5 elevation, §3.6 motion have **no named token symbols at all** — the contract describes them as frozen public API but the `AppTheme.Typography` / `.Elevation` / `.Motion` enums were never created. |
| 2. Off-grid shadows → 0 call sites OR each has a §3.5 exception line | **FAIL** | 7 off-grid shadow call sites remain; 4 are the §6-enumerated ones, **3 are un-enumerated** (the contract did not know about them). |
| 3. Eyebrow tracking `1.0` → 0 call sites | **FAIL** | 2 `.tracking(1.0)` sites remain; additionally 5 `.tracking(1.1)` + 1 `.tracking(0.8)` off-spec sites the §6 note did not mention. |
| 4. `HealthPalette.{mint,cyan,amber,coral,canvas,ink,mutedInk,cardStroke}` → 0 call sites | **FAIL** | 7 of the 8 members still consumed (`canvas` is clean); ~82 call sites across `ContentView.swift` + `DashboardSections.swift`. |
| 5. No NEW code references `Palette.surfaceElevated` directly | **PASS** | Only the 2 grandfathered consumers (`MessageBubble`, `ComposerBar`) reference it; no new references crept in. |
| 6. `tint(for:)` / `statusTint(for:)` — typed signature OR formally v1-permanent | **DECISION REQUIRED** | See §6 below. Recommendation: **accept as v1-permanent** (no code change; §6 of the contract already pre-records the v2 typed-enum rename). |
| 7. §4.4 component-state mapping — ≥1 component implements each of the 7 states end-to-end | **FAIL** | `ActionCardShell` (`ActionCardState`) covers 4 of 7 (`default`, `accepted`, `dismissed`, `loading`). No component covers `empty`, `error`, `disabled` end-to-end. |

**Headline.** The single largest blocker is box 1, and it is **not a
migration problem** — it is a missing-implementation problem. The
typography / elevation / motion token enums do not exist; every
component hardcodes those values inline or via local per-component
constants. Boxes 2–4 and 7 are genuine migration / coverage work.
Box 5 already passes. Box 6 needs a one-line decision, recommended
below.

---

## 2. §3 frozen-row consumer audit

### 2.1 §3.1 Color — PASS (16 / 16 rows have consumers)

All counts are production files referencing `AppTheme.Palette.<token>`,
excluding the definition file `AppTheme.swift`.

| Token | Consumer files | Token | Consumer files |
|---|---|---|---|
| `accent` | 6 | `textPrimary` | 19 |
| `accentStrong` | 6 | `textSecondary` | 15 |
| `backgroundStart` | 1 | `textMuted` | 15 |
| `backgroundEnd` | 6 | `textOnStrong` | 9 |
| `backgroundInset` | 4 | `success` | 13 |
| `surface` | 8 | `warning` | 10 |
| `surfaceStrong` | 6 | `danger` | 4 |
| `line` | 8 | `sky` | 5 |

No §3.1 row is orphaned. `backgroundStart` is thin (1 file) but
present.

### 2.2 §3.3 Spacing — PASS (2 / 2)

| Token | Consumer files |
|---|---|
| `Metrics.screenPadding` | 9 |
| `Metrics.sectionSpacing` | 9 |

### 2.3 §3.4 Radius — PASS (2 / 2)

| Token | Consumer files |
|---|---|
| `Metrics.cardRadius` | 4 |
| `Metrics.compactRadius` | 9 |

### 2.4 §3.2 Typography — FAIL (0 / 9 rows exist as symbols)

The contract §3.2 freezes 9 token names (`display`, `sectionTitle`,
`heading`, `actionLabel`, `body`, `meta`, `chip`, `eyebrow`,
`micro`) and states "The token name (left column) is contract."

**There is no `AppTheme.Typography` enum.** Typography is applied
through ~194 inline `.font(.largeTitle)` / `.font(.title3)` / …
call sites scattered across the feature views. The frozen token
names are *conceptual* — a reviewer cannot `grep` for `display` or
`eyebrow` and find a symbol.

This is a contract/implementation mismatch, not a migration:
- **Option A** — create `AppTheme.Typography` with the 9 cases,
  migrate the 194 call sites. Large.
- **Option B** — amend §3.2 to explicitly state the token names are
  a *naming convention over SwiftUI's native ramp*, not Swift
  symbols, and that box 1 is satisfied for §3.2 by the SwiftUI
  sources being in use. Doc-only.

This audit does not pick the option (that is a contract decision);
it records that box 1 cannot be checked for §3.2 until one is taken.

### 2.5 §3.5 Elevation — FAIL (0 / 3 rows exist as symbols)

The contract §3.5 freezes 3 tiers (`elevation.flat`,
`elevation.raised`, `elevation.floating`) with normative
shadow-α / blur / y-offset values.

**There is no `AppTheme.Elevation` enum.** Shadow values are
hardcoded. Where components happen to be on-grid, they restate the
values via *local per-component constants* rather than a shared
token:

| Site | Values | On-grid? |
|---|---|---|
| `KAirSurface.elevated` (`KAirSurface.swift:55`) | α 0.06 / r 12 / y 6 | ✓ matches `elevation.raised` |
| `ActionCardShell` (`ActionCardShell.swift:41-43`) | α 0.06 / r 12 / y 6 | ✓ matches `elevation.raised` |
| `SystemSummaryBlock` (`SystemSummaryBlock.swift:22-24`) | α 0.06 / r 12 / y 6 | ✓ matches `elevation.raised` |
| `NextStepPromptBlock` primary (`NextStepPromptBlock.swift:20-22`) | α 0.08 / r 14 / y 6 | ✓ matches `elevation.floating` |
| `KAirActionCapsule` emphasized (`KAirPageChrome.swift:82`) | α 0.08 / r 14 / y 6 | ✓ matches `elevation.floating` |

So the *values* are largely correct — but every one is a private
restatement. Box 1 for §3.5 needs the same Option A / Option B
decision as §3.2.

### 2.6 §3.6 Motion — FAIL (0 / 2 rows exist as symbols)

The contract §3.6 freezes 2 tiers (`motion.standard`,
`motion.emphasized`).

**There is no `AppTheme.Motion` enum.** The whole codebase has
only **2 inline animation call sites** total. Motion is effectively
unimplemented at v1 — there is almost nothing to migrate, but there
is also no token to point box 1 at. Same Option A / Option B
decision applies; Option A here is cheap (2 call sites).

---

## 3. §6 off-grid shadow call sites (box 2)

The §6 note enumerates 4 off-grid shadow sources. The sweep confirms
all 4 are still off-grid **and** finds 3 more the contract never
listed.

### 3.1 §6-enumerated (4 sources, all still off-grid)

| Site | Values | Deviation from `elevation.raised` (α 0.06 / r 12 / y 6) |
|---|---|---|
| `KAirSurface.hero` (`KAirSurface.swift:53`) | α 0.07 / r 12 / y 6 | α +0.01 |
| `KAirSurface.sunken` (`KAirSurface.swift:57`) | α 0.04 / r 12 / y 6 | α −0.02 |
| `GlassCard` (`HealthDashboardStyle.swift:91`) | α 0.04 / r 18 / y 10 | α −0.02, blur +6, y +4 |
| `KAirActionCapsule` non-emphasized (`KAirPageChrome.swift:82`) | α 0.08 / r 10 / y 6 | blur −2 (vs raised); not `floating` either |

### 3.2 Un-enumerated off-grid shadows (3 sources — NEW findings)

These are NOT in the §6 list. The contract author did not know about
them. They must either migrate or be added to §6 as new exception
rows.

| Site | Values |
|---|---|
| `ChatHomeView.swift:467` | α 0.08 / r 22 / y 10 |
| `ChatHomeView.swift:521` | α 0.09 / r 20 / y 8 |
| `ChatHomeView.swift:537` | α 0.09 / r 20 / y 8 |

**Recommendation:** box 2 should be closed by migrating all 7 to
`elevation.raised` / `elevation.floating` once the `Elevation` enum
exists (see §7). Until then, §6 should be amended to list the 3
ChatHomeView sites so the contract's exception inventory is honest.

---

## 4. §6 eyebrow-tracking call sites (box 3)

The §6 note calls out "Eyebrow tracking `1.0` (existing in
`KAirPageHeader`)". The sweep finds the `1.0` sites **plus** a
spread of other off-spec tracking values.

| Site | Tracking | Note |
|---|---|---|
| `KAirPageChrome.swift:28` | `1.0` | The §6-named `KAirPageHeader` site |
| `ActionCardShell.swift:93` | `1.0` | **Not** named in §6 — a second `1.0` site |
| `DashboardSections.swift:533` | `1.1` | Off-spec (contract unifies at `1.2`) |
| `TodayHomeView.swift:54,91,128,157` | `1.1` ×4 | Off-spec |
| `ComposerBar.swift:48` | `0.8` | **Reclassified — see §4.1.** NOT an eyebrow (`.caption2.weight(.bold)`, not `.caption.weight(.bold)`); intentional exception, excluded from box-3 scope |
| `HealthDashboardStyle.swift:146` | `1.2` | ✓ on-spec |
| `SystemSummaryBlock` / `NextStepPromptBlock` / `SystemEvidenceBlock` | `1.2` (via `Self.eyebrowTracking`) | ✓ on-spec, 3 sites |

So box 3 as literally worded ("`1.0` → 0") needs 2 sites fixed
(`KAirPageChrome:28`, `ActionCardShell:93`). But the *spirit*
(eyebrow tracking unified at `1.2`) needs 7 sites fixed
(`1.0` ×2, `1.1` ×5, `0.8` ×1). The contract should clarify which
it means; this audit recommends the spirit reading and a §6 amend
to list the `1.1` / `0.8` sites.

Note the Continuation blocks already define a `static let
eyebrowTracking: CGFloat = 1.2` per file — three local copies of
the same constant. A shared `Typography`/`Metrics`-level token
would dedupe these.

### 4.1 ComposerBar tracking exception (box-3 scope correction)

**Decision (Tier 2, PR #39): `ComposerBar.swift:48` is excluded
from box-3's migration scope as a documented, intentional
exception. It is NOT migrated, NO new token is added, and its
visual is unchanged.**

The audit table above listed `ComposerBar.swift:48` under
"eyebrow-tracking call sites" because it carries a `.tracking(0.8)`
call. On closer inspection during Tier 2, that classification is
wrong: the site is **not** an eyebrow.

| | `ComposerBar` mode label | `AppTheme.Typography.eyebrow` |
|---|---|---|
| Font | `.caption2.weight(.bold)` | `.caption.weight(.bold)` |
| Tracking | `0.8` | `1.2` |

Why it is excluded rather than migrated:

1. **Font mismatch.** The mode label uses `.caption2`, the
   `eyebrow` token uses `.caption`. They are different sizes — the
   site genuinely does not match the `eyebrow` token.
2. **No-redesign constraint.** Forcing `.kAirTypography(.eyebrow)`
   would enlarge the label from `.caption2` to `.caption`,
   changing the composer's visual hierarchy. Tier 2 forbids visual
   redesign.
3. **No-new-token constraint.** Inventing a 10th §3.2 token (a
   "micro-emphasis" token for `.caption2.weight(.bold)`) is a
   *contract expansion*, not a Tier-2 migration. Tier 1 (PR #38)
   froze the §3.2 set at 9 tokens.
4. **Therefore the site is excluded from box-3 scope.** It is a
   composer micro-emphasis label, not a section eyebrow. Whether a
   dedicated micro-emphasis token should be added is **deferred to
   a future Typography semantic audit** — a contract decision, not
   a missed migration.

The site is pinned in source as named `static let`s
(`ComposerBar.modeLabelFont` / `.modeLabelTracking`) with the full
rationale in a code comment, and pinned in tests by
`DesignSystemTier2MigrationTests
.test_composerBar_modeLabel_isIntentionalExceptionNotMissedEyebrowMigration`
(plus `…_isNotAnyFrozenTypographyToken`). The values are
byte-identical to the previous inline literals — zero visual
change. This guarantees a future reviewer sees it as an
intentional exception, not an oversight.

**Box-3 scope, corrected:** every *true* eyebrow site (the 7
`.caption.weight(.bold)` sites) is migrated to
`AppTheme.Typography.eyebrow`; the composer micro-emphasis label
is deferred. Box 3 is satisfied for its actual scope.

---

## 5. §6 `HealthPalette` alias call sites (box 4)

`HealthPalette` is defined in `kAir/HealthDashboardStyle.swift:10`.
Of the 8 §6-listed members:

| Member | Aliases | Call sites | Status |
|---|---|---|---|
| `canvas` | `backgroundStart` | 0 | ✓ clean |
| `ink` | `textPrimary` | 35 | ✗ |
| `mutedInk` | `textSecondary` | 29 | ✗ |
| `cardStroke` | `line` | 1 | ✗ |
| `mint` | `success` | 6 | ✗ |
| `cyan` | `sky` | 4 | ✗ |
| `amber` | `warning` | 4 | ✗ |
| `coral` | `danger` | 3 | ✗ |

Total: **~82 call sites** across exactly two files —
`kAir/ContentView.swift` and `kAir/DashboardSections.swift`. The
blast radius is narrow (2 files) but deep (82 sites). `ink` and
`mutedInk` alone are 64 of the 82.

Out of scope for box 4 but worth recording: `HealthPalette` also
carries `plum`, `sky` (a local variant colliding with the frozen
`Palette.sky` role), and `heroGradient` — all three are §7
out-of-scope symbols, not §6 aliases. They are not box-4 blockers
but the §7 note already flags them.

---

## 6. `tint(for:)` / `statusTint(for:)` signature decision (box 6)

**Current state.** Both functions take `String`:
- `AppTheme.tint(for token: String) -> Color` — health-metric keys.
- `AppTheme.statusTint(for band: String) -> Color` — status bands.

Production call sites are few: `tint(for: String)` is used at
`TodayHomeView.swift:115` (via `insight.accentToken`);
`statusTint(for: String)` at `TodayHomeView.swift:68` & `:103` and
`HealthWorkspaceView.swift:94`. (There is also
`tint(for: AppSection)` — a *different*, already-typed overload —
which is fine and not part of box 6.)

**Box 6 requires choosing:** introduce typed enums now, OR formally
accept the `String` signatures as v1-permanent.

**Recommendation: accept as v1-permanent.**

Rationale:
1. The contract §6 *already* records the intended v2 path
   ("v2 typechecks via a `HealthMetricToken` enum" /
   "`StatusBand` enum"). Accepting v1-permanent does not lose that
   plan — it just declines to pull it forward.
2. The behavior is already frozen by §4.2 / §4.3; only the
   *signature* is unfrozen. A v1-permanent ruling freezes the
   signature too, which is strictly more stable, not less.
3. The call-site count is small (~4) and all are health-domain
   internal — there is no external API-surface pressure forcing
   the typed rename now.
4. Introducing `HealthMetricToken` / `StatusBand` enums is an
   *implementation* change; doing it would violate this PR's
   audit-only scope. Deferring keeps the audit clean.

**Action to close box 6:** a one-line amendment to
`design-system-v1.md` §6 / §8.1 stating the `String` signatures
are accepted as v1-permanent, with the v2 typed-enum rename
remaining pre-recorded. That is a doc-only change and is **not**
made by this audit PR — it belongs in the next contract status
update, bundled with whatever else lands then.

---

## 7. Recommended follow-up implementation PRs (sequenced — NOT done here)

This audit performs **no** code changes. The work below is the
remediation backlog, smallest-leverage-first within each tier.
Each is its own PR; none should be bundled.

**Tier 1 — unblock box 1 (the root blocker).**

1. **Contract decision PR (doc-only):** for §3.2 / §3.5 / §3.6,
   pick Option A (create the token enums) or Option B (amend the
   contract to treat the names as conventions over SwiftUI
   primitives). This is a prerequisite — the implementation PRs
   below depend on the answer.
2. **If Option A for §3.6 Motion:** create `AppTheme.Motion` (2
   cases), migrate the 2 inline animation sites. Tiny.
3. **If Option A for §3.5 Elevation:** create `AppTheme.Elevation`
   (3 cases), migrate the 5 on-grid local-constant sites to
   consume it. Medium.
4. **If Option A for §3.2 Typography:** create `AppTheme.Typography`
   (9 cases), migrate the ~194 `.font(...)` sites. Large — likely
   itself split per feature area.

**Tier 2 — box 2 (off-grid shadows).** Depends on Elevation token
existing. Migrate the 7 off-grid sites (4 enumerated + 3
ChatHomeView). If any genuinely need a non-grid shadow, add an
explicit §3.5 exception row instead of migrating.

**Tier 3 — box 3 (eyebrow tracking).** Migrate the `1.0` ×2
(plus, per the spirit reading, `1.1` ×5 and `0.8` ×1) to a single
shared `1.2` tracking value. Dedupe the 3 local
`eyebrowTracking` constants in the Continuation blocks.

**Tier 4 — box 4 (`HealthPalette` aliases).** Reroute the ~82 call
sites in `ContentView.swift` + `DashboardSections.swift` from
`HealthPalette.{ink,mutedInk,cardStroke,mint,cyan,amber,coral}` to
their `AppTheme.Palette` equivalents. Narrow blast radius (2
files). Then delete the dead alias members.

**Tier 5 — box 7 (§4.4 seven-state coverage).** Extend
`ActionCardState` (or another component) to cover `empty`,
`error`, `disabled` end-to-end so the §4.4 table is proven
buildable.

**Box 5** already passes — no work.
**Box 6** closes with the Tier-1 contract decision PR (the
v1-permanent ruling can ride along in it).

After Tiers 1–5 land, `design-system-v1.md` §8.1 is fully
checkable and the contract can move to ratified — which in turn
unblocks the visual-contract trio (`mixed-recommendation-rail-visual-v1`,
`negative-feedback-affordance-visual-v1`,
`continuation-transcript-visual-v1`).

---

## 8. What this audit did NOT do

- Did **not** change any Swift file. Repo test baseline stays at
  307/0 (`be6c908`).
- Did **not** edit `design-system-v1.md` or any contract — including
  the box-6 v1-permanent ruling, which is *recommended* here but
  must be enacted by a separate doc PR.
- Did **not** create `AppTheme.Typography` / `.Elevation` /
  `.Motion` enums.
- Did **not** migrate any `HealthPalette`, shadow, or tracking
  call site.
- Did **not** touch Friends, SwiftData, telemetry, continuation
  runtime, or any visual-contract status.
- Did **not** ratify, or move toward ratifying, any contract.
