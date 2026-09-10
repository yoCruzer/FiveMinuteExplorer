# Release SOP

1. Push the candidate branch and wait for **iOS CI** (`static`, `ios`) to pass.
2. Open a PR to `main`; wait for PR CI and independent ChatGPT code review.
3. After approval, merge deliberately. R1.1 automation does not merge.
4. Wait for **main push iOS CI** to pass at the exact merged HEAD.
5. In Actions, run **iOS Full QA** manually on `main` (or `gh workflow run ios-full-qa.yml --ref main`). Wait for success at the same HEAD. The workflow becomes dispatchable once introduced on the default branch.
6. On a clean, up-to-date local `main`, run `scripts/release-preflight.sh 0.1.0 1`, then `scripts/create-testflight-tag.sh 0.1.0 1` for a dry run.
7. Only after independent review and both exact-main-HEAD gates, intentionally run `scripts/create-testflight-tag.sh 0.1.0 1 --push`.
8. The `testflight-0.1.0-build1` tag triggers the existing Xcode Cloud archive/distribution path. Inspect that build, then perform TestFlight iPhone device testing.

No TestFlight tag before independent review. Neither release script merges or uploads to App Store Connect. Normal CI has read-only permissions, no secrets and no signing; Xcode Cloud remains the signing/distribution system. Public CI uses standard `ubuntu-latest` and `macos-26` runners.

Normal CI runs focused unit/Store tests, a fresh Simulator Debug build, and an unsigned generic iOS Release build through `scripts/ci-ios.sh`. Full QA adds only `testStabilizationLargeTextFlow`, including its intentional approximately 65-second Useful Exit wait; the default launch-performance test is excluded. Each stage has fresh DerivedData.

For a failure, inspect `gh run view RUN_ID --log-failed` or the Actions job log. Download the failure artifact from the run page (or `gh run download RUN_ID`); raw logs and `.xcresult` bundles are retained for 7 days, only on failure. Open `.xcresult` with Xcode. Local logs are under `.ci-artifacts/run.*`; these outputs are ignored and should not be committed.

Preflight fails closed without authenticated GitHub access, exact successful main push CI and manual Full QA, matching version/build, clean synchronized main, and an absent release tag. A newer main commit needs both gates again. If tag push fails, inspect local and remote tag state before retrying; never overwrite a published tag.
