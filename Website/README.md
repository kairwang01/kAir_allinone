# kAir — Marketing Website

The official pre-launch promotional site for **kAir** — home of **Odera**, the local-first AI agent
that turns intent into action on iPhone (v1: Chat + Health).

> **Status:** Pre-launch. The release date is to be announced. The primary call to
> action is a **waitlist email capture**, not an App Store link (see
> [Launch-day checklist](#launch-day-checklist)).

---

## Design direction

A clean, light, mainstream app-launch page — **not** cyberpunk. The direction was
set by researching the conventions of leading AI-assistant sites (Tencent **Yuanbao**,
ByteDance **Doubao**, **Kimi**, Tencent **Marvis**) and company-grade global product
pages (Apple, Claude, Signal, Proton, DuckDuckGo). The shared playbook:

- **Light, white-led canvas with one calm brand accent.** kAir's accent is the
  indigo→violet of the app icon (`#6C5CE9 → #8944ED`), used only for the logo, the
  primary CTA, and a soft hero glow. Everything else is the app's real neutral system.
- **Privacy framed as a feeling and a number** — the "0 accounts · 0 servers · 0 data
  leaving your iPhone" line, the "What kAir never does" list.
- **Company-grade scaffolding** — structured nav, a fat 4-column footer, a locked
  design-token system, legal pages, SEO/Open Graph/manifest, JSON-LD.

The visual tokens **mirror the app's frozen `Contracts/Design/design-system-v1.md`**
so the site and the product never drift. See `assets/css/tokens.css`.

---

## Architecture

Zero-build static site — semantic HTML + a layered CSS token system + a little
vanilla JS. Deployable to any static host with no toolchain.

```
Website/
├── index.html              # Landing page (all sections)
├── privacy.html            # Privacy Policy (template — review before launch)
├── terms.html              # Terms of Service (template — review before launch)
├── site.webmanifest        # PWA manifest
├── README.md
└── assets/
    ├── css/
    │   ├── tokens.css       # Design tokens — mirrors app design-system-v1 + brand purple
    │   ├── base.css         # Reset, document defaults, type + layout primitives
    │   ├── components.css   # Nav, buttons, cards, forms, footer, iPhone mockup, accordion
    │   └── site.css         # Page-level section composition + responsive
    ├── js/
    │   ├── i18n.js          # Bilingual (EN / 中文) string table + language toggle
    │   └── main.js          # Nav, scroll-reveal, FAQ accordion, waitlist form
    └── img/                 # Icon set, favicons, apple-touch-icon, OG image
```

### Bilingual (EN / 中文)

English ships as the crawlable default text in the HTML; `i18n.js` swaps to the
selected language and remembers the choice (`localStorage` key `kair-lang`). It also
respects the browser language on first visit. Translate by editing the `I18N` table —
keys are referenced from markup via:

- `data-i18n="key"` → sets `textContent`
- `data-i18n-html="key"` → sets `innerHTML`
- `data-i18n-attr="placeholder:key;aria-label:key"` → sets attributes

### Accessibility & performance

Semantic landmarks, skip link, `:focus-visible` rings, `aria-expanded` accordion,
labelled form fields, and a full `prefers-reduced-motion` path (reveal animations and
device tilt are disabled). No web fonts (system font stack), no frameworks, no trackers.

---

## Run locally

It's static — open `index.html`, or serve the folder:

```bash
cd Website
python3 -m http.server 8080
# → http://localhost:8080
```

## Deploy

Drop the `Website/` folder on any static host — **Vercel, Netlify, Cloudflare Pages,
or GitHub Pages**. No build step. Point the apex domain (e.g. `kair.app`) at it over
HTTPS and update the absolute URLs in `index.html` (`<link rel="canonical">`, the
Open Graph `og:url` / `og:image`) to the real domain.

---

## Wiring the waitlist

`main.js` currently validates the email and stores it in `localStorage` as a
placeholder, then shows the success state. To capture real signups, replace the
"No backend yet" block in `main.js` with a `fetch()` POST to your provider
(e.g. Mailchimp/ConvertKit/Buttondown, a Formspree endpoint, or a serverless
function). The success/`form.success` UI is already wired.

---

## Launch-day checklist

The site is intentionally pre-launch-correct. When kAir ships:

- [ ] **Swap the CTA to the App Store.** Replace the custom "Coming soon" store
      badge (`.store-badge` in `index.html`) with the **official black "Download on
      the App Store" badge** from Apple's Marketing Tools
      (`toolbox.marketingtools.apple.com/app-store/`). Keep it ≥40px tall with
      ¼-height clear space, unmodified. *(Apple forbids a recolored/disabled badge,
      which is why the pre-launch CTA is a custom button, not a greyed-out Apple badge.)*
- [ ] Point the badge/links at the real App Store URL; optionally add a QR code that
      opens the listing (the layout leaves room for one in the hero store row).
- [ ] Update copy: "Coming soon" → live; remove the `Soon` tag; adjust the hero badge.
- [ ] Set the real domain in `canonical` / `og:url` / `og:image` / JSON-LD.
- [ ] Replace the **template** Privacy Policy and Terms with counsel-reviewed copy.
- [ ] Fill the footer Company/Connect links (About, Blog, Careers, social).
- [ ] Add analytics **only if** it stays consistent with the privacy promise on the page.

---

## Content sources of truth

Marketing copy is grounded in the app's shipped strings and contracts, not invented:

- Tagline / on-device claims → `kAir/Features/Onboarding/...`, `kAir/Shared/KAirLegalCopy.swift`
- Health disclaimer (App Store 1.4.1) → `KAirLegalCopy.healthDisclaimer`
- Privacy posture → `kAir/PrivacyInfo.xcprivacy`, `kAir/Core/Privacy/PrivacyGuardPolicy.md`
- Shipped vs. coming-soon surfaces → `kAir/Shared/Utilities/FeatureFlag.swift` (v1 = Chat + Health)
- Visual tokens → `Contracts/Design/design-system-v1.md`
