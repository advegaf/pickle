# PICKLE

A premium native iOS calorie and macro tracker. SwiftUI, iPhone-only, styled after the Equinox+ app
(pure black, Helvetica Neue, sharp corners). Built for the fastest possible log: the category's real
killer is logging friction, not motivation.

Status: v1 is feature complete and runs on device. Local-first; the paid/sync layer is pre-launch
(see Roadmap).

## What it does

- **Home** — a kcal-remaining ring (turns red when you go over), macro bars, today's meals, a floating Log pill.
- **Log** (5 ways) — Recents (one-tap re-log), Search (Open Food Facts + a bundled ~80-item common-foods set), barcode Scan (VisionKit), AI photo + text estimate (Claude), and Quick add (raw kcal/P/C/F).
- **Explore** — curated, one-tap-loggable **recipes** and category browsing.
- **Coach** — an adaptive weekly target (a poor-man's MacroFactor from logged intake + weight trend), plan transparency, and an AI "your coach" card that reads your patterns.
- **Activity** — month calendar with day-states, streak, stats, per-day detail.
- **More** — Goals & Plan, Apple Health, Favorites, Custom Foods, Loved Meals (save a meal section as a reusable bundle), Export (CSV/JSON), About.
- **WidgetKit** — lock + home-screen kcal ring, reads a shared App Group snapshot.

## Stack

- SwiftUI + **SwiftData** (`@Model`, local-first; CloudKit-compatible, sync currently off).
- **XcodeGen** generates `Pickle.xcodeproj` from `project.yml` (the `.xcodeproj` is gitignored).
- Icons: Hugeicons (stroke-rounded) as template PDFs, plus a few Lucide glyphs.
- iOS 18 deployment target. Targets: `Pickle` (app), `PickleWidgetExtension`, `PickleTests`, `PickleUITests`. Shared snapshot code in `Shared/`.

## Build & run

```bash
# 1. Secrets (the real key never gets committed)
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # then fill ANTHROPIC_API_KEY for AI logging (optional; mock otherwise)

# 2. Generate the project
/opt/homebrew/bin/xcodegen generate

# 3. Build + test on the simulator
xcodebuild -project Pickle.xcodeproj -scheme Pickle \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/pickle-dd CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test
```

DEBUG launch args for the screenshot loop: `--seed`, `--seed-empty`, `--seed-over`, `--reset`,
`--tab N`, `--open log|ai|quick|detail|recipe|more-<route>`.

Tests: 72 unit tests + a position-faithful More-routing UI test.

## Roadmap (before charging)

Freemium subscription is the plan (Pro = AI logging + adaptive coach + iCloud sync). Hard blockers
before taking money:

1. **Proxy** — move the Anthropic key server-side (Cloudflare Worker + per-device rate limit). It currently ships in the binary for local testing only.
2. **StoreKit 2 paywall + gating.**
3. **Legal** — privacy policy + terms, App Store privacy labels, AI/health disclaimer, in-app data deletion.
4. **iCloud sync on** + two-device validation (data durability for paying users).

Then: on-device QA (barcode / HealthKit / widget), crash reporting, re-engagement notifications.

## Privacy

Diary and health data stay on device (and in your iCloud once sync is on). The one exception is AI
logging: a described or photographed meal is sent to the AI service to estimate macros, then
discarded. `Config/Secrets.xcconfig` and the reference frames are gitignored.
