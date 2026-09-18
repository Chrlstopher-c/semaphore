# Echo

An iOS control center that ships as a single app: **Vigie** (a ccremote client — agent fleet, decisions, terminal), **EchoHub Mobile** (a local-model client — feed, conversations, machine), **Saily** (a personal capture inbox) and **Duplex** (listening on the phone to whatever the PC is playing) inside one binary. Swift 6 / SwiftUI, compiled from Arch Linux with [xtool](https://github.com/xtool-org/xtool) — no Xcode, no simulator, no Mac. Target: iPhone XS, iOS 18.

## The constraint that shaped the architecture

There is no Mac and no paid Apple developer account here. Free provisioning means every installed app expires after seven days and has to be re-signed and reinstalled by hand. Two separate apps would be two signatures a week; one app is one. So instead of shipping Vigie and EchoHub as two iOS apps, they are merged into a single bundle (`com.echo.labs`) — and Vigie's keep-alive machinery (audio session, location relay, background wakeups) now holds the whole process alive, so an EchoHub generation survives the screen going dark. The weekly-expiry limitation of free signing became the reason the two clients share one process and one lifecycle.

Building without a Mac is the other half: the entire toolchain (Swift SDK for Darwin, xtool) runs on Linux, and the app is signed with a free provisioning profile and side-loaded.

## Toolchain

| Tool | Version | Location |
|---|---|---|
| swiftly + Swift | 6.3.3 | `~/.local/share/swiftly` |
| Darwin SDK | installed | `swift sdk list` → `darwin` |
| xtool | 1.17.0 | `~/.local/bin/xtool` |
| Impactor | AppImage | `~/.local/opt/Impactor.AppImage` |

## Build and deploy to the iPhone

```bash
./build.sh     # produces xtool/Echo.ipa (unsigned)
./deploy.sh    # builds, then opens Impactor — the drag-and-drop stays manual
```

The environment must be set before any `swift` call — the scripts do it; on a bare shell, without these lines `swift` fails on an unrelated message (`libncurses.so.6 not found`):

```bash
. "$HOME/.local/share/swiftly/env.sh"
export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"
export PATH="$HOME/.local/bin:$PATH"
```

## Verify

```bash
swift test         # both cores, on Linux — the only automatic proof
xtool dev build    # the real iOS compilation
```

`swift build` alone proves nothing for the screens: everything touching SwiftUI is under `#if canImport(SwiftUI)`, so it is compiled out on Linux. Only `xtool dev build` compiles the views.

## Duplex and its protocol

Duplex speaks to a desktop app over a frozen wire protocol that lives **outside this repo**: `/mnt/projects/duplex/PROTOCOLE.md`. Both sides conform to it and neither changes it alone. Everything pure — packet header parsing, sequence-gap detection, the audio ring, clock-drift correction, the pairing state machine — lives in `DuplexNoyau` and is covered by `swift test` on Linux. That separation is deliberate: with no simulator and no debugger, those tests are the only automatic proof this project has.

## Free signing

Seven days. On expiry, **reinstall over the top** — never delete the app, the data container goes with it. Architecture and module boundaries: `ARCHITECTURE.md`. State: `STATE.md`.
