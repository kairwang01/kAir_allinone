# Friends Service Contract

目的：

- 预留未来社交功能的服务端边界。
- 明确 Friends 能承载什么，绝对不能承载什么。
- 在 V1 阶段把 Friends 与 Health 做物理与语义隔离。

## V1 立场

- Friends 是可选能力，不得成为本地健康功能的前置依赖。
- Local app 在没有任何 Friends 服务端的情况下必须可用。
- V1 Friends 合同中不得出现 `HealthKit` 原始字段，也不得出现健康派生字段。
- 任何“分享健康给好友”的需求在 V1 一律视为未批准需求，必须另开合同和法律评审。

## Initial resource model

- `User`
- `Friend`
- `Conversation`
- `Participant`
- `Message`
- `Attachment`
- `Presence`
- `Invite`

## Planned endpoint groups

- `/v1/auth/*`
- `/v1/users/*`
- `/v1/friends/*`
- `/v1/conversations/*`
- `/v1/messages/*`
- `/v1/presence/*`
- `/v1/push/*`

## 合规总则

- HealthKit data does not flow into friends features by default.
- Social transport must stay optional in V1.
- Local app must remain usable without any server dependency.
- Friends backend must not receive or infer health data from payload shape, metadata, ranking inputs, or AI context.

## 可能涉及敏感信息的字段

| 资源 | 敏感/高风险字段 | 合规说明 |
| --- | --- | --- |
| `User` | `fullName`, `email`, `phoneNumber`, `avatar`, `dateOfBirth`, `location`, `bio` | 属于个人识别信息；V1 仅保留最小必要身份字段。`dateOfBirth`、精确位置默认不进 Friends 合同。 |
| `Friend` | relationship labels, nicknames, notes, block status | 社交关系本身属于敏感关系图谱；不得扩展成健康关系标签。 |
| `Conversation` | participant list, title, timestamps, unread state | 可暴露社交关系与活跃时间；不得增加“健康主题”“风险等级”等派生标签。 |
| `Participant` | role, join status, mute/block state | 角色不能暗示病情、照护等级或医疗身份，除非未来单独做 caregiver 合同。 |
| `Message` | free-form text, reply context, edits, reactions | 任意消息体都应视为可能含敏感个人内容；不得自动插入健康摘要。 |
| `Attachment` | filenames, previews, OCR text, media metadata | 高风险，可能夹带健康报告或截图；V1 禁止把健康导出物作为 Friends 附件源。 |
| `Presence` | online state, last seen | 只能做粗粒度 presence；不得推断睡眠、运动、恢复状态。 |
| `Invite` | email, phone, contact hash, referral metadata | 仅可用于完成邀请；不得用于增长画像或营销再利用。 |

## 明确禁止进入 Friends 合同的字段

以下字段或等价语义字段不得出现在任何 request / response / event / analytics schema 中：

- `healthData`
- `healthSummary`
- `healthSignals`
- `healthRiskLabel`
- `diagnosis`
- `condition`
- `symptom`
- `medication`
- `heartRate`
- `sleepAnalysis`
- `ecg`
- `biologicalSex`
- `dateOfBirth`（作为健康或年龄推断用途）
- `medicalNote`
- `healthPrompt`
- `healthEmbedding`
- `modelHealthOutput`

## 哪些行为需要用户明确同意

以下行为必须获得明确、可撤回、可解释的用户同意，不能用模糊文案或默认勾选替代：

- 创建 Friends 账户并上传资料。
- 上传或匹配通讯录联系人。
- 发送好友邀请。
- 发送消息或附件。
- 开启 push 通知并接收社交提醒。
- 把任何内容从本地导出到 Friends 服务端。
- 任何把用户内容送入第三方 AI、第三方审核、第三方分析服务的处理。
- 开启账号同步、跨设备恢复、长期保留策略。

## 不需要模糊“总同意”覆盖的场景

以下场景不能依赖“注册即视为同意”一次性覆盖：

- 通讯录发现
- 附件上传
- 导出/分享
- 第三方处理
- 未来任何健康相关分享

## Friends 与健康功能的隔离要求

- Friends 数据库、缓存、搜索索引、消息队列不得复用 Health 数据存储。
- Friends 推荐、排序、presence、通知不得使用健康数据或健康派生信号。
- Health 页面不得提供“直接发给好友”的快捷通道。
- Chat / Friends AI 助手不得读取 Health 上下文，除非未来另立合同并重新评审。

## 服务端最低约束

- 所有 Friends 流量必须只承载社交数据，不承载健康数据。
- 服务端日志、监控、重试队列不得记录消息正文之外的额外健康标签。
- 数据保留期、删除流程、账号删除入口必须在隐私政策中说明。
- 如果 Friends 支持账户创建，产品上线前必须补齐应用内账号删除路径。
- 如果 Friends 允许用户生成内容，必须满足 Apple 对 UGC 的最低要求：可举报、可屏蔽、可处理不良内容、可联系平台。

## 产品与服务端都不能做的事

- 不能把 HealthKit 数据或健康摘要塞进消息附件、快捷回复、推荐文案。
- 不能基于健康状态做好友推荐、排序或通知。
- 不能把邀请码、联系人哈希、消息内容用于广告定向或外部增长投放。
- 不能默认开启联系人上传、自动邀请、自动同步。
- 不能把“未来照护者/好友分享”与当前 Friends 合同混在一起发布。

## V1 通过标准

只有满足以下条件，Friends 才能进入 V1 发布讨论：

- 所有 schema 均不含健康字段或健康派生字段。
- 所有上传型行为都有明确同意点。
- 本地健康功能在断网、无账号、无好友服务时仍完整可用。
- 如果消息/UGC 上线，举报、屏蔽、删除、联系渠道同步上线。

## 参考依据

- [App Review Guidelines | Apple Developer](https://developer.apple.com/app-store/review/guidelines/)
- [Protecting user privacy | Apple Developer](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)
