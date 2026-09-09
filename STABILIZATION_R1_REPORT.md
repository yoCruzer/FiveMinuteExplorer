# Prototype V0 Stabilization Round 1 — Acceptance Report

## Goal Result

COMPLETE — technical acceptance passed. The final handoff supplies the committed HEAD, remote SHA and clean-worktree verification accompanying this report.

## Repository and baseline

- Starting branch: `codex/prototype-v0`.
- Starting HEAD and verified remote checkpoint: `bf95cd798c37ad9beba5243352d6b664cff190aa` (`wip: checkpoint prototype v0 implementation`).
- Stabilization branch: `codex/prototype-v0-stabilization-r1`, created directly from the verified remote checkpoint.
- Protected `main`: `95f6fb47ae7365847ffb4d58896d3a770062dca2`.
- Final HEAD/commit and remote verification: supplied in the final handoff after this report is committed.
- The existing native `.xcodeproj`, shared `FiveMinuteExplorer` scheme, signing/team and bundle ID `com.yocruzer.FiveMinuteExplorer` are preserved.
- Display name remains `5分钟探索`; built products confirm iOS 18.0 and `UIDeviceFamily = [1]`.
- Unit-test deployment target remains 26.5; available iOS 26.5 simulators execute it successfully. No deployment-target workaround was needed.
- No project generator, package conversion, new dependency, release workflow, or scope-frozen feature was introduced.
- No existing test was removed. One focused accessibility UI scenario was added; default launch-performance tests were not run.

Before editing, the four package documents were read in full. `pwd`, status, remotes, fetch/prune, all three baseline SHAs, 12-commit log, Xcode version and project listing were checked. Xcode is 26.6 (17F113). Remote stabilization branch did not yet exist. The initial worktree was clean.

## Gate A — correctness

| Requirement | Result | Evidence |
|---|---|---|
| Warm resume <30 minutes | PASS | `warmResumeDoesNotServeAgain`: same Quest/session and exactly one serve despite resume and repeated start calls. |
| Long resume | PASS | `longResumeKeepsPreviousReflectionIdentity`: new session; shown/answered events retain previous session and Seed. |
| Cold stale session without background timestamp | PASS | `coldStaleMissingBackgroundStartsNewSession`, `legacySnapshotWithoutTimingExpires`: persisted activity timestamp or conservative legacy expiry; state/context reset. |
| Cold long-return reflection | PASS | `coldLongReturnRetainsReflectionAndThirdSkipSurvivesRelaunch`: reflection persists through relaunch and binds to old session/Seed. |
| Single lifecycle path | PASS | Cold start and foreground both call `resume`; timeout is the named `SessionPolicy.inactivityTimeout` (30 minutes). |
| Useful Exit attribution | PASS | `AppSurface` covers intro/home/explore/lab/skip_help/feedback; `.background` alone records departure. `nonHomeBackgroundDoesNotOfferReflection` covers all non-Home surfaces. |
| Feedback handled status | PASS | Exact SwiftData predicate for session/Seed/type; `oldFeedbackOutsideRecentCacheIsStillHandled` covers >40 newer events. Pending reflection is separately persisted and dismissible. No completion inference. |
| Skip 1–2 | PASS | Tap records append-only event immediately and serves replacement; events contain selected state and context profile. |
| Skip 3+ | PASS | `thirdSkipIsDurableBeforeReasonAndDismissDoesNotCountTwice`: event and removal of active Seed are durable before reason UI. Cold-relaunch scenario also tested. |
| Optional reasons | PASS | `everySkipReasonHasImmediateEffect`: context clears/adjusts, movement becomes Stay Here, effort becomes Low/Very Low, immediate replacement avoids rejected World, not-now selects Do nothing. Separate `skip_reason_selected` event. |
| Skip state choice | PASS | `choosingSameStateFromSkipStillServesOnce`: even selecting an already-active state serves exactly once. Explore action opens Library; cancellation uses Pause behavior without a second skip. Reroll limit reads bundled config. |
| Shared state matcher | PASS | Recommendation scoring and Explore filters both use `QuestMatchingPolicy.stateFit` for all six states. |
| ContextProfile aliases | PASS | `catalogContractsAndContextProfiles`: all nine profiles have visible real content; Waiting includes Waiting for Food; Transit includes Station/Airport and Transit environment. WorkSchool/Nature environments supported. |
| Explore intent continuity | PASS | `libraryCommitPreservesIntentAndServesExactlyOnce`: Listen/Home/Transit selections commit intent once and preserve it through later skips. Home provides clearable profile indicator. |
| World selection | PASS | `worldSelectionDoesNotInventPreferences`: exact World selection does not invent state/context. |
| Move / Short Walk | PASS | `moveIncludesShortWalkButDoesNotConfirmSafeWalkingArea`; four movement classes, high Short Walk fit, Chinese label and movement safety reminder. Move does not assert safe walking context. |
| Safety hard gates | PASS | Public-space unknown/home/waiting/night fail; explicit transit can pass. Daylight, safe-lit night, companion and explicit-input restrictions remain hard filters. `allSafetyFlagsRemainHardEvenWhenSeedsExhausted`, `publicSpaceRequiresPositiveEvidence`, `fallbackNeverRelaxesSafety`. |
| Recommendation exhaustion | PASS | Progressive levels 0–3: strict → lens relaxation → long Seed relaxation excluding latest two → least-recent hard-eligible candidate. Engine and Store full-catalog cooldown scenarios pass. Nil pool shows an explicit non-spinning Home state with Lab diagnostics. |

## Gate B — product and measurement

| Requirement | Result | Evidence |
|---|---|---|
| Explore Library IA | PASS | First screen contains category links in three groups, including six states + weird/create, 10 Worlds and nonempty ContextProfiles. No preview carousels. |
| Finite category detail | PASS | Stable surface/rank/Seed order; initial 10 rows; explicit increments of 10 via 显示更多. No automatic loading or related-content rail. Selection leaves Explore for Home. |
| Experimental excluded | PASS | Shared `libraryQuests` excludes Hidden, Experimental and Experimental only. Real catalog contract test verifies ordinary output. Catalog is unchanged. |
| Home hierarchy and taste wording | PASS | Quest is the central card, skip secondary, Explore plain/secondary navigation. Taste labels are 这类不错 / 这类不适合我 with events retained. |
| Dynamic Type | PASS | Intro and feedback scroll; feedback uses medium/large detents, vertically arranged answers and 44pt dismiss target. Detail rows have natural height and unrestricted text. Home metadata stacks vertically. Focused Accessibility XXXL UI test passed and screenshots were visually reviewed. |
| Exact Explore source | PASS | Both selection and serve persist broad source and sourceDetail (`listen`, `home`, exact World etc.). Export test covers all three source types. |
| State/context events | PASS | `state_changed`, `context_changed` (including clearing), skip metadata and session-scoped profile persistence. |
| Recommendation diagnostics | PASS | `quest_served` includes config recommendation version, numeric score, serendipity and fallback level. Lab score includes fallback. |
| Prompt visibility vs answer | PASS | Actual feedback view `onAppear` records `attention_shift_prompt_shown`; separate `attention_shift_feedback` and dismissal. Store test verifies no shown event before view appearance callback. |
| Export identity | PASS | `exportRetainsIdentitySourcesAndAttentionMetrics`: schema v0.2, actual bundle app/build, catalog/recommendation version, timestamp and optional event fields. |
| Export success | PASS | File written atomically before success event insertion. Failed path test leaves no false `event_log_exported`. Successful file intentionally excludes its own later success event. |
| Event query hygiene | PASS | Feedback uses exact predicate fetch with limit 1; Lab recent cache fetch has limit 40. |

## Gate C — release readiness

- Approved source: Goal ZIP `Assets/five_minute_explorer_icon_production_master_1024.png`.
- Integrated unchanged at `FiveMinuteExplorer/Assets.xcassets/AppIcon.appiconset/five_minute_explorer_icon_production_master_1024.png`.
- PNG size: 1024 × 1024. SHA-256: `0418609e3d90b93f9bf09966c26f343b4f61f87de8e65fc9be3d3d1f5ad42417` (matches package).
- Primary universal iOS 1024 slot points to the approved file; no regenerated artwork, added mask, or conversion. Fresh Debug and Release compile the primary AppIcon successfully; built `CFBundlePrimaryIcon.CFBundleIconName = AppIcon` and icon resources exist.
- `PrivacyInfo.xcprivacy`: valid plist, bundled and byte-identical to source. Tracking false, no tracking domains or collected-data types, UserDefaults category with `CA92.1` for app-owned preferences. Schema/reason checked against [Apple's Required Reason API documentation](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).
- Generated Info.plist: `ITSAppUsesNonExemptEncryption = false`, `CFBundleShortVersionString = 0.1.0`, `CFBundleVersion = 1` in both builds.
- No repository evidence of an already-published Build 1: remote had no tags, and checkpoint was the WIP implementation. No App Store Connect publication was initiated or assumed.

## Tests and builds

All three final DerivedData directories below were newly created with `mktemp -d`; none reused Gate A/B or previous incremental artifacts.

### Final focused tests — PASS (38 passed, 0 failed, 0 skipped)

```sh
xcodebuild test -project FiveMinuteExplorer.xcodeproj -scheme FiveMinuteExplorer \
  -destination 'platform=iOS Simulator,id=4C8C76D9-41F0-4EB1-9881-836515666D9F' \
  -only-testing:FiveMinuteExplorerTests \
  -derivedDataPath /tmp/FiveMinuteExplorer-StabilizationTests.bODEzx
```

Log: `/tmp/FiveMinuteExplorer-StabilizationTests.log`.
Result: `/tmp/FiveMinuteExplorer-StabilizationTests.bODEzx/Logs/Test/Test-FiveMinuteExplorer-2026.09.09_22-33-45-+0800.xcresult`.
Device: iPhone 17 Pro, iOS 26.5, x86_64 simulator. Tests were checked through xcresult summary, not just log exit text.

### Fresh Simulator Debug build — PASS

```sh
xcodebuild build -project FiveMinuteExplorer.xcodeproj -scheme FiveMinuteExplorer \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=4C8C76D9-41F0-4EB1-9881-836515666D9F' \
  -derivedDataPath /tmp/FiveMinuteExplorer-StabilizationDebug.3IsFpc
```

Log: `/tmp/FiveMinuteExplorer-StabilizationDebug.log`.

### Fresh generic iOS Release compile — PASS

```sh
xcodebuild build -project FiveMinuteExplorer.xcodeproj -scheme FiveMinuteExplorer \
  -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath /tmp/FiveMinuteExplorer-StabilizationRelease.NTDGmN
```

Log: `/tmp/FiveMinuteExplorer-StabilizationRelease.log`.
This is a local unsigned compile, not an archive upload or TestFlight publication.

### Focused large-text UI review — PASS (1 passed, 0 failed, 0 skipped)

```sh
xcodebuild test -project FiveMinuteExplorer.xcodeproj -scheme FiveMinuteExplorer \
  -destination 'platform=iOS Simulator,id=5F04DE28-8329-4774-9488-076D6DDC5230' \
  -only-testing:FiveMinuteExplorerUITests/FiveMinuteExplorerUITests/testStabilizationLargeTextFlow \
  -derivedDataPath /tmp/FiveMinuteExplorer-R1-VisualQA
```

Uses iPhone 16 (393 × 852pt) with Accessibility XXXL. Covers scroll-safe Intro, Home, category navigation, detail selection and real >60-second Home background/return feedback. Does not run template launch-performance tests.

Passed log: `/tmp/FiveMinuteExplorer-R1-VisualQA-recheck.log`.
Result: `/tmp/FiveMinuteExplorer-R1-VisualQA/Logs/Test/Test-FiveMinuteExplorer-2026.09.09_22-36-49-+0800.xcresult`.
Seven screenshots are exported at `/tmp/FiveMinuteExplorer-R1-VisualQA-passed/` with `manifest.json`. Visual inspection confirms Intro's start button is reachable by scrolling; Library detail text wraps at natural height; feedback can expand/scroll to all three answer buttons. This UI-only locator correction did not change the application compiled in the three final fresh validations.

### Additional verification — PASS

```sh
git diff --check
plutil -lint FiveMinuteExplorer/PrivacyInfo.xcprivacy
sips -g pixelWidth -g pixelHeight FiveMinuteExplorer/Assets.xcassets/AppIcon.appiconset/five_minute_explorer_icon_production_master_1024.png
shasum -a 256 FiveMinuteExplorer/Assets.xcassets/AppIcon.appiconset/five_minute_explorer_icon_production_master_1024.png
```

Built Info.plists were inspected with `plutil -p`. Release resource files were compared with source using `cmp`; all match. Runtime contract remains catalog v1 / 580 Quests / 580 unique IDs with valid titles/text/taxonomy.

Protected artifacts have zero diff against checkpoint, including the shared scheme. SHA-256:

| File | SHA-256 |
|---|---|
| `quests_v1.json` | `6d204d9736805069fd6fc6c49549958a98defcad37b2e63ac0a0dc541a288c04` |
| `recommendation_v1.json` | `02df7d6b805f741b464a32fed39f14db698b612dd2c50e8ae830bcf6ca905d2a` |
| Root audited XLSX | `e557d49a5ddd92589f51d8532e733422c33509b6c2e2ef74796e18d52a36476d` |
| Root Prototype V0 ZIP | `3d6e614f5211aac8db6d0a11d260a60f04fa6d77da1a71c6d78e9340510caee9` |

## Verification iterations and known issues

Gate A/B development runs preceded final clean validation. A new test had a Swift argument-order error, fixed before successful rerun. Another test used identical timestamps for 580 historical events and incorrectly inspected a limited recent-event cache; giving history its proper earlier timestamp fixed the fixture. The first UI run incorrectly selected the background Home's identically named Listen button; the query is now scoped to the Library collection. These are recorded as resolved verification issues, not hidden successes.

Final fresh builds contain only Xcode's informational warning that AppIntents metadata extraction was skipped because this app has no AppIntents dependency. The Swift actor-isolation warnings observed during development were fixed before the fresh final builds.

Open P0/P1/P2: none found within this round's scope and validation. Independent review remains the next release gate.

## Release status

- `testflight-*` tag created: NO.
- Xcode Cloud/TestFlight manually triggered or uploaded: NO.
- GitHub Actions workflows: none found by read-only API query; checkpoint has no check runs.
- Main merged/modified: NO.
- WIP checkpoint modified/force-pushed: NO.
- Stabilization branch and clean-worktree evidence: final handoff verifies remote SHA equality and `git status --short --branch` after committing this report.

READY FOR INDEPENDENT REVIEW
