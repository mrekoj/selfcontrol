# SkyControl

## About

SkyControl is a free and open-source macOS app that helps you block access to distracting sites for a set period of time. This repository is a SwiftUI rewrite targeting modern macOS on Apple silicon.

## Requirements

- Apple silicon (M‑series)
- macOS 13+
- Xcode 15+ (Swift 5.9)

## Building (SwiftPM)

1. Clone the repo.
2. Open `Package.swift` in Xcode, or build from the terminal:

```sh
swift build
```

Targets:

- `SelfControlApp` (SwiftUI app)
- `selfcontrold` (privileged daemon)
- `selfcontrol-cli` (CLI)
- `SelfControlTests`

## Emergency Unlock

Phase 5 replaces the old “Killer” app with a guarded emergency unlock flow. It is rate-limited and requires a reason.

CLI example:

```sh
./build/SkyControl.app/Contents/MacOS/selfcontrol-cli unlock --reason "accidentally blocked work site"
./build/SkyControl.app/Contents/MacOS/selfcontrol-cli update --blocklist "example.com,news.com"
./build/SkyControl.app/Contents/MacOS/selfcontrol-cli extend --minutes 30
```

## Sparkle 2 (Updater)

Sparkle is wired via Swift Package Manager. You must update these keys in `Sources/SelfControlApp/Resources/AppInfo.plist`:

- `SUFeedURL` (your appcast URL)
- `SUPublicEDKey` (your Ed25519 public key)

Generate keys with Sparkle’s `generate_keys` tool, and use the public key in `SUPublicEDKey`.

## Packaging (App Bundle)

Create an `.app` bundle that places the LaunchDaemon plist at `Contents/Library/LaunchDaemons`:

```sh
scripts/package_app.sh
```

Optional signing:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" scripts/package_app.sh
```

## Dev Workaround (No Developer ID)

If you do not have a Developer ID certificate, macOS blocks SMAppService for LaunchDaemons.
For local testing only, you can bootstrap the daemon manually:

```sh
scripts/dev_bootstrap_daemon.sh /Applications/SkyControl.app
```

This dev bootstrap also enables a local authorization bypass for the daemon.

## Future Work / TODO

- Replace the dev bootstrap with proper signed HelperTool flow (requires Developer ID Application cert).
- Provide a CLI `--force` unlock to explicitly clear orphaned PF/hosts blocks.
- Update Sparkle `SUFeedURL` + `SUPublicEDKey` for release updates.

## License

SkyControl is free software under the GPL. See `COPYING` for details.
