# Phase 1 Super Kernel Design Specifications v3

## 1. Screen Inventory v3
以下是 Phase 1 唯一允许存在的界面资产。设计中不得新增“临时页面”。

| 名称 | 层级 | 容器形式 | 进入条件 | 退出条件 | 回流类型 | 后台状态 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Chat Input** | L1 | Fixed Bottom | App 启动默认载入 | 全局常驻 | N/A | N/A |
| **Recommended Next** | L2 | Inline Chip Row | 意图解析后 / 回流后 | 折叠 / 替换 / 降级 | N/A | 否 |
| **Location Card** | L3 | Card | 地点候选生成 | dismiss / 新会话替换 | N/A | 否 |
| **Route Card** | L3 | Card | 路线候选生成 | dismiss / 开始导航 | N/A | 否 |
| **Song / Playlist Card** | L3 | Card | 音乐候选生成 | dismiss / 播放 | N/A | 否 |
| **Answer / Search Card**| L3 | Card | 回答或网页结果生成 | dismiss / 阅读原文 | N/A | 否 |
| **Tool Card** | L3 | Live Card | 工具指令触发 | 关闭 / 完成 | N/A | 是 |
| **Service Card** | L3 | Card | 服务候选生成 | dismiss / 确认进入 | N/A | 否 |
| **Detail Sheet** | L4 | Bottom Sheet | 点卡片主 CTA | 下拉关闭 / 升级全屏 | 弱回流 | 视对象而定 |
| **Navigation Surface** | L4 | Full-screen Modal| 开始导航 | 到达 / 退出 | 强回流 | 否 |
| **Reader Surface** | L4 | Full-screen Modal| 阅读原文 / 深挖 | 返回 / 关闭 | 弱回流 | 否 |
| **Full-screen Player** | L4 | Full-screen Modal| 点击 Mini Player / 封面| 下拉关闭 | 弱回流 | 是 |
| **Mini Player** | L4 | Floating Inline | 音乐播放中退出全屏 | 停止播放 / 划走 | N/A | 是 |
| **Live Tool Surface** | L3/L4| Live Card / Optional Sheet | 倒计时等工具运行 | 完成 / 手动关闭 | 强回流或 N/A| 是 |

## 2. Global Shell Spec v3
### 2.1 全局空间关系
*   **底部固定控制台**：Chat Input (L1) + Recommended Next (L2)。
*   **中部滚动内容层**：Action Cards Feed (L3)，承载结构化对象。
*   **顶层执行层**：Sheet / Full-screen / Mini Player (L4)，承载沉浸执行。

### 2.2 滚动关系
*   **Feed 垂直滚动**：从底部控制台下方穿过，层级明确分离。
*   **Chat Input**：永远固定在底部。
*   **Recommended Next**：默认展示 1–3 个可见项，超出部分横向滚动。在以下场景折叠为单行或小状态点（不允许完全消失，保留“系统还有下一步建议”的存在感）：
    *   键盘弹起
    *   用户连续上滑浏览历史
    *   执行层打开

### 2.3 Modal 规则
*   全局最多 1 个主执行容器。
*   不允许 Sheet 上再叠第二个 Sheet。
*   **Sheet 的 Detents 规则**：
    *   Peek：约 40–50%
    *   Detail：约 75–85%
    *   Takeover：全屏接管
*   只有满足“需要深度阅读 / 导航 / 沉浸播放 / 长表单确认”时，才允许从 Sheet 升级为全屏 Full-screen Modal。

### 2.4 回流规则
*   **强回流**：任务自然结束，系统自动收起执行层，并直接给出下一步推荐。
*   **弱回流**：用户主动退出，保留上下文；若后台仍运行，则保留 Mini Player 或 Live Card。

---

## 3. Unified Action Card Spec v3
每张卡片（L3）必须且只能表达一个对象或一个决策单元，且必须统一遵循以下结构，不允许各业务线单独起体系。

### 3.1 统一结构
1.  **Header**
    *   来源 icon / 来源名
    *   状态标签（Live / Updated / Expired / Completed）
    *   右上角显式菜单入口 (`···`)
2.  **Main Content**
    *   主标题
    *   核心数字或结论
    *   1 个最关键判断
3.  **Sub Content**
    *   摘要
    *   标签
    *   辅助信息
4.  **Action Area**
    *   **主 CTA**：唯一高亮，必须是立即推进任务的动作。
    *   **次 CTA**：弱化，不超过 2 个按钮并列，只能是辅助动作。
5.  **Feedback / Utility (仅出现在显式菜单或次 CTA)**
    *   Dismiss / Not Interested / Now Not Needed
    *   Save / Share 这类低优先级动作只能进菜单或次 CTA，不得抢主操作。

### 3.2 8 类卡片模板列表
1.  Location Card
2.  Route Card
3.  Song / Playlist Card
4.  Video Card
5.  Search Result Card
6.  Answer Card
7.  Tool Card
8.  Service Card

---

## 4. Feedback Spec v3
全局使用统一的负反馈机制，禁止只使用手势作为唯一入口，每个 Chip 和 Card 必须有可见的显式入口。

### 4.1 Dismiss
*   **触发**：横滑（加速器）或显式菜单首层。
*   **UI**：卡片/Chip 向侧边移出并淡出。
*   **系统**：当前对象降权，候补项补位。
*   **支持撤销**：3 秒内可撤销。

### 4.2 Not Interested
*   **触发**：显式菜单首层可见。
*   **UI**：显示“减少此类推荐”。
*   **系统**：对该类对象或该实体显著降权。
*   **支持撤销**：本轮会话内可撤销。

### 4.3 Now Not Needed
*   **触发**：显式菜单首层可见。
*   **UI**：显示“当前不需要”。
*   **系统**：仅在当前情境暂时隐藏，不长期降权。
*   **支持撤销**：本轮会话内可撤销。

### 4.4 反馈入口位置
*   **Card**：右上角 `···`
*   **Chip**：长按可选，但必须另有显式入口（例如末尾 utility chip 或 card menu）。
*   Swipe 仅为快捷方式，不作为唯一入口。

---

## 5. State Matrix v3
每个组件必须覆盖以下状态，UI 设计需明确，不得交由工程兜底。

| 组件 | Default | Focused | Loading | Empty | Error | Stale | Active | Completed | Dismissed | Background |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Chat Input | ✅ | ✅ | ✅ | ✅ | ✅ | - | ✅ | - | - | - |
| Recommended Next | ✅ | ✅ | ✅ | ✅ | - | - | ✅ | - | ✅ | - |
| Location Card | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | - | ✅ | - |
| Route Card | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | - |
| Song / Playlist Card| ✅ | ✅ | ✅ | ✅ | ✅ | - | ✅ | - | ✅ | - |
| Answer / Search Card| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | - | ✅ | - |
| Tool Card | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Service Card | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | - | ✅ | - |
| Detail Sheet | ✅ | - | ✅ | ✅ | ✅ | - | ✅ | - | ✅ | - |
| Full-screen Modal | ✅ | - | ✅ | ✅ | ✅ | - | ✅ | - | ✅ | ✅ |
| Mini Player | ✅ | ✅ | ✅ | ✅ | ✅ | - | ✅ | - | ✅ | ✅ |

*(注：Empty、button states、contrast、Dynamic Type 都必须在 Figma 或后续视觉稿中明确被设计出)*

---

## 6. Transition & Accessibility Table v3 (Platform Baseline)

| 规则维度 | 强制要求 | 适用对象 | 备注说明 |
| :--- | :--- | :--- | :--- |
| **Touch Targets** | 最小 48 × 48dp 或等价物理尺寸 | 全局可点击元素 (Buttons, Chips, List Items) | Material 3 建议标准，Chip 也要求 48dp 高或点击热区。 |
| **Typography** | 必须支持 Dynamic Type / 字体动态缩放 | 正文字号与关键 CTA | 依赖原生系统的动态字体本地化适配。 |
| **Interaction States**| 明确定义 pressed / disabled / loading | 所有交互元素 | 不允许仅靠颜色传达状态（考虑到色弱用户），必须有明度/图标/动画辅助。 |
| **Motion** | 提供 Reduce Motion 降级方案 | 所有动效 (Sheet 弹起, Card 插入, 路由切换) | 满足系统无障碍设置需求，将平滑位移降级为淡入淡出。 |
| **Contrast** | 高对比模式下信息仍可读 | 文本与背景、边界线 | 需要明确的边界对比度，尤其是 L2/L3 与背景，L4 叠加态。 |
