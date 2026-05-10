# WeMeet → kAir Friends · Migration Plan (doc-only)

> **Status: Phase 2 candidate — NOT active.**
> 本文档为占位计划。**任何 Friends 代码迁移在 §7 全部前置条件 ✅ 之前一律不允许开启。**
> 当前主线（transcript continuation / Layer-4 rail / negative-feedback affordance /
> capability · telemetry · feedback runtime skeleton）尚在收口期。开启此迁移会
> 立刻引入新 vertical（domain / storage / identity / nav / 合规面），打断主线节奏。
> 因此本文档**只沉淀计划，不开工**。

---

## 0. 文档范围与状态

- **类型**：doc-only · planning artifact。
- **代码影响**：零。本文档不授权任何 Swift / config / 导航 / 资产改动。
- **下一步触发条件**：§7 列出的全部前置项落地后，由维护者按 §5 的 PR 序列开启实施 PR。
- **反向退出**：§6 任意 risk 升级到 blocker → 文档归档为 `archived`，需另开计划。
- **关联契约**：[`Contracts/FriendsAPI/FriendsServiceContract.md`](../../Contracts/FriendsAPI/FriendsServiceContract.md)（V1 立场、资源、合规要求）。
- **来源仓库**：
  - `WeMeet/`（已废弃私有仓库，作为素材库）
  - `WeMessager/`（**整仓废弃**，无独有资产；无需检视）

---

## 1. 迁移目标

1. **目标位置**：`kAir/Features/Friends/`（已搭骨架，目前仅含占位 `Domain/FriendModels.swift` + `Presentation/FriendsHomeView.swift`）。
2. **资源对齐**：把 WeMeet 的 SwiftData 模型与 SwiftUI 视图填入 Friends 模块，以兑现 `FriendsServiceContract.md` 列出的 V1 资源（`User` / `Friend` / `Conversation` / `Participant` / `Message` / `Attachment` / `Presence`）。
3. **范围限定**：
   - **是** Friends vertical migration（人 ↔ 人）。
   - **不是** AI Chat 增强；`Features/Chat/`（人 ↔ kAir）保持原状，迁移过程中不得触碰。
   - **不是** real backend 接入；V1 全部 local-first，server 只留接口形状不接通。
   - **不是** Firebase 接入。
4. **V1 立场**（与 contract 一致）：
   - 离线可用，无服务端依赖。
   - 物理隔离 Friends 与 Health 数据存储。
   - 任何上传 / 推送 / 第三方处理需显式同意。

---

## 2. 不迁移内容

下列项目从源仓库到 kAir 的迁移**全部禁止**，即使后续 PR 也不允许夹带。

| # | 来源 | 拒绝理由 |
| - | --- | --- |
| 1 | `WeMessager/`（整仓） | 严格子集，无独有资产 |
| 2 | `WeMeet/AuthViewModel.swift` | Firebase Auth；与 V1 local-first 冲突 |
| 3 | `WeMeet/LoginView.swift` | Firebase 登录 UI |
| 4 | `WeMeet/CredentialFields.swift` | 同上 |
| 5 | `WeMeet/ToggleAuthModeButton.swift` | 同上 |
| 6 | `WeMeet/GoogleService-Info.plist` | Firebase 配置 |
| 7 | `WeMeet/Item.swift` | Xcode template stub |
| 8 | `WeMeet/WeMeetApp.swift` | App entry；kAir 已有 |
| 9 | `WeMeet/ContentView.swift` | 根视图；kAir 已有 |
| 10 | `WeMeet/ChatDetailView.swift::simulateRecipientReply()` | demo mock；不留灰区 |
| 11 | `WeMeet/ChatView.swift::addChatItem()` 内的随机假用户生成 | demo mock |
| 12 | `User.privateKeyData` 的实际 E2E 加密链路 | 字段可保留作未来钩子；**任何调用方/加解密路径**在 V1 不实现，避免半成品 |
| 13 | "对方正在输入..." 的本地伪 typing indicator | 没有真实信令时不上 |

---

## 3. 文件映射表

> Action 词义：
> - **migrate**：原样搬移（含路径调整），不改实现。
> - **adapt**：搬移并改名 / 套 DesignSystem token / 提取 i18n key / 删除 demo 调用。
> - **rewrite**：保留意图，重写实现。
> - **drop**：明确不迁。
>
> Target 路径里若含 `?`，表示该文件归 **Friends 私有** 还是 **`Shared/` 通用件**取决于 PR-F2 是否启用（见 §5）；F2 未启用时一律落入 Friends 私有路径。

### 3.1 Domain（4 项）

| # | Source | Target | Rename | Action | Notes |
| - | --- | --- | --- | --- | --- |
| D1 | `WeMeet/Message.swift` | `kAir/Features/Friends/Domain/FriendsMessage.swift` | `Message` → `FriendsMessage` | adapt | 命名空间隔离，避免与 `Features/Chat/ConversationMessage` 撞 |
| D2 | `WeMeet/ChatItem.swift` | `kAir/Features/Friends/Domain/Conversation.swift` | `ChatItem` → `Conversation` | adapt | 对齐 contract 资源名 |
| D3 | `WeMeet/User.swift` | `kAir/Features/Friends/Domain/FriendsUser.swift` | `User` → `FriendsUser` | adapt | 见 §6 R-2；`birthday` 字段删除（contract 禁 `dateOfBirth`）；`privateKeyData` 字段保留但未启用 |
| D4 | _(无源)_ | `kAir/Features/Friends/Domain/Presence.swift` | _(新增)_ | rewrite | 把 WeMeet 的 `UserStatus` enum 单独抽成 `Presence`，对齐 contract |

### 3.2 Data（3 项，全部 PR-F4 阶段）

| # | Source | Target | Rename | Action | Notes |
| - | --- | --- | --- | --- | --- |
| Da1 | _(无源)_ | `kAir/Features/Friends/Data/FriendsBackend.swift` | _(新增协议)_ | rewrite | local stub + 网络实现的接口边界；类比 `RecommendationProvider` |
| Da2 | _(无源)_ | `kAir/Features/Friends/Data/LocalFriendsBackend.swift` | _(新增 stub)_ | rewrite | SwiftData 本地实现 |
| Da3 | _(无源)_ | `kAir/Features/Friends/Data/FriendsModelContainer.swift` | _(新增)_ | rewrite | **独立的** `ModelContainer`，与 Health / Chat 物理隔离 |

### 3.3 Presentation（7 项）

| # | Source | Target | Rename | Action | Notes |
| - | --- | --- | --- | --- | --- |
| P1 | `WeMeet/ChatView.swift` | `kAir/Features/Friends/Presentation/ConversationListView.swift` | `ChatView` → `ConversationListView` | adapt | 删 `addChatItem()` 假用户生成；中文 → i18n；颜色 → DesignSystem token |
| P2 | `WeMeet/ChatDetailView.swift` | `kAir/Features/Friends/Presentation/ConversationView.swift` | `ChatDetailView` → `ConversationView` | adapt | 删 `simulateRecipientReply()`；接 `FriendsBackend.send()` |
| P3 | `WeMeet/ChatRow.swift` | `kAir/Features/Friends/Presentation/ConversationRow.swift` | `ChatRow` → `ConversationRow` | adapt | DesignSystem 对齐 |
| P4 | `WeMeet/MessageListView.swift` | `kAir/Features/Friends/Presentation/MessageScrollView.swift` | `MessageListView` → `MessageScrollView` | adapt | 删 typing indicator（见 §2 #13） |
| P5 | `WeMeet/MessageRow.swift` | `kAir/Features/Friends/Presentation/MessageBubbleRow.swift` | `MessageRow` → `MessageBubbleRow` | adapt | 命名避开 `Shared/Components/Conversation/MessageBubble`；i18n "已读"/"送达" |
| P6 | `WeMeet/MessageInputView.swift` | `kAir/Features/Friends/Presentation/ConversationComposer.swift` | `MessageInputView` → `ConversationComposer` | adapt | i18n "发送消息"/"发送" |
| P7 | `WeMeet/PersonalInfoView.swift` | `kAir/Features/Friends/Presentation/FriendsProfileView.swift` | `PersonalInfoView` → `FriendsProfileView` | adapt | 留待后续是否拆到 `Features/Profile/`；V1 内嵌在 Friends |

### 3.4 通用件（3 项 / 4 个文件，PR-F2 条件性启用）

> ⚠️ 默认放在 Friends 私有路径下。**仅当** `Shared/` 抽取被独立批准（见 §5 PR-F2）时才搬到 `Shared/`。本计划不主动开 Shared 抽取 PR。

| # | Source | Target (F2 未启用) | Target (F2 启用) | Action |
| - | --- | --- | --- | --- |
| S1 | `WeMeet/ImagePicker.swift` | `kAir/Features/Friends/Presentation/_Internal/ImagePicker.swift` | `kAir/Shared/Utilities/ImagePicker.swift` | migrate |
| S2 | `WeMeet/SearchBarView.swift` | `kAir/Features/Friends/Presentation/_Internal/SearchBarView.swift` | `kAir/Shared/Components/SearchBar/SearchBarView.swift` | adapt（i18n "搜索"/"取消"） |
| S3 | `WeMeet/AvatarView.swift` + `AvatarImageView.swift` + `AvatarPickerView.swift` | `kAir/Features/Friends/Presentation/_Internal/Avatar/*.swift` | `kAir/Shared/Components/Avatar/*.swift` | adapt |

### 3.5 不动的文件

| # | Source | Action | Notes |
| - | --- | --- | --- |
| X1 | `WeMeet/Assets.xcassets/AccentColor.colorset/*` | drop | kAir 已有 DesignSystem |
| X2 | `WeMeet/Assets.xcassets/AppIcon.appiconset/*` | drop | kAir 已有 |
| X3 | `WeMeet/WeMeetTests/*`, `WeMeetUITests/*` | drop | 测试用例耦合 Firebase / 旧命名；新模型新写测试 |
| X4 | `WeMeet/Preview Content/*` | drop | 模板默认 |

---

## 4. Contract 合规清单

每一项契约要求 → 一个具体代码动作 → 一个可勾选的验收点。

| # | Contract 条款（对应 `FriendsServiceContract.md` 节） | 必须执行的代码动作 | 验收 done check |
| - | --- | --- | --- |
| C-1 | §1 / §合规总则：**Local app 在没有任何 Friends 服务端的情况下必须可用** | PR-F4: 引入 `FriendsBackend` 协议；`LocalFriendsBackend` 默认注入；任何网络实现必须可被 unset | UITest: 在禁网状态下完成"创建会话 → 发送消息 → 重启 app 仍可见"流程 |
| C-2 | §合规总则：**Friends 数据库 / 缓存 / 索引不得复用 Health 数据存储** | PR-F1: 独立 `ModelContainer(for: FriendsUser.self, Conversation.self, FriendsMessage.self)`；不与 `HealthDashboardStore` / Health context 共享 | 编译期验证：grep 确保 Friends 模块无 `import HealthKit` |
| C-3 | §哪些行为需要用户明确同意：**通讯录上传** | PR-F4: 任何 contact discovery 入口前置 explicit consent screen；默认不勾选 | UI 评审：consent 不能用模糊文案；可撤回 |
| C-4 | 同上：**push 通知** | PR-F5: 接入 push 前 consent；可撤回；可在系统设置外另设 in-app off | UI 评审 + 单元测试 |
| C-5 | 同上：**附件上传** | PR-F4: 发送图片附件前 consent；附件不能复用 HealthKit 导出物 | 编译期验证 + UI 评审 |
| C-6 | §合规总则：**HealthKit data does not flow into friends features by default** | 全过程：Friends 模块禁止 `import HealthKit`；禁止读 `HealthDashboardStore` / `LocalHealthAnalyzer` | grep 闸：CI 任务 fail-fast 检查这些 import |
| C-7 | §不能做的事：**不能基于健康状态做好友推荐 / 排序 / 通知** | 全过程：Friends 推荐 / 排序输入只接受 Friends-domain 字段 | code review checklist |
| C-8 | §服务端最低约束：**消息正文之外不得记录额外健康标签** | 全过程：日志 / telemetry 中 Friends 事件 schema 不允许出现 §禁止字段表 列出的字段 | telemetry contract 评审 |
| C-9 | §V1 通过标准：**消息 / UGC 上线则举报、屏蔽、删除、联系渠道同步上线** | PR-F4: block / report / delete-conversation 三入口同步上线 | UITest 三条 happy path |
| C-10 | §敏感字段表：`User.dateOfBirth` 默认不进 Friends 合同 | PR-F1: `FriendsUser` 删除 `birthday` 字段 | grep 验证：`FriendsUser` 无 `birthday` / `dateOfBirth` |
| C-11 | §敏感字段表：精确位置不进 Friends | 全过程：Friends 模型 / message payload 不出现 lat/lng / `CLLocation` | grep 闸 |

---

## 5. PR 切分方案

> 每个 PR 互锁。后续 PR 不得合并直到前序全部 merged + green。所有 PR 走 kAir 现有的提交风格规范（`Skel(...)` / `I1` / `Hygiene` / `doc-only`）。

### PR-F0: doc-only · 本文档落地

- **Scope**：仅本文件 `Docs/migrations/wemeet-to-friends.md`。
- **Out of scope**：任何代码 / 配置 / 导航。
- **Depends on**：无。
- **DoD**：本文档合并；`Features/Friends/` 目录无任何变化。
- **Commit prefix**：`Docs(migrations):` 或 `doc-only:`。

### PR-F1: Friends domain models + isolated container

- **Scope**：D1–D4（`FriendsMessage` / `Conversation` / `FriendsUser` / `Presence`）+ Da3（`FriendsModelContainer`）+ 模型层单元测试骨架。
- **Out of scope**：任何 view、navigation、backend 接口（Da1 / Da2 留 PR-F4）；任何 demo 假数据。
- **Depends on**：PR-F0；§7 全绿。
- **DoD**：
  - 4 个 model + 1 个独立 container 编译通过。
  - 单元测试：建模、insert、fetch 在隔离 container 上跑通。
  - grep 闸 C-2 / C-6 / C-10 / C-11 全部通过。
  - `Features/Friends/Presentation/` 无任何新文件。
- **Commit prefix**：`Skel(friends-domain):`。

### PR-F2: 通用件抽取（**OPTIONAL · 不阻塞后续 PR**）

- **Status**: **OPTIONAL · MUST NOT block PR-F3 / PR-F4 / PR-F5.**
  PR-F2 既不是 PR-F3 的前置依赖，也不是 PR-F4 / PR-F5 的前置依赖。
  PR-F3/F4/F5 默认按 §3.4 "F2 未启用" 路径推进（S1–S3 留在 Friends 私有路径下）。
  即使将来 PR-F2 被批准、被合并，也只是事后做一次 hygiene 重构——不允许任何人把 PR-F2 当成 PR-F3/F4/F5 的前置闸卡，重新拖慢 Friends 迁移。
- **Scope**：S1–S3 上移到 `Shared/`，附带最小调用方迁移（仅 Friends 内部）。
- **Out of scope**：任何 Friends 业务逻辑。
- **Depends on**：PR-F1。
- **DoD**：
  - 抽取后通过 SwiftPM target / module 边界检查。
  - kAir 现有屏幕（非 Friends）无引用变化。
- **触发条件**：维护者明确批准"现在抽 Shared 件"。**不批准则永远跳过此 PR**，S1–S3 留在 Friends 私有路径下。
- **Commit prefix**：`Hygiene(shared):`。

### PR-F3: Friends presentation migration

- **Scope**：P1–P7（`ConversationListView` / `ConversationView` / `ConversationRow` / `MessageScrollView` / `MessageBubbleRow` / `ConversationComposer` / `FriendsProfileView`）。
- **Out of scope**：消息真实发送链路（PR-F4）；导航 wire（PR-F5）。
- **Depends on**：PR-F1；PR-F2（如启用，否则按 3.4 默认路径）。
- **DoD**：
  - 7 个 view 编译通过；预览（Xcode Preview）有 mock 数据可见。
  - 中文硬编码全部走 i18n key（含 "聊天"/"搜索"/"取消"/"已读"/"送达"/"发送"/"发送消息" 等）。
  - 颜色 / 字体走 kAir DesignSystem token，不留 raw `Color.green` / `Color.gray`。
  - 删除：`simulateRecipientReply()` 调用、addChatItem 假用户、本地 typing indicator（见 §2）。
- **Commit prefix**：`Skel(friends-ui):` 或 `I1(friends-ui):`。

### PR-F4: Local backend + 合规 UX

- **Scope**：Da1 / Da2（`FriendsBackend` 协议 + `LocalFriendsBackend` SwiftData 实现）；block / report / delete-conversation 三入口；contact / push / attachment 三个 consent gate。
- **Out of scope**：导航 wire；远端 backend 实现。
- **Depends on**：PR-F1, PR-F3。
- **DoD**：
  - C-1, C-3, C-4, C-5, C-9 全部 ✅。
  - 离网 UITest pass：见 C-1 验收。
  - block / report / delete 三条 happy path UITest pass。
- **Commit prefix**：`I1(friends-backend):` + `I2(friends-consent):`（拆两条 commit 也行）。

### PR-F5: Navigation + entry wiring

- **Scope**：把 Friends 入口接进 kAir 主导航；`FriendsHomeView` 替换为新 `ConversationListView`；最小可用流程 end-to-end。
- **Out of scope**：任何 Friends 内部 polish；任何与 Chat / Health 模块的交互。
- **Depends on**：PR-F4。
- **DoD**：
  - 主导航出现 Friends tab/route。
  - End-to-end UITest：从主屏 → Friends → 创建会话 → 发消息 → 退出 → 重进可见。
  - 全部合规 grep 闸（C-2 / C-6 / C-7 / C-8 / C-10 / C-11）通过。
- **Commit prefix**：`I1(friends-nav):` + `Main(friends):`。

---

## 6. 风险与阻塞项

| ID | 风险 | 类型 | 触发条件 | 处理 |
| - | --- | --- | --- | --- |
| R-1 | **命名冲突**：`Message` / `User` / `ChatItem` / `ChatView` 与 kAir 现有/计划名撞 | naming | PR-F1 起 | §3 已强制 `FriendsMessage` / `FriendsUser` / `Conversation` / `ConversationView` 命名空间隔离；不允许保留旧名 |
| R-2 | **`User` 的双重语义**：WeMeet 中 `User` 同时表示 self 和 contact；contract 把 `User` 与 `Friend` 分开 | semantic | PR-F1 设计阶段 | 决定一次：`FriendsUser` 表示 Friends 模块内任何身份（含 self + contact），新增 `Friend` 类型仅用于"已添加的联系人关系"；如该决定无法在 PR-F1 评审通过 → blocker，归档本计划 |
| R-3 | **SwiftData container 共存**：与 kAir 现有 Health 持久化层冲突 | infra | PR-F1 | C-2 强制隔离；如 kAir 主仓尚未确立 SwiftData 总策略 → 升级为 blocker，等待主线决定 |
| R-4 | **i18n 基础设施缺失**：kAir 主仓尚未启用 `Localizable.strings` 工作流 | infra | PR-F3 | §7 前置项；若未就绪 → 不开 PR-F3 |
| R-5 | **Firebase 残留**：迁移过程中误带入 Firebase 依赖 | compliance | 任意 PR | code review checklist + grep `import Firebase` 闸；触发即 reject |
| R-6 | **Demo mock 残留**：`simulateRecipientReply` 类伪逻辑被悄悄保留 | quality | PR-F3 | §2 #10–#13 已显式禁止；review 时强制 grep |
| R-7 | **作者署名混乱**：源文件头 `// Created by Bokai Wang` 与 kAir 现风格不符 | hygiene | PR-F1 / PR-F3 | adapt 时统一为 kAir 现有 header 风格（无 author 行） |
| R-8 | **隐含 E2E 加密期待**：保留 `privateKeyData` 字段会让外部期待 V1 已加密 | product | PR-F1 | 字段保留，但 §2 #12 已禁止任何调用；PR-F1 commit 注释里强调"字段保留作占位，V1 不实现加解密" |
| R-9 | **Friends contract 自身 V1 形态变动** | dependency | 任意 PR | §7 前置项；contract 一旦修订需重审本计划 |
| R-10 | **当前主线（Main A/B/C）尚未收口** | scheduling | 任意 PR | §7 前置项；不满足则不开 PR-F1 |

---

## 7. 启动前置条件

**全部 gate ✅ 之前**，本计划保持 dormant。任何项 ❌ 则不允许开 PR-F1。
所有 gate 均为 **merge / ratification-based**——锚定具体 commit / PR / merge SHA，不接受时间条件（"最近 N 天无修订"等）。
PR-F1 reviewer 在开 PR-F1 时**逐项核对**这张表，并把当下确认的 commit / SHA 写进 PR 描述。

### 7.1 已合并 gate（PR-F1 时必须仍在 main，未 revert）

每条都对应已发生的 merge；reviewer 需用 `git log` 确认其仍在 main 历史里。

| ID | Gate | Anchor | 状态（本计划写就时） |
| - | --- | --- | --- |
| MERGE-1 | Feedback runtime **real wiring** merged | `Main A: feedback runtime real wiring in ChatStore.dismissRecommendation` PR #28 (`fc6d9a5`) | ✅ in main |
| SKEL-1 | Capability skeleton merged | `Skel(capability)` PR #26 (`7f194b9`) | ✅ in main |
| SKEL-2 | Telemetry skeleton merged | `Skel(telemetry)` PR #25 (`3aee155`) | ✅ in main |
| SKEL-3 | Feedback runtime skeleton merged | `Skel(feedback-runtime)` PR #24 (`d3a4925`) | ✅ in main |
| CONTRACT-1 | Capability registry & adapter contract v1 ratified | `Capability registry and adapter contract v1 (doc-only)` PR #23 (`db86417`) | ✅ in main |
| CONTRACT-2 | Telemetry contract v1 ratified | `Telemetry contract v1 (doc-only)` PR #20 (`5c546b9`) | ✅ in main |
| CONTRACT-3 | Feedback runtime contract v1 ratified | `Feedback runtime contract v1 (doc-only)` PR #21 (`b05ce67`) | ✅ in main |

### 7.2 未合并 gate（必须在 PR-F1 之前 author + merge）

| ID | Gate | 必须产生的 artifact | 状态 |
| - | --- | --- | --- |
| ADR-1 | SwiftData 持久化策略 ADR merged。须覆盖：哪些 feature 用 SwiftData、Friends 与 Health 的 container 隔离规则、迁移路径。 | `Docs/adr/NNNN-swiftdata-persistence-strategy.md` 或等价 path | ❌ not started |
| INFRA-1 | i18n baseline landed in main：至少一份 `Localizable.strings`（English + 中文）在 main 上有真实生产 call site（不是占位字符串）。 | i18n infra PR + 真实使用 commit | ❌ not started |

### 7.3 录入 gate（PR-F1 开启时锁定快照）

| ID | Gate | PR-F1 reviewer 须做的动作 |
| - | --- | --- |
| SNAPSHOT-1 | 锁定 `Contracts/FriendsAPI/FriendsServiceContract.md` 当前 commit hash 进 PR-F1 描述。如该 hash 与本计划 commit 时的 hash 不同 → 必须重审本计划，先改本文档 §1–§6 再开 PR-F1。 | 在 PR-F1 描述里写：`FriendsServiceContract.md commit at PR-F1 open: <full sha>` |
| REVIEW-1 | 维护者已 comment / approve 本计划 PR（即 doc-only PR）的 §3 / §4 / §5。 | PR-F0 已 merged 即视为达成 |

---

## 附录 A: 词汇表

- **vertical**：一条端到端的产品功能线（Friends / Chat / Health 等都是 vertical）。
- **adapt**：见 §3 顶部。
- **Friends-domain 字段**：仅来自 `FriendsServiceContract.md` 资源表的字段；不包括任何 Health / HealthKit 派生字段。
- **grep 闸**：CI / pre-merge 检查，按字面字符串搜索，命中即 fail。

## 附录 B: 关联文档

- `Contracts/FriendsAPI/FriendsServiceContract.md`
- `Contracts/UX/feedback-runtime-v1.md`
- `Contracts/UX/telemetry-contract-v1.md`
- `Contracts/capability-registry-and-adapter-contract-v1.md`
- `Docs/PRODUCT_CONTRACT.md`（产品不变量；Friends 也必须守）
