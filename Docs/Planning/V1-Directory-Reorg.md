# V1 Directory Reorganization

This workspace now has a target folder structure for a chat-first local AI app.

Rules for the next implementation phase:
- Keep current running health dashboard files in place until the new app shell is wired.
- Build new features under the new folders first.
- Migrate old root-level Swift files only after the replacement flow is stable.

Current root-level implementation that remains active for now:
- `ContentView.swift`
- `KAirApp.swift`
- `HealthDashboardStore.swift`
- `HealthDashboardModels.swift`
- `HealthKitService.swift`
- `LocalHealthAnalyzer.swift`
- `CoreMLService.swift`
- `DashboardSections.swift`
- `HealthDashboardStyle.swift`
- `HealthDashboardSampleData.swift`

Target module layout:
- `App/`: app bootstrap and navigation shell
- `Core/`: AI runtime, memory, privacy, transport, model abstractions
- `DesignSystem/`: tokens and shared surfaces
- `Features/`: user-facing app areas
- `Spaces/`: tool workspaces such as Health
- `Shared/`: reusable UI and small utilities
- `Contracts/`: future server and provider contracts
- `Docs/Planning/`: implementation handoff
