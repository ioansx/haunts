# Haunts — workspaces for Ghostty

A haunt is where a ghost spends its time. Haunts gives [Ghostty](https://ghostty.org)
numbered workspaces — one layer above tabs — with a strip in the title bar,
instant hotkey switching, and live Claude Code agent status per workspace.

Ghostty stays completely stock — full Metal rendering speed, no mux in the
render path. Haunts talks to it through the AppleScript dictionary that
shipped in Ghostty 1.3, so it needs **Ghostty ≥ 1.3**.

## Keys

| Key | Action |
|---|---|
| `⌃⌥1` … `⌃⌥9` | Switch to workspace N (empty slot: opens a new window and binds it) |
| `⌃⌥0` | New workspace (next free number) |
| `⌃⌥⇧1` … `⌃⌥⇧9` | Renumber: move Ghostty's front window to workspace N |

Each workspace is one Ghostty window (with its native tabs). Windows are
adopted into free slots automatically. The strip rides the right half of the
focused window's title bar: click a number to switch, `+` to add, drag a
number to reorder (windows shift numbers; the strip stays 1…n). The menu
bar shows the active workspace number, with an amber dot when any agent
needs attention.

## Agent status

Claude Code hooks (`hooks/haunts-agent-status`, registered in
`~/.claude/settings.json`) report each session's state; Haunts matches
agents to workspaces by working directory. Badge colors: blue = working
(pulsing), orange = needs you, green = done (clears when you focus the
workspace), gray = idle.

## Install

```sh
./install.sh
```

Builds, signs, and copies Haunts.app to /Applications. On first switch,
macOS asks to allow Haunts to control Ghostty. For a signing identity that
survives rebuilds (no repeated permission prompts), create a code-signing
certificate named `haunts-dev` in Keychain Access; the build scripts pick
it up automatically.

## Notes

- Ghostty window ids don't survive a Ghostty restart; Haunts remembers each
  workspace's directory and re-adopts windows onto their old numbers, falling
  back to the first free slot. `⌃⌥⇧N` rearranges.
- Ghostty's AppleScript support is a preview feature; all Ghostty calls
  live in `Sources/haunts/Ghostty.swift`.
- Hotkeys use Carbon `RegisterEventHotKey` — no Accessibility permission
  needed. Modifier combos live in `main.swift` (`setupHotkeys`).
