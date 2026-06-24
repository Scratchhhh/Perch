# Perch

A native macOS menu-bar app that watches your AI coding agents — **Claude Code, Cursor, Codex** —
and pings you the moment one **finishes** or **needs your input**. No more walking away from a long
task only to find the agent finished ten minutes ago, or quietly stalled on an "Allow this command?"
prompt while you wait.

Perch = a bird on a perch, keeping an eye on your agents. There's an optional mascot to prove it.

<br>

## Privacy first — zero telemetry

Perch is **local-only**:

- It listens on `127.0.0.1` and makes **no network calls beyond localhost**.
- Everything is stored in a local SwiftData database on your Mac.
- **No accounts, no servers, no analytics, no telemetry.** None.

The only processes involved are the app and a small bundled helper that talk to each other over a
loopback socket authenticated with a locally generated token.

<br>

## How it works — three detection channels

Every signal flows into one deduplicating **event bus**, so overlapping reports become a single
notification.

| Channel | What it is | Catches |
|--------|------------|---------|
| **MCP** (`perch_notify`) | A stdio MCP server the agent calls itself. Works in any environment and for all three tools. | "I'm done", "I have a question", "I'm blocked" — wherever the agent runs. |
| **Hooks** (Claude Code) | `Stop` / `Notification` / `SubagentStop` hooks relayed by the helper. | The big one: an agent **blocked on a permission prompt** (MCP can't, the model is frozen). |
| **File-watch** | Passive FSEvents tail of `~/.claude/projects/**/*.jsonl`. | A finished turn when hooks didn't fire. |

Because the hook and file-watch channels share Claude Code's real session id, the deduplicator
collapses them automatically — you get one banner, not three.

<br>

## Requirements

- macOS 14.0 or later (developed against macOS 26 / Swift 6.2)
- Xcode 16+ (Xcode 26 used here)
- Apple Silicon

<br>

## Build & run

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonkim/XcodeGen).
The generated `Perch.xcodeproj` is committed, so you can open it directly:

```sh
open Perch.xcodeproj
```

Pick the **Perch** scheme and hit ▶. The app has **no Dock icon** (`LSUIElement`) — look for the bird
in the menu bar.

From the command line:

```sh
# build
xcodebuild -scheme Perch -destination 'platform=macOS' build

# run the tests
xcodebuild -scheme Perch -destination 'platform=macOS' test
```

To regenerate the project after editing `project.yml`:

```sh
brew install xcodegen   # once
xcodegen generate
```

<br>

## Connecting your tools

Open the dashboard (menu bar → **Open Dashboard** → **Settings**) and use the **Integrations**
section. Each tool has a status pill, a **Connect / Remove** button, and a "What changes" disclosure
that shows the exact edit before you make it.

- **Claude Code** — merges hooks into `~/.claude/settings.json` and registers the `perch_notify`
  MCP server in `~/.claude.json`.
- **Cursor** — registers the MCP server in `~/.cursor/mcp.json`.
- **Codex** — adds an `[mcp_servers.perch]` block to `~/.codex/config.toml`.

Perch **always backs up a config before editing it** (`<file>.perch-backup-<timestamp>`), only
touches its own entries, preserves unknown keys, and is fully idempotent — **Remove** is a clean
rollback. Files holding secrets (like `~/.claude.json`) keep their `0600` permissions.

For environments without hooks, each MCP tool offers an optional **prompt snippet** you can copy into
your project rules so the agent calls `perch_notify` on its own. It is never written for you.

<br>

## Features

- **Menu bar**: animated state icon (idle / working / needs-you), live session list, Do-Not-Disturb,
  quick actions.
- **Dashboard**: Sessions, History (full-text search), Stats, Settings, and a Logs screen with export.
- **Stats**: minutes of waiting saved, a day streak, and a 14-day chart.
- **Notifications**: distinct sounds for "done" vs "needs you", action buttons, click-to-focus.
- **Do Not Disturb**: manual toggle and a scheduled quiet-hours window (overnight aware).
- **Mascot** (off by default): a small, draggable, always-on-top bird that reacts to your agents.
- **Launch at login** via `SMAppService`.

<br>

## Packaging a `.dmg`

```sh
scripts/build-dmg.sh
```

This builds a Release `Perch.app` and produces `build/Perch.dmg`. By default it signs the build
ad-hoc ("Sign to Run Locally"), which is enough to run it yourself.

### Code signing & notarization (for distribution)

To distribute Perch to other Macs without Gatekeeper warnings you need an Apple **Developer ID**:

1. **Sign** with hardened runtime (already enabled in the project):

   ```sh
   codesign --deep --force --options runtime \
     --sign "Developer ID Application: Your Name (TEAMID)" \
     build/Release/Perch.app
   ```

   The bundled `perch-helper` and `PerchCore.framework` are inside the app and get signed with it.

2. **Notarize** the `.dmg`:

   ```sh
   xcrun notarytool submit build/Perch.dmg \
     --apple-id you@example.com --team-id TEAMID --password APP_SPECIFIC_PASSWORD \
     --wait
   xcrun stapler staple build/Perch.dmg
   ```

Perch is **not sandboxed** (it needs to read `~/.claude`, write tool configs, run the helper and host
a localhost listener) and uses the **hardened runtime**, which is what notarization requires.

<br>

## Project layout

```
PerchCore/      framework: shared wire types + pure, tested logic
  Wire/         event types, relay message, paths, MCP handler
  Logic/        dedup, settings/MCP/TOML editors, transcript parser, stats, quiet hours
Perch/          the app (menu bar, dashboard, SwiftData, listener, notifiers, integrations, mascot)
PerchHelper/    the perch-helper tool (hook + mcp subcommands)
PerchTests/     XCTest suites
```

`perch-helper` lives at `Perch.app/Contents/Helpers/perch-helper`; integrations write its absolute
path into tool configs.

<br>

## Tests

```sh
xcodebuild -scheme Perch -destination 'platform=macOS' test
```

Covers the settings.json merge/unmerge (preserving foreign keys), the MCP JSON-RPC handling, the
JSON `mcpServers` and TOML config edits, event deduplication, JSONL transcript parsing, the
config-backup round trip, quiet-hours math and the stats calculator.

<br>

## License

TBD.
