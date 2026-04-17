# PrivacyGuard Policy

最后核对日期：2026-04-16  
适用范围：Kair Health iOS App V1

## 目的

`PrivacyGuard` 是 V1 的硬边界，不是建议清单。凡是会触碰 HealthKit、本地模型、好友传输、导出/分享的路径，都应先过这一层规则。

V1 的默认立场：

- Health 数据默认仅留在设备本地。
- 健康分析默认仅使用本地模型。
- Friends 功能默认不得接触任何 HealthKit 原始或派生数据。
- 任何导出都必须是用户主动触发；任何离开设备的健康内容默认阻断。

## 1. Health 数据访问边界

### 允许

- 为明确的健康/健身功能请求 `HealthKit` 读取权限。
- 仅按“最小必要范围”请求数据类型。
- 在功能发生点附近做 just-in-time 权限请求。
- 在本地生成趋势摘要、解释和覆盖率提示。

### 必须满足

- 读取目的必须在 UI、权限文案、App Store 文案中都说得清楚。
- 请求的数据类型必须与当前功能直接对应，不能因为“以后可能会用到”就先拿全量权限。
- 缺失数据只能解释为 `unknown` / `not available`，不能解释为“用户拒绝了”或“用户没有该健康信号”。
- 原始 HealthKit 数据、派生健康摘要、健康 embeddings、健康风险标签，都按“健康数据”同级处理。

### 禁止

- 为通用聊天、社交推荐、增长实验、广告、画像而读取 HealthKit。
- 把“用户没授权某项读取”当作产品可观察信号。
- 把 HealthKit 数据混入调试日志、第三方分析、崩溃上报、埋点属性。
- 把 app 管理的个人健康信息放进 iCloud、CloudKit、iCloud Drive 或可云备份目录。

## 2. 本地模式边界

### V1 默认

- 健康分析只允许走本地模型路径。
- 通用聊天模型与健康分析模型必须在职责上隔离。
- 模型记忆、聊天上下文、健康数据缓存必须分库存放，不能共用一份“全局记忆”。

### 禁止

- 将 HealthKit 数据、健康摘要、健康 prompts、健康 embeddings、风险分级发送到远端模型或第三方 AI 服务。
- 把健康信号用于推送排序、好友推荐、增长分层、广告定向或营销归因。
- 把“local-only”写成营销话术，但实际仍把健康上下文发到远端服务。

### 模型输出边界

- 可以做：本地趋势总结、覆盖率说明、变化解释、建议用户关注或补充数据。
- 不可以做：诊断、治疗指令、药物建议、急诊分诊结论、未经验证的准确性宣称。
- 必须显示：这是本地信息性输出，不是诊断；如果数据覆盖不足或置信度不足，必须显式提示限制。

## 3. 好友功能与健康功能隔离

### V1 硬规则

- Friends API 不得接收任何 `HealthKit` 原始数据。
- Friends API 不得接收任何健康派生结果，包括：
  - 健康摘要
  - 风险标签
  - 诊断样式文案
  - 健康 prompts / embeddings
  - 由健康上下文驱动的推荐文本
- Friends 服务端不得根据健康数据做匹配、推荐、排序、presence、通知触发。

### 允许

- 用户手动输入的非健康社交内容。
- 与健康无关的资料、好友关系、邀请、聊天元数据。

### 未来如果要做“分享给好友/照护者”

V1 一律不做。未来若要支持，必须单开法律评审并至少补齐：

- 单独的产品目的说明
- 单独的显式同意流
- 单独的数据模型与服务合同
- 单独的撤回与删除机制
- 单独的上架审查说明

## 4. 导出 / 分享前提

### V1 默认

- 用户可以在本地准备导出内容。
- 任何离开设备的健康内容默认阻断，直到单独法律评审放行。

### 任何导出都必须满足

- 由用户主动点击触发，不允许后台自动导出。
- 导出前必须预览：
  - 包含哪些数据类别
  - 时间范围
  - 是否含模型生成说明
- 默认最小化导出内容；不应默认带上 DOB、biological sex、原始 ECG、完整聊天记录。

### 明确禁止

- 一键把健康摘要发到 Friends 聊天。
- 后台自动同步健康报告到服务器。
- 生成公开链接分享健康内容。
- 用“分享”名义把健康数据送入任何非健康服务型第三方。

## 5. Release-blocking 触发器

发现以下任一情况，V1 应直接停止发布：

- HealthKit 数据或健康派生内容进入 Friends API。
- 健康上下文进入远端模型、第三方 AI、第三方 analytics、第三方 crash payload。
- 健康内容进入 iCloud 或其他云备份路径。
- 任何文案声称诊断、治疗、医学准确率，但没有验证依据或监管依据。
- 导出/分享路径允许后台自动运行，或没有用户预览与确认。

## 官方依据

以下为本文件采用的主要 Apple 官方依据：

- [Protecting user privacy | Apple Developer](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)
- [App Review Guidelines | Apple Developer](https://developer.apple.com/app-store/review/guidelines/)
- [HealthKit | Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/healthkit)
