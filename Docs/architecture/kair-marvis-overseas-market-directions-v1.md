# kAir Marvis-Style Overseas Market Directions v1

Status: architecture/product contract, value-only.
Last updated: 2026-06-01.

This document locks the Marvis-style companion lanes kAir should be able
to grow into for overseas users. It is not a runtime expansion. The
catalog is mirrored in `MarketCompanionCatalog` so tests can prevent
accidental drift.

## 1. Scope

- Keep kAir positioned as a chat-first personal action companion, not a
  generic chatbot.
- Use overseas apps and providers as first examples when a lane needs
  public information, media, tickets, productivity files, learning
  content, or travel signals.
- Preserve the current execution contract: public APIs, App Intents,
  Shortcuts, universal links, ShareSheet, local files, or user-confirmed
  server/provider handoff only.
- Treat "auto" features as monitoring, preparation, reminders,
  checklists, or confirmed handoffs until a later provider-specific
  contract creates a lawful executable path.

## 2. Direction Catalog

| Direction | kAir lane | Example overseas apps/providers | Current mapping | Execution boundary |
|---|---|---|---|---|
| Marvis celebrity fan companion | 追星好搭子 | Google News, X, Instagram, TikTok, YouTube, Reddit | `webSearch`, `aiCompletion`, `localStoreLookup`; Search/AI/Store surfaces | Search celebrity news, prepare fan check-in reminders, organize user-provided media. No hidden posting or background third-party app control. |
| Marvis gaming companion | 游戏陪你玩 | Steam, PlayStation, Xbox, Discord, Twitch, Reddit | `webSearch`, `aiCompletion`, `localStoreLookup`; Search/AI/Store surfaces | Monitor public event windows, plan quests, prepare daily checklists. No botting, account automation, or ToS bypass. |
| Marvis intelligence monitor | 情报监控器 | Google News, Hacker News, X, Ticketmaster, SeatGeek, Eventbrite | `webSearch`, `aiCompletion`, `localStoreLookup`; Search/AI/Store surfaces | Monitor industry/social news and ticket availability. Ticket purchase remains user-confirmed external handoff. |
| Marvis knowledge manager | 知识管理员 | Kindle, Apple Books, Google Drive, Notion, LinkedIn, Indeed | `aiCompletion`, `threadLookup`, `localStoreLookup`, `webSearch`; AI/Chat/Store/Search surfaces | Distill permitted/user-provided content, refine notes, prepare job materials. No copyright or paywall bypass. |
| Marvis office helper | 打工好帮手 | Google Drive, Microsoft 365, Dropbox, Adobe Acrobat, DocuSign, Slack | `aiCompletion`, `localStoreLookup`, `webSearch`; AI/Store/Search surfaces | Prepare file conversions, extract contract fields, analyze user-provided operations data. No legal-advice claim or signature/send action without confirmation. |
| Marvis PC butler | 电脑小管家 | Apple Shortcuts, macOS System Settings, Windows Settings, Speedtest, Cloudflare WARP | `aiCompletion`, `localStoreLookup`, `webSearch`; AI/Store/Search surfaces | Explain system settings, prepare cleanup plans, triage network repair. No private APIs, destructive cleanup, or system change without confirmation. |
| Marvis growth accelerator | 成长加速器 | Duolingo, YouTube, arXiv, Semantic Scholar, Google Scholar, OpenAI Docs | `aiCompletion`, `webSearch`, `localStoreLookup`; AI/Search/Store surfaces | English reading support, literature organization, AI-tool guidance. User-provided or cited public sources only. |
| Marvis lifestyle artist | 生活艺术家 | Letterboxd, IMDb, Rotten Tomatoes, Apple Photos, Google Maps, Tripadvisor, Booking.com | `videoPlayback`, `aiCompletion`, `placeSearch`, `routePlanning`, `webSearch`; Video/AI/Maps/Search surfaces | Recommend movies, organize user-provided baby-album plans, evaluate travel options. Booking/payment/export remains user-confirmed handoff. |

## 3. Product Rule

These eight lanes are product directions, not eight new tabs. They should
enter the app through chat, recommendation cards, and existing execution
surface families. Add a new visible surface only when a lane has enough
state and a tested adapter contract to justify it.

## 4. Implementation Boundary

Allowed now:

- Value catalogs, docs, prompt examples, route fixtures, and provider
  status copy.
- Search/read-only monitor contracts and local/user-provided content
  transforms.
- User-confirmed handoff copy for overseas apps and websites.

Not allowed in this gate:

- Real third-party app automation, simulated taps, private APIs, or
  background posting/check-in/gameplay.
- Ticket purchase, booking, signing, payment, system cleanup, or system
  setting mutation without a provider contract plus explicit
  confirmation.
- Crawler runtime, MCP runtime, provider credentials, or live transport
  widening beyond the existing server/provider gates.
