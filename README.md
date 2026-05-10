# kAir

**Chat-first, AI-first iOS super-app.** Ask once → on-device router picks the right tool → tap to execute → result flows back into the conversation.

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

kAir is a chat-first iOS super-app where every user utterance is routed by a fine-tuned on-device LLM to one of a closed catalog of capabilities (music, messaging, navigation, web search, direct answer). The chat surface stays in control: actions and results render as part of the transcript, never as a separate modal flow that the user has to context-switch into.

The product north star is one minute, one tap:

```
"play something for studying"
        │
        ▼
on-device router (Qwen3.5-0.8B, LoRA-tuned)
        │
        ▼
  { tool: "music.search_play",
    args: { mood: "study", play_now: true } }
        │
        ▼
surface adapter (iOS) ──► system music app
        │
        ▼
result re-renders into the chat transcript
```

### Architecture

kAir is split into two cleanly separated subsystems with a versioned contract between them.

```
┌────────────────────────────────────────────────────────────┐
│  kAir  (this repo) — Swift / SwiftUI                       │
│                                                            │
│  ┌─────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │ Chat shell  │  │ Recommendation   │  │ Capability     │ │
│  │ transcript  │  │ rail / cards     │  │ registry +     │ │
│  │ blocks      │  │ (Layer-4)        │  │ surface        │ │
│  │             │  │                  │  │ adapters       │ │
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
3. **12-agent development workflow.** kAir is being built using a custom Claude Code orchestration template (`Docs/AGENTS/`, `Docs/ORCHESTRATOR.md`) that splits an iOS app build into 12 specialized agents (architecture / state / assets / services / AI layer / UI clusters / QA / demo) running in parallel where dependencies allow. The template itself is project-agnostic — only `PROJECT_BRIEF.md` and `PRODUCT_CONTRACT.md` need to be filled in to retarget it to a different app.

### Project Status

This repository is the **engineering substrate** for kAir, not a shipping product. Architecture and contracts are landed; feature surfaces are still being filled in.

| Area | Status |
| --- | --- |
| Capability registry + adapter contract v1 | ✅ Landed (#23) |
| Telemetry contract v1 + no-op emitter | ✅ Landed (#20, #25) |
| Feedback runtime contract v1 + tests | ✅ Landed (#21, #24) |
| Chat continuation transcript blocks | ✅ Landed (#10, #13) |
| Recommendation rail + ActionCardShell | ✅ Landed (#14, #15, #16) |
| Negative-feedback affordance (✕, ⋯ menu) | ✅ Landed (#17, #19) |
| Surface kind consolidation | ✅ Landed (#27) |
| Three shipped capability stubs | ✅ Landed (#26) |
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
| On-device ML inference | Core ML + llama.cpp (planned) |
| Routing model | Qwen3.5-0.8B + LoRA — see [`kAir-models`](https://github.com/kairwang01/kAir-models) |
| Tooling | Xcode 15+, Swift Package Manager |
| Min target | iOS 17.0 |

### Repository Layout

```
.
├── kAir/                   App source (Swift / SwiftUI)
│   ├── App/                Entry points, scene wiring
│   ├── Core/               Surface kinds, capability registry, telemetry
│   ├── DesignSystem/       Tokens, components, theming
│   ├── Features/           Friends, Store, Health Dashboard, ...
│   ├── OnDeviceModels/     CoreML / on-device inference glue
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

kAir 是一款 chat-first 的 iOS super-app：用户每说一句话，端侧 LoRA 微调后的小模型把它路由到一个**封闭的能力目录**（音乐 / 消息 / 导航 / 网页搜索 / 直接回答），然后由 surface adapter 真正执行。聊天界面始终是主舞台——动作和结果都作为 transcript 的一部分渲染，不会跳出到独立的弹窗或新场景里打断对话。

产品北极星：**一分钟，一次点击**。

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
│  │ 聊天 shell  │  │ 推荐 rail / 卡片 │  │ 能力注册表 +   │ │
│  │ transcript  │  │ (Layer-4)        │  │ surface        │ │
│  │ blocks      │  │                  │  │ adapter        │ │
│  └─────────────┘  └──────────────────┘  └────────────────┘ │
│                                                            │
│  ┌─────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │ Telemetry   │  │ 反馈 runtime     │  │ HealthKit /    │ │
│  │（可关 emit  │  │（✕、⋯ 菜单）     │  │ Core ML 服务   │ │
│  │ 的 emitter) │  │                  │  │                │ │
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
2. **PR 纪律化的提交**：每个 commit 对应一个 PR，前缀有严格分类：
   `Skel(...)` 搭骨架、`Hygiene:` 仅重构、`I1 / I2 / I3` 实现迭代、`V1 / V2 / V3` 视觉契约修订、`doc-only` 仅改契约不动代码。
3. **12-agent 开发流水线**：kAir 是用我自定义的 Claude Code 编排模板搭建的（`Docs/AGENTS/`、`Docs/ORCHESTRATOR.md`），把一个完整 iOS app 的开发拆成 12 个职责明确的 agent（架构 / 状态 / 资产 / 服务 / AI 层 / UI 集群 / QA / Demo），在依赖允许的地方并行执行。模板本身是项目无关的——只要把 `PROJECT_BRIEF.md` 和 `PRODUCT_CONTRACT.md` 填好，就可以套到任何新的 iOS 项目。

### 项目状态

本仓库是 kAir 的**工程基底**，不是已上线的产品。架构和契约已经落地，业务表面还在逐个填充。

| 领域 | 状态 |
| --- | --- |
| Capability 注册表 + adapter 契约 v1 | ✅ 已落地 (#23) |
| Telemetry 契约 v1 + no-op emitter | ✅ 已落地 (#20, #25) |
| Feedback runtime 契约 v1 + 测试 | ✅ 已落地 (#21, #24) |
| 聊天连续 transcript blocks | ✅ 已落地 (#10, #13) |
| 推荐 rail + ActionCardShell | ✅ 已落地 (#14, #15, #16) |
| 负反馈交互（✕、⋯ 菜单） | ✅ 已落地 (#17, #19) |
| Surface kind 整合 | ✅ 已落地 (#27) |
| 3 个上线版 capability stub | ✅ 已落地 (#26) |
| 真实 provider 接入 | ⏳ 进行中 |
| 端到端 demo 流程 | ⏳ 预发布 |
| App Store / TestFlight 构建 | ⏳ 暂未启动 |

### 技术栈

| 层 | 技术 |
| --- | --- |
| 语言 | Swift 5.9 |
| UI | SwiftUI |
| 并发 | `async / await`、`@Observable`（iOS 17 Observation 框架） |
| 健康数据 | HealthKit |
| 端侧 ML 推理 | Core ML + llama.cpp（计划中） |
| Routing 模型 | Qwen3.5-0.8B + LoRA，见 [`kAir-models`](https://github.com/kairwang01/kAir-models) |
| 工具链 | Xcode 15+、Swift Package Manager |
| 最低支持 | iOS 17.0 |

### 仓库结构

```
.
├── kAir/                   App 源码（Swift / SwiftUI）
│   ├── App/                入口、Scene 装配
│   ├── Core/               Surface kind、能力注册表、telemetry
│   ├── DesignSystem/       Token、组件、主题
│   ├── Features/           Friends、Store、Health Dashboard 等
│   ├── OnDeviceModels/     CoreML / 端侧推理胶水代码
│   ├── Shared/             跨 feature 工具
│   └── Spaces/             Scene 组合
├── kAirTests/              契约 + 行为测试
├── Contracts/              版本化子系统契约（markdown）
├── Docs/                   项目 brief、产品契约、orchestrator
│   └── AGENTS/             12-agent Claude Code 工作流模板
├── kAir.xcodeproj/         Xcode 工程
├── kAir.entitlements
├── LICENSE                 MIT
└── README.md
```

### 作者

**Kair Wang** ([@kairwang01](https://github.com/kairwang01))
