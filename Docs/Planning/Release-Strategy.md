# kAir Release Strategy

Last updated: 2026-04-16

## 1. Release model

Use three layers of planning:
- `Version roadmap` for product direction
- `Milestones` for delivery grouping
- `Issue tracks` for engineering execution

Recommended cadence:
- one major product target at a time
- two-week engineering sprints
- one version review at the end of every second sprint

## 2. Current recommended target

Current primary target:
- `v0.2 Chat-First Alpha`

Reason:
- the repo now has the folder structure for a chat-first rebuild
- the next highest-value proof is changing the app identity from dashboard-first to conversation-first
- this can be done without expanding into risky social or remote features

## 3. Milestone breakdown

## Milestone A: Shell and navigation

Outcome:
- app opens into the new shell
- root information architecture is visible

Includes:
- root navigation
- chat home scaffold
- spaces entry
- models entry
- friends shell
- me/settings shell

## Milestone B: Local AI foundation

Outcome:
- chat can run through a real or controlled local provider abstraction

Includes:
- conversation engine
- model provider protocol
- model library store
- basic memory summary
- tool registry shell

## Milestone C: Health integration under Spaces

Outcome:
- Health works as a focused workspace and callable tool

Includes:
- Health workspace root
- Health tool adapter
- migration boundary for current health files
- clear return path into chat

## Milestone D: Trust and launch packaging

Outcome:
- alpha is shippable to internal or TestFlight users

Includes:
- compliance pass
- onboarding copy
- privacy disclosures
- crash and performance review

## 4. Release gates

Every version needs four gates before promotion:

### Product gate
- main user loop is understandable
- the app has one clear home surface

### Engineering gate
- no unstable cross-module hacks that block the next version
- target devices meet responsiveness expectations

### Privacy gate
- Health boundaries still hold
- no accidental remote leakage

### Quality gate
- no broken navigation
- no dead-end surfaces
- no fake functionality presented as real

## 5. Branch and release strategy

Recommended Git strategy:
- `main` stays releasable
- short-lived feature branches per milestone task
- optional `release/v0.x` branch only when preparing a TestFlight cut

Suggested branch naming:
- `feature/chat-home-shell`
- `feature/model-library-shell`
- `feature/health-workspace`
- `feature/local-provider-abstraction`
- `docs/version-roadmap`

## 6. Labels and tracking

Suggested GitHub labels:
- `version:v0.2`
- `version:v0.3`
- `track:shell`
- `track:ai-core`
- `track:health`
- `track:friends`
- `track:privacy`
- `track:design-system`
- `risk:blocker`
- `risk:compliance`
- `release:alpha`
- `release:beta`

## 7. Definition of done by layer

### Shell work is done when
- navigation is wired
- states are visible
- the next team can attach real data without rewriting the UI structure

### AI core work is done when
- a real provider can plug in without changing the chat UI contract
- model state is inspectable

### Health work is done when
- Health can be opened from chat or spaces
- existing health logic is not duplicated blindly

### Friends work is done when
- social data models exist
- no Health data crosses the boundary

## 8. Stop conditions

Pause the next version if any of these happen:
- chat-first shell is delayed by feature creep from maps, store, or friends
- AI layer couples directly to one runtime with no abstraction
- Health logic is rewritten instead of adapted, causing regressions
- social work begins before privacy guardrails are encoded in code and contracts

## 9. Recommended next 6-week plan

### Weeks 1-2
- finish Milestone A
- lock visual direction and root navigation

### Weeks 3-4
- finish Milestone B
- connect chat store, provider abstraction, and model library shell

### Weeks 5-6
- finish Milestone C
- move Health under Spaces and enable the tool adapter boundary

At the end of week 6:
- assess whether `v0.2` is ready for internal alpha
- do not start Friends implementation until that decision is made
