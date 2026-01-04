# SelfControl

## About

SelfControl is a free and open-source macOS app that helps you block access to distracting sites for a set period of time. This repository is a SwiftUI rewrite targeting modern macOS on Apple silicon.

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
./build/SelfControl.app/Contents/MacOS/selfcontrol-cli unlock --reason "accidentally blocked work site"
./build/SelfControl.app/Contents/MacOS/selfcontrol-cli update --blocklist "example.com,news.com"
./build/SelfControl.app/Contents/MacOS/selfcontrol-cli extend --minutes 30
```

## Packaging (App Bundle)

Create an `.app` bundle that places the LaunchDaemon plist at `Contents/Library/LaunchDaemons`:

```sh
scripts/package_app.sh
```

Optional signing:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" scripts/package_app.sh
```

## License

SelfControl is free software under the GPL. See `COPYING` for details.
