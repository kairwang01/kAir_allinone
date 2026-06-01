# kAir

**Chat-first, AI-first iOS super-app.** Say what you need → Odera figures out the right thing to do → tap to confirm → results flow back into the conversation. All on your iPhone.

[![Status](https://img.shields.io/badge/status-pre--release-orange)](#project-status)
[![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)](https://www.swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-orange)](https://developer.apple.com/xcode/swiftui/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

🌐 **Languages:** [English](#english) · [中文](#中文)

> **Companion repository:** [`kAir-models`](https://github.com/kairwang01/kAir-models) — the on-device tool-routing model subsystem (Qwen3.5-0.8B, LoRA on Apple Silicon, three-layer artifact pipeline).

---

<a id="english"></a>

## English

### What is kAir

kAir is a chat-first iOS super-app powered by a fine-tuned on-device language model. You speak naturally; Odera understands your intent and connects you to the right feature — music, messaging, navigation, web search, or a direct answer. The chat is always the main stage: every action and result appears right inside the conversation, with no pop-ups or context switches to break your flow.

The product north star: **one minute, one tap, one thing done.**

```
"play something for studying"
        │
        ▼
Odera on your iPhone (Qwen3.5-0.8B, LoRA-tuned)
        │
        ▼
  { tool: "music.search_play",
    args: { mood: "study", play_now: true } }
        │
        ▼
iOS ──► system music app
        │
        ▼
result returns to your conversation
```

### Architecture

kAir is split into two cleanly separated subsystems with a versioned contract between them.

```
┌────────────────────────────────────────────────────────────┐
│  kAir  (this repo) — Swift / SwiftUI                       │
│                                                            │
│  ┌─────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │ Chat UI       │  │ Recommendations │  │ Feature        │ │
│  │ conversation  │  │ cards (Layer-4) │  │ registry +     │ │
│  │               │  │                 │  │ adapters       │ │
│  │               │  │                 │  │                │ │
│  └─────────────┘  └──────────────────┘  └────────────────┘ │
│                                                            │
│  ┌─────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │ Telemetry   │  │ Feedback         │  │ HealthKit /    │ │
│  │ (no-op-able │  │ runtime          │  │ Core ML        │ │
│  │ emitter)    │  │ (✕, ⋯ menu)      │  │ services       │ │
│  └─────────────┘  └──────────────────┘  └────────────────┘ │
└──────────────────────────────┬─────────────────────────────┘
                               │
                  router_sample.schema.json (v1, frozen)
                               │
┌──────────────────────────────┴─────────────────────────────┐
│  kAir-models  (sibling repo) — Python / MLX-LM             │
│                                                            │
│  Qwen3.5-0.8B base + LoRA adapter                          │
│  → fused safetensors                                       │
│  → quantized GGUF                                          │
│  → Core ML  (.mlpackage) for iOS                           │
└────────────────────────────────────────────────────────────┘
```

### Engineering Approach

1. **Contract-first.** Every cross-subsystem touchpoint exists as a versioned markdown / YAML / JSON contract before any code is written. See [`Contracts/`](Contracts/):
   - `capability-registry-and-adapter-contract-v1.md`
   - `telemetry-contract-v1.md`
   - `Design/`, `UX/`, `AIProviders/`, `FriendsAPI/`
2. **PR-disciplined commits.** Each commit maps to one PR with a typed prefix:
   `Skel(...)` for scaffolding, `Hygiene:` for refactor-only, `I1 / I2 / I3` for implementation iterations, `V1 / V2 / V3` for visual contract revisions, `doc-only` for contract changes that don't touch code.
3. **12-agent development workflow.** kAir is built using a custom Claude Code orchestration template (`Docs/AGENTS/`, `Docs/ORCHESTRATOR.md`) that splits an iOS app build into 12 specialized agents (architecture / state / assets / services / AI layer / UI / QA / demo) running in parallel where dependencies allow. The template is project-agnostic — only `PROJECT_BRIEF.md` and `PRODUCT_CONTRACT.md` need to be filled in to retarget it.

### Project Status

This repository is the **engineering foundation** for kAir, not a shipping product. Architecture and contracts are in place; features are being filled in.

| Area | Status |
| --- | --- |
| Feature registry + adapter contract v1 | ✅ Landed (#23) |
| Telemetry contract v1 + no-op emitter | ✅ Landed (#20, #25) |
| Feedback runtime contract v1 + tests | ✅ Landed (#21, #24) |
| Chat conversation blocks | ✅ Landed (#10, #13) |
| Recommendation cards + ActionCardShell | ✅ Landed (#14, #15, #16) |
| Negative-feedback affordance (✕, ⋯ menu) | ✅ Landed (#17, #19) |
| Feature surface consolidation | ✅ Landed (#27) |
| Three feature stubs | ✅ Landed (#26) |
| Real provider integrations | ⏳ In progress |
| End-to-end demo flow | ⏳ Pre-release |
| App Store / TestFlight build | ⏳ Not yet |

### Tech Stack

| Layer | Technology |
| --- | --- |
| Language | Swift 5.9 |
| UI | SwiftUI |
| Concurrency | `async / await`, `@Observable` (iOS 17 Observation framework) |
| Health data | HealthKit |
| On-device AI | Core ML + llama.cpp (planned) |
| Intent model | Qwen3.5-0.8B + LoRA — see [`kAir-models`](https://github.com/kairwang01/kAir-models) |
| Tooling | Xcode 15+, Swift Package Manager |
| Min target | iOS 17.0 |

### Repository Layout

```
.
├── kAir/                   App source (Swift / SwiftUI)
│   ├── App/                Entry points, scene wiring
│   ├── Core/               Feature registry, telemetry
│   ├── DesignSystem/       Tokens, components, theming
│   ├── Features/           Friends, Store, Health, ...
│   ├── OnDeviceModels/     CoreML / on-device inference
│   ├── Shared/             Cross-feature utilities
│   └── Spaces/             Scene compositions
├── kAirTests/              Contract + behavior tests
├── Contracts/              Versioned subsystem contracts (markdown)
├── Docs/                   Project brief, product contract, orchestrator
│   └── AGENTS/             12-agent Claude Code workflow templates
├── kAir.xcodeproj/         Xcode project
├── kAir.entitlements
├── LICENSE                 MIT
└── README.md
```

### Author

**Kair Wang** ([@kairwang01](https://github.com/kairwang01))

---

<a id="中文"></a>

## 中文

### 什么是 kAir

kAir 是一款以聊天为中心的 iOS 超级应用：你每说一句话，手机上经过微调的 AI 模型会自动判断你需要什么（音乐 / 消息 / 导航 / 网页搜索 / 直接回答），然后帮你实际执行。聊天界面始终是主舞台——所有操作和结果都在对话里自然呈现，不会跳出弹窗或切换场景打断你。

产品目标：**一分钟，点一下，搞定一件事**。

```
"放点学习用的音乐"
        │
        ▼
端侧 router 模型（Qwen3.5-0.8B + LoRA 微调）
        │
        ▼
  { tool: "music.search_play",
    args: { mood: "study", play_now: true } }
        │
        ▼
iOS surface adapter ──► 系统音乐应用
        │
        ▼
执行结果回流到聊天 transcript
```

### 系统架构

kAir 由两个边界清晰的子系统组成，中间用版本化契约连接。

```
┌────────────────────────────────────────────────────────────┐
│  kAir  (本仓库)  Swift / SwiftUI                           │
│                                                            │
│  ┌─────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │ 聊天界面    │  │ 推荐卡片流      │  │ 功能注册表 +   │ │
│  │ 对话记录    │  │ (Layer-4)        │  │ 各功能界面     │ │
│  └─────────────┘  └──────────────────┘  └────────────────┘ │
│                                                            │
│  ┌─────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │ 遥测        │  │ 反馈系统         │  │ HealthKit /    │ │
│  │（可关闭）   │  │（✕、⋯ 菜单）    │  │ Core ML 服务   │ │
│  └─────────────┘  └──────────────────┘  └────────────────┘ │
└──────────────────────────────┬─────────────────────────────┘
                               │
                  router_sample.schema.json (v1, frozen)
                               │
┌──────────────────────────────┴─────────────────────────────┐
│  kAir-models  (兄弟仓库)  Python / MLX-LM                  │
│                                                            │
│  Qwen3.5-0.8B 基座 + LoRA adapter                          │
│  → fused safetensors                                       │
│  → 量化 GGUF                                               │
│  → iOS Core ML  (.mlpackage)                               │
└────────────────────────────────────────────────────────────┘
```

### 工程方法论

1. **契约先行**：跨子系统的接触点都先有版本化的 markdown / YAML / JSON 契约，再写代码。详见 [`Contracts/`](Contracts/)：
   - `capability-registry-and-adapter-contract-v1.md`
   - `telemetry-contract-v1.md`
   - `Design/`、`UX/`、`AIProviders/`、`FriendsAPI/`
2. **严格的 PR 提交规范**：每个 commit 对应一个 PR，前缀有明确分类：
   `Skel(...)` 搭骨架、`Hygiene:` 纯重构、`I1 / I2 / I3` 实现迭代、`V1 / V2 / V3` 视觉契约修订、`doc-only` 只改契约不动代码。
3. **12-agent 开发流水线**：kAir 用自定义的 Claude Code 编排模板搭建（`Docs/AGENTS/`、`Docs/ORCHESTRATOR.md`），把一个完整 iOS app 的开发拆成 12 个职责分明的 agent（架构 / 状态 / 资产 / 服务 / AI 层 / UI / QA / Demo），在依赖允许的地方并行执行。模板本身与项目无关——只要把 `PROJECT_BRIEF.md` 和 `PRODUCT_CONTRACT.md` 填好，就能套用到任何新的 iOS 项目。

### 项目状态

本仓库是 kAir 的**工程基底**，不是已上线的产品。架构和契约已经落地，各功能模块还在逐步填充。

| 领域 | 状态 |
| --- | --- |
| 功能注册表 + adapter 契约 v1 | ✅ 已落地 (#23) |
| 遥测契约 v1 + no-op emitter | ✅ 已落地 (#20, #25) |
| 反馈系统契约 v1 + 测试 | ✅ 已落地 (#21, #24) |
| 聊天连续对话记录 | ✅ 已落地 (#10, #13) |
| 推荐卡片流 + ActionCardShell | ✅ 已落地 (#14, #15, #16) |
| 负反馈交互（✕、⋯ 菜单） | ✅ 已落地 (#17, #19) |
| 功能界面整合 | ✅ 已落地 (#27) |
| 3 个功能 placeholder | ✅ 已落地 (#26) |
| 真实服务商接入 | ⏳ 进行中 |
| 端到端演示流程 | ⏳ 预发布 |
| App Store / TestFlight 构建 | ⏳ 暂未启动 |

### 技术栈

| 层 | 技术 |
| --- | --- |
| 语言 | Swift 5.9 |
| UI | SwiftUI |
| 并发 | `async / await`、`@Observable`（iOS 17 Observation 框架） |
| 健康数据 | HealthKit |
| 端侧 AI 推理 | Core ML + llama.cpp（计划中） |
| 意图路由模型 | Qwen3.5-0.8B + LoRA，见 [`kAir-models`](https://github.com/kairwang01/kAir-models) |
| 工具链 | Xcode 15+、Swift Package Manager |
| 最低支持 | iOS 17.0 |

### 仓库结构

```
.
├── kAir/                   App 源码（Swift / SwiftUI）
│   ├── App/                入口、场景装配
│   ├── Core/               功能类型、注册表、遥测
│   ├── DesignSystem/       Token、组件、主题
│   ├── Features/           Friends、Store、Health Dashboard 等
│   ├── OnDeviceModels/     CoreML / 端侧推理胶水代码
│   ├── Shared/             跨功能工具
│   └── Spaces/             场景组合
├── kAirTests/              契约 + 行为测试
├── Contracts/              版本化子系统契约（markdown）
├── Docs/                   项目简介、产品契约、编排器
│   └── AGENTS/             12-agent Claude Code 工作流模板
├── kAir.xcodeproj/         Xcode 工程
├── kAir.entitlements
├── LICENSE                 MIT
└── README.md
```

### 作者

**Kair Wang** ([@kairwang01](https://github.com/kairwang01))
