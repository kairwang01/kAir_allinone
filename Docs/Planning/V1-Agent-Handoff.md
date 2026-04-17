# V1 Agent Handoff

## Frontend or iOS architect
- Own `App/`
- Own `DesignSystem/`
- Own `Features/Chat/Presentation/`
- Own `Features/Models/Presentation/`
- Own `Features/Friends/Presentation/`
- Own `Features/Me/Presentation/`
- Own `Spaces/Health/Presentation/`
- Own `Shared/Components/`

## Backend engineer
- Own `Core/Networking/`
- Own `Contracts/FriendsAPI/`
- Support `Features/Friends/Domain/`

## AI or platform engineer
- Own `Core/AI/`
- Own `Core/Models/`
- Own `Core/Memory/`
- Support `Features/Chat/Data/`
- Support `Features/Models/Data/`

## Legal or compliance
- Review `Core/Privacy/`
- Review `Contracts/FriendsAPI/`
- Review all Health-related data flows before any friend-sharing features ship

## Health specialist
- Own `Spaces/Health/`
- Later migrate logic from current root files:
  - `HealthDashboardModels.swift`
  - `HealthDashboardStore.swift`
  - `HealthKitService.swift`
  - `LocalHealthAnalyzer.swift`
  - `CoreMLService.swift`
  - `DashboardSections.swift`
