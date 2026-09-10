# Manual repository settings handoff

Apply these settings **after the workflows have merged to main and normal main CI has passed once**. This document does not imply any remote settings were changed.

- Keep Actions default workflow permissions read-only where practical.
- Confirm or enable the public repository's available secret scanning and push protection.
- Add a main ruleset / branch protection requiring a PR and successful `static` and `ios` checks before merge.
- Block main force pushes and branch deletion. An owner bypass may be retained for deliberate emergency solo-maintainer recovery.
- Do not require manual Full QA on ordinary PRs: it is an exact-main-HEAD release gate.

Keep the existing Xcode Cloud `testflight-*` trigger. GitHub workflows require no signing or App Store Connect secrets. Do not add credentials to allow fork CI.
