# PICKLE

A premium native iOS calorie and macro tracker. SwiftUI, iPhone-only, true-OLED-black with a
white/gray monochrome chrome; color is earned, not painted: a progressive Whoop-graded calorie
gauge (white -> green -> yellow -> orange, red only when over), natural-color food photography,
and one warm accent for goal moments. Built for the fastest possible log: the category's real
killer is logging friction, not motivation.

Status: v1.5 (post-redesign) is feature complete, sim-verified, pre-TestFlight. Local-first;
the AI proxy is scaffolded (`proxy/`, deploy pending) and sync stays off until after launch.

## What it does

- **Home** — greeting header with reminders bell, a navigable week strip (tap a day; logging on a
  past day backfills to that day), a 270-degree progressive calorie gauge with a glass lens knob,
  monochrome macro cards, a **Predicted meal** card (local heuristic: your usual next meal, one tap
  to log), today's meals, quick links.
- **Log** (5 ways, from ANY tab via the floating bar) — Recents (one-tap re-log), Search (Open Food
  Facts + a bundled ~80-item common-foods set), barcode Scan (VisionKit), AI photo + text estimate
  (Claude via the proxy; realistic mock until it's deployed), and Quick add (raw kcal/P/C/F).
- **Meal reminders** — real local notifications with generic lock-screen copy (never food names),
  per-meal times, auto-skip for meals you already logged, tap -> Log sheet on that meal.
- **Explore** — curated, one-tap-loggable **recipes** (natural-color photography) and categories.
- **Coach** — an adaptive weekly target (a poor-man's MacroFactor from logged intake + weight
  trend), plan transparency, and an AI "your coach" card that reads your patterns.
- **Activity** — month calendar with day-states, streak, stats, per-day detail.
- **More** — Goals & Plan, Apple Health, Favorites, Custom Foods, Loved Meals, Export (CSV/JSON),
  About (with a DEBUG median seconds-to-log readout: the north-star metric, measured).
- **WidgetKit** — lock + home-screen calorie arcs with the same progressive ramp, macros widget,
  shared App Group snapshot.

## Stack

- SwiftUI + **SwiftData** (`@Model`, local-first; CloudKit-compatible, sync currently off).
- **XcodeGen** generates `Pickle.xcodeproj` from `project.yml` (the `.xcodeproj` is gitignored).
- Design system: single token funnel (`Shared/PaletteValues.swift` -> app `Palette` + widget `W`,
  drift is a compile error), SF Pro with Dynamic Type preserved via UIFontMetrics scaling,
  Liquid Glass cards/bar (iOS 26), WCAG contrast gates enforced by unit tests.
- Icons: Hugeicons (stroke-rounded) as template PDFs, plus a few Lucide glyphs.
- **iOS 26** deployment target. Targets: `Pickle` (app), `PickleWidgetExtension`, `PickleTests`,
  `PickleUITests`. Shared snapshot + palette code in `Shared/`. AI proxy Worker in `proxy/`.

## Build & run

```bash
# 1. Secrets (no key ever gets committed; production uses the proxy)
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig

# 2. Generate the project
/opt/homebrew/bin/xcodegen generate

# 3. Build + test on the simulator
xcodebuild -project Pickle.xcodeproj -scheme Pickle \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/pickle-dd CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test
```

DEBUG launch args for the screenshot loop: `--seed`, `--seed-empty`, `--seed-over`, `--reset`,
`--tab N`, `--open log|ai|quick|detail|widgets|more-<route>`.

Tests: 121 unit tests (store logic, prediction engine, reminder scheduling, week math, WCAG
contrast + ramp gates) + UI tests for More-tab routing and horizontal-pan regressions.

## Ship track (in progress)

1. **Device verification pass** — glass scroll performance, reminders end-to-end, widgets on the
   springboard (signed build ready; waiting on hardware).
2. **Deploy the proxy** (`proxy/README.md`) — moves the Anthropic key fully server-side and turns
   on real AI logging. Fast follows tracked in TODOS.md (rate limiting, USDA search passthrough).
3. **TestFlight** — Release archive verified; CloudKit stays off for the first build.

Before charging (later): StoreKit 2 paywall, legal (privacy policy/terms/labels), iCloud sync on
with two-device validation. See TODOS.md for the full deferred list.

## Privacy

Diary and health data stay on device (and in your iCloud once sync is on). Notifications never
show food names on the lock screen. The one exception to on-device: AI logging sends the described
or photographed meal to the AI service to estimate macros, then discards it. `Config/Secrets.xcconfig`
and the reference frames are gitignored.
