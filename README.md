<div align="center">

<img src="docs/perch-icon.png" width="128" alt="Perch icon" />

# Perch

**macOS menu-bar app that watches local AI coding agents and notifies you when one finishes or needs input.**

[![platform](https://img.shields.io/badge/platform-macOS%2014%2B-black?logo=apple&logoColor=white)](#install)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](#build)
[![binary](https://img.shields.io/badge/binary-universal-success)](#build)
[![license](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![dependencies](https://img.shields.io/badge/dependencies-none-success)](#build)

</div>

## What it does

Perch watches agents you connect (Claude Code, Cursor, Codex) and posts a native
notification when an agent finishes a turn or stops on a prompt (input, permission, or
block). It runs in the menu bar with a session list, history, stats, and settings, and
stores events in a local SwiftData database. It makes no network calls beyond 127.0.0.1.

## How it works

Three input channels feed one event bus that deduplicates, persists, and notifies:

- MCP: a stdio server (`perch_notify`) the agent calls itself. Works for all three tools.
- Hooks (Claude Code): `Stop` / `Notification` / `SubagentStop` relayed by a bundled helper.
- File watch: an FSEvents tail of `~/.claude/projects/**/*.jsonl`.

Hooks and file-watch share Claude Code's session id, so duplicate reports collapse into one
notification. The app and the bundled helper talk over a loopback socket authenticated with a
token generated on the machine.

## Features

- 🐤 Menu-bar icon with idle / working / needs-you states and a waiting-count badge.
- 📋 Sessions list with typical-turn ETA, stuck detection, per-session snooze, and open-in-terminal.
- 📊 Stats: focus saved (union of waiting intervals), context switches avoided, daily streak, 14-day chart, weekly digest.
- 🔔 Notifications: burst coalescing, distinct sounds for done vs needs-you, action buttons, per-project rules.
- 🌙 Do Not Disturb with a scheduled quiet-hours window.
- 🪶 Optional resizable mascot (off by default).
- 🚀 Launch at login via `SMAppService`.

## Install

Download `Perch.dmg` from [releases](https://github.com/Scratchhhh/Perch/releases), open it, and
drag Perch to Applications. The build is ad-hoc signed and not notarized, so on first launch
right-click the app and choose Open, or clear the quarantine flag:

```sh
xattr -dr com.apple.quarantine /Applications/Perch.app
```

The app has no Dock icon (`LSUIElement`); look for the bird in the menu bar.

## Build

Requirements: macOS 14+, Xcode 16+, Swift 6.

```sh
git clone https://github.com/Scratchhhh/Perch.git
cd Perch
open Perch.xcodeproj   # pick the Perch scheme and run
```

Command line:

```sh
xcodebuild -scheme Perch -destination 'platform=macOS' build
xcodebuild -scheme Perch -destination 'platform=macOS' test
```

The project is generated from `project.yml` with [XcodeGen](https://github.com/yonkim/XcodeGen).
Run `xcodegen generate` after adding, removing, or renaming files.

Package a dmg with `scripts/build-dmg.sh`, which builds a Release `Perch.app` and writes
`build/Perch.dmg`. The local build is ad-hoc signed with hardened runtime off so it loads its
bundled framework. To distribute to other Macs, re-enable `ENABLE_HARDENED_RUNTIME` in
`project.yml`, sign with a Developer ID, and notarize the dmg.

## Config

Connect tools from the dashboard: menu bar, Open Dashboard, Settings, Integrations. Each tool
has a Connect / Remove button and shows the exact edit before it runs.

- Claude Code: hooks in `~/.claude/settings.json`, `perch_notify` in `~/.claude.json`.
- Cursor: MCP server in `~/.cursor/mcp.json`.
- Codex: `[mcp_servers.perch]` block in `~/.codex/config.toml`.

Perch backs up a config before editing it (`<file>.perch-backup-<timestamp>`), edits only its own
entries, and keeps unrecognized keys. Remove reverts those entries. Files holding secrets keep
their `0600` permissions.

Notification behavior is set in Settings: sounds, Do Not Disturb, quiet hours, mascot size, and
per-project rules (banner, sound, volume).

## Layout

```
PerchCore/   framework: wire types + pure, tested logic
Perch/       app: menu bar, dashboard, SwiftData, listener, notifiers, integrations, mascot
PerchHelper/ perch-helper tool (hook + mcp subcommands)
PerchTests/  XCTest suites
```

## License

MIT. See [LICENSE](LICENSE).
