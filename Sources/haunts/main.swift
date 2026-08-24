import AppKit
import Carbon.HIToolbox

// Haunts — workspaces for Ghostty.
// ⌘⌥A/S/D/… switches to a workspace (creates a window on an empty slot),
// ⌘⌥⇧A/S/D/… assigns Ghostty's front window to a workspace.

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = Workspaces()
    let hotkeys = Hotkeys()
    var rail: RailController?
    var statusMenu: StatusMenu?

    func applicationDidFinishLaunching(_ note: Notification) {
        model.start()
        rail = RailController(model: model)
        statusMenu = StatusMenu(model: model)
        setupHotkeys()
    }

    private func setupHotkeys() {
        let switchMods = UInt32(cmdKey | optionKey)
        let assignMods = UInt32(cmdKey | optionKey | shiftKey)
        for (i, key) in Workspaces.keys.enumerated() {
            hotkeys.register(id: UInt32(i + 1), keyCode: key.code, modifiers: switchMods) { [model] in
                model.switchTo(i)
            }
            hotkeys.register(id: UInt32(100 + i), keyCode: key.code, modifiers: assignMods) { [model] in
                model.assignFrontWindow(to: i)
            }
        }
        // ⌘⌥0 — new workspace (key code 29 = ANSI 0)
        hotkeys.register(id: 200, keyCode: 29, modifiers: switchMods) { [model] in
            model.addWorkspace()
        }
    }

}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run() // returns only on quit; keeps `delegate` alive
}
