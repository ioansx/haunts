import AppKit
import Carbon.HIToolbox

// Haunts — workspaces for Ghostty.
// ⌃⌥1-9 switches to a workspace (creates a window on an empty slot),
// ⌃⌥⇧1-9 assigns Ghostty's front window to a workspace.

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
        let switchMods = UInt32(controlKey | optionKey)
        let assignMods = UInt32(controlKey | optionKey | shiftKey)
        for i in 0..<Workspaces.slots {
            hotkeys.register(id: UInt32(i + 1), keyCode: digitKeyCodes[i], modifiers: switchMods) { [model] in
                model.switchTo(i)
            }
            hotkeys.register(id: UInt32(100 + i), keyCode: digitKeyCodes[i], modifiers: assignMods) { [model] in
                model.assignFrontWindow(to: i)
            }
        }
        // ⌃⌥0 — new workspace (key code 29 = ANSI 0)
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
