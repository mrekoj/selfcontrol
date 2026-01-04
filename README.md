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
- `selfcontrold` (privileged daemon - stub in Phase 1)
- `selfcontrol-cli` (CLI - stub in Phase 1)
- `SelfControlTests`

## License

SelfControl is free software under the GPL. See `COPYING` for details.
