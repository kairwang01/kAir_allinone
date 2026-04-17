# V1 Planned File Map

## App shell
- `Kair Health/Kair Health/App/AppEntry/AppBootstrap.swift`
- `Kair Health/Kair Health/App/Navigation/AppSection.swift`
- `Kair Health/Kair Health/App/Navigation/RootShellView.swift`

## Core runtime
- `Kair Health/Kair Health/Core/AI/AgentRegistry.swift`
- `Kair Health/Kair Health/Core/AI/ConversationEngine.swift`
- `Kair Health/Kair Health/Core/AI/ToolRegistry.swift`
- `Kair Health/Kair Health/Core/Memory/MemoryStore.swift`
- `Kair Health/Kair Health/Core/Models/LocalModelDescriptor.swift`
- `Kair Health/Kair Health/Core/Models/ModelProvider.swift`
- `Kair Health/Kair Health/Core/Networking/ServerTransport.swift`
- `Kair Health/Kair Health/Core/Privacy/PrivacyGuard.swift`

## Design system
- `Kair Health/Kair Health/DesignSystem/Tokens/AppTheme.swift`
- `Kair Health/Kair Health/DesignSystem/Components/KairSurface.swift`

## Chat feature
- `Kair Health/Kair Health/Features/Chat/Domain/ChatSession.swift`
- `Kair Health/Kair Health/Features/Chat/Data/ChatStore.swift`
- `Kair Health/Kair Health/Features/Chat/Presentation/ChatHomeView.swift`

## Model library
- `Kair Health/Kair Health/Features/Models/Data/ModelLibraryStore.swift`
- `Kair Health/Kair Health/Features/Models/Presentation/ModelLibraryView.swift`

## Friends
- `Kair Health/Kair Health/Features/Friends/Domain/FriendModels.swift`
- `Kair Health/Kair Health/Features/Friends/Presentation/FriendsHomeView.swift`

## Me
- `Kair Health/Kair Health/Features/Me/Presentation/ProfileAndSettingsView.swift`

## Health space
- `Kair Health/Kair Health/Spaces/Health/Domain/HealthWorkspaceModels.swift`
- `Kair Health/Kair Health/Spaces/Health/Data/HealthToolAdapter.swift`
- `Kair Health/Kair Health/Spaces/Health/Presentation/HealthWorkspaceView.swift`

## Shared UI
- `Kair Health/Kair Health/Shared/Components/Conversation/ComposerBar.swift`
- `Kair Health/Kair Health/Shared/Components/Conversation/MessageBubble.swift`
- `Kair Health/Kair Health/Shared/Utilities/FeatureFlag.swift`

## Contracts
- `Kair Health/Contracts/FriendsAPI/FriendsServiceContract.md`
- `Kair Health/Contracts/AIProviders/LocalModelProviderContract.md`

## Migration note
Old health dashboard code stays at the source root until the new shell replaces it.
