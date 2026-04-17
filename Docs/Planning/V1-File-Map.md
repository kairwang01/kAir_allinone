# V1 Planned File Map

## App shell
- `kAir/kAir/App/AppEntry/AppBootstrap.swift`
- `kAir/kAir/App/Navigation/AppSection.swift`
- `kAir/kAir/App/Navigation/RootShellView.swift`

## Core runtime
- `kAir/kAir/Core/AI/AgentRegistry.swift`
- `kAir/kAir/Core/AI/ConversationEngine.swift`
- `kAir/kAir/Core/AI/ToolRegistry.swift`
- `kAir/kAir/Core/Memory/MemoryStore.swift`
- `kAir/kAir/Core/Models/LocalModelDescriptor.swift`
- `kAir/kAir/Core/Models/ModelProvider.swift`
- `kAir/kAir/Core/Networking/ServerTransport.swift`
- `kAir/kAir/Core/Privacy/PrivacyGuard.swift`

## Design system
- `kAir/kAir/DesignSystem/Tokens/AppTheme.swift`
- `kAir/kAir/DesignSystem/Components/KAirSurface.swift`

## Chat feature
- `kAir/kAir/Features/Chat/Domain/ChatSession.swift`
- `kAir/kAir/Features/Chat/Data/ChatStore.swift`
- `kAir/kAir/Features/Chat/Presentation/ChatHomeView.swift`

## Model library
- `kAir/kAir/Features/Models/Data/ModelLibraryStore.swift`
- `kAir/kAir/Features/Models/Presentation/ModelLibraryView.swift`

## Friends
- `kAir/kAir/Features/Friends/Domain/FriendModels.swift`
- `kAir/kAir/Features/Friends/Presentation/FriendsHomeView.swift`

## Me
- `kAir/kAir/Features/Me/Presentation/ProfileAndSettingsView.swift`

## Health space
- `kAir/kAir/Spaces/Health/Domain/HealthWorkspaceModels.swift`
- `kAir/kAir/Spaces/Health/Data/HealthToolAdapter.swift`
- `kAir/kAir/Spaces/Health/Presentation/HealthWorkspaceView.swift`

## Shared UI
- `kAir/kAir/Shared/Components/Conversation/ComposerBar.swift`
- `kAir/kAir/Shared/Components/Conversation/MessageBubble.swift`
- `kAir/kAir/Shared/Utilities/FeatureFlag.swift`

## Contracts
- `kAir/Contracts/FriendsAPI/FriendsServiceContract.md`
- `kAir/Contracts/AIProviders/LocalModelProviderContract.md`

## Migration note
Old health dashboard code stays at the source root until the new shell replaces it.
