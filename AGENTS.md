# Repository Guidelines

## Project Structure & Module Organization
- `Sources/` holds all Swift code, organized by SwiftPM targets:
  - `SelfControlApp/` (SwiftUI app UI + ServiceManagement integration)
  - `SelfControlDaemon/` (`selfcontrold` LaunchDaemon + XPC service)
  - `SelfControlCLI/` (`selfcontrol-cli` command‑line client)
  - `SelfControlCore/` (shared logic: blocklists, PF/hosts, settings, auth)
- `Tests/` contains unit tests (SwiftPM test targets).
- `scripts/` contains packaging tools (notably `package_app.sh`).
- `build/` is the local output folder for the packaged app bundle.
- App resources live under `Sources/SelfControlApp/Resources/`.
- Legacy Objective‑C remains on `master` as reference; `main` is the Swift rewrite.

## Build, Test, and Development Commands
- `swift build -c debug`  
  Builds all targets (app, daemon, CLI) with SwiftPM.
- `swift test`  
  Runs unit tests.
- `scripts/package_app.sh`  
  Builds and creates `build/SkyControl.app` (includes daemon, CLI, resources).
- `scripts/dev_bootstrap_daemon.sh /Applications/SkyControl.app`  
  Dev-only workaround to load the daemon without a Developer ID certificate (also enables auth bypass).
- Run the CLI directly:  
  `build/SkyControl.app/Contents/MacOS/selfcontrol-cli version`
- Install for daemon registration (required for LaunchDaemon):  
  `cp -R build/SkyControl.app /Applications/`

## Coding Style & Naming Conventions
- Language: Swift 5.x, SwiftUI for UI.
- Indentation: 4 spaces (Swift standard).
- Types use UpperCamelCase; functions/vars use lowerCamelCase.
- Keep shared logic in `SelfControlCore` and call via XPC in app/CLI.

## Testing Guidelines
- Framework: XCTest via SwiftPM.
- Test names should describe the behavior (e.g., `testBlocklistCleanerStripsSchemes`).
- Run with `swift test` before packaging or releasing.
- End‑to‑end sanity check:
  - Install app to `/Applications`, click **Install** in UI, then run  
    `selfcontrol-cli status` to verify the daemon is reachable.

## Commit & Pull Request Guidelines
- Commit messages are short and descriptive; recent history uses “Phase N: …”
  or concise imperative statements (e.g., “Security: require admin authorization”).
- PRs should include a brief description, test commands run, and screenshots for UI changes.

## Phase Alignment (1–6)
- Phase 1: SwiftPM scaffold + SwiftUI app shell + core types.
- Phase 2: Core blocking logic (blocklist parsing, settings, PF/hosts management).
- Phase 3: XPC/daemon wiring + LaunchDaemon packaging support.
- Phase 4: UI workflows + packaging script for `.app` bundle.
- Phase 5: Emergency unlock + admin authorization.
- Phase 6: Sparkle updater integration (placeholders in `AppInfo.plist`).

## Security & Configuration Tips
- `selfcontrold` is a LaunchDaemon; install from `/Applications` to register.
- Packaging signs the app for local runs; set `SIGN_IDENTITY` for release signing.
- Block/unblock operations require admin authorization.
- Sparkle requires `SUFeedURL` and `SUPublicEDKey` in `AppInfo.plist` before release.

## Deferred Items
- Replace dev bootstrap with signed helper flow (Developer ID required).
- Consider explicit CLI `--force` unlock for orphaned blocks.
