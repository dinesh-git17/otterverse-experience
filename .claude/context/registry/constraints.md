---
last_updated: 2026-02-14T11:00:00Z
schema_version: 1
---

# Known Constraints

- **[TOOLING]** No Xcode project exists yet. All Swift implementation blocked until PH-01 completes. Reference: `docs/PHASES.md` PH-01.
- **[TOOLING]** No git repository initialized. Version control unavailable. Reference: `docs/PHASES.md` PH-01.
- **[FRAMEWORK]** iOS 19+ deployment target required. APIs must be verified against iOS 19 SDK. Reference: `CLAUDE.md` §4.1.
- **[FRAMEWORK]** No third-party dependencies permitted. Apple-native frameworks exclusively. Reference: `CLAUDE.md` §3.1.
- **[FRAMEWORK]** No Combine framework usage. `@Observable` and `async/await` only. Reference: `CLAUDE.md` §3.1.
- **[FRAMEWORK]** No UIKit unless explicitly required for a capability unavailable in SwiftUI. Reference: `CLAUDE.md` §3.1.
- **[BUILD]** CoreHaptics unavailable in Simulator. On-device testing required for haptic validation. Reference: `docs/PHASES.md` PH-16.
- **[API]** `AVAudioPlayer.currentTime` drifts on seek and interruption recovery. Use `CACurrentMediaTime()` for beat-critical timing. Reference: `CLAUDE.md` §4.5.
- **[RUNTIME]** SpriteView retains SKScene references after SwiftUI removal unless explicitly nil-ed. Reference: `CLAUDE.md` §4.3, `Design-Doc.md` §11.5.
- **[ENVIRONMENT]** Discord webhook URL must be XOR-encoded. Plaintext URL forbidden in source, comments, logs, tests, docs. Reference: `CLAUDE.md` §5.
