# V1 Compliance Guardrails

最后核对日期：2026-04-16

这份文档给产品、工程、设计同一套 V1 发布边界。规则按保守口径写，目的不是“尽量通过”，而是“先别走错”。

## 什么能做

- 在设备本地读取用户明确授权的 `HealthKit` 数据，用于清晰说明的健康/健身功能。
- 在设备本地运行模型，对健康趋势做解释、总结、覆盖率提示。
- 用非诊断文案表达健康变化，例如“需要关注”“建议复查”“数据不足”。
- 让用户手动使用 Friends 的非健康社交能力，例如资料、邀请、普通聊天。
- 在本地准备导出内容，并在导出前给用户做数据范围预览。

## 什么不能做

- 不能把 `HealthKit` 原始数据、健康摘要、风险标签、健康 prompts / embeddings 发到 Friends 服务端。
- 不能把健康上下文发到远端模型、第三方 AI、第三方 analytics、第三方广告或增长工具。
- 不能把健康数据用于广告、营销、增长实验、好友推荐、消息排序、push 定向。
- 不能把个人健康信息放进 iCloud、CloudKit、iCloud Drive 或其他云备份路径。
- 不能把模型输出写成诊断、治疗、药物建议、医学准确率结论。
- 不能因为拿不到某项 HealthKit 数据，就推断用户拒绝授权或用户状态异常。
- 不能在 V1 上线任何“分享健康给好友”的直连功能。

## 模型输出免责声明边界

- 必须有：本地信息性输出、不是诊断、不能替代医生判断。
- 必须有：当数据覆盖不全、时间窗口不足、信号冲突时，明确说出限制。
- 不得有：疾病诊断语气、治疗方案、药物调整建议、紧急医疗判断。
- 不得有：未经验证的方法学、准确率、医学效能宣称。

## 社交分享边界

- V1 的 Friends 只处理社交数据，不处理健康数据。
- 任何健康导出都不能直接进入 Friends 聊天、动态、附件、链接卡片。
- 如果未来要做照护者/好友分享，需要单独产品定义、单独合同、单独法律评审，不得借当前 Friends 合同“顺带上线”。

## 上线前必须检查什么

### 权限与文案

- `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` 已配置，且文案准确说明用途。
- Health 权限请求是 just-in-time，不是首启无差别全量索取。
- App Store 文案、应用内文案、权限说明对 Health 数据用途保持一致。

### 数据边界

- 健康数据不进入远端模型、Friends API、第三方分析、第三方 crash payload。
- 健康文件、缓存、报告均被排除出 iCloud / 云备份路径。
- 健康存储、社交存储、模型记忆彼此隔离。

### 产品行为

- 没有后台自动导出、自动分享、自动邀请、自动联系人上传。
- 所有上传型行为都有明确的用户动作和明确的取消路径。
- 若 Friends 上线 UGC，举报、屏蔽、平台联系方式同步上线。
- 若 Friends 支持账号创建，应用内账号删除同步上线。

### 内容与上架

- 所有健康输出都带有限制性表达，不做诊断或治疗承诺。
- 没有未经验证的健康测量或准确率宣传。
- App Privacy 营养标签、隐私政策、删除/撤回说明与真实实现一致。
- App Review Notes 已说明：
  - 健康分析为本地优先
  - Friends 与 Health 分离
  - V1 不做健康社交分享

## Stop-ship 条件

出现以下任一项，直接停止发布：

- 健康数据或健康派生内容进入 Friends payload。
- 健康上下文进入任何远端 AI 或第三方处理器。
- 健康内容进入云备份。
- 健康输出缺少“非诊断”限制，或存在医疗宣称。
- 实际数据流与隐私政策、App Privacy 披露不一致。

## 参考依据

- [App Review Guidelines | Apple Developer](https://developer.apple.com/app-store/review/guidelines/)
- [Protecting user privacy | Apple Developer](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)
- [HealthKit | Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/healthkit)
