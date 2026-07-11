# ismux

Workspace switcher for [Ghostty](https://ghostty.org) on macOS. One layer above
tabs: each workspace is a Ghostty window (with all its native tabs), a floating
rail on the left edge shows workspaces 1–9, and hotkeys jump between them.

Ghostty stays completely stock — full Metal rendering speed, no mux in the
render path. ismux talks to it through the AppleScript dictionary that shipped
in Ghostty 1.3, so it needs **Ghostty ≥ 1.3**.

## Keys

| Key | Action |
|---|---|
| `⌃⌥1` … `⌃⌥9` | Switch to workspace N (empty slot: opens a new window and binds it) |
| `⌃⌥0` | New workspace (next free number) |
| `⌃⌥⇧1` … `⌃⌥⇧9` | Renumber: move Ghostty's front window to workspace N |

Ghostty windows are adopted into free slots automatically, so existing
windows get numbers on launch and new ones (however opened) appear within a
couple of seconds. The rail shows only occupied slots plus a `+` button;
clicking a number switches, clicking `+` adds a workspace. The rail is
draggable. The yellow ring marks the active workspace.

## Build & run

```sh
./make-app.sh
open ismux.app
```

On first switch, macOS asks to allow ismux to control Ghostty
(System Settings → Privacy & Security → Automation if you need to re-enable).

For development, `swift run` works too — the Automation permission then
attaches to your terminal instead of ismux.

## Notes

- Ghostty window ids (`tab-group-…`) don't survive a Ghostty restart, so
  workspace assignments reset when Ghostty quits. Reassign with `⌃⌥⇧N`.
- Ghostty's AppleScript support is a preview feature; if a Ghostty update
  breaks something, all Ghostty calls live in `Sources/ismux/Ghostty.swift`.
- Hotkeys use Carbon `RegisterEventHotKey` — no Accessibility permission
  needed. Change the modifier combos in `main.swift` (`setupHotkeys`).
