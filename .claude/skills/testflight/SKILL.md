---
name: testflight
description: Ship a new PICKLE build to TestFlight end to end - bump the build number, run the test gate, archive, upload via App Store Connect, tag it, and hand back the exact App Store Connect follow-ups (version, build, What's New draft, where to click). Use when the user says "ship to TestFlight", "cut a new build", "upload a build", "push to TestFlight", or "/testflight".
---

# /testflight - one-command TestFlight release for PICKLE

This is the repeatable ship pipeline for this repo. Run it top to bottom. Every command
here is real and tuned to this project. Do not improvise a different toolchain.

## Arguments

- `/testflight` - bump the build number by 1, keep the marketing version. The normal case.
- `/testflight 1.1` (any `X.Y` / `X.Y.Z`) - also set MARKETING_VERSION to that. The build
  number still only ever increments (never resets on a version change - App Store Connect
  rejects a build number it has seen before under the same version train).
- `/testflight fast` - run only the unit tests at the gate (skip the UI tests). Use when
  you already ran the full suite this session and only touched non-UI code.

## Fixed facts about this project (do not re-derive)

- XcodeGen project: `Pickle.xcodeproj` is git-ignored and regenerated from `project.yml`.
  ALWAYS `xcodegen generate` after editing `project.yml`.
- Scheme: `Pickle`. It archives Release by default. App bundle: `com.angelvega.pickle`;
  widget extension target `PickleWidgetExtension` (`com.angelvega.pickle.widget`).
- Version source of truth: `project.yml` base settings -> `MARKETING_VERSION` and
  `CURRENT_PROJECT_VERSION`. Both the app and widget Info.plists inherit these via
  `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`, so bumping the base value is the
  only edit needed.
- Export config already exists and is correct: `Config/ExportOptions.plist`
  (`method=app-store-connect`, `destination=upload`, `teamID=DV483F72N3`,
  `manageAppVersionAndBuildNumber=true`). Reuse it verbatim. Never edit it as part of a ship.
- Signing is Automatic, team `DV483F72N3` (Individual, paid). `-allowProvisioningUpdates`
  lets `xcodebuild` fetch the cloud-managed Apple Distribution cert even though only an
  Apple Development cert is in the local keychain. `ITSAppUsesNonExemptEncryption=false`
  is already in the app Info.plist, so TestFlight asks no export-compliance question.
- Simulator for the test gate: iPhone 17 Pro,
  id `B0B10D6D-AF5A-440A-BF29-AF6825C16BDA`. If that id is gone, pick any booted
  iPhone from `xcrun simctl list devices available | grep iPhone` and use its id.
- NEVER stage or commit `Config/Secrets.xcconfig`. NEVER add an AI co-author trailer.
  NEVER `git push` here (pushing is a separate, explicitly-worded action). NEVER
  `git add -A` / `git add .` - stage files by name.

## Pipeline

### 1. Preflight

```bash
cd /Users/advegaf/Desktop/projects/Pickle
git status --short
command -v xcodegen >/dev/null || echo "MISSING xcodegen"
```

- The tree must be clean of *tracked* changes. An untracked `proxy/.wrangler/` is fine
  (ignore it). If tracked files are modified, STOP and ask the user whether to commit
  them into this build or stash them - never bundle mystery changes into a release
  silently. (For a normal ship the user has already committed their feature work.)

### 2. Read the current build number, compute the next

```bash
grep -nE "MARKETING_VERSION|CURRENT_PROJECT_VERSION" project.yml
```

- `NEXT_BUILD = CURRENT_PROJECT_VERSION + 1`.
- If a version arg was given, `NEW_MARKETING = that arg`, else keep the current one.

### 3. Bump + regenerate

Edit `project.yml` base settings (the `settings: base:` block near the top):
- Set `CURRENT_PROJECT_VERSION: "<NEXT_BUILD>"` (keep it quoted).
- If a version arg was given, set `MARKETING_VERSION: "<NEW_MARKETING>"`.

```bash
xcodegen generate
plutil -p Pickle/Info.plist | grep -i version
plutil -p PickleWidget/Info.plist | grep -i version
```

Both plists still show `$(...)` variables - that is correct, they resolve at build time.

### 4. Test gate (green or stop)

Full suite (default):
```bash
xcodebuild test -project Pickle.xcodeproj -scheme Pickle \
  -destination 'id=B0B10D6D-AF5A-440A-BF29-AF6825C16BDA' 2>&1 | tail -40
```
`fast` arg: append `-only-testing:PickleTests`.

Require `** TEST SUCCEEDED **`. Any failure -> STOP, show the failing tests, do not
archive. A ship never goes out on a red suite.

### 5. Archive (separate Bash call, 600s timeout)

```bash
ARCH=~/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)
mkdir -p "$ARCH"
xcodebuild archive -project Pickle.xcodeproj -scheme Pickle \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCH/Pickle-<MARKETING>-<NEXT_BUILD>.xcarchive" \
  -allowProvisioningUpdates 2>&1 | tail -30
```

Require `** ARCHIVE SUCCEEDED **`. Then confirm the build number actually baked in:
```bash
plutil -p "$ARCH/Pickle-<MARKETING>-<NEXT_BUILD>.xcarchive/Products/Applications/Pickle.app/Info.plist" | grep -i version
```
`CFBundleVersion` must equal `<NEXT_BUILD>`. The dated Archives path means Xcode's
Organizer also lists this archive, which is the manual-upload fallback in step 6.

### 6. Upload (separate Bash call, 600s timeout)

Auto-detect an App Store Connect API key. If one exists, prefer it (fully headless);
otherwise rely on the Xcode-signed-in session.

```bash
KEY=$(ls ~/.appstoreconnect/private_keys/AuthKey_*.p8 2>/dev/null | head -1)
AUTH=""
if [ -n "$KEY" ] && [ -f ~/.appstoreconnect/issuer_id ]; then
  KID=$(basename "$KEY" | sed -E 's/AuthKey_(.*)\.p8/\1/')
  AUTH="-authenticationKeyPath $KEY -authenticationKeyID $KID -authenticationKeyIssuerID $(cat ~/.appstoreconnect/issuer_id)"
fi
xcodebuild -exportArchive \
  -archivePath "$ARCH/Pickle-<MARKETING>-<NEXT_BUILD>.xcarchive" \
  -exportOptionsPlist Config/ExportOptions.plist \
  -exportPath /tmp/pickle-export-<NEXT_BUILD> \
  -allowProvisioningUpdates $AUTH 2>&1 | tail -40
```

Outcomes:
- `** EXPORT SUCCEEDED **` + exit 0 -> uploaded. Go to step 7.
- Output mentions authentication / account / "No signing certificate" / session ->
  the CLI could not auth headlessly. Fall back:
  ```bash
  open "$ARCH/Pickle-<MARKETING>-<NEXT_BUILD>.xcarchive"
  ```
  This opens the Xcode Organizer on this archive. Tell the user, verbatim:
  "Xcode's CLI could not upload with the signed-in session. I opened the Organizer on
  the build 3 archive. Click **Distribute App -> TestFlight & App Store -> Distribute**,
  and tell me once it says Upload complete." WAIT for the user to confirm before step 7.
- Output mentions a build number already exists / redundant binary -> App Store Connect
  already has this build. Bump again (back to step 3 with the next number) and redo.
- A transient network error -> retry the same command once. Re-uploading a build number
  that never landed is allowed.

### 7. Tag + record the bump

Only after a confirmed upload:
```bash
git add project.yml
git commit -m "chore(ship): build <NEXT_BUILD>"
git tag testflight/<NEXT_BUILD>
```
Do NOT push. (Tags and commits stay local until the user explicitly says to push.)

### 8. Ship report (the deliverable)

Draft "What's New" from the commits since the last shipped build:
```bash
PREV=$(git tag --list 'testflight/*' | sort -V | tail -2 | head -1)
RANGE=${PREV:+$PREV..HEAD}
git log ${RANGE:-HEAD} --format='- %s'
```
(If no previous `testflight/*` tag exists yet, use the last `chore(ship)` commit as the
baseline instead.) Rewrite those commit subjects into short human sentences a tester
reads - group them, drop internal noise, no conventional-commit prefixes.

Then give the user this block, filled in:

> **Build <NEXT_BUILD> uploaded - version <MARKETING> (<NEXT_BUILD>)**
>
> **In App Store Connect (appstoreconnect.apple.com):**
> 1. Processing takes ~5-15 min. You'll get an email when build <NEXT_BUILD> is ready.
> 2. My Apps -> Pickle -> TestFlight -> iOS builds -> build <NEXT_BUILD>.
> 3. Export compliance: nothing to answer (the app declares no non-exempt encryption).
> 4. Paste the What's New below into the build's "What to Test", then add the build to
>    your tester group.
>
> [If MARKETING_VERSION changed this run, add:]
> 5. This is a NEW version train (<MARKETING>). For an App Store submission (not just
>    TestFlight) you'll also create the <MARKETING> version record, paste release notes,
>    attach this build, and Submit for Review.
>
> **What's New draft:**
> <the rewritten, human changelog>
>
> Nothing was pushed to GitHub. Say the word when you want the commits + the
> `testflight/<NEXT_BUILD>` tag pushed.

## Guardrails (every run)

- Stage files by name only. Never `git add -A` / `git add .`.
- Never commit `Config/Secrets.xcconfig` (it holds the proxy URL + API key locals).
- Never add a `Co-Authored-By` / AI co-author trailer.
- Never `git push` or force-push as part of this skill. Pushing is always a separate,
  explicitly-worded user action.
- If the test gate is red, stop at the gate. Do not archive or upload.
