# Perch

A native macOS menu-bar app that watches your AI coding agents (Claude Code, Cursor, Codex)
and pings you the moment one **finishes** or **needs your input** — so you stop babysitting a
terminal and stop missing the "Asking permission…" prompt that quietly blocks everything.

Perch = a bird on a perch, keeping an eye on your agents.

## Privacy

Perch is local-only. It listens on `127.0.0.1`, stores everything in a local SwiftData database,
and ships **zero telemetry**. No accounts, no servers, no network calls beyond localhost.

## Requirements

- macOS 14.0+
- Xcode 16+ (developed against Xcode 26 / Swift 6.2)
- Apple Silicon

## Build & run

The Xcode project is generated with [XcodeGen](https://github.com/yonkim/XcodeGen) from
`project.yml`. The generated `Perch.xcodeproj` is committed, so you can open it directly:

```sh
open Perch.xcodeproj
```

To regenerate after changing `project.yml`:

```sh
brew install xcodegen   # once
xcodegen generate
```

Build and test from the command line:

```sh
xcodebuild -scheme Perch -destination 'platform=macOS' build
xcodebuild -scheme Perch -destination 'platform=macOS' test
```

Run the app from Xcode (the ▶ button) or launch the built `Perch.app`. It has no Dock icon
(`LSUIElement`); look for the bird in the menu bar.

## Architecture

Three detection channels feed a single deduplicating `EventBus`:

1. **MCP** — a stdio MCP server (`perch-helper mcp`) exposing `perch_notify`. Works in any
   environment and across all three tools. *(M3)*
2. **Hooks** — `perch-helper hook` relays Claude Code `Stop` / `Notification` /
   `PermissionRequest` / `SubagentStop` events. This is what catches "blocked on a permission
   prompt", which MCP cannot. *(M2)*
3. **File-watch** — a passive FSEvents tail of `~/.claude/projects/**/*.jsonl` as a backstop. *(M4)*

The app (`Perch.app`) hosts the menu bar, dashboard, SwiftData store, notifiers and the loopback
listener. The `perch-helper` binary (in `Contents/Helpers/`) authenticates to the listener with a
token written to `~/Library/Application Support/Perch/`.

## Status

This repository is being built milestone by milestone. M1 (skeleton: menu bar, dashboard shell,
SwiftData, local notifications, listener + helper relay) is in place. See the commit history.

## License

TBD.
