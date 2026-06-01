/* ==========================================================================
   kAir — Bilingual content layer (EN / 中文)
   The HTML ships with English as crawlable default text; this table swaps
   to the selected language. Keys are grouped by section.
   Apply: textContent via [data-i18n], innerHTML via [data-i18n-html],
   attributes via [data-i18n-attr="placeholder:key;aria-label:key"].
   ========================================================================== */
(function () {
  "use strict";

  const I18N = {
    en: {
      "meta.title": "kAir — Meet Odera",
      "meta.desc": "Meet Odera — the AI inside kAir that understands what you mean and quietly takes care of it. Just say what you need. Everything stays on your iPhone. v1 ships Chat + Health. Coming soon.",

      /* Nav */
      "nav.features": "Features",
      "nav.privacy": "Privacy",
      "nav.how": "How it works",
      "nav.faq": "FAQ",
      "nav.notify": "Notify me",
      "nav.menu": "Open menu",

      /* Hero */
      "hero.app": "on kAir · Coming soon · iPhone",
      "hero.title": "Meet Odera",
      "hero.lead": "The AI that knows what you mean — and quietly takes care of it.",
      "hero.tagline": "You talk. Odera understands. Things happen.",
      "hero.demo": "What can I help with?",
      "hero.hook": "Private by design · Memory you control · Chat + Health in v1",
      "hero.email": "Enter your email",
      "hero.cta": "Notify me at launch",
      "hero.note": "Release date to be announced · iPhone · iOS",
      "hero.store.small": "Coming soon to the",
      "hero.store.big": "App Store",

      "feat.title": "What Odera can do for you",
      "feat.lead": "One conversation that connects to everything — an AI companion that gets things done, not a chatbot that just replies.",
      "feat.health.note": "Health summaries are wellness information, not medical advice. kAir is not a medical device.",

      "cap.recipes.title": "Recipes",
      "cap.recipes.body": "Plan meals, swap ingredients, and remember what you like — all handled right on your iPhone when this feature ships.",
      "cap.routes.title": "Routes",
      "cap.routes.body": "Ask for directions or transit. Odera opens maps and keeps the context in your conversation.",
      "cap.health.title": "Health",
      "cap.health.body": "Private Apple Health insights, processed entirely on your iPhone when you ask. One of many skills — available in v1.",
      "cap.search.title": "Search",
      "cap.search.body": "Find answers and sources without leaving the conversation. Unlocking after v1.",
      "cap.media.title": "Media",
      "cap.media.body": "Play, queue, or discover — Odera connects you to the right feature. Unlocking after v1.",
      "cap.store.title": "Store",
      "cap.store.body": "Services and commerce when you're ready to act. Unlocking after v1.",

      /* How it works */
      "how.title": "Three steps. That's it.",
      "how.s1.title": "Download kAir",
      "how.s1.body": "One tap from the App Store when it launches on iPhone.",
      "how.s2.title": "Say what you need",
      "how.s2.body": "Type or speak naturally — find a route, check your health, draft a message, or ask anything on your mind.",
      "how.s3.title": "Confirm, and it's done on your iPhone",
      "how.s3.body": "Odera figures out what to do, you review the plan, and results come back to your conversation — all processed on your phone in v1.",

      /* Privacy */
      "priv.title": "Private by design — everything stays on your iPhone.",
      "priv.tagline": "On your iPhone · Memory you control · No account needed",
      "priv.lead": "Your conversations, memory, and everything Odera does are designed to run on your iPhone. In v1, your prompts and data never leave your device.",
      "priv.z1": "accounts",
      "priv.z2": "external servers",
      "priv.z3": "trackers",
      "priv.c1.title": "Runs on your iPhone",
      "priv.c1.body": "Odera uses Apple Foundation Models, processing everything right on your device.",
      "priv.c2.title": "Nothing leaves your phone",
      "priv.c2.body": "Your prompts, memory, and data are processed on your iPhone in v1 — nothing is sent to kAir servers.",
      "priv.c3.title": "No account, no tracking",
      "priv.c3.body": "No sign-up required. No ads, no cross-app tracking, no analytics profile built about you.",
      "priv.c4.title": "You are always in control",
      "priv.c4.body": "Any export is something you start, preview, and confirm. It is never automatic and never silent.",
      "priv.never.title": "What kAir does not do",
      "priv.never.1": "Send your chats to a server",
      "priv.never.2": "Export your Apple Health data",
      "priv.never.3": "Show you ads",
      "priv.never.4": "Track you across apps",
      "priv.never.5": "Require an account to work",
      "priv.never.6": "Upload your data to train models",

      /* Roadmap */
      "road.eyebrow": "The road ahead",
      "road.title": "v1 ships Chat + Health. More skills unlock over time.",
      "road.lead": "Odera lives inside kAir — your private conversation space. Launch ships two features that run on your iPhone; recipes, routes, search, media, and store follow as each becomes ready.",
      "road.live": "Available at launch",
      "road.soon": "Planned for later",
      "road.chat": "Chat",
      "road.health": "Health",
      "road.recipes": "Recipes",
      "road.routes": "Routes",
      "road.search": "Search",
      "road.media": "Media",
      "road.store": "Store",

      /* FAQ */
      "faq.eyebrow": "FAQ",
      "faq.title": "Questions, answered.",
      "faq.lead": "Everything you might want to know before Odera lands on your iPhone.",
      "faq.q0": "What is Odera?",
      "faq.a0": "Odera is the AI inside kAir — your companion that understands what you want and takes care of it. You describe what you need; Odera understands your intent, uses memory you control, checks permissions and risk, and handles the task using the right feature in the app. kAir is the app; Odera is who you talk to inside it. v1 ships with Chat and Health.",
      "faq.q1": "When will kAir launch?",
      "faq.a1": "The launch date is being finalized. Join the list and you'll be the first to know — we'll email you the moment kAir is live.",
      "faq.q2": "Which devices does kAir support?",
      "faq.a2": "kAir launches on iPhone (iOS). Support for additional platforms may follow in future versions.",
      "faq.q3": "Is Odera private?",
      "faq.a3": "Yes. In v1, Odera runs entirely on your iPhone. Your prompts and data are not sent to kAir servers, and no account is required.",
      "faq.q4": "Do I need an account?",
      "faq.a4": "No. kAir works fully on your iPhone, so you can open it and start right away. Sign-in is optional.",
      "faq.q5": "Is kAir a medical device?",
      "faq.a5": "No. kAir is a wellness and information tool, not a medical device. It does not diagnose, treat, or prevent any condition, and its AI summaries can be incomplete or wrong. Always consult a qualified clinician for medical decisions.",
      "faq.q6": "How much will kAir cost?",
      "faq.a6": "Pricing will be shared closer to launch. Join the list and we'll keep you updated.",

      /* Final CTA */
      "cta.title": "Be the first to meet Odera.",
      "cta.lead": "Coming soon on kAir for iPhone — we'll let you know the moment v1 is ready.",
      "cta.email": "Enter your email",
      "cta.btn": "Notify me at launch",
      "cta.note": "We'll email you on launch day. No spam, ever.",
      "form.success": "You're on the list. We'll email you when kAir launches — nothing else.",
      "form.invalid": "Please enter a valid email address.",

      /* Footer */
      "foot.tagline": "kAir — home of Odera, your private AI companion.",
      "foot.product": "Product",
      "foot.company": "Company",
      "foot.legal": "Legal",
      "foot.connect": "Connect",
      "foot.features": "Features",
      "foot.privacy": "Privacy",
      "foot.how": "How it works",
      "foot.roadmap": "Roadmap",
      "foot.faq": "FAQ",
      "foot.about": "About",
      "foot.blog": "Blog",
      "foot.careers": "Careers",
      "foot.contact": "Contact",
      "foot.privacyPolicy": "Privacy Policy",
      "foot.terms": "Terms of Service",
      "foot.health": "Health disclaimer",
      "foot.email": "hello@kair.app",
      "foot.ai": "Odera uses AI that runs on your iPhone inside kAir. AI-generated content can be incomplete or wrong — please use your own judgment, and never rely on it for medical, legal, or financial decisions.",
      "foot.healthFull": "kAir is a wellness and information tool, not a medical device. It does not diagnose, treat, or prevent any condition. Always consult a qualified clinician for medical decisions, and call your local emergency number in an emergency.",
      "foot.copyright": "© 2026 kAir. All rights reserved.",
      "foot.madeWith": "Designed for privacy. Built for iPhone.",

      /* Legal pages */
      "legal.updated": "Last updated",
      "legal.draft": "Template draft — review with legal counsel before launch.",
      "legal.draftShort": "Pre-launch template",
      "legal.back": "Back to home",
      "pp.title": "Privacy Policy",
      "pp.intro": "kAir is built to keep everything on your iPhone. This policy explains what that means for your data. In short: in v1, your prompts, memory, and data are processed on your iPhone and are not sent to kAir servers.",
      "pp.s1.t": "1. Our approach",
      "pp.s1.b": "Privacy is the default in kAir, not an option you switch on. The app is designed so that personal content has nowhere else to go — it stays on your iPhone.",
      "pp.s2.t": "2. Information we do not collect",
      "pp.s2.b": "kAir does not require an account and does not ask for your name, email, or phone number to function. We do not collect your chats, your prompts, or your Apple Health data. We do not sell or share personal data, because we do not have it.",
      "pp.s3.t": "3. Data processed on your device",
      "pp.s3.b": "Your commands and conversation are processed on your iPhone using local models. If you grant Apple Health access, kAir reads only the data you allow, strictly on your device, when you use the health feature. Your memory and preferences stay on your iPhone under policies you can review in settings.",
      "pp.s4.t": "4. App settings",
      "pp.s4.b": "kAir stores your in-app preferences locally on your iPhone (for example, using the system's app-scoped settings storage). These settings stay on the device and are not transmitted to kAir.",
      "pp.s5.t": "5. No tracking, no ads",
      "pp.s5.b": "kAir does not track you across apps or websites, does not show advertising, and does not build an analytics profile about you. There are no third-party advertising or tracking SDKs in this version.",
      "pp.s6.t": "6. Children",
      "pp.s6.b": "kAir is not directed to children under the age required by your local laws to consent to data processing. Because kAir does not collect personal data, no such data about children is gathered.",
      "pp.s7.t": "7. Changes to this policy",
      "pp.s7.b": "If a future version of kAir introduces optional features that involve a server (for example, account sign-in or cloud sync), this policy will be updated to describe them clearly before those features are enabled, and any such processing will be opt-in.",
      "pp.s8.t": "8. Contact",
      "pp.s8.b": "Questions about privacy? Reach us at hello@kair.app.",
      "tos.title": "Terms of Service",
      "tos.intro": "These Terms govern your use of the kAir app. By using kAir, you agree to them. Please read them together with our Privacy Policy.",
      "tos.s1.t": "1. The service",
      "tos.s1.b": "kAir is the app; Odera is the AI companion inside it. You describe tasks naturally; Odera handles them using features that run on your iPhone. v1 ships Chat and Health; recipes, routes, search, media, store, and more unlock over time.",
      "tos.s2.t": "2. Not professional advice",
      "tos.s2.b": "kAir is a wellness and information tool, not a medical device. It does not diagnose, treat, or prevent any condition. Its summaries can be incomplete or wrong. Always consult a qualified clinician for medical decisions, and call your local emergency number in an emergency. kAir does not provide legal, financial, or other professional advice.",
      "tos.s3.t": "3. AI-generated content",
      "tos.s3.b": "Responses are generated by AI on your iPhone and may be inaccurate, incomplete, or out of date. You are responsible for how you use any output. Do not rely on kAir for decisions that require professional judgment.",
      "tos.s4.t": "4. Acceptable use",
      "tos.s4.b": "Use kAir lawfully and do not attempt to misuse, disrupt, reverse engineer, or use the app to harm yourself or others.",
      "tos.s5.t": "5. Intellectual property",
      "tos.s5.b": "kAir, its name, logo, and design are owned by the kAir team. These Terms do not grant you rights to our trademarks or branding.",
      "tos.s6.t": "6. Disclaimers and liability",
      "tos.s6.b": "kAir is provided \"as is,\" without warranties of any kind, to the maximum extent permitted by law. To the extent permitted by law, the kAir team is not liable for any indirect or consequential damages arising from your use of the app.",
      "tos.s7.t": "7. Changes",
      "tos.s7.b": "We may update these Terms as kAir evolves. Material changes will be reflected here with an updated date.",
      "tos.s8.t": "8. Contact",
      "tos.s8.b": "Questions about these Terms? Reach us at hello@kair.app."
    },

    zh: {
      "meta.title": "kAir — 认识 Odera",
      "meta.desc": "认识 Odera——住在 kAir 里的 AI 伙伴。告诉她想做什么，她来帮你完成。首批支持聊天和健康。即将登陆 iPhone。",

      "nav.features": "功能",
      "nav.privacy": "隐私",
      "nav.how": "怎么用",
      "nav.faq": "常见问题",
      "nav.notify": "通知我",
      "nav.menu": "打开菜单",

      "hero.app": "kAir 即将上线 · iPhone",
      "hero.title": "认识 Odera",
      "hero.lead": "告诉 Odera 你想做什么，剩下的交给她。",
      "hero.tagline": "说出你的想法，Odera 会理解、记住、判断、帮你完成。",
      "hero.demo": "你想做什么？",
      "hero.hook": "只在你的手机上运行 · 记忆由你掌控 · 首批支持聊天和健康",
      "hero.email": "输入你的邮箱",
      "hero.cta": "发布时通知我",
      "hero.note": "发布日期待公布 · iPhone · iOS",
      "hero.store.small": "即将登陆",
      "hero.store.big": "App Store",

      "feat.title": "Odera 能帮你做什么",
      "feat.lead": "一次对话，搞定日常大小事——是真正能帮你做事的伙伴，不是只会聊天的机器人。",
      "feat.health.note": "健康摘要仅供参考，并非医疗建议。kAir 不是医疗设备。",

      "cap.recipes.title": "菜谱",
      "cap.recipes.body": "规划三餐、替换食材、记住你的口味——这些都在你手机上就能完成。",
      "cap.routes.title": "路线",
      "cap.routes.body": "想去哪儿，直接说。Odera 帮你查路线、看公交，全程不离开对话。",
      "cap.health.title": "健康",
      "cap.health.body": "问一下今天的步数、心率趋势——你的健康数据只在手机上处理，不出设备。首批可用。",
      "cap.search.title": "搜索",
      "cap.search.body": "想查什么直接问，不用跳出聊天。后续版本开放。",
      "cap.media.title": "影音",
      "cap.media.body": "想听歌、看视频，告诉 Odera 就好。后续版本开放。",
      "cap.store.title": "生活服务",
      "cap.store.body": "买东西、订服务，Odera 帮你安排好。后续版本开放。",

      "how.title": "三步，就够了。",
      "how.s1.title": "下载 kAir",
      "how.s1.body": "发布后，在 App Store 一键获取。",
      "how.s2.title": "说出你想做的事",
      "how.s2.body": "打字或语音都行——查路线、看健康、写消息，或者随便问问。",
      "how.s3.title": "看一眼，点一下，搞定",
      "how.s3.body": "Odera 找到最合适的处理方式，你确认一下，结果直接回到对话——全部在你手机上完成。",

      "priv.title": "你的数据，不离开你的手机。",
      "priv.tagline": "手机端处理 · 记忆由你掌控 · 无需注册",
      "priv.lead": "所有的理解、记忆、执行，都在你手机上完成。你说的话、产生的数据，不会发给 kAir 的服务器。",
      "priv.z1": "账号",
      "priv.z2": "服务器参与",
      "priv.z3": "追踪器",
      "priv.c1.title": "手机上处理",
      "priv.c1.body": "AI 推理在你自己的 iPhone 上完成，又快又私密。",
      "priv.c2.title": "数据不离开手机",
      "priv.c2.body": "你说的话、你的偏好、你的健康数据，都在手机上处理，不发给任何服务器。",
      "priv.c3.title": "不用注册、不被追踪",
      "priv.c3.body": "打开就能用。没有广告、不追踪你、不会建立你的用户画像。",
      "priv.c4.title": "你说了算",
      "priv.c4.body": "任何导出都由你发起、预览、确认。不会悄悄进行，不会自动触发。",
      "priv.never.title": "kAir 绝不会做的事",
      "priv.never.1": "把你的聊天内容发给服务器",
      "priv.never.2": "导出你的 Apple 健康数据",
      "priv.never.3": "给你看广告",
      "priv.never.4": "跨应用追踪你",
      "priv.never.5": "强迫你注册",
      "priv.never.6": "拿你的数据去训练模型",

      "road.eyebrow": "未来规划",
      "road.title": "首批上线聊天和健康。更多功能陆续到来。",
      "road.lead": "Odera 住在 kAir 里，所有处理都在你手机上。首批上线聊天和健康；菜谱、路线、搜索、影音、生活服务会陆续开放。",
      "road.live": "首发可用",
      "road.soon": "后续上线",
      "road.chat": "聊天",
      "road.health": "健康",
      "road.recipes": "菜谱",
      "road.routes": "路线",
      "road.search": "搜索",
      "road.media": "影音",
      "road.store": "生活服务",

      "faq.eyebrow": "常见问题",
      "faq.title": "你的疑问，我们逐一回答。",
      "faq.lead": "在 Odera 来到你的 iPhone 之前，你想知道的都在这里。",
      "faq.q0": "Odera 是什么？",
      "faq.a0": "Odera 是住在 kAir 里的 AI 伙伴。你告诉她你想做什么，她会理解你的意思，看看有没有权限、安不安全，然后找到最合适的方式帮你搞定。kAir 是 app，Odera 是里面那个帮你做事的伙伴。首批支持聊天和健康。",
      "faq.q1": "kAir 什么时候上线？",
      "faq.a1": "上线日期正在最后确认。留下邮箱，你会第一时间知道——kAir 一上线，我们立刻通知你。",
      "faq.q2": "kAir 支持哪些手机？",
      "faq.a2": "kAir 首发支持 iPhone（iOS 系统）。后续版本会考虑支持更多设备。",
      "faq.q3": "Odera 真的能保护隐私吗？",
      "faq.a3": "能。Odera 就在你 iPhone 上运行，不需要联网。你说的话、产生的数据，都不会离开你的手机，也不用注册账号就能用。",
      "faq.q4": "需要注册吗？",
      "faq.a4": "不需要。kAir 完全在你手机上工作，打开就能用，登录是可选的。",
      "faq.q5": "kAir 是医疗设备吗？",
      "faq.a5": "不是。kAir 是健康和生活参考工具，不是医疗设备。它不诊断、不治疗、不预防任何疾病，AI 给出的健康信息可能不完整或有偏差。任何医疗决定请务必咨询专业医生。",
      "faq.q6": "kAir 收费吗？",
      "faq.a6": "价格会在临近上线时公布。留下邮箱，我们会及时告诉你。",

      "cta.title": "比别人先认识 Odera。",
      "cta.lead": "kAir for iPhone 即将上线——第一时间通知你。",
      "cta.email": "输入你的邮箱",
      "cta.btn": "发布时通知我",
      "cta.note": "上线当天邮件通知，绝无垃圾邮件。",
      "form.success": "已加入名单。kAir 发布时第一时间通知你——没有其他打扰。",
      "form.invalid": "请输入有效的邮箱地址。",

      "foot.tagline": "kAir——Odera 的家，只在你手机上运行的 AI 伙伴。",
      "foot.product": "产品",
      "foot.company": "公司",
      "foot.legal": "法律",
      "foot.connect": "联系",
      "foot.features": "功能",
      "foot.privacy": "隐私",
      "foot.how": "怎么用",
      "foot.roadmap": "未来规划",
      "foot.faq": "常见问题",
      "foot.about": "关于我们",
      "foot.blog": "博客",
      "foot.careers": "加入我们",
      "foot.contact": "联系我们",
      "foot.privacyPolicy": "隐私政策",
      "foot.terms": "服务条款",
      "foot.health": "健康声明",
      "foot.email": "hello@kair.app",
      "foot.ai": "Odera 在 kAir 里用你手机上的 AI。AI 生成的内容可能不完整或有误，请自行判断，不要依赖它做医疗、法律或财务决策。",
      "foot.healthFull": "kAir 是健康和生活参考工具，不是医疗设备。它不诊断、不治疗、不预防任何疾病。任何医疗决定请务必咨询专业医生，紧急情况请拨打当地急救电话。",
      "foot.copyright": "© 2026 kAir 版权所有。",
      "foot.madeWith": "为隐私而设计，为 iPhone 而生。",

      "legal.updated": "最后更新",
      "legal.draft": "模板草稿——上线前请交由法律顾问审阅。",
      "legal.draftShort": "上线前模板",
      "legal.back": "返回首页",
      "pp.title": "隐私政策",
      "pp.intro": "kAir 的核心设计理念是：你的数据留在你的手机上。这份政策说明这意味着什么。简单来说：你说的话、你的偏好、你的数据，都在你 iPhone 上处理，不会发给 kAir 的服务器。",
      "pp.s1.t": "1. 我们的理念",
      "pp.s1.b": "在 kAir 里，隐私是默认状态，不是需要你去找的开关。我们从设计上确保你的个人内容出不去——就留在你的 iPhone 上。",
      "pp.s2.t": "2. 我们不收集的信息",
      "pp.s2.b": "kAir 不需要注册，运行时也不会要你的姓名、邮箱或电话。我们不收集你的聊天内容、你问的问题、你的 Apple 健康数据。我们不出售、不共享个人数据——因为我们根本没有。",
      "pp.s3.t": "3. 在你手机上处理的数据",
      "pp.s3.b": "你的问题和对话由你手机上的 AI 自己处理。如果你给了 Apple 健康权限，kAir 只在你问健康问题时，在手机本地读取你允许的数据。你的偏好和记忆留在手机上，在设置里随时可以看。",
      "pp.s4.t": "4. 应用设置",
      "pp.s4.b": "kAir 把你的偏好设置放在你手机本地（用系统自带的应用设置存储）。这些设置留在手机上，不会发给 kAir。",
      "pp.s5.t": "5. 不追踪、不广告",
      "pp.s5.b": "kAir 不会跨应用或网站追踪你，不给你看广告，不会建立你的用户画像。当前版本不含任何第三方广告或追踪相关的代码库。",
      "pp.s6.t": "6. 关于儿童",
      "pp.s6.b": "kAir 不面向当地法律规定的、需经同意才能处理数据的年龄以下的儿童。因为 kAir 本来就不收集个人数据，所以也不会收集任何儿童的此类数据。",
      "pp.s7.t": "7. 政策更新",
      "pp.s7.b": "如果未来的 kAir 加入了需要联网的可选功能（比如账号登录或云端同步），我们会在启用前更新这份政策，把情况说清楚，而且所有联网功能都是你自己选的，不会强制。",
      "pp.s8.t": "8. 联系我们",
      "pp.s8.b": "对隐私有疑问？请通过 hello@kair.app 联系我们。",
      "tos.title": "服务条款",
      "tos.intro": "本条款适用于你使用 kAir 应用。使用 kAir 即表示你同意。请和我们的隐私政策一起看。",
      "tos.s1.t": "1. 服务说明",
      "tos.s1.b": "kAir 是 app；Odera 是里面的 AI 伙伴。你用日常语言说想做什么，Odera 帮你在手机上完成。首批支持聊天和健康；菜谱、路线、搜索、影音、生活服务等会陆续解锁。",
      "tos.s2.t": "2. 非专业建议",
      "tos.s2.b": "kAir 是健康和生活参考工具，不是医疗设备。它不诊断、不治疗、不预防任何疾病，给出的信息可能不完整或有偏差。任何医疗决定请务必咨询专业医生，紧急情况请拨打当地急救电话。kAir 不提供法律、财务或其他专业建议。",
      "tos.s3.t": "3. AI 生成内容",
      "tos.s3.b": "回复由你手机上的 AI 生成，可能不准确、不完整或已过时。你需要自己判断怎么用这些内容。涉及专业判断的决定，不要依赖 kAir。",
      "tos.s4.t": "4. 合理使用",
      "tos.s4.b": "请合法使用 kAir，不要试图滥用、干扰、逆向工程，或用它伤害自己或他人。",
      "tos.s5.t": "5. 知识产权",
      "tos.s5.b": "kAir 及其名称、标志和设计属于 kAir 团队。本条款不给你任何使用我们商标或品牌的权利。",
      "tos.s6.t": "6. 免责与责任",
      "tos.s6.b": "在法律允许的最大范围内，kAir 按"现状"提供，不附带任何担保。在法律允许范围内，kAir 团队不因你使用本应用而产生的任何间接或后果性损失承担责任。",
      "tos.s7.t": "7. 条款更新",
      "tos.s7.b": "随着 kAir 的发展，我们可能会更新这些条款。重要变更会在这里更新并注明日期。",
      "tos.s8.t": "8. 联系我们",
      "tos.s8.b": "对本条款有疑问？请通过 hello@kair.app 联系我们。"
    }
  };

  const SUPPORTED = ["en", "zh"];
  const STORE_KEY = "kair-lang";

  function detectLang() {
    try {
      const saved = localStorage.getItem(STORE_KEY);
      if (saved && SUPPORTED.includes(saved)) return saved;
    } catch (e) {}
    const nav = (navigator.language || "en").toLowerCase();
    return nav.startsWith("zh") ? "zh" : "en";
  }

  function t(key, lang) {
    const dict = I18N[lang] || I18N.en;
    return (key in dict) ? dict[key] : (I18N.en[key] != null ? I18N.en[key] : key);
  }

  function applyLang(lang) {
    if (!SUPPORTED.includes(lang)) lang = "en";
    document.documentElement.lang = (lang === "zh") ? "zh-Hans" : "en";

    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      el.textContent = t(el.getAttribute("data-i18n"), lang);
    });
    document.querySelectorAll("[data-i18n-html]").forEach(function (el) {
      el.innerHTML = t(el.getAttribute("data-i18n-html"), lang);
    });
    document.querySelectorAll("[data-i18n-attr]").forEach(function (el) {
      el.getAttribute("data-i18n-attr").split(";").forEach(function (pair) {
        const idx = pair.indexOf(":");
        if (idx === -1) return;
        const attr = pair.slice(0, idx).trim();
        const key = pair.slice(idx + 1).trim();
        if (attr && key) el.setAttribute(attr, t(key, lang));
      });
    });

    // toggle button state
    document.querySelectorAll("[data-lang-set]").forEach(function (btn) {
      btn.setAttribute("aria-pressed", String(btn.getAttribute("data-lang-set") === lang));
    });

    try { localStorage.setItem(STORE_KEY, lang); } catch (e) {}
    document.dispatchEvent(new CustomEvent("kair:langchange", { detail: { lang: lang } }));
  }

  // Expose minimal API
  window.kAirI18n = { apply: applyLang, t: t, current: detectLang };

  function init() {
    applyLang(detectLang());
    document.querySelectorAll("[data-lang-set]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        applyLang(btn.getAttribute("data-lang-set"));
      });
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
