# Five-Minute Explorer / 5分钟探索

A five-minute real-world attention tool: choose one small Quest, then put the phone away. It is not a feed.

Current status: **Prototype V0 / pre-TestFlight**, pending independent review and device testing. The 580-Quest catalog is bundled; session state and event records stay locally on the device. V0 has no location, weather, AI, account, backend, or cloud integration.

Open `FiveMinuteExplorer.xcodeproj` with Xcode 26.6 and select the shared `FiveMinuteExplorer` scheme. The app supports iPhone on iOS 18.0+, portrait only; the current test targets require an iOS 26.5+ simulator.

```bash
python3 scripts/verify-static.py
scripts/ci-ios.sh
# Focused large-text / Useful Exit smoke in addition to normal validation:
scripts/ci-ios.sh --full-qa
```

Source and bundled resources live in `FiveMinuteExplorer/`; unit/Store tests and UI tests have their own target directories. `scripts/` contains shared CI and release checks; `.github/workflows/` provides normal public CI and manual Full QA. The audited XLSX and original Prototype ZIP are retained as reference assets.

See [Release SOP](docs/RELEASE_SOP.md) for CI and release gates, and [repository settings handoff](docs/REPOSITORY_SETTINGS.md) for recommended post-merge settings. GitHub CI validates unsigned code; Xcode Cloud handles signing and distribution. No TestFlight tag before independent review.
