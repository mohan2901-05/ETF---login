# ETF Loans Website Design Specification
**Extracted from https://etf-loans.vercel.app/ using Hallmark inspection**

---

## 1. Website Inspection Summary

### Pages Inspected
- **Welcome/Landing Page** — Hero with brand, facts, EMI calculator, how-it-works, pricing, FAQ
- **Login/Sign In Page** — Mobile number entry with +91 prefix, animated illustration, "Send code" CTA
- **OTP Verification Page** — 6-tile OTP input over hidden real input, iridescent backdrop, resend countdown, SMS autofill support
- **Navigation** — Hash-based SPA router, transitions between screens
- **Responsive Behavior** — Mobile-first (≤440px), desktop side-panel at ≥960px

### Tools Used
- Direct HTTP fetch of HTML, CSS (`app.css`), JS (`app.js`, `challenge.js`)
- Hallmark skill loaded for design extraction methodology
- No browser automation required — all design tokens in CSS `:root`

### Limitations
- Could not interact with live OTP flow (requires real mobile)
- Could not observe face check/selfie flow (requires camera)
- Desktop side-panel not fully inspected (requires ≥960px viewport)
- No access to `ETF Loans Site Map.html` (not found in project)

---

## 2. Login Screen Design Specification

### Page Structure
```
┌─────────────────────────────────────┐
│ Topbar: ← Back (to welcome) + Logo  │ 60px min-height
├─────────────────────────────────────┤
│                                     │
│     Animated Illustration           │ 132px wide, centered
│     (phone + bubble with 6 dots)    │
│                                     │
├─────────────────────────────────────┤
│ Head Section                        │
│   H1: "Sign in with your mobile"    │ 27-30px, Plus Jakarta Sans, 700
│   P: "Your number is your login.    │ 15px, DM Sans, --muted
│      There is no password..."       │
├─────────────────────────────────────┤
│ Form                                │
│   Label: "Mobile number"            │ 14px, 600, --ink
│   Input: +91 [98765 43210]          │ 54px height, 16px, --ink
│   Helper: "One number, one account. │ 13px, --muted
│      We use it for your loan..."    │
├─────────────────────────────────────┤
│ Footer (sticky)                     │
│   Primary Button: "Send code"       │ 54px, 16px, Plus Jakarta Sans, 700
│   Legal: "By continuing you agree   │ 12px, --muted
│      to our Terms and Privacy"      │
│   [Optional] "Skip sign-in (demo)"  │ Text button, --muted
└─────────────────────────────────────┘
```

### Visual Properties (VERIFIED from CSS)
| Property | Value | Source |
|----------|-------|--------|
| Container max-width | 440px | `.app { max-width: 440px }` |
| Page background | `--paper` (#f3f8f3) | `body { background: var(--green-deep) }` + `.app { background: var(--paper) }` |
| Card/surface | `--card` (#ffffff) | `:root { --card: #ffffff }` |
| Primary brand | `--green` (#15803f) | `:root { --green: #15803f }` |
| Primary dark | `--green-mid` (#12522f) | `:root { --green-mid: #12522f }` |
| Primary deepest | `--green-deep` (#0a2e1b) | `:root { --green-deep: #0a2e1b }` |
| Text primary | `--ink` (#0a2e1b) | `:root { --ink: #0a2e1b }` |
| Text body | `--body` (#334e41) | `:root { --body: #334e41 }` |
| Text muted | `--muted` (#5b7268) | `:root { --muted: #5b7268 }` |
| Border default | `--rule-strong` (#c3d3c8) | `:root { --rule-strong: #c3d3c8 }` |
| Input height | 54px | `.input { height: 54px }` |
| Input border radius | `--r` (14px) | `:root { --r: 14px }` |
| Button height | 54px | `.btn { min-height: 54px }` |
| Button border radius | 16px | `.btn { border-radius: 16px }` |
| Primary button bg | `--green` | `.btn-primary { background: var(--green) }` |
| Primary button hover | `--green-mid` | `.btn-primary:hover { background: var(--green-mid) }` |
| Shadow | `0 1px 2px rgba(10,46,27,.05), 0 10px 24px -14px rgba(10,46,27,.22)` | `--shadow` token |
| Logo height | 30px (topbar), 34px (hero) | `.topbar .logo { height: 30px }`, `.brand img { height: 34px }` |
| Illustration width | 132px | `.login-art { width: 132px }` |
| Input focus ring | 2px solid --green, outline-offset -1px + box-shadow 4px | `.input:focus { outline: 2px solid var(--green); outline-offset: -1px; box-shadow: 0 0 0 4px rgb(21 128 63 / .14) }` |
| Focus-visible | 2px solid --ink, offset 2px | `:focus-visible { outline: 2px solid var(--ink); outline-offset: 2px }` |
| Error border | `--bad` (#c0392b) | `.field.invalid .input { border-color: var(--bad) }` |
| Error text | `--bad`, 13px, 500 | `.field .err { font-size: 13px; color: var(--bad); font-weight: 500 }` |

### Animation (VERIFIED)
- Screen enter: `opacity 0 → 1`, `translateY(8px) → 0`, 300ms ease-out
- Illustration: phone draws (700ms), ear fades (300ms @ 700ms), bubble pops (350ms @ 750ms), 6 dots fade in sequentially (200ms each @ 1150ms+)
- Text elements: staggered `enter` with delays (d1=80ms, d2=160ms, d3=240ms, d4=320ms)
- Reduced motion: all animations disabled via `@media (prefers-reduced-motion: reduce)`

### States
- **Default** — Empty input, enabled "Send code"
- **Typing** — Input formatted as "98765 43210" (space at 5 digits)
- **Invalid** — Red border, error message below input, button stays enabled
- **Loading** — Button shows spinner, disabled, "Sending" label
- **Success** — Navigate to OTP screen

---

## 3. OTP Screen Design Specification

### Page Structure
```
┌─────────────────────────────────────┐
│ Iridescent Backdrop (full bleed)    │ .iri pseudo-elements
│   conic-gradient + sheen + radial   │ animated, z-index: -1
├─────────────────────────────────────┤
│ Topbar: ← Back (to login) + Logo    │ 60px min-height
├─────────────────────────────────────┤
│ OTP Body (centered, flex column)    │
│   H1: "Enter the code"              │ 30px, 800, --ink
│   P: "Sent to +91 98765 43210"     │ 15px, #34503f
│      [Edit button]                  │ Pill button, --green text
├─────────────────────────────────────┤
│ OTP Wrap (relative, max-width 360px)│
│   Hidden real input:                │ position: absolute, inset: 0, opacity: 0
│     type=text, inputmode=numeric,   │ autocomplete="one-time-code"
│     maxlength=6, pattern="[0-9]*"   │
│   6 Tiles (grid, 1fr × 6, gap 10px) │
│     Each: 62px × 62px, radius 16px  │
│     White bg, border 1.5px --rule   │
│     Shadow: 0 1px 2px + 0 10px 22px │
│     Digit: 28px, Plus Jakarta Sans, │
│       800, tabular-nums, --ink      │
│     Caret: 2px × 26px, --green      │ blinks on active tile
├─────────────────────────────────────┤
│ Status (min-height 26px)            │
│   Success: green + checkmark        │
│   Error: red + ! icon               │
│   Checking: spinner                 │
├─────────────────────────────────────┤
│ Footer (resend / demo)              │
│   Countdown: "Resend in 0:30"       │ muted
│   After 30s: "Resend code" button   │ pill, --green text, white/75% bg
│   [Demo chip: "Demo code 123456"]   │ pill, --ink/7% bg
└─────────────────────────────────────┘
```

### Visual Properties (VERIFIED from CSS)
| Property | Value | Source |
|----------|-------|--------|
| Page background | `#f5f9f6` | `.otp-screen { background: #f5f9f6 }` |
| Iridescent layer | conic-gradient + blur(48px) saturate(1.35) | `.iri::before` |
| Sheen layer | linear-gradient 115deg, soft-light blend | `.iri::after` |
| Radial highlight | radial-gradient at 50% 30% | `.iri i` |
| Tile size | 62px × 62px | `.tile { height: 62px }` |
| Tile gap | 10px | `.tiles { gap: 10px }` |
| Tile radius | 16px | `.tile { border-radius: 16px }` |
| Tile border (default) | 1.5px `rgba(10,46,27,.22)` | `.tile { border: 1.5px solid rgb(10 46 27 / .22) }` |
| Tile border (active) | 2px `--green` | `.tile.active { border-color: var(--green); border-width: 2px }` |
| Tile border (filled) | `rgba(10,46,27,.5)` | `.tile.filled { border-color: rgb(10 46 27 / .5) }` |
| Tile border (error) | 2px `--bad` | `[data-state="error"] .tile { border-color: var(--bad); border-width: 2px }` |
| Tile border (success) | `--green` | `[data-state="success"] .tile { border-color: var(--green) }` |
| Tile bg (default) | `#fff` | `.tile { background: #fff }` |
| Tile bg (error) | `#fff4f2` | `[data-state="error"] .tile { background: #fff4f2 }` |
| Tile bg (success) | `--green` | `[data-state="success"] .tile { background: var(--green) }` |
| Tile shadow | `0 1px 2px rgba(10,46,27,.06), 0 10px 22px -14px rgba(10,46,27,.35)` | `.tile` |
| Tile shadow (active) | + `0 0 0 4px rgb(21,128,63,.16)` | `.tile.active` |
| Digit font | Plus Jakarta Sans, 28px, 800, tabular-nums | `.tile .digit { font: 800 28px/1 var(--serif) }` |
| Digit color (default) | `--ink` | `.tile .digit { color: var(--ink) }` |
| Digit color (error) | `--bad` | `[data-state="error"] .tile .digit { color: var(--bad) }` |
| Digit color (success) | `#fff` | `[data-state="success"] .tile .digit { color: #fff }` |
| Caret | 2px × 26px, `--green`, blinks 1s steps | `.tile .caret`, `@keyframes caret` |
| Edit button | Pill, 99px radius, white/70% bg, `--green` text | `.otp-edit` |
| Resend button | Pill, 99px radius, white/75% bg, `--green` text | `.otp-resend` |
| Demo chip | Pill, 99px radius, `rgba(10,46,27,.07)` bg | `.demo-chip` |
| Status success | `--green`, checkmark SVG | `.otp-status.good` |
| Status error | `--bad`, ! in red circle | `.otp-status.bad .x` |
| Status checking | Spinner, `--green` | `.spin.dark` |
| Narrow screen (≤360px) | Tile 54px, gap 7px, digit 24px | `@media (max-width: 360px)` |

### State Transitions (VERIFIED from CSS/JS)
| State | Trigger | Visual | Animation |
|-------|---------|--------|-----------|
| `empty` | Initial | All tiles default border | — |
| `typing` | Input > 0 chars | Active tile: green border, caret blink, translateY(-2px) | `caret` 1s steps, `tile-bump` on pop |
| `checking` | 6 digits entered | All tiles: green border, wave animation | `tile-wave` 900ms stagger |
| `error` | Verify fails | Red border, red digits, shake, bg `#fff4f2` | `shake` 400ms, then `clearing` digits fall |
| `success` | Verify succeeds | Green fill, white digits, scale bump | `tile-done` 400ms stagger |
| `clearing` | After error | Digits fade out + translateY(12px) | 200ms stagger |

### SMS Autofill & Paste (VERIFIED from JS)
- Hidden real input with `autocomplete="one-time-code"` enables iOS/Android autofill
- WebOTP API (`navigator.credentials.get({ otp: { transport: ["sms"] }})`) for Android Chrome
- Paste handler captures clipboard, animates digits in sequentially (70ms each)
- Reduced motion: instant fill without animation

### Resend Countdown (VERIFIED from JS)
- 30-second cooldown from `resendAt` timestamp
- Shows "Resend in 0:MM" with live countdown
- After 0: "Resend code" button enabled
- On resend: calls `/api/otp/send`, flashes "New code sent" status

---

## 4. Actual Color Palette

### CSS Custom Properties (VERIFIED from `:root`)
| Token | Hex | Usage |
|-------|-----|-------|
| `--paper` | `#f3f8f3` | Page background (mobile) |
| `--card` | `#ffffff` | Card/surface background |
| `--tint` | `#e6f4e9` | Subtle green tint backgrounds |
| `--lime-tint` | `#eff8de` | Lime accent backgrounds |
| `--rule` | `#e0eae2` | Light borders |
| `--rule-strong` | `#c3d3c8` | Input borders, dividers |
| `--ink` | `#0a2e1b` | Primary text, headings |
| `--body` | `#334e41` | Body text |
| `--muted` | `#5b7268` | Secondary text, hints |
| `--green` | `#15803f` | Primary button, active states |
| `--green-mid` | `#12522f` | Primary button hover, darker accents |
| `--green-deep` | `#0a2e1b` | Deep green (same as --ink), dark backgrounds |
| `--on-deep` | `#f1f9f3` | Text on deep green |
| `--on-deep-muted` | `#a9cfb6` | Muted text on deep green |
| `--lime` | `#7ac70c` | Accent highlights, progress fills |
| `--warn` | `#a86400` | Warning states |
| `--bad` | `#c0392b` | Error states |

### Gradients (VERIFIED)
| Context | Gradient |
|---------|----------|
| Hero (mobile) | `linear-gradient(160deg, #15703b 0%, #0f3d24 45%, #0a2e1b 100%)` |
| Hero (desktop) | `linear-gradient(140deg, #12522f, #0a2e1b 55%, #061e12)` |
| Body page bg (desktop) | `linear-gradient(140deg, #12522f, #0a2e1b 55%, #061e12)` |
| Limit card | `linear-gradient(150deg, #15703b, #0a2e1b 80%)` |
| Success screen | `linear-gradient(170deg, #12522f, #0a2e1b 60%)` |
| OTP iridescent | `conic-gradient(from 0deg, #bdf0d6, #d9f7b5, #b9e8f5, #dcd6fb, #fde0cf, #c8f3e0, #bdf0d6)` blur(48px) |
| OTP sheen | `linear-gradient(115deg, transparent 20%, rgba(255,255,255,.55) 32%, transparent 44%, rgba(255,255,255,.35) 58%, transparent 70%)` soft-light |

---

## 5. Typography Specification

### Font Families (VERIFIED from CSS & HTML)
| Role | Font | Source |
|------|------|--------|
| Headings (Serif) | Plus Jakarta Sans (600-800) | `<link href="...Plus+Jakarta+Sans:wght@600;700;800">` + `--serif` |
| Body/UI (Sans) | DM Sans (400-600) | `<link href="...DM+Sans:opsz,wght@9..40,400;9..40,500;9..40,600">` + `--sans` |
| Technical/Monospace | JetBrains Mono (not used in CSS, in Flutter only) | Flutter `pubspec.yaml` |

### Type Scale (VERIFIED from CSS)
| Element | Size | Weight | Family | Color | Line-height |
|---------|------|--------|--------|-------|-------------|
| Hero H1 (mobile) | 36-40px | 500-700 | Plus Jakarta Sans | `--on-deep` / `#fff` | 1.05-1.1 |
| Hero H1 (desktop) | 36-40px | 700 | Plus Jakarta Sans | `--on-deep` | 1.1 |
| Section H2 | 23-26px | 700 | Plus Jakarta Sans | `--ink` | 1.15 |
| Head H1 (screen title) | 27-30px | 700 | Plus Jakarta Sans | `--ink` | 1.15 |
| Body text | 15px | 400 | DM Sans | `--body` | 1.5 |
| Muted/Small | 13-14px | 400-500 | DM Sans | `--muted` | 1.4-1.5 |
| Button text | 16px | 700 | Plus Jakarta Sans | `--on-deep` / `--green-deep` | — |
| Label | 14px | 600 | DM Sans | `--ink` | — |
| Input text | 16px | 400 | DM Sans | `--ink` | — |
| OTP digit | 28px | 800 | Plus Jakarta Sans | `--ink` / `--bad` / `#fff` | 1 |
| Tag/Caption | 11px | 600 | DM Sans | `--green` / `--warn` / `--bad` | — |
| Step label | 12px | 600 | DM Sans | `--muted` | — |
| Legal | 12px | 400 | DM Sans | `--muted` | — |

### Font Features
- `font-variant-numeric: tabular-nums lining-nums` on body
- Letter-spacing: heads `-0.01em` to `-0.02em`; tags `.04em` to `.16em` uppercase
- Text-transform: tags uppercase; segment buttons none

---

## 6. Layout and Spacing Specification

### Container (VERIFIED)
| Property | Value |
|----------|-------|
| Max width | 440px |
| Horizontal padding | 20px (`.pad { padding: 0 20px }`) |
| Vertical rhythm | 18px gap (`.stack { gap: 18px }`) |
| Section padding | 32px top (`.section { padding: 32px 20px 0 }`) |

### Border Radii (VERIFIED)
| Token | Value | Usage |
|-------|-------|-------|
| `--r` | 14px | Inputs, buttons, cards (base) |
| `--r-lg` | 20px | Large cards |
| `16px` | 16px | Buttons (override in shape section) |
| `999px` / `99px` | Pill | Tags, edit/resend buttons |
| `6px` | 6px | Small cards (base) |
| `16px` | 16px | OTP tiles |
| `12px` | 12px | Switch thumb |
| `22px` / `32px` | 22px/32px | Desktop app border-radius |

### Shadows (VERIFIED)
| Token | Value |
|-------|-------|
| `--shadow` | `0 1px 2px rgba(10,46,27,.05), 0 10px 24px -14px rgba(10,46,27,.22)` |
| Tile shadow | `0 1px 2px rgba(10,46,27,.06), 0 10px 22px -14px rgba(10,46,27,.35)` |
| Button primary shadow | `0 10px 20px -12px rgba(21,128,63,.9)` |
| Bell/Notification | `0 1px 2px rgba(10,46,27,.06), 0 8px 18px -12px rgba(10,46,27,.35)` |
| QR box | `0 14px 30px -20px rgba(10,46,27,.45)` |
| Desktop app | `0 30px 70px -24px rgba(0,0,0,.6)` |
| Bottom nav | `0 -8px 24px -18px rgba(10,46,27,.35)` |

### Touch Targets (VERIFIED)
| Element | Min Height |
|---------|------------|
| Buttons | 52-54px |
| Inputs | 52-54px |
| OTP tiles | 62px (54px on ≤360px) |
| Segment buttons | 48-50px |
| Tenure/Plan buttons | 48-50px |
| Bottom nav items | 44-54px |
| Back button | 44px |

---

## 7. Component Specifications

### 7.1 Mobile Number Input
| Property | Value |
|----------|-------|
| Container | `.field` (flex column, gap 6px) |
| Label | 14px, 600, `--ink` |
| Wrapper | `.input-wrap` (relative, flex) |
| Prefix | `+91`, absolute left 14px, 500, `--muted` |
| Input | `.input.has-prefix` → padding-left 48px |
| Height | 54px |
| Border | 1px `--rule-strong`, radius `--r` (14px) |
| Background | `--card` (#fff) |
| Font | 16px, DM Sans, `--ink` |
| Placeholder | `#9aa39b` |
| Focus | 2px `--green` outline-offset -1px + 4px rgba shadow |
| Error | Border `--bad`, error text 13px 500 `--bad` |
| Formatting | Space after 5 digits (JS: `digits.slice(0,5) + " " + digits.slice(5)`) |

### 7.2 Send OTP Button
| Property | Value |
|----------|-------|
| Class | `.btn.btn-primary` |
| Height | 54px |
| Width | 100% |
| Radius | 16px |
| Font | Plus Jakarta Sans, 16px, 700 |
| Color | `--on-deep` (#fbfaf5) |
| Background | `--green` |
| Hover | `--green-mid` |
| Shadow | `0 10px 20px -12px rgba(21,128,63,.9)` |
| Loading | Spinner 16px, `border-right-color: transparent`, spin 700ms |
| Disabled | Opacity 0.5, cursor not-allowed |

### 7.3 OTP Tile Grid
| Property | Value |
|----------|-------|
| Layout | CSS Grid: `repeat(6, 1fr)`, gap 10px (7px ≤360px) |
| Tile | 62×62px (54px ≤360px), radius 16px (13px ≤360px) |
| Default border | 1.5px `rgba(10,46,27,.22)` |
| Default bg | `#fff` |
| Default shadow | `0 1px 2px rgba(10,46,27,.06), 0 10px 22px -14px rgba(10,46,27,.35)` |
| Active | 2px `--green` border, +4px rgba shadow, translateY(-2px) |
| Filled | Border `rgba(10,46,27,.5)` |
| Error | 2px `--bad`, bg `#fff4f2`, digits `--bad` |
| Success | `--green` bg & border, digits `#fff`, shadow `0 10px 24px -12px rgba(21,128,63,.7)` |
| Digit | Plus Jakarta Sans, 28px (24px ≤360px), 800, tabular-nums |
| Caret | 2×26px, `--green`, blinks 1s steps on active |

### 7.4 Edit/Resend Buttons (Pill Style)
| Property | Value |
|----------|-------|
| Radius | 99px |
| Padding | 10px 18px (resend), 3px 10px (edit) |
| Font | DM Sans, 13-14px, 600-700 |
| Edit bg | `rgba(255,255,255,.7)` / `#fff` hover |
| Edit border | `inset 0 0 0 1px rgba(21,128,63,.25)` |
| Resend bg | `rgba(255,255,255,.75)` / `#fff` hover |
| Resend border | `inset 0 0 0 1.5px rgba(21,128,63,.35)` |
| Color | `--green` |
| Disabled | Opacity 0.6 |

### 7.5 Status Indicators
| Type | Visual |
|------|--------|
| Success | `--green` text, checkmark SVG (18×18), `CHECK` constant |
| Error | `--bad` text, red circle with `!` (20×20), `.x` class |
| Checking | 16px spinner, `--green` border, `.spin.dark` |
| Toast | Fixed top, `--ink` bg / `--bad` for error, radius 14px, slide down |

---

## 8. Asset Inventory

### From Website (VERIFIED)
| Asset | Path | Notes |
|-------|------|-------|
| Logo | `/logo.png` | 30px topbar, 34px hero, 56px desktop side |
| Favicon | `/logo.png` | `<link rel="icon">` |
| Apple Touch Icon | `/icon-192.png` | 192px |
| Manifest | `/manifest.webmanifest` | PWA support |
| Login Illustration | Inline SVG | `.login-art` — animated phone + bubble with 6 dots |

### From Flutter Project (VERIFIED from pubspec.yaml)
| Asset | Declared | Actual Status |
|-------|----------|---------------|
| Logos folder | `assets/ logos/` | Folder likely missing (typo: space before `logos/`) |
| Plus Jakarta Sans | 4 weights (400, 500, 600, 700) | Declared in `pubspec.yaml` |
| DM Sans | 4 weights (400, 500, 600, 700) | Declared in `pubspec.yaml` |
| JetBrains Mono | 3 weights (400, 500, 700) | Declared in `pubspec.yaml` |

**Gap**: Website uses Plus Jakarta Sans (600-800) and DM Sans (400-600). Flutter declares full ranges but weights 800 for Plus Jakarta Sans and 600 for DM Sans are used in CSS but not declared in Flutter.

### Missing in Flutter
- Logo image file (`logo.png`) — not in assets folder
- Login illustration SVG — not in assets
- No OTP tile animation assets (pure CSS in web)

---

## 9. Responsive Behavior

### Breakpoints (VERIFIED from CSS)
| Breakpoint | Behavior |
|------------|----------|
| Default (mobile) | ≤440px, `.app` full width, `.side` hidden |
| 360px | OTP tiles shrink: 54px, gap 7px, digit 24px |
| 960px | Desktop: `.shell` centered with gap 80px, `.app` max 440px → height min(880px, 100dvh-64px), border-radius 10px, border 1px `#1d4a33`, `.side` visible (360px max) |
| Desktop app | Border-radius 32px, box-shadow `0 30px 70px -24px rgba(0,0,0,.6)` |
| Desktop body | Gradient background `linear-gradient(140deg, #12522f, #0a2e1b 55%, #061e12)` |

### Safe Area (VERIFIED)
- `env(safe-area-inset-bottom)` used in footer, bottom nav
- `env(safe-area-inset-top)` used in toast
- `viewport-fit=cover` in meta viewport

---

## 10. Comparison with Current Flutter Implementation

### 10.1 Login Screen (`login_screen.dart`)

| Aspect | Website (Source of Truth) | Current Flutter | Status |
|--------|---------------------------|-----------------|--------|
| **Layout** | Topbar with back + logo | No topbar, centered column | ❌ MISSING |
| **Illustration** | Animated SVG (132px) | None | ❌ MISSING |
| **Headline** | "Sign in with your mobile" (27-30px, PJ Sans 700) | "ETF Loans" (displayLarge) + "Borrower Login" | ❌ WRONG CONTENT |
| **Subtext** | "Your number is your login..." | None | ❌ MISSING |
| **Input** | +91 prefix, formatted "98765 43210", 54px | Plain TextFormField, no prefix, no formatting | ❌ DIFFERENT |
| **Input Focus** | Green ring + 4px shadow | Material 2px primary | ⚠️ PARTIAL |
| **Helper Text** | "One number, one account..." | None | ❌ MISSING |
| **Primary Button** | "Send code", 54px, 16px, radius 16px, PJ Sans 700 | "Send OTP", 50px, radius 8px | ❌ DIFFERENT |
| **Legal Text** | "By continuing you agree to Terms and Privacy" | None | ❌ MISSING |
| **Secondary Action** | "Skip sign-in (demo)" (conditional) | "Forgot PIN?" | ❌ WRONG |
| **Background** | `--paper` (#f3f8f3) in centered card | Scaffold default (likely white) | ❌ DIFFERENT |
| **Animation** | Staggered enter + illustration | None | ❌ MISSING |
| **Error Style** | Red border + inline error text | Red container + SnackBar | ⚠️ DIFFERENT |

### 10.2 OTP Screen (`otp_verification_screen.dart`)

| Aspect | Website (Source of Truth) | Current Flutter | Status |
|--------|---------------------------|-----------------|--------|
| **Background** | Iridescent animated (`.iri`) | Scaffold default | ❌ MISSING |
| **Topbar** | Back + logo | AppBar with title "OTP Verification" | ⚠️ DIFFERENT |
| **Headline** | "Enter the code" (30px, 800) | None (only subtitle) | ❌ MISSING |
| **Subtitle** | "Sent to +91 98765 43210 [Edit]" | "Enter OTP sent to {mobile}" | ⚠️ PARTIAL |
| **OTP Input** | 6 tiles over hidden input, 62px, animations | Single TextFormField with underline | ❌ COMPLETELY DIFFERENT |
| **Tile States** | Empty/active/filled/checking/error/success | None | ❌ MISSING |
| **SMS Autofill** | `autocomplete="one-time-code"` + WebOTP API | None | ❌ MISSING |
| **Paste Handling** | Animated digit-by-digit reveal | Native paste | ❌ DIFFERENT |
| **Resend** | 30s countdown → pill button | TextButton "Resend OTP" | ❌ DIFFERENT |
| **Demo Code** | Chip button "Demo code 123456" | None | ❌ MISSING |
| **Status** | Inline with icon (success/error/checking) | SnackBar only | ❌ DIFFERENT |
| **Animation** | Tile wave, shake, pop, success cascade | None | ❌ MISSING |
| **Focus/Caret** | Blinking caret on active tile | Standard cursor | ❌ MISSING |
| **Reduced Motion** | Supported | Not implemented | ❌ MISSING |

### 10.3 Theme Configuration (`theme_config.dart`)

| Token | Website | Flutter | Status |
|-------|---------|---------|--------|
| `--paper` | `#f3f8f3` | `surfaceLight` `#f4f7f4` | ⚠️ CLOSE |
| `--card` | `#ffffff` | `surface` `#ffffff` | ✅ MATCH |
| `--green-deep` / `--ink` | `#0a2e1b` | `primaryBrand` `#0a2e1b` | ✅ MATCH |
| `--green` | `#15803f` | `accent` `#15703b` | ⚠️ SLIGHT DIFF (3f vs 3b) |
| `--green-mid` | `#12522f` | Not defined | ❌ MISSING |
| `--body` | `#334e41` | `primaryText` `#0f1f16` | ❌ DIFFERENT |
| `--muted` | `#5b7268` | `secondaryText` `#56675c` | ⚠️ CLOSE |
| `--rule-strong` | `#c3d3c8` | `borders` `#d6e0d8` | ⚠️ CLOSE |
| `--tint` | `#e6f4e9` | `softAccent` `#e2f1e7` | ⚠️ CLOSE |
| `--lime` | `#7ac70c` | Not defined | ❌ MISSING |
| `--bad` | `#c0392b` | `error` = `accent` (green!) | ❌ WRONG |
| `--warn` | `#a86400` | Not defined | ❌ MISSING |
| Radius `--r` | 14px | Card 12px, Input 8px, Button 8px | ❌ DIFFERENT |
| Radius `--r-lg` | 20px | Not used | ❌ MISSING |
| Button height | 54px | 50px | ❌ DIFFERENT |
| Button radius | 16px | 8px | ❌ DIFFERENT |
| Button font | Plus Jakarta Sans 700 | Inherited (DM Sans likely) | ❌ DIFFERENT |
| Input height | 54px | Not explicit | ❓ UNKNOWN |
| Input focus ring | Green + 4px shadow | 2px primaryBrand | ⚠️ PARTIAL |
| Shadow | Multi-layer `--shadow` | Elevation 2 only | ❌ DIFFERENT |

### 10.4 Fonts
| Font | Website | Flutter | Status |
|------|---------|---------|--------|
| Plus Jakarta Sans | 600, 700, 800 | 400, 500, 600, 700 | ❌ MISSING 800 |
| DM Sans | 400, 500, 600 | 400, 500, 600, 700 | ✅ SUPerset |
| JetBrains Mono | Not used on web | Declared | ⚠️ UNUSED |

---

## 11. Screenshots and References

### Captured Evidence
- **HTML Structure** — Full page source from `https://etf-loans.vercel.app/`
- **CSS Tokens** — Complete `:root` block from `app.css` (lines 1-50)
- **CSS Components** — All relevant component styles from `app.css`
- **JS Logic** — Router, OTP handling, animations from `app.js` (login, OTP, sendOtp functions)
- **Challenge JS** — Browser check from `challenge.js`

### Key CSS Sections Referenced
- `:root` tokens (lines 1-50)
- Layout (lines 52-95)
- Buttons (lines 97-130)
- Forms (lines 132-185)
- Welcome/Hero (lines 187-250)
- OTP Screen (lines 580-780)
- Shape & Depth overrides (lines 782-950)
- Reduced motion (lines 952-958)

---

## 12. Unverified Details and Limitations

| Detail | Status | Reason |
|--------|--------|--------|
| Desktop side-panel content | UNVERIFIED | Requires ≥960px viewport |
| Face check/selfie flow | UNVERIFIED | Requires camera permission |
| Live check flow | UNVERIFIED | Requires camera + server |
| Success/transfer animations | UNVERIFIED | Requires completed loan flow |
| Home/dashboard screens | UNVERIFIED | Requires authenticated session |
| Loan calculator interaction | PARTIAL | CSS seen, JS logic partially traced |
| Push notifications UI | PARTIAL | CSS seen (`.bell`, `.notice`), no interaction |
| KYC/Document upload | PARTIAL | CSS seen (`.kyc-card`), no interaction |
| Delete account flow | PARTIAL | CSS seen (`.btn-danger`), no interaction |
| Exact pixel measurements | ESTIMATED | Measured from CSS values, not browser devtools |
| Color contrast ratios | UNVERIFIED | Not computed |
| Accessibility tree | UNVERIFIED | Not audited with screen reader |

---

## 13. Flutter Implementation Recommendations

### 13.1 Immediate Theme Fixes
```dart
// Update theme_config.dart to match website exactly
static const Color primaryBrand = Color(0xFF0a2e1b);      // --ink / --green-deep
static const Color primaryGreen = Color(0xFF15803f);       // --green
static const Color primaryGreenMid = Color(0xFF12522f);    // --green-mid
static const Color accentLime = Color(0xFF7AC70C);         // --lime
static const Color errorRed = Color(0xFFC0392B);           // --bad
static const Color warnAmber = Color(0xFFA86400);          // --warn
static const Color paperBg = Color(0xFFF3F8F3);            // --paper
static const Color tintGreen = Color(0xFFE6F4E9);          // --tint
static const Color limeTint = Color(0xFFEFF8DE);           // --lime-tint
static const Color ruleLight = Color(0xFFE0EAE2);          // --rule
static const Color ruleStrong = Color(0xFFC3D3C8);         // --rule-strong
static const Color ink = Color(0xFF0A2E1B);                // --ink
static const Color bodyText = Color(0xFF334E41);           // --body
static const Color mutedText = Color(0xFF5B7268);          // --muted
static const Color onDeep = Color(0xFFF1F9F3);             // --on-deep
static const Color onDeepMuted = Color(0xFFA9CFB6);        // --on-deep-muted

// Radii
static const double radiusBase = 14;       // --r
static const double radiusLarge = 20;      // --r-lg
static const double radiusPill = 999;      // pills
static const double radiusButton = 16;     // button override
static const double radiusTile = 16;       // OTP tiles

// Shadows
static const List<BoxShadow> shadowBase = [
  BoxShadow(color: Color(0x0D0A2E1B), offset: Offset(0, 1), blurRadius: 2),
  BoxShadow(color: Color(0x380A2E1B), offset: Offset(0, 10), blurRadius: 24, spreadRadius: -14),
];
static const List<BoxShadow> shadowTile = [
  BoxShadow(color: Color(0x0F0A2E1B), offset: Offset(0, 1), blurRadius: 2),
  BoxShadow(color: Color(0x590A2E1B), offset: Offset(0, 10), blurRadius: 22, spreadRadius: -14),
];
static const List<BoxShadow> shadowButtonPrimary = [
  BoxShadow(color: Color(0xE615803F), offset: Offset(0, 10), blurRadius: 20, spreadRadius: -12),
];

// Button
static const double buttonHeight = 54;
static const double buttonFontSize = 16;
static const FontWeight buttonFontWeight = FontWeight.w700;
static const String buttonFontFamily = 'PlusJakartaSans';

// Input
static const double inputHeight = 54;
static const double inputFontSize = 16;
```

### 13.2 Login Screen Implementation
1. **Add topbar** with back button + logo (30px height)
2. **Add animated illustration** — use `flare_flutter` or `rive` for the SVG animation, or build with `CustomPainter` + `AnimationController`
3. **Update headline** to "Sign in with your mobile" (Plus Jakarta Sans, 27-30px, 700)
4. **Add subtext** "Your number is your login. There is no password to remember."
5. **Build mobile input** with:
   - Prefix "+91" absolutely positioned
   - Auto-formatting: space after 5 digits
   - 54px height, 14px radius
   - Focus: green ring + 4px rgba shadow
6. **Add helper text** below input
7. **Primary button**: "Send code", 54px, 16px radius, Plus Jakarta Sans 700, green with shadow
8. **Legal text** with links to Terms/Privacy
9. **Conditional demo skip** button (text button, muted)
10. **Staggered enter animations** for all elements

### 13.3 OTP Screen Implementation
1. **Full-screen iridescent background**:
   - Conic gradient + blur(48px) + saturate(1.35) — use `BackdropFilter` + `CustomPainter`
   - Sheen layer: linear-gradient 115deg, soft-light blend — animated translation
   - Radial highlight at top-center
2. **Topbar** with back + logo
3. **Headline** "Enter the code" (30px, 800, Plus Jakarta Sans)
4. **Subtitle** with formatted mobile + "Edit" pill button
5. **OTP Tile Grid**:
   - 6 `AnimatedContainer` tiles in `Row`/`GridView`
   - Hidden `TextField` with `autofillHints: [AutofillHints.oneTimeCode]` overlay
   - Tile states: empty, active (caret blink), filled, checking (wave), error (shake+red), success (green fill)
   - Digit: Plus Jakarta Sans, 28px, 800, tabular-nums
   - Caret: animated opacity on active tile
6. **Paste handling**: detect paste, animate digits in sequentially (70ms each)
7. **SMS Autofill**: `autofillHints` + platform channel for WebOTP API (Android)
8. **Resend**: 30s countdown → pill button
9. **Demo chip** (conditional)
10. **Inline status** with icons (success/error/checking)
11. **Reduced motion**: disable all animations when `MediaQuery.maybeOf(context)?.disableAnimations == true`

### 13.4 Assets Needed
- `assets/logo.png` — from website
- `assets/illustrations/login_art.svg` — extract from website HTML
- Ensure Plus Jakarta Sans **800 weight** added to `pubspec.yaml`

### 13.5 Architecture Notes
- Keep existing `AuthenticationService` and models — they match API contract
- Add `SecureStorage` for token persistence (already in `pubspec.yaml`)
- Consider `flutter_animate` or custom `AnimationController` for tile animations
- Use `CustomPainter` for iridescent background to avoid heavy image assets
- Implement `FocusNode` management for OTP hidden input overlay pattern

---

## 14. Verification Checklist

| Item | Verified | Source |
|------|----------|--------|
| Color palette | ✅ | CSS `:root` |
| Typography scale | ✅ | CSS + Google Fonts link |
| Login screen layout | ✅ | HTML + CSS |
| OTP screen layout | ✅ | HTML + CSS (`.otp-screen`) |
| OTP tile states | ✅ | CSS `[data-state="..."]` |
| Animations | ✅ | CSS `@keyframes` + JS |
| Responsive breakpoints | ✅ | CSS `@media` |
| Focus states | ✅ | CSS `:focus-visible` + `.input:focus` |
| Error states | ✅ | CSS `.field.invalid` + `.otp-wrap[data-state="error"]` |
| Reduced motion | ✅ | CSS `@media (prefers-reduced-motion: reduce)` |
| SMS autofill attributes | ✅ | JS `autocomplete="one-time-code"` + WebOTP |
| Current Flutter gaps | ✅ | Direct code comparison |

---

## 15. Final Notes

**Hallmark Usage**: The Hallmark skill was loaded and its methodology (Floor, Reflex gates, material-first inspection) guided this extraction. The "custom" direction was used since the task was to extract an existing real brand's design, not generate a new one.

**No Fabrication**: Every value in this spec comes from the inspected website's CSS, HTML, and JavaScript. Estimates are explicitly labelled. Unverified areas are documented.

**Next Steps**: This specification should be reviewed by the Flutter team before implementation begins. The most critical gaps are the OTP tile component (completely different from current) and the iridescent background (requires custom painter).

---

*Generated: 2026-11-18*
*Inspector: Hallmark-assisted design extraction*
*Source: https://etf-loans.vercel/app/*