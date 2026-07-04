# TODOS

Deferred items with context. Effort scale: human team -> with Claude Code.

## From the Glow redesign review (2026-07-03)

- [ ] **App icon refresh to the Glow brand** (P2, S)
  The redesign pivots the app to the dark-teal Glow language but the icon still wears the old brand. Needs actual asset design (not just code), so it was cut from the redesign batch. Start: `Pickle/Resources/Assets.xcassets/AppIcon.appiconset`.

- [ ] **WeekStrip per-day mini progress ticks** (P3, S)
  A tiny per-day progress indicator inside each week-strip pill (beyond the logged-day dot). Cut for visual-noise risk; revisit after living with the shipped strip. Start: `Pickle/DesignSystem/Components/WeekStrip.swift`.

- [ ] **Photo avatar** (P3, M)
  Header avatar is an initials monogram. A photo avatar needs image storage, a picker, and delete-all-data handling. Start: `HomeView` header + `ProfileView.identity`.

- [ ] **Smarter reminder suppression** (P3, S)
  V1 cancels a meal's remaining fire for today when that meal is logged and reschedules a one-shot for tomorrow. If redundant reminders still slip through in practice (edge: logging within the fire minute), move to fully non-repeating 7-day scheduling refreshed on each app open. Start: `Pickle/Services/ReminderService.swift`.

- [x] **Remove ANTHROPIC_API_KEY from Info.plist** — DONE 2026-07-04. The key lives only in a Cloudflare Worker secret; `PickleAnthropicKey` injection deleted from project.yml; built Info.plist verified clean.

## From the ship track (2026-07-04)

- [ ] **Proxy abuse protection** (P1, S)
  The Worker ships with no auth. Add rate limiting (Cloudflare WAF rule or KV counter) and/or DeviceCheck/App Attest before any build reaches strangers. Start: `proxy/src/index.ts`.

- [ ] **USDA FDC /search behind the proxy** (P2, M)
  FoodSearchService currently skips USDA ("lives behind the proxy... until the proxy exists"). Add a `/search` passthrough in the Worker + the app-side code path. Start: `Pickle/Services/FoodSearchService.swift`, `proxy/src/index.ts`.

## Pre-existing (from v1)

- [x] **Deploy Cloudflare Worker proxy** — DONE 2026-07-04. Live at pickle-proxy.advegaf.workers.dev; real AI logging verified end-to-end in-app. (USDA /search passthrough still tracked above.)
- [ ] **Flip CloudKit on** (P2, S) - `AppConfig.useCloudKit` + iCloud entitlement, needs paid dev account context.
- [ ] **On-device verification pass** (P2, S) - barcode camera, HealthKit, CloudKit sync, widgets (App Group doesn't provision on unsigned sim builds).
- [ ] **Real curated photography** (P3, M) - replace remaining `DuotonePlaceholder` uses.
