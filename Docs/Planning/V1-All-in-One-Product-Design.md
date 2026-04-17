# kAir Chat-First Design Rebuild

## Product definition

kAir should no longer feel like five equal tabs competing for attention.

It should behave like one primary conversation product with four integrated capability layers:

1. `Chat` as the permanent home
2. `Health` as the evidence layer
3. `AI` as the runtime transparency layer
4. `Maps` and `Store` as invoked action layers

The key shift is this:

- users do not "go into Maps" first
- users do not "go into Store" first
- users express intent in chat
- kAir decides when to invoke a focused surface

Example:

- user types `I want to go to Apple Store`
- chat detects navigation intent
- kAir hands off into the local Maps flow
- chat is no longer the visible surface until the user exits navigation

That interaction model is much closer to what an all-in-one AI app should feel like.

## North star

kAir should feel like:

- ChatGPT in overall restraint
- WeChat in everyday immediacy
- Apple Health in trust and local-data grounding

It should feel:

- minimal
- quiet
- fast
- intent-driven
- deeply integrated

It should not feel like:

- five separate mini apps
- a dashboard grid
- a super app homepage with too many icons

## Core principles

### 1. Chat is the home surface

When the app opens, the user lands in chat.

This is the only permanent home surface.

Everything else is secondary and gets invoked from that conversation.

### 2. Capabilities are embedded, not advertised

Health, AI, Maps, and Store should feel like built-in abilities of the conversation, not like external destinations demanding attention.

This means:

- fewer permanent navigation affordances
- more intent recognition
- more contextual handoff

### 3. One visible action hierarchy

On the main screen, there should be one clear primary action:

- type into the AI box

Everything else supports that:

- chat history above
- add/reference action in the top-right
- attached context
- routed surface handoff when necessary

### 4. Health remains the trust anchor

Even in a chat-first shell, health data is still the deepest trust layer.

Health should be:

- local-first
- visible as a source of grounding
- clearly separated from speculation
- accessible instantly when the conversation requires proof or detail

### 5. Maps and Store are task exits

Maps and Store are not top-level attention surfaces.

They are task-specific exits from chat:

- route me somewhere
- find something nearby
- help me buy something relevant

They should appear only when the user's intent justifies them.

## Primary information architecture

## App entry

The app opens directly into `Chat`.

No multi-tab landing state.

## Main chat screen

The main layout should be:

1. top header
2. upper content area with chat history / messages
3. lower fixed AI composer

### Header

Header contents:

- brand / thread identity on the left
- `Add` action in the top-right, inspired by WeChat's quick add language
- optional profile / settings access beside it or one step away

### Upper area

This is the conversation record area.

It should show:

- current thread messages
- system handoff notes
- structured tool result cards
- suggested prompt starters near the top

### Lower fixed area

This is the permanent AI composer.

It should always stay visible.

It handles:

- typing
- sending
- quick mode selection
- capability shortcuts if needed

## Capability model

## Health

Health is not a permanent tab anymore.

It is invoked when:

- the user asks about health
- the user asks for deeper explanation
- the user needs evidence or signal detail
- the system needs to show proof behind a claim

Health can open as a focused full-screen or modal surface and should always allow return to chat.

## AI

AI is a transparency layer, not the home.

It opens when:

- the user asks which model is active
- the user wants to understand routing
- the product needs to explain what is happening under the hood

## Maps

Maps opens when the user's intent is spatial or navigational.

Examples:

- `I want to go to Apple Store`
- `Show me a nearby pharmacy`
- `Take me to a quiet gym`

Expected behavior:

- detect intent in chat
- hand off into the local maps/navigation surface
- preserve conversation continuity

## Store

Store opens when the user's intent is transactional.

Examples:

- `I want to buy magnesium`
- `Show me sleep products`
- `Which wearable should I get`

Expected behavior:

- infer buying intent from conversation
- open curated commerce surface
- keep curation calm and relevant

## Reference model

The top-right `Add` action should work like a lightweight reference intake.

Initial reference types:

- Apple Health snapshot
- current location
- photo or file
- store / purchase intent

The important design point is not the exact list.

The important point is that the user can enrich the conversation without leaving the main screen.

## Interaction model

## Happy path

1. User opens kAir
2. User lands in chat
3. User sees recent messages and suggested prompts
4. User types into the fixed composer
5. kAir either:
   - replies directly in chat
   - or routes to Health / Maps / Store / AI

## Routing behavior

Routing should feel immediate and unsurprising.

Examples:

- `How did I sleep` -> stay in chat or open Health
- `I want to go to Apple Store` -> open Maps
- `What should I buy for recovery` -> open Store
- `Which model is answering this` -> open AI

## Return path

Every capability surface must have a clear return path back to chat.

Chat is the permanent context holder.

The user should never feel like they opened a separate app and lost the thread.

## Visual direction

## Tone

Reference tone:

- ChatGPT for minimalism
- not for visual sameness

The design should be:

- restrained
- warm-neutral
- low saturation
- high whitespace
- focused on hierarchy instead of decoration

## Color system

Base palette:

- mineral off-white background
- soft white surfaces
- graphite text
- muted semantic accents

Accent use:

- green-sage for health and trust
- slate-blue for AI/system
- sand for maps/navigation
- muted graphite for general controls

Rule:

color should guide state, not create noise

## Surfaces

Use three surface levels:

1. hero
2. elevated
3. sunken

The main chat screen should not feel card-heavy.

The upper message area needs room to breathe.

## Motion

Motion should be simple:

- thread updates feel responsive
- handoff to a capability surface feels direct
- return to chat feels instant

Avoid ornamental animation.

## Microcopy

Language should feel:

- calm
- direct
- competent
- never theatrical

Preferred phrasing:

- `Open Maps`
- `Attached`
- `Local-first`
- `Grounded in Apple Health`
- `Return to chat`

Avoid:

- marketing hype
- diagnostic certainty
- ecommerce urgency

## Current implementation target

The build should now follow this order:

1. make `Chat` the only permanent root screen
2. add a top-right `Add` reference action
3. keep the AI composer fixed at the bottom
4. route intent from chat into `Health`, `AI`, `Maps`, or `Store`
5. preserve conversation continuity when entering and leaving those surfaces

## Success criteria

The redesign is successful when:

- the user immediately understands that chat is the main interface
- Maps and Store feel like integrated abilities, not permanent tabs
- the `Add` action feels natural and useful
- the composer always feels available
- Health still feels authoritative and grounded
- the whole app feels simpler than before, not more complex
