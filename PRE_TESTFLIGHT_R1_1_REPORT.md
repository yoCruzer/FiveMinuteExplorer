# Prototype V0 Pre-TestFlight Readiness R1.1

## Goal result

**COMPLETE — implementation validated locally and by real branch and PR CI.**

Product changes, automation, documentation and local validation are complete and pushed. Real branch push CI and PR CI both passed. This report pins the verified implementation and its evidence; the final report-only commit introduces no code changes.

## Repository evidence

- Repository: `yoCruzer/FiveMinuteExplorer`; GitHub API confirmed `PUBLIC` on 2026-09-10.
- Starting branch: `codex/prototype-v0-stabilization-r1`.
- Starting HEAD and preserved remote R1 checkpoint: `0dd63be9eaf15adf6f00e3e31fedb37ff86745e2`.
- Candidate branch created: `codex/pre-testflight-r1-1`.
- Exact tested implementation HEAD: `05b937451774c768b37e9adb0881079fc5889e7a`.
- Remote candidate SHA verified for the runs below: `05b937451774c768b37e9adb0881079fc5889e7a`.
- Remote main remains `95f6fb47ae7365847ffb4d58896d3a770062dca2`.
- Final report commit: the commit introducing this file, resolved exactly with `git log -1 --format=%H -- PRE_TESTFLIGHT_R1_1_REPORT.md`. A file cannot embed its own containing commit hash; the handoff message supplies the final publication SHA and its fresh CI links separately.
- Final handoff requires local HEAD == remote candidate HEAD and clean `git status --short`. Ignored local validation artifacts remain under `.ci-artifacts/`.
- R1.1 implementation commit: `05b9374`, `fix: finish pre-testflight readiness and add public CI`.
- PR: [#1](https://github.com/yoCruzer/FiveMinuteExplorer/pull/1), targeting main; open and unmerged.
- Actions API reports enabled, default workflow permissions `read`; no repository settings were changed.

## Product fixes

| Requirement | Local result and evidence |
| --- | --- |
| Explicit ContextProfile preference | PASS: shared compatibility tiers precede soft score ordering; exact > confirmed public space > universal. Real-catalog tests cover all nine profiles with nil, Listen and Think states using a verified non-serendipity seed. |
| Incompatible context handling | PASS: incompatible content is excluded before all fallback levels; universal content remains eligible. Synthetic tests cover Anywhere plus another specific context, environment-only matches, and confirmed contextual PublicSpaceOnly content. |
| Home replacement | PASS: real library selection → skip yields a different Home-matching Quest in Store tests. |
| Transit / Waiting replacement | PASS: equivalent real-catalog Store scenarios retain the profile and match the replacement. |
| Safe-lit Night | PASS: visible title is `安全明亮的夜晚`; explicit selection stores Safe Lit Space in session active contexts. Clearing the profile removes it. A legacy Night-only selection does not silently gain confirmation. |
| NightSafeOnly | PASS: unchanged hard safety gate rejects unknown and Night-only contexts; real Night content becomes eligible with explicit confirmation. Night does not confirm public space. |
| Serendipity | PASS: a single distinct choice never records serendipity, tested across 100 deterministic seeds. |
| Walking copy | PASS: moving cards explicitly say `不要为了 Quest 过马路`. |
| Catalog error UX | PASS: Home shows a friendly message without technical error interpolation; existing Lab diagnostics retain details. |
| Portrait-only | PASS: project guard and generated Debug app Info.plist confirm iPhone Portrait only, family 1, iOS 18.0. |

The R1 seed/lens cooldown and diversity guardrails remain in place; explicit-context preference applies to the remaining hard-eligible candidate pool. No catalog regeneration was used.

ModelContainer fallback audit: retained the existing in-memory fallback `try!`. If both persistent and in-memory ModelContainer creation fail, the existing Store cannot initialize. Merely substituting `fatalError` would not improve behavior; adding a separate app bootstrap failure lifecycle would exceed this small optional P2. The Goal explicitly permits retaining and documenting this case. Normal SwiftData initialization and Store tests pass.

## Public repository hygiene

- PASS: `.gitignore` covers environment secrets (with `.env.example` exception), signing material, keystores, IPA/archive/results and local build outputs.
- PASS: concise public README, short PR template, Release SOP and manual repository settings handoff added.
- PASS: dependency-free static guard validates v1/580/580 unique IDs, recommendation v1, approved 1024×1024 PNG and SHA-256, privacy, app version/build, encryption declaration, iPhone-only/iOS 18/portrait settings.
- PASS: all staged files scanned for sensitive paths and high-confidence credential formats; credential findings report rule/path/line without values.
- No license added and no history rewritten.

## CI infrastructure

`ios-ci.yml`: branch push to main/codex/** and PR to main; branch-only push filtering excludes tags. Workflow-level `contents: read`; checkout credentials not persisted; no secrets, signing, privileged PR trigger, external dependencies or third-party Actions. Jobs are `static` on `ubuntu-latest` and dependent `ios` on standard `macos-26`. Ref-aware concurrency cancels stale runs. Static job also runs automation regression tests and candidate whitespace checking.

Both workflows select `/Applications/Xcode_26.6.app/Contents/Developer` when present and assert Xcode 26.6. GitHub-owned checkout/upload-artifact v7.0.1 versions were verified through the official repositories' latest-release APIs. Failure-only log/result artifacts have 7-day retention; no dependency cache is introduced.

`ios-full-qa.yml`: workflow_dispatch only; same security/toolchain settings. Runs static validation and normal CI plus the focused `testStabilizationLargeTextFlow`. It is expected to become dispatchable after introduction on main.

## Real GitHub Actions evidence

Mandatory push run: [34434531632](https://github.com/yoCruzer/FiveMinuteExplorer/actions/runs/34434531632), exact head SHA `05b937451774c768b37e9adb0881079fc5889e7a`, completed **success**.

- `static`: success, job `102736751505`, 8 seconds; static contracts, automation tests and whitespace checks passed on ubuntu-latest.
- `ios`: success, job `102736785647`, 5m33s, standard macos-26 / ARM64.
- Runner image: `macos-26-arm64/20260831.0337`; macOS 26.6.2, Darwin arm64.
- Xcode: 26.6 (17F113), selected and asserted successfully.
- Simulator: iPhone Air, iOS 26.5, `D8661337-7CF0-4F5F-B9B7-BF00428555EA`.
- 44 tests in 4 suites passed; `TEST SUCCEEDED` at 03:50:09 UTC.
- Fresh Debug Simulator build: `BUILD SUCCEEDED` at 03:50:42 UTC.
- Fresh unsigned generic iOS Release: `BUILD SUCCEEDED` at 03:51:04 UTC.
- Failure-only artifact step correctly skipped on success.
- Raw evidence downloaded with `gh run view 34434531632 --log`, retained locally as `/tmp/fme-r1-1-github.log`.

PR CI: [34434975146](https://github.com/yoCruzer/FiveMinuteExplorer/actions/runs/34434975146), event `pull_request`, head SHA `05b937451774c768b37e9adb0881079fc5889e7a`; completed **success**.

- `static`: success, job `102738038595`, 6 seconds.
- `ios`: success, job `102738065397`, 4m59s; same macOS 26.6.2 ARM64 / Xcode 26.6 / iPhone Air iOS 26.5 environment.
- PR checkout tested GitHub's synthetic merge ref (`31584db…`) against unchanged main `95f6fb47…`; no actual main merge was performed.
- 44 tests passed; Debug and unsigned Release builds both succeeded. Failure artifact upload was skipped on success.
- Raw PR evidence: `/tmp/fme-r1-1-pr.log`.

After publishing this report-only commit, the final handoff also waits for its new branch/PR checks. Those final publication run links are supplied with the final SHA in the handoff message rather than rewriting the report indefinitely and generating another commit/run cycle.

## Release scripts

- `verify-static.py`: local PASS, including staged new files.
- `ci-ios.sh`: local normal and Full QA execution PASS; new DerivedData per stage/run, raw logs, result bundles, dynamic compatible iPhone selection, unsigned Release build, no launch-performance test execution.
- `release-preflight.sh`: requires clean synchronized main, matching version/build, absent tag, authenticated gh and successful exact-main-HEAD push CI plus manual Full QA with required successful jobs.
- `create-testflight-tag.sh`: defaults to read-only preflight/dry run; publication is gated behind explicit `--push`; only the intended tag can be pushed. Failed/uncertain push leaves and reports the local tag state.
- Shell syntax checks PASS for all three shell scripts.
- Actual `scripts/create-testflight-tag.sh 0.1.0 1` returned the expected nonzero `Must run on merged main after independent review`, without creating a tag.
- `python3 scripts/test-automation.py`: 3 test methods PASS, including ten isolated release scenarios. Wrong SHA, missing Full QA, skipped job, dirty worktree, wrong branch, remote drift, existing local/remote tag and unavailable auth fail closed. Successful mocked dry run also performs no git tag/push. Static negative fixtures confirm credential redaction.
- The tag script was **never invoked with `--push`**, including in tests. Mocks isolate orchestration tests; they are not claimed as GitHub CI evidence.

## Local validation evidence

Machine: macOS 26.6.1, x86_64; Xcode 26.6 (17F113). Dynamically chosen simulator: iPhone Air, iOS 26.5, `9DE5EBCC-04A9-41BD-87DF-FDB57542E661`.

Final implementation command: `scripts/ci-ios.sh` (captured in `/tmp/fme-r1-1-verified-local.log`). Artifacts: `.ci-artifacts/run.dkAxlK/`.

- 44 Swift Testing tests in 4 suites passed; 0 failures; `TEST SUCCEEDED`.
- Fresh Debug Simulator build: `BUILD SUCCEEDED`.
- Fresh generic iOS Release compile with `CODE_SIGNING_ALLOWED=NO`: `BUILD SUCCEEDED`.

Earlier `scripts/ci-ios.sh --full-qa` also passed; artifacts `.ci-artifacts/run.HvQLk0/`. Focused large-text UI result: 1 passed, 0 failed, 0 skipped, verified with `xcrun xcresulttool get test-results summary`. Its roughly 65-second Useful Exit wait was retained. This UI pass preceded the final shared-filter correction; final normal validation above covers that correction, which did not alter UI code.

Additional commands, all PASS:

```bash
python3 scripts/verify-static.py
python3 scripts/test-automation.py
bash -n scripts/ci-ios.sh
bash -n scripts/release-preflight.sh
bash -n scripts/create-testflight-tag.sh
git diff --check
git diff --cached --check
git diff --check origin/main
```

## Protected assets

No changes to the 580-Quest catalog, recommendation configuration, audited XLSX, original Prototype ZIP, approved icon bytes, Privacy Manifest, bundle identity/display name, iOS 18 deployment target, iPhone-only family or shared scheme. The approved icon hash remains `0418609e3d90b93f9bf09966c26f343b4f61f87de8e65fc9be3d3d1f5ad42417`. Project edits only restrict the two app configurations' iPhone orientations.

## Known issues

- No unresolved P0/P1 product or CI failure was observed in the completed validation.
- ModelContainer fallback disposition is documented above as permitted by the Goal.
- Manual GitHub Full QA on merged main remains an intentional future release gate, not an R1.1 branch-readiness requirement. It has not been dispatched in this round.

## Release gate status

- Merged to main: NO, as required.
- `testflight-*` tag created: NO; local and remote tag queries returned none.
- Xcode Cloud triggered by this work: NO tag or Cloud API operation performed.
- TestFlight uploaded by this work: NO upload operation performed.
- Remote rulesets/security settings changed: NO.

READY FOR INDEPENDENT REVIEW
