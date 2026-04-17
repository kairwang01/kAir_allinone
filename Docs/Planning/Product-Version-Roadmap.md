# kAir Product Version Roadmap

Last updated: 2026-04-16

## 1. Product positioning

kAir is not a health dashboard with extra tabs.

kAir is a chat-first, local-first AI operating app:
- `Chat` is the permanent home surface
- `Health` is the trust and evidence layer
- `Models` is the local AI runtime layer
- `Friends` is the future social layer
- other action surfaces are invoked from intent, not treated as equal home tabs

That positioning changes the release logic:
- early versions must prove local trust and shell cohesion
- middle versions must prove local AI usefulness and tool routing
- later versions can expand into social and action surfaces

## 2. Versioning principles

We will use product versions, not engineering-only milestones.

Release progression:
- `v0.x` = validation and architecture buildout
- `v1.0` = first public product definition that matches the long-term direction

Every version must define:
- what the product is
- what it is explicitly not yet
- what user loop it proves
- what technical debt is acceptable for that phase

## 3. Version ladder

## v0.1 Foundation Build

### Goal
Prove local Health capability, local privacy posture, and the new folder architecture baseline.

### Product definition
An on-device Health experience with local analysis and the first app skeleton for future expansion.

### Must ship
- direct local HealthKit access
- on-device health analysis
- local compact risk model bundle
- privacy guardrails
- repository and module reorganization

### Must not expand into
- chat-first shell
- model downloads
- friends
- maps or store
- remote sync

### Success criteria
- Health data loads locally on supported devices
- health insights remain understandable and non-diagnostic
- project structure is ready for multi-team implementation

### Exit criteria
- stable local health flow exists
- new module layout is in place
- compliance boundaries are documented

## v0.2 Chat-First Alpha

### Goal
Turn the app into a true conversation-first product while preserving local Health as a callable space.

### Product definition
A local AI chat shell with a usable conversation home, a minimal local model layer, and Health as a secondary workspace.

### Must ship
- `Chat / Spaces / Models / Friends / Me` root structure
- chat-first home screen
- conversation composer
- message timeline and tool-result cards
- model library shell
- Health workspace entry
- Health tool adapter boundary

### Must not expand into
- full social sync
- large multi-agent automation
- heavy RAG
- complex commerce or maps execution

### Success criteria
- users understand that chat is the home surface
- Health no longer feels like the app homepage
- model and privacy status are visible enough to build trust

### Exit criteria
- chat shell replaces dashboard-first home
- Health can be opened as a focused space
- local model abstractions exist even if some providers are still mock

## v0.3 Local AI Runtime Alpha

### Goal
Make local AI execution real and understandable, not just architectural.

### Product definition
A chat-first app that can run at least one real local chat runtime plus specialized on-device models.

### Must ship
- provider abstraction in active use
- at least one real local chat runtime integrated
- model install or registration flow
- active model transparency UI
- local memory summary baseline
- basic tool calling for Health

### Must not expand into
- multi-user social
- remote AI fallback by default
- uncontrolled prompt and memory growth

### Success criteria
- the app can answer locally on-device for core chat cases
- model switching is understandable
- users can see why the system routed into Health or another tool

### Exit criteria
- one stable local runtime available
- chat, tool calls, and model state form a coherent loop

## v0.4 Action Surface Alpha

### Goal
Validate the “intent invokes surface” model.

### Product definition
Chat remains home, while non-home surfaces open only when user intent requires them.

### Candidate surfaces
- `Health`
- `AI transparency`
- `Maps`
- `Store`

### Must ship
- routing layer for intent-driven handoff
- return-to-chat continuity
- focused surfaces for at least two invoked capabilities

### Must not expand into
- broad tab sprawl
- destination-first navigation

### Success criteria
- chat can hand off into a focused surface without feeling like a context switch into another app

## v0.5 Friends Private Beta

### Goal
Introduce the social shell without violating Health boundaries.

### Product definition
A local-first app with a private beta social layer for plain conversation and identity, fully isolated from Health data.

### Must ship
- Friends domain models
- local friends UI shell
- server transport abstraction
- optional auth and account baseline
- reporting, blocking, and deletion requirements if user-generated communication is enabled

### Must not expand into
- health sharing
- health-derived ranking
- health-enhanced recommendations for friends

### Success criteria
- social foundation can be tested without touching Health data flows

## v0.8 Closed Beta

### Goal
Bring the major pillars together into one coherent pre-launch product.

### Product definition
A private beta of the real kAir concept:
- chat-first
- local AI
- Health as trust layer
- model management
- early social foundation

### Must ship
- performance tuning on target iPhone classes
- privacy review completion
- stronger memory behavior
- clearer model status and fallback behavior
- TestFlight-ready build discipline

### Exit criteria
- internal and invited beta users can complete the core weekly product loop

## v1.0 Public Product Definition

### Goal
Launch the first public version that truly matches the kAir identity.

### Product definition
A calm, local-first AI operating app where chat is the home, Health is grounded and private, and local model capability is visible and useful.

### Must ship
- polished chat-first shell
- stable local AI routing
- stable Health workspace
- model library with understandable compatibility
- privacy disclosures aligned with actual implementation
- onboarding that explains local trust and capability boundaries

### Optional for v1.0
- limited Friends release, only if compliance and moderation are ready

### Must not ship if incomplete
- health social sharing
- hidden remote AI dependence
- unclear privacy disclosures
- unstable local model behavior on supported devices

## 4. Recommended execution path

Recommended sequence:
1. lock `v0.2` as the next major delivery target
2. keep `v0.3` focused on real local runtime integration
3. defer social beyond `v0.4` unless there is a dedicated backend and compliance owner

Reason:
- the product is not yet a stable chat-first experience
- social too early will dilute focus and add compliance risk
- maps and store should come from routing maturity, not tab expansion

## 5. Version summary table

| Version | Product identity | Core proof |
| --- | --- | --- |
| `v0.1` | local Health foundation | trust, privacy, local analysis |
| `v0.2` | chat-first shell | home surface reset |
| `v0.3` | local AI runtime | real on-device chat loop |
| `v0.4` | invoked capability model | routing into focused surfaces |
| `v0.5` | social shell beta | future network layer without Health leakage |
| `v0.8` | closed beta | coherence across major pillars |
| `v1.0` | public product launch | true kAir identity |
